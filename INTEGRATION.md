# IMP-VISION — CAD integration pass (2026-11-20)

The electronics go into the frames. Prior CAD was frame shells with
ghost envelopes; this pass models the temple-f pass-1 product stack
as real blocks (board, WROOM module, PureThermal Micro + Lepton 3.5,
cells, transducer, buttons) seated in the aviator, wayfarer and
Reticle, with the bridge/brow sensor clusters at real part sizes and
FOV cones ray-checked against the frame meshes.

Files: `glasses_integration_cad.py` (models + checks, report in
`integration_report.txt`), `render_integration_sheets.py` (sheets).
Sheets: `glasses-pod-internals-techsheet.png`,
`glasses-aviator-integration-techsheet.png`,
`glasses-wayfarer-integration-techsheet.png`,
`glasses-reticle-integration-techsheet.png`.

**Method.** Component blocks use the sizes in
`designs/temple-f/DESIGN.md` plus datasheet figures (WROOM-1
25.5 × 18 × 3.1; PureThermal Micro 12.2 × 14 × 1.0; socket 1.6;
Lepton 3.5 10.5 × 12.7 × 7.2 → carrier stack 9.8 deep; OV2640 head
8.5 × 8.5 × 5). Sensor housings are modelled as outer solids with a
window cut; interior clearances are computed on a 1.2 mm wall basis
(outer minus wall vs carrier). FOV: trimesh ray casting, 16 boundary
rays on the elliptical spec cone + the axis ray, per sensor, against
frame + glass + housing + pod shells; hits ≤2 mm count as window
vignetting, beyond that as occlusion. All overall dims are read back
from the exported STLs with trimesh. FOV inputs: Lepton 57° H × 44°
V; OV2640 stock lens ≈66° diagonal → 53° H × 41° V.

## Pod internals — FITS

Shell 55 long × 31 tall × 11.5 thick, 1.2 walls, cavity
52.6 × 28.6 × 9.10. Board 50 × 28 × 1.0 sits with 1.3 mm/end and
0.30 mm/side to spare. Thickness stack at the module:

| Layer | mm |
|---|---|
| Cell (402025-class pouch, 4.0 × 20 × 25) | 4.00 |
| Gap | 0.35 |
| PCB | 1.00 |
| ESP32-S3-WROOM-1 module | 3.10 |
| **Stack total / cavity** | **8.45 / 9.10** |

Module face to shell: 0.45. **Zero internal overlaps** (bbox audit
over board, module, cell, power band, IMU pair, INMP441, USB-C,
transducer, both switches + caps). Underside button caps stand
1.4 proud of the shell (overall pod height 32.8 at the caps).
Tightest clearance in the pod: **0.20 mm**, twice — cell back to
cavity wall, and transducer to board edge.

Two placement notes: the pod-local cell is the short 25 mm
(~180 mAh class) pouch because the bone transducer takes the rear
14 mm of the pod; the 34 mm (~250 mAh) cell rides in the opposite
temple, the split-cell arrangement DESIGN.md already specifies. The
Lepton carrier stack (9.8 deep) does **not** live in the pod — it is
bridge-mounted; the pod sheet draws it alongside for height
comparison only.

## Aviator — FITS, with the pass-1 posture cost stated

Overall (trimesh) **142.5 W × 53.4 H × 149.4 L** vs the form
study's 135.6 × 53.4 × 139.2. The +6.9 width is the pods
(3.45/side); the +10.2 length is the Lepton housing standing proud
of the frame front — temple length itself is unchanged.

- Pod at the temple front: stands **+11.2 above the temple top
  line** and ~13 below it. This is the F-prototype lump DESIGN.md
  open decision #4 already accepts; it is not a stealth fit, and
  nothing in this pass pretends otherwise.
- Bridge cluster: the centre block widens 13 → 20 to carry the
  housing (17 × 18 × 11, z 1.2–12.2). Lepton stack inside on the
  1.2-wall basis: **0.80 top/bottom, 1.20 sides**; lens face
  recessed 0.4 behind the housing front.
- **Camera relocated**: bridge centre → right rim top-inner corner.
  The 12.2 mm carrier consumes the centre block; a 9 mm camera head
  cannot share it. Rec dot (Ø1.0, flush) moves onto the housing
  front face — still at the bridge, still hardwired per DESIGN.
- 940 nm studs stay in the rim top edge at the Recon pass-3
  placement (±52, 24.6).
- FOV: **Lepton cone clear, camera cone clear** — 0 occluded,
  0 window-vignetted of 17 rays each.
