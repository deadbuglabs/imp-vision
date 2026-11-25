# Temple-F Routing Log — routing pass 2026-11-20 (finisher follow-on)

Board: templef.kicad_pcb · KiCad 7.0.11 · starting state per LAYOUT_LOG.md FINAL DRC:
176 unconnected / 0 shorts / 2 clearance / items_not_allowed 167 / 645 total.

## Route chosen

Scripted pcbnew routing (route (a) of the brief): power rails first, then I2C,
then signals, REC_LED_A treated as must-route. Freerouting NOT retried — jar is
gone from /tmp and the finisher's evidence says short runs fail on time; the
scripted route is the one proven on IMP-1. JRE 25 at ~/jre25 verified present
(not needed for this route). kicad-cli 7.0.11 verified present at /usr/bin.

## Fences held for the whole pass

- No footprint moves. Anchors frozen: U1, J1–J7, U13, D2, U10, SW1, SW2.
- 0 shorts is a hard floor — any step introducing a short is reverted, not banked.
- Board saved BEFORE every DRC; DRC = pcbnew WriteDRCReport after zone refill.
- The J3-south-tab vs U13 pads 15/16 clearance pair (0.05 mm, both anchors) is
  fenced: copper-only closure attempted; if impossible it stays as the single
  reported fenced item. Neither footprint moves.

## Stage 0 — Baseline verification (DONE)

Snapshot templef_route_stage0.kicad_pcb taken before any change; baseline DRC
re-run on the saved board to confirm the finisher's numbers are the true start.

- Baseline DRC (drc_stage0.rpt, zones refilled, WriteDRCReport) CONFIRMS the
  finisher exactly: **176 unconnected / 0 shorts / 2 clearance /
  items_not_allowed 167 / 645 total.**
- Netclass: single Default — track 0.2 mm, clearance 0.2 mm, via 0.6/0.3 mm.
  GND zones In1/In2: local clearance 0.25 mm. Outline: rect (0,0)–(50,28).
- Unconnected by net (DRC items): V3_3 32 · SYS 16 · GND 9 · CAM_3V3 7 ·
  VBUS_5V 6 · BAT_CELL 6 · I2C_SDA 5 · I2C_SCL 5 · ILL_K 4 · BTN_PTT 3 ·
  BTN_PHOTO 3 · CELL_NEG 3 · EN 3 · 20 nets × 2 · ~28 nets × 1 (incl.
  REC_LED_A 1 — the R18.2→D2.2 hop).
- **Keepout geometry measured, not assumed:** U1's footprint rule area acts in
  board space as the band **y ≥ 20.75 mm, x ≤ 44 mm** on F.Cu/In1.Cu/B.Cu
  (In2.Cu is NOT in its layer set). 50 of the 176 unconnected items are pads
  inside that band. Consequence: every band pad needs a short F.Cu escape —
  ~+1 items_not_allowed per band pad connected is unavoidable copper-only
  cost; escapes are kept minimal and In2.Cu (keepout-free) is used for
  in-band travel where a via pair beats a long in-band run. items_not_allowed
  will rise; it is reported, not chased (per brief).
- **The 2 clearance items are pad-to-pad, both anchors, no copper involved:**
  J3 MP pad (GND) @(46.90, 22.15) sits 0.05 mm from U13 pad 15 (NC)
  @(47.95, 23.325) and U13 pad 16 (I2C_SDA) @(47.45, 23.325). No track or via
  can change pad-to-pad distance → **FENCED for the whole pass**, exactly the
  one item the brief allows to remain. Routing I2C_SDA to U13.16 does not
  affect it.
- U13 itself (x ≥ 46.9) is OUTSIDE the keepout x-range (≤44) — its pads route
  clean; only its GND neighbour J3 MP needs care (stub must run west/north,
  away from U13 pads).

## Stage 1 — GND remainder (9 items): stub+via to the In1/In2 pours (DONE)

Router: route_temple_f.py — grid A* (0.1 mm cells, 4 layers), rasterized
per-net copper masks, foreign copper dilated by clearance+width/2 as a soft
obstacle, keepout band as per-cell penalty (In2 exempt), DRC gate per stage.

