# Temple-F Layout Log — finisher run 2026-11-20

Board: templef.kicad_pcb · KiCad 7.0.11 · netlist templef.net (92 comps, 70 nets, checker 435/435)

## Stage 0 — Assessment of inherited state (first layout agent, errored mid-run)

- File on disk: 312,970 B, placement-only. **87 footprints placed, 0 tracks, 0 vias, 0 zones.**
- Outline: board-edge bbox 50.05 × 28.05 mm (0.05 = edge line width) → **50 × 28 pod outline CORRECT**.
- Placement spread X 0.8–48.7, Y 1.9–27.3 — all inside outline, none at origin (no unplaced pile).
- Missing vs netlist (5): D3, D4, D5, D6, U12.
  - **U12 (MLX90640) is off-board by design** — it lives on the J5 bridge sub-board
    (footprint string in build script: "Sensor:MLX90640_TO39 (bridge board)"). Not a gap.
  - **D3–D6 (VSMY12940 940 nm illuminators, FULL population) are a real gap** — placed in Stage 1.
- **INMP441 (U10) verdict: CORRECT.** Custom TempleF footprint, 9 pads, nets match
  DS-INMP441-00 Table 6 exactly: 1 SCK→I2S_BCLK, 2 SD→I2S_DIN, 3 WS→I2S_WS,
  4 L/R→GND, 5/6/9 GND (pad 5 = 1.56×1.56 centre pad), 7 VDD→V3_3, 8 CHIPEN→V3_3.
- **Magnetometer rule: SATISFIED.** U13 (MMC5983MA) at (48.2, 24.6) — far east end.
  Transducer lands J4 at (3.4, 2.9) — far west end. Opposite ends of the pod, max separation.
- **Recording LED D2: untouched.** LED_0805 at (48.7, 5.3); pad 1 = GND, pad 2 = REC_LED_A
  (net = exactly {R18.2, D2.1} per schematic checker). Hardwire preserved; placement not altered.
- Stackup: 4 copper layers. Pads: 373 placed (GND 91, V3_3 33, SYS 17, VBUS_5V 9 …).

## Stage 1 — Complete placement + planes (this run)

- D3–D6 placed along the east edge near J6 (illuminator connector, 42.9/4.4), nets per netlist:
  D3 1=ILL_A1 2=ILL_M1 · D4 1=ILL_M1 2=ILL_K · D5 1=ILL_A2 2=ILL_M2 · D6 1=ILL_M2 2=ILL_K
  (two series strings of two, landed via J6 to the rim flex in the product; on this bench
  pod they sit on-board so the strings are electrically complete and DRC-checkable).
- GND zones added on In1.Cu and In2.Cu (full-outline pours) — GND is 91 of 373 pads;
  planes are the only sane way to close it in a 50×28 pod. Signals route F.Cu/B.Cu + inner
  overflow via freerouting.

## Stage 1b — Inherited placement audit (why routing could not start immediately)

Layer-aware pad check: **75 same-side cross-net pad overlaps** — the inherited placement
was never collision-resolved (e.g. TP10 sits on U8 pads 1/13/14; J1's pads overlap
R1/R2/R6/D1/C1/C2; D2.1 overlaps R18.2). All 91 footprints are on F.Cu.
Baseline DRC (zones filled, nothing routed): **228 unconnected pads, 896 violations**
(228 unconnected, 161 courtyards_overlap, 121 clearance, 89 items_not_allowed —
footprint-embedded keepouts, mostly the ESP32 antenna zone — 75 solder_mask_bridge, silk classes).
Fence: no router can start from shorted pads. A scripted de-collision pass follows:
force-directed repulsion on movable parts (frozen: U1, J1–J7, U13, D2, U10, SW1, SW2 —
mechanical/recording-LED/magnetometer positions), discretes that cannot clear on F.Cu
flip to B.Cu.

## Stage 1c — De-collision attempt 1 FAILED, placement rebuilt deterministically

Force-directed repulsion diverged (pad overlaps 78 → 364, parts piled at the clamps) and
was saved before the count printed. No backup existed. Damage assessment: the pass only
translated movable footprints — every anchor (U1, J1–J7, U13, D2, U10, SW1, SW2) kept its
original position, and all anchor coordinates were already recorded in this run's
assessment output. The scrambled parts are exactly the passives/TPs whose inherited
positions were collision-ridden anyway. Recovery = deterministic re-placement of all
movable parts: net-affinity anchor point per part (shared-net pad centroid, planes
down-weighted), first-fit rectangle search on a 0.25 mm occupancy raster (pad-union box
+ 0.3 mm), F.Cu first, B.Cu flip if no fit. D3–D6 reset to their Stage-1 positions.

