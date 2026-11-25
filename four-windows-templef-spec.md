# Four Windows — Temple-F run window (SPEC, prepared for the parent to apply)

> Do NOT edit the artifact directly from this file — subagents cannot edit
> artifacts. The parent applies this spec. This is the exact content for
> the Temple-F run window in the Four Windows Space.

## Window title

**Temple-F — IMP-VISION temple board sweep**

## Status line

Reference board reproduced live: **50 unconnected / 0 shorts / 2 clearance**
(1026 total). Finish line: **DRC-clean 0/0/0**. Board is NOT DRC-clean,
NOT fab-ready. Harness + boards are in the repo; the workflow file is
awaiting browser-add (see below); family drivers are still to be written,
so now-tier jobs currently report `blocked` (driver missing) until a
driver lands. Respin tier is QUEUED — see below.

## Reference

- Board: Temple-F routed final (`hardware/pcb/temple-f/templef_tfa.kicad_pcb`,
  md5 `af531665acd5dc7b0f543ce80cde5273` — identical to the workspace
  `templef.kicad_pcb` / `templef_route_final.kicad_pcb`).
- Counts verified by fresh DRC on this VM before staging: 50 / 0 / 2.
- The 2 clearance are ONE fenced geometry: J3's south MP tab (GND) sits
  0.05 mm from U13 pads 15/16. Both footprints are anchors — pad-to-pad,
  no copper can change it. Clearance floor for the whole now-tier is 2.
- REC_LED_A is connected — the hardwired recording-LED path is
  electrically complete.
- Correction to the routing log, found while staging: `ROUTING_LOG.md`
  says "1076 total" but its own `drc_routed.rpt` says 1026 and a fresh
  DRC reproduces 1026. 1026 is the verified total. The log's per-group
  tally of the remaining 50 also sums to 46 in prose; DRC (50) is the
  arbiter.

## Matrix — Tier A: buildable NOW (current placement, no footprint moves)

4 families × 6 variants = 24 jobs. A family "beats" the reference with
<50 unconnected at 0 shorts / ≤2 clearance. Tier ceiling: 49 closable
(V3_3 U13.4 is fenced); clearance floor 2 stands.

| Family | Attack | Pool |
|---|---|---|
| `tfa` CAM-bus-first | J3 0.5 mm-pitch single-column escape + 15–25 mm hauls U1↔J3, zone-aware lane planning (SIOC/SIOD already closed proves endpoints reachable) | 13 |
| `tfb` interface-cleanup | I2C ends 5, USB-C 4, U2 north-row 4, PROT 3, I2S 5, LEP 3 — gated A* + DRC-gated pair router on dense-field escapes | 24 |
| `tfc` singles-and-pour | GND pour-neck island + U2 stub pair, CAM_3V3 J3.20, MAG_CAP, EN, CC1, SPK_N, BOOT, I2S_DIN, ILL_G, CAM_CT — must prove a zero-clearance-add join (every authored join so far added clearance and was rejected) | 11 |
| `tfd` case-first | Locked 50×28 pod outline, anchors frozen — win = routes inside the locked outline; if it cannot route, report FENCED with proof, never force it | — |

Variants: `astar-0.1` (route_temple_f.py native grid), `astar-0.05`,
`astar-0.02`, `freerouting-mp3`, `freerouting-mp10` (long window —
Freerouting pass 2 regressed on this board and it writes SES only at
the end), `gated-pairs` (DRC-gated pair router — banked 13 clean in
Stage 5, the proven closer).

Dropped with evidence: soft-penalty retry (64→46 but clearance 8→499,
GND 2→16, reverted in full); `freerouting-mp1` (short runs fail on
time, not routing).

## Matrix — Tier B: GATED respin (QUEUED — NEEDS TREVOR'S RESPIN SCOPE CALL)

The honest next step is a placement respin around J3/U13/U2. That
respin is TREVOR'S SCOPE CALL, still open. No respin board is staged,
no respin job runs. Every entry below reports status `queued`.

| Family | Moves | Must prove |
|---|---|---|
| `tfr1` J3 respin | Re-site J3 (camera FPC) off the U13 pads | Fenced clearance pair closes to 0; J3 escape opens for the CAM 13 |
| `tfr2` U13 respin | Move U13 within the east field, staying temple-front opposite J4 (magnetometer rule holds) | V3_3 U13.4 closable (today: F channels ≤0.45 mm where 0.6 needed, every via site violates); MAG_CAP haul shortens |
| `tfr3` U2 / power-field respin | U2 north-row field, CAM_3V3 via, and/or the GND stitch fencing U13.4 | U2 set + GND pour neck + U13.4 fence open at legal width |
| `tfr4` combined respin | J3+U13+U2 together | DRC-clean 0/0/0 reachable at all in a 50×28 pod |

4 × 6 = 24 queued entries. They unqueue only when Trevor rules the
scope AND a respin board lands in the repo.

## Case-first window (the form factor IS the product)