- First gndfix run was RIPPED UP and redone: it created 3 new clearance items
  (J3.19 stub clipped J3.18; C18.2 stub clipped a J5 no-net MP pad — root
  cause: no-net pads were missing from the obstacle model; now stamped as
  foreign to all nets) and missed J3's north MP pad (two J3 pads share the
  number "MP"; the DRC parse now keys pads by coordinates).
- Two pads needed hand-laid escapes after A* clipped neighbours twice:
  J3.19 — west stub in its pad row, north in the x=42.65 channel (0.225 mm
  clear of both TP12 and the J3 pad row), via at (42.40, 9.30);
  U13.9 — 0.20 mm track on the y=25.325 centreline (the channel between
  U13.10 and the south pad row is exactly 0.65 mm: 0.2+0.25+0.2 does not
  fit, 0.2+0.2+0.2 does), via at (48.55, 24.90). Both pre-checked against
  every F.Cu foreign pad rect before committing.
- **Stage 1 DRC (drc_stage1.rpt): 167 unconnected / 0 shorts / 2 clearance /
  items_not_allowed 183 / total 664.** Full class diff vs baseline: ONLY
  unconnected 176→167 (all 9 GND items closed), items_not_allowed 167→183
  (+16 band escapes, expected — see Stage 0), copper_edge_clearance 14→15
  (+1: U13.9's stub leaves a pad 0.525 mm from the east edge — same
  unavoidable class as the finisher's U13.11 stub already in baseline),
  hole_near_hole 4→6 (new vias near existing holes). Clearance = exactly
  the fenced J3/U13 pair; zero new clearance, zero shorts.
- Snapshot: templef_route_stage1.kicad_pcb.

## Stage 2 — Power rails (DONE, with a straggler list)

Three attempts, each gated:
1. Soft-obstacle A* at 0.4 mm: unconnected 167→96 but **clearance 2→41** —
   RIPPED UP. Root cause: wall-hugging grid paths land ~0.03 mm short of
   true clearance (values clustered 0.15–0.196), and the cluster model
   over-merged adjacent same-net pads (bbox stamps touching: U2 SYS pads
   9/10/11 read as one cluster while DRC kept pad 11 separate).
2. Hard-obstacle A*: clearance exploded to 153 — a tuple bug in the
   goal-exemption (`(li,ni,nj)` tested against a set of `(j,i)` pairs) made
   pad-only target clusters unreachable and paths grazed everything.
3. Hard A* + fixes (exemption repaired; cluster labelling eroded +
   4-connectivity; obstacles rebuilt as an exact distance transform instead
   of disc dilation, which had over-sealed narrow channels by ~0.1 mm —
   U13.2's legal 0.25-clearance channel read as walled): **the keeper.**

Result by net (0.4 mm trunk, then 0.3/0.25/0.2 hard fallbacks per net):
SYS, VBUS_5V, BAT_CELL, CELL_NEG, CELL_POS, ILL_K fully connected.
**Stage 2 DRC (drc_stage2.rpt): 97 unconnected / 0 shorts / 8 clearance /
items_not_allowed 199 / total 723.** Clearance 8 = 2 fenced + 6 marginal
(0.175-class, pad-row escapes from attempt 3's trunk — repair-pass list).
Edge clearance 15→30 (fallback routes hugging the south edge; noted,
repair pass will trim what it can). Remaining power stragglers, all
dense-field pads, carried to the final repair pass: V3_3 — U13.2, U13.4
(3 items); CAM_3V3 — J3.20, J3.2 (2 items); SYS — 1 item; PROT_VDD_F —
1 item (DRC count; the mask cluster model reads it as 3, DRC wins).
Snapshot: templef_route_stage2.kicad_pcb.

## Stage 3 — I2C + camera control (DONE — copper laid, model blind)

The stage laid real copper (mask cells: SDA 415→841, SCL 410→841, SIOC
247→732, SIOD 247→950, vias added) but the router's own cluster report
read 6/6/3/3 clusters left throughout: the eroded-label cluster model
splits connections KiCad counts as joined (via-centre and edge-touch
cases), so route_net re-routed already-joined pads until its attempt cap.
DRC is the arbiter: **93 unconnected / 0 shorts / 8 clearance / 199
items_not_allowed** (drc_stage3.rpt). I2C remainder is near-miss stubs
(SDA: U1.34 sits one stub-length off a track end; the {J7.9, U13.16} pair
is joined to each other but not the trunk). Snapshot:
templef_route_stage3.kicad_pcb. Lesson recorded: trust DRC per-net
pair lists over the router's cluster model from here on.

## Stage 4 — Signal nets (DONE)

**Stage 4 DRC (drc_stage4.rpt): 71 unconnected / 0 shorts / 8 clearance /
199 items_not_allowed / total 1029.** Snapshot: templef_route_stage4.kicad_pcb.
Clearance unchanged (no new clips). Two systematic defects identified
from the DRC pair list, both in emit geometry, not in search:
(1) paths ending in a layer change leave the last hop unlaid — the via
lands beside the pad (EN via↔TP6.1, CAM_3V3 via↔J3.20); (2) paths ending
on a pad's bounding-box corner cell stop ~0.14 mm short of the real
(roundrect) copper — the recurring 0.1414 mm fragments, REC_LED_A's
D2.2 stub among them. GND REGRESSED +2: signals-stage In2 tracks severed
a narrow In2 pour neck (zone↔zone split + one F stub islanded).

## Stage 5 — Repair pass (in progress)

Step 1 (bridges) DONE: DRC-driven bridge script closed 7 near-miss items
(V3_3 F/B pair, CAM_3V3, SYS, **REC_LED_A — the hardwired recording-LED
path is now electrically complete**, ILL_A1, ILL_A2, BOOT). Gate after
bridges: **64 unconnected / 0 shorts / 8 clearance / 199 items_not_allowed**
(drc_stage5.rpt; snapshot templef_route_stage5.kicad_pcb).

Step 2 (soft retry) TRIED AND REVERTED IN FULL: retry flavour
(soft_pen 60, extra 0) cut unconnected 64→46 but clearance exploded
8→499 and GND unconnected ballooned 2→16 (soft paths plowed the pour
necks and hugged every pad row). Board restored from the stage-4
snapshot and the bridges replayed deterministically — gate re-verified
at exactly 64/0/8/199. Lesson: on this board soft mode is not a repair
tool; every further route is hard-geometry or hand-laid and verified
segment-by-segment against the distance transform before it is banked.

Remaining pool after bridges (64): ~40 pad↔pad pairs (CAM bus U1↔J3,
LEP U1↔J7, CHG/PROT/I2S clusters, USB-C A/B pairs, I2C chain ends,
U13.2/U13.4), ~15 bridge-skipped near-misses (straight shot failed the
0.20 mm check — need a jog or a nearest-point drop), the GND In2 island
pair + GND F-track pair, and the 5 banked Stage-2 clearance segments.

## Stage 5 (cont.) — gated pair router, emit fix, VM loss, hand routes

- Ungated pair router (verify-before-bank against the distance
  transform): cut unconnected to 33 on paper but banked vias at
  unchecked positions (endpoint vias were verify-exempt; the model is
  also blind to zone fills) — clearance 8→261, GND 2→11. REVERTED to
  the stage-5 snapshot in full.
- DRC-GATED pair router (real WriteDRCReport after every tentative
  route; bank only if unconnected drops with shorts 0, clearance ≤8,
  hole ≤6, edge ≤+1): **13 routes banked clean** (BTN_PTT U1.28,
  BTN_PHOTO ×2, PROT_VDD_F, EN U1.3→C9.1, CAM_SIOC, CAM_SIOD,
  I2C_SDA ×2, I2C_SCL ×1, ILL_A2, BATT_ADC, CHG_PGOOD U1.33→R7.1).
  **Gate: 51 unconnected / 0 shorts / 8 clearance / 199 items_not_allowed
  (drc_stage7.rpt; snapshot templef_route_stage7.kicad_pcb).**
- Bridge re-run on stage-7 pairs: 0 (the remaining near-misses need
  jogs, not straight shots).
- The VM was REPLACED mid-pass: /tmp (scripts, logs, bank file) wiped
  and KiCad uninstalled; the system's package replay restored KiCad
  7.0.11 on its own. The killed dual-mode run banked nothing — board
  verified byte-equivalent in DRC terms to the stage-7 state before
  work resumed. All tooling moved into work/ (durable) from here.
- Two further gated A* variants banked ZERO: distance-sorted fudge
  (every candidate either A*-failed or was rejected — e.g. PROT_CS
  U3.2→trunk reached unc 50 only with clearance 45 / hole 18, i.e. the
  search model's blindness to zone fills and via clearances is the
  binding constraint, not search effort) and B/In2-weighted fudge.
- Hand-laid batch 1 (gated): **V3_3 U13.2 BANKED** — F stub east from
  the pad, via at (47.65,24.5), B.Cu run north to the (49.15,22.75)
  trunk via. Gate: **50 unconnected** (drc_now.rpt state). GND U2 stub
  join (straight + south-detour variants) connects electrically but
  adds clearance (crosses U2.7's row / south lane grazes) — rejected
  both. CAM_3V3 J3.20 via-B (two via sites): connects, +1..+3
  clearance/hole — rejected both. V3_3 U13.4 via-B: connects, clearance
  15 / hole 13 — rejected; U13.4's fence is measured in the final
  report (every via site in reach violates a U13 pad rect or the
  C17/C18 GND via's hole clearance; every F channel is ≤0.45 mm wide
  where 0.6 mm is needed).
- Hand-laid batch 2 (gated, all rejected, state intact): EN TP6 via
  In2 (+14 clearance — In2 pour conflicts), LEP_CS ×3 (fragment chain
  authored from the track inventory; the y=9.85 east run crosses the
  cap field at +42 clearance), BOOT west strip (+21), I2S_DIN B run
  (+108 — B.Cu mid-board is far denser than the masks suggested),
  ILL_G (+8). Lesson banked: blind hand-authoring without a full local
  obstacle map wastes gate cycles; the residue needs either a
  zone-aware router or a placement respin, both outside this pass's
  constraints.
- A third gated A* variant (F/B-only layers, via_cost 300) was killed
  by the SECOND VM replacement of the pass; its log shows zero banked
  before the kill and the board re-verified clean at 50/0/8/199
  afterwards. Not re-run: three A* parameterizations had already
  converged on the same residue.

## Stage 6 — Clearance re-lays (DONE)

The five Stage-2 marginal items shared one cause: 0.4 mm power escapes
passing 0.373 mm from the neighbouring pad rect (0.373 − 0.2 half-width
= 0.175 net). Each segment was ripped and re-laid at identical geometry
in 0.2 mm, gated with unconnected required not to rise and clearance
required to drop: BAT_CELL (U2.3 escape), SYS (U2.10 escape), V3_3
(U13.13, U8.12, U11.7 escapes) — **all five banked, clearance 8 → 2.**
The remaining 2 clearance items are the fenced pair (J3 MP tab ↔
U13 pads 15/16, 0.05 mm, both anchors, pad-to-pad — no copper can
change it).

## FINAL STATE (drc_routed.rpt, board saved as templef.kicad_pcb)

**50 unconnected / 0 shorts / 2 clearance / 199 items_not_allowed /
1076 total violations.** From the finisher's 176 / 0 / 2 / 167 / 645:
126 of 176 unconnected closed, shorts never above 0 at any banked
step, clearance back to exactly the one fenced geometry.
items_not_allowed rose 167 → 199: +32, all of it rule-area crossings
by mandatory escapes out of the ESP32 antenna-keepout band (50 of the
baseline 176 unconnected were pads inside that band; every legal
escape crosses the rule area on F/In1/B or pays vias on In2).
**REC_LED_A is connected — the hardwired recording-LED path
(R18.2 → D2.2) is electrically complete.**
Snapshot: templef_route_final.kicad_pcb. Tooling preserved in work/
(tf_drc.py, tf_hand.py, tf_pairs4.py, route modules + gate logs).

### The remaining 50, with the measured reason for each group

- **CAM bus, 13 items** (HREF, PCLK, XCLK, D0–D7, RESET U1↔J3;
  PWDN R17.1↔J3.18): the J3 single-column escape (0.5 mm pitch,
  0.2 mm inter-pad gaps) plus 15–25 mm hauls to U1's east/north edge
  pads. Every candidate across four A* parameterizations and
  hand-authored lanes either failed to connect at legal width or was
  DRC-rejected for clearance/hole additions; the two CAM nets that
  did close (SIOC, SIOD) prove the endpoints are reachable in
  principle — the remaining 13 need lane planning against the full
  obstacle field (zone-aware router) or a J3-area placement respin.
  Both are outside this pass's constraints (no footprint moves).
- **V3_3, 1 item — U13.4, FENCED with measurements:** its F escapes
  west are walled by CAM_3V3's via at (45.95,24.45) and U13.3's rect
  (free channel 0.45 mm where 0.6 mm is needed); every via site in
  reach violates U13 pad 3/5/6 rects by 0.05–0.15 mm or the
  C17/C18 GND via's hole clearance (best site 0.65 mm vs 0.85 mm
  required); the east side is pocketed by GND stitch copper
  (via at (48.575,24.35) + tracks at y 24.35/25.325 + U13.12's pad).
  A hand B-route was emitted and DRC-rejected (clearance 15,
  hole 13). Closing it needs a respin (move CAM_3V3's via or the
  GND stitch) — placement is frozen in this pass.
- **GND, 2 items** (In2 zone island + the U2.6/U2.8 stub pair): the
  signals stage's In2 tracks severed a narrow pour neck. Both
  authored joins (straight along the U2 row, south detour) connect
  electrically but add 1–3 clearance items (U2.7 CHG_PGOOD sits on
  the direct line; the detour grazes the south lane) — rejected to
  hold the 0-shorts/clearance floor.
- **I2C chain ends, 5 items** (SCL: U1.35↔stub, U1.35↔U8.13,
  J7.10↔U8.13; SDA: U13.16↔J7.9, stub↔J7.9): last hops inside the
  U1 west-edge field and the J7 0.5 mm-pitch row; straight bridges
  failed the 0.20 mm check and gated A* attempts were rejected.
- **USB-C pairs, 4 items** (DP_C/DN_C A↔B↔D1): the A/B pad hop must
  round the J1 end at 0.65 mm pitch; gated attempts rejected.
- **U2 north-row set, 4 items** (CHG_ILIM, CHG_ISET, CHG_TMR,
  CHG_PGOOD U2.7): 0.5 mm-pitch QFN edge escapes; the same wall that
  fenced the Stage-2 fallbacks.
- **PROT set, 3 items** (CS, OD, OC across U3/U4/R10): the single
  near-success (PROT_CS U3.2→trunk) cost clearance 45 — the cluster
  is boxed by its own neighbours at legal width.
- **I2S set, 5 items** (BCLK ×2, WS ×2, DOUT): U1↔U11↔U10 triangle;
  hand B-run for the related DIN net cost +108 clearance — the
  mid-board B field is saturated.
- **LEP set, 3 items** (MISO, SCK U1↔J7; CS R31.1 tap): J7 row
  escapes plus long hauls; the authored LEP_CS chain cost +42
  clearance across the cap field.
- **Singles, 8 items:** CAM_CT (C12.1 B↔U7.5, mid-board cross);
  CAM_3V3 J3.20 (connects at two via sites, each +1..+3
  clearance/hole — rejected); MAG_CAP (C27.1↔U13.10, a 26 mm
  diagonal haul); EN TP6.1 (In2 run costs +14 vs the pour);
  CC1 (R1.1↔J1.A5, J1 field); SPK_N (J4.2↔U11.10); BOOT R14.1
  (west strip costs +21); I2S_DIN R24.1 (B run costs +108);
  ILL_G R29.2 (+8 on the authored run).

No fab-readiness claim is made: 50 unconnected items remain open.
The board is DRC-stable at the numbers above, every banked step was
gated on a fresh WriteDRCReport, and no footprint was ever moved.