- Tightest clearance: **0.20** (inside the pod, above); tightest
  frame-side: carrier-to-housing **0.80**.

## Wayfarer — FITS, best stealth host confirmed

Overall **140.1 W × 49.1 H × 150.7 L** vs 136.2 × 46.7 × 140.3.
Same cluster as the aviator (block widened to 20, housing
z 1.5–12.5, lens recess 0.4, carrier 0.80/1.20, camera to the right
rim corner, studs at ±50, 22.6). The pod adds only **+2.4** to
frame height — the chunky acetate temple line swallows the lump
better than any other stealth style, as the form study predicted.
FOV: **both cones clear**, 0/17 occluded or vignetted. Tightest:
**0.20** (pod) / **0.80** (carrier-to-housing).

## Reticle — FITS, brow bar detailed as a housing

Overall **144.5 W × 47.0 H × 158.2 L** (combiner forward), temple
141.0 — matches the form study's depth exactly.

- The brow bar's centre segment is now a real sensor housing,
  **36 × 18 × 11.5** (z −2 to 9.5). It grew 14 → 18 tall against
  the first sketch: the 14-tall carrier needs its 0.80 top/bottom
  on the 1.2-wall basis. Inside: Lepton right of centre (lens face
  z 9.0, recessed 0.5), camera left (gap camera-to-carrier 4.65),
  rec dot flush on the housing face, studs ×4 on the bar as drawn.
  The old centre bridge block is deleted — the housing replaces it.
- Combiner arm at production intent: **Ø4.4 hinge pin** with end
  caps, twin brow-side knuckles with the arm knuckle between,
  clamp block + 2 bolts to the bar; **slide rail 20 long, carriage
  8, end stops both ends → ~10 mm usable eye-relief travel** (the
  design intent figure). Park position (+110° about the hinge):
  **0.0 mm³ bbox overlap** with the brow bar outside the hinge
  mount zone — the parked optic clears.
- Pods in both temples with boards inside; the drawn swell grows
  8 → **11.5 thick** (the product pod thickness, see below).
- FOV: **both cones clear**, 0/17. Tightest: **0.20** (pod) /
  carrier-to-housing **0.80** top/bottom (5.70 to the right wall).

## What does not fit — stated, not smoothed over

1. **The pod is not the drawn swell.** The design set's Tech swells
   are drawn 8 thick; the real stack needs a 9.10 cavity → an 11.5
   shell. Every integration model uses 11.5. At 8 the stack
   interferes by ~2.8 (cavity ≈5.6 vs stack 8.45).
2. **The flex zone is a respin away.** The stealth temple zone
   (48 × 7.2 × 4.2) vs the pod stack (8.45 thick, 28 tall): the
   module pod misses it on every axis, as DESIGN.md already says.
   The ranking below is what closes it.
3. **The Lepton brow is visible.** 9.8 of stack + housing puts the
   lens face ~10–11 mm in front of the donor frames' front plane.
   On the stealth line that reads as a Recon brow block (pass 3's
   direction, at real depth); there is no placement that hides a
   Lepton behind a 2.4 mm bridge block.

## Flex respin — what must shrink first (ranked)

Target: the 4.2-thick flex zone. Current pod stack: 8.45.

1. **WROOM module → bare ESP32-S3.** The module is 3.1 of the 8.45
   (37%). Bare die + RF/passives ≈ 1.0–1.2 → **saves ~2.0**, and
   frees the 25.5 × 18 plan area. The single biggest win; the cost
   is the RF design risk pass 1 deliberately deferred.
2. **Split / thin the cell.** 4.0 pouch → two 2.0–2.5 pouches, one
   per temple (the split-cell arrangement is already the design)
   → **saves ~1.5–2.0** of local stack.
3. **Transducer off the board's plan.** On flex it moves to the
   temple tip on its own tail; the rear-plan contention disappears
   and the full-length 34 mm cell fits its temple again.
4. **PCB 1.0 rigid → 0.6 flex / rigid-flex.** Saves 0.4 and lets
   the stack fold around the temple curve.
5. **USB-C receptacle (3.3 tall on the board face) → low-profile
   or contact charging.** Saves up to ~1.9 locally at the front
   end; last because it touches the service/charge story.

Items 1 + 2 + 4 recover ≈ 4.15–4.4 → stack ≈ 4.1–4.3, i.e. the
respin closes on the 4.2 zone **only if both 1 and 2 happen**. The
Lepton stack does not shrink at all — it is not in the temple; the
flex frames carry it in a brow housing whose ~11 depth is set by
the part, on every line including stealth.