Pod outline + sensor housing designed first; the board must fit it and
route inside it. 50×28 pod, board 50×28×1.0, pod internals stack 8.45
of 9.10 cavity (tightest 0.20 mm), Lepton carrier stack 9.8 deep
bridge-mounted in a 17×18×11 brow housing (~11 mm, never shrinks),
aviator pod +11.2 above the temple line, wayfarer +2.4 (best stealth
host), magnetometer rule U13 temple-front opposite J4, INMP441
footprint verified exact. Full thermal frames ride Wi-Fi only; BLE
carries a 40×30 radiometric preview at 2 fps + full-res stills.
Honest trade, carried in the window: a locked outline can fence the
routing (IMP-1 v17's fence proofs showed exactly that failure mode),
so a case-first entry is only a win if the board routes inside the
locked outline.

## Links

- Repo: https://github.com/deadbuglabs/imp-vision
- Actions (workflow `Temple-F sweep`, file `.github/workflows/sweep-templef.yml`):
  https://github.com/deadbuglabs/imp-vision/actions
- Live results branch (`sweep-results`, namespaced `results/templef/`):
  https://github.com/deadbuglabs/imp-vision/tree/sweep-results/results/templef
- Live summary JSON:
  https://raw.githubusercontent.com/deadbuglabs/imp-vision/sweep-results/results/templef/summary.json
- Per-job result JSON:
  https://raw.githubusercontent.com/deadbuglabs/imp-vision/sweep-results/results/templef/<run-number>/<family>-<variant>.json
- Harness + matrix design in-repo:
  https://github.com/deadbuglabs/imp-vision/tree/main/tools/sweep-templef
- Boards in-repo:
  https://github.com/deadbuglabs/imp-vision/tree/main/hardware/pcb/temple-f

## Live snapshots

NONE for Temple-F — assessed honestly, not omitted by accident.
`route_temple_f.py` writes no plan.json, no progress.jsonl, no drc.json
(it mutates the board in place per stage and prints a REPORT line to
stdout only, with a hardcoded board path and CELL=0.1). It cannot meet
the A* snapshot contract. Live feed is results JSON per finished job +
final-board artifact replay. A driver that implements the plan contract
is future work; do not show a snapshot feed for Temple-F until one does.

## 24/7 status

- Triggers (once the workflow file is live): `workflow_dispatch` +
  every-4h schedule (`0 */4 * * *`) + push-to-workflow smoke only.
- The workflow file is NOT live yet: the Muse GitHub App cannot
  create/edit `.github/workflows/` (403). It is prepared and validated
  in the workspace — add it via the browser (steps below). Until then
  there is no schedule, no dispatch, no 24/7 run.
- Family drivers (`tools/sweep-templef/<family>/run.sh`) are still to
  be written: now-tier jobs report `blocked` (driver missing) until a
  driver lands. The toolchain smoke job already proves the reference
  DRC on the runner.

## Browser-add instructions (workflow file — parent / Trevor, via github.com)

1. Open https://github.com/deadbuglabs/imp-vision/new/main/.github/workflows/sweep-templef.yml
   (or: repo → Add file → Create new file, path
   `.github/workflows/sweep-templef.yml`).
2. Paste the entire contents of the workspace file
   `~/workspace/sweep-stage-templef/.github/workflows/sweep-templef.yml`
   (validated YAML: name `Temple-F sweep`; triggers `workflow_dispatch`
   + schedule `0 */4 * * *` + push-to-self smoke; matrix job `if:`
   includes BOTH `workflow_dispatch` and `schedule`; aggregate likewise).
3. Commit message: `Temple-F sweep: dispatch + 4h schedule + push smoke (50/0/2 reference)`
   Commit directly to `main` (or a PR — either is fine; direct is what
   the IMP-1 workflow used).
4. Verify:
   a. The file is visible at
      https://github.com/deadbuglabs/imp-vision/blob/main/.github/workflows/sweep-templef.yml
   b. Actions tab lists the `Temple-F sweep` workflow:
      https://github.com/deadbuglabs/imp-vision/actions
   c. The push that added the file triggered the toolchain smoke job
      only (job name `Toolchain smoke (Temple-F DRC + live results)`),
      and it goes green with 50 / 0 / 2.
   d. Its live result appears at
      `https://raw.githubusercontent.com/deadbuglabs/imp-vision/sweep-results/results/templef/<run-number>/toolchain-templef-baseline.json`
      (replace `<run-number>` with the run number from the Actions page).
   e. Only then run the matrix once manually: Actions → `Temple-F
      sweep` → Run workflow (defaults `tfa,tfb,tfc,tfd` — expect 24
      jobs reporting `blocked` until family drivers land; that is the
      honest state, not a failure).
5. Do NOT push this file via the API / connector — it will 403. Browser only.

## What is blocked and by what

- 24/7 run: blocked on the browser-add above (workflow file not in repo).
- Real routing jobs: blocked on family drivers
  (`tools/sweep-templef/tfa|tfb|tfc|tfd/run.sh` — to be written; each
  must parameterize `route_temple_f.py` — hardcoded CELL=0.1 and board
  path — or implement the gated-pairs / Freerouting path).
- Respin tier (24 entries): blocked on TREVOR'S RESPIN SCOPE CALL.
- Live snapshots: blocked on a driver implementing the A* plan contract.
- Nothing here claims fab-readiness or a gate PASS. Finish line is
  DRC-clean 0/0/0; the board sits at 50/0/2.