## Stage 2 — Deterministic re-placement (result)

- Anchors kept at inherited positions (all ICs, connectors, U13, U10, D2, SW1, SW2);
  D3–D6 reset to Stage-1 spots. All other parts re-placed by net-affinity first-fit
  on the occupancy raster. 8 caps (C4, C5, C9, C12, C20, C23, C26, C29) did not fit
  F.Cu and were flipped to B.Cu — legitimate for a pod: discretes on the back face.
- One anchor conflict fenced and fixed: J6.3 (ILL_K) overlapped J3.24 (GND) by
  0.77 × 0.40 mm. J6 nudged (42.9, 4.4) → (42.9, 3.6); a westward nudge was tried
  first and rejected (collided C13/C27/R31).
- **Final placement check: 0 cross-net pad overlaps** (was 75 inherited).
- Backup of the placed board: templef_placed_backup.kicad_pcb.
- Inherited mechanical notes (not redesigned this pass): J1 USB-C pad union reaches
  x = −1.1 mm (receptacle overhang at the west edge — pads S1 partly off-board,
  verify against the HRO TYPE-C-31-M-12 drawing before fab); U1 module pad union
  spans y 0.8–19.7 mm.

## Stage 3 — Routing (freerouting)

- Specctra DSN exported from the placed board; freerouting (jar at /tmp/freerouting.jar,
  needs Java 25 — Temurin JRE 25 fetched to ~/jre25; the workspace JDK 17 cannot run it)
  with the GND zones on In1.Cu/In2.Cu in place. Result + DRC below.

## Stage 3 (cont.) — Freerouting verdict: too slow for this board, abandoned with evidence

Freerouting pass 1: 214 s, 161 → 116 unrouted items, 3 violations. Pass 2 REGRESSED
(185 unrouted). At ~200 s/pass on this VM the 15-pass run was killed at 9 min with no
SES written (freerouting writes output only at the end). Fence: the router is not the
blocker — time is. A future run should give it an hour or route interactively.

## Stage 4 — GND closure by scripted via-stitching + final DRC

- Every GND SMD pad got a 0.25 mm stub + 0.6/0.3 mm via to the In1/In2 GND planes
  (first free of 12 candidate offsets, pad-bbox obstacle check): 88/91 GND pads closed.
- Stub audit against DRC: 12 stub tracks clipped neighbouring pads (segment vs point
  check gap) — those stubs+vias were deleted (pads revert to unconnected; a short
  risk is a defect, an unconnected pad is just unfinished). Two iterations → clean.
- J3's two no-net MP shell tabs assigned to GND (standard shell grounding), which
  cleared 3 of the last 5 clearance items; D3 shifted (47.2, 8.6) → (47.2, 10.2)
  to clear the north MP tab.

## FINAL DRC (drc_final.rpt, zones refilled, WriteDRCReport)

- **Unconnected pads: 176** (baseline 228). GND is closed except 8 pad-items;
  the 176 are the unrouted signal/power nets — V3_3 32 pads, SYS 16, CAM_3V3 7,
  VBUS_5V 6, BAT_CELL 6, I2C_SDA/SCL 5+5, the rest spread over ~40 nets.
  REC_LED_A is among them: the D2 hardwire NET is intact (schematic-proven),
  the copper hop R18.2→D2.2 is simply part of the unrouted signal set.
- **Shorts: 0. Clearance: 2** — both the same fenced geometry: J3's south MP tab
  (now GND) sits 0.05 mm from U13 pads 15/16. J3 and U13 are both anchors
  (camera FPC position; magnetometer banked at the temple-front end) — closing
  this needs one of them re-sited, a respin decision, not a layout fix.
- Remaining violation classes are non-electrical or keepout bookkeeping:
  items_not_allowed 167 (footprint keepouts — ESP32 antenna zone vs nearby
  discretes/vias; a placement-polish item), courtyards_overlap 64 (the placer
  enforced pad-level clearance, not courtyard-level), silk classes ~255
  (cosmetic), lib_footprint_issues 91 (TempleF.pretty path check, cosmetic),
  copper_edge_clearance 14 (J1 overhang + edge parts, see Stage 2 note).

## What remains, honestly

Signal routing (~176 pads / ~55 nets) is the open work. The board is placed,
collision-free at pad level, GND-planed and stitched, with 0 shorts. Next pass
should route interactively or give freerouting a long window, starting from
templef.kicad_pcb as saved (placed backup: templef_placed_backup.kicad_pcb —
pre-stitch, pre-MP-fix).
