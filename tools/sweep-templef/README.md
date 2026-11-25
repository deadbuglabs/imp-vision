# Temple-F placement sweep — harness

Parallel sandbox matrix on GitHub Actions
(`.github/workflows/sweep-templef.yml`), adapted from the proven IMP-1
sweep (`tools/sweep/` in deadbuglabs/imp-1, commits ec33efce / 8beaa64f).
Same shape, different reference: each family × variant runs as its own
job on `ubuntu-24.04` with KiCad 7, Java 21, Xvfb and Freerouting 1.9.0
(jar downloaded at runtime from the verified release — no binaries
committed).

## Reference

- Source board: `hardware/pcb/temple-f/templef_tfa.kicad_pcb` (all four
  now-tier family boards are the same copper: the routed final,
  md5 `af531665acd5dc7b0f543ce80cde5273` — verified identical to
  `templef.kicad_pcb` / `templef_route_final.kicad_pcb` in the workspace).
  The `.kicad_pro` sibling must stay name-matched, or KiCad falls back
  to default project settings and the counts inflate.
- Reference counts, reproduced live on this VM before staging
  (pcbnew WriteDRCReport, zones refilled): **50 unconnected / 0 shorts /
  2 clearance / 1026 total** (parse of `docs/drc_routed.rpt` and fresh
  DRC agree exactly).
- The 2 clearance are ONE fenced geometry: J3's south MP tab (GND)
  sits 0.05 mm from U13 pads 15/16. Both footprints are anchors
  (camera FPC position; magnetometer banked at the temple-front end) —
  pad-to-pad, no copper can change it. Clearance floor for the whole
  now-tier is therefore **2, not 0**.
- Finish line: **DRC-clean 0/0/0**. No now-tier job can reach it
  (clearance floor 2 + V3_3 U13.4 fenced, see below); only a respin-tier
  board can. A family "beats" the reference only with <50 unconnected
  at 0 shorts / ≤2 clearance.
- NOTE on the logs: `docs/ROUTING_LOG.md` says "1076 total" in its final
  state, but the `drc_routed.rpt` it cites has header "** Found 1026
  DRC violations **" and a fresh DRC reproduces 1026. The log's 1076
  is wrong; 1026 is the verified total. The log's per-group tally of
  the remaining 50 also sums to 46 in prose (13+1+2+5+4+4+3+5+9
  singles as listed, against "8" stated), leaving 4 items unaccounted
  in the prose breakdown. DRC (50) is the arbiter, not the prose.

## Matrix — Tier A: buildable NOW (current placement, no footprint moves)

Order = most promising first. All four families share the reference
placement; the family identity lives in the driver strategy, not the
copper. Ceiling for the whole tier: 49 closable (V3_3 U13.4 is fenced
with measurements — see tfc/tfr2), clearance floor 2 stands.

Families:

- `tfa` — CAM-bus-first (13 items: HREF, PCLK, XCLK, D0–D7, RESET
  U1↔J3; PWDN R17.1↔J3.18). The biggest pool. Attack: J3
  single-column 0.5 mm-pitch escape + 15–25 mm hauls to U1's east/north
  edge pads, lane-planned against the full obstacle field (zone-aware
  router). Evidence it is reachable in principle: SIOC/SIOD already
  closed on the same J3 field.
- `tfb` — interface-cleanup-first (24 items: I2C chain ends 5, USB-C
  pairs 4, U2 north-row set 4, PROT set 3, I2S set 5, LEP set 3).
  Attack: gated A* variants + DRC-gated pair router on dense-field
  (0.5 mm-pitch QFN / FPC-row) escapes.
- `tfc` — singles-and-pour (11 items: GND 2 — In2 pour-neck island +
  U2.6/U2.8 stub pair; CAM_3V3 J3.20; MAG_CAP 26 mm diagonal haul;
  EN TP6.1; CC1; SPK_N; BOOT; I2S_DIN; ILL_G; CAM_CT). Attack:
  zone-aware pour repair + hand-laid gated lanes. Honest warning:
  every authored join tried so far ADDED clearance (GND +1..3,
  CAM_3V3 +1..3, EN +14, BOOT +21, I2S_DIN +108, ILL_G +8) and was
  rejected to hold the floor — this family must prove a
  zero-clearance-add join or report the item fenced.
- `tfd` — case-first / outline-locked (Family D pattern from IMP-1).
  The glasses form factor IS the product, so the pod outline +
  sensor housing are designed first and the board must fit and route
  inside them: 50×28 pod, board 50×28×1.0, pod internals stack
  8.45 of 9.10 cavity (tightest 0.20 mm), Lepton carrier stack 9.8
  deep bridge-mounted in a 17×18×11 brow housing (~11 mm, never
  shrinks), aviator pod +11.2 above the temple line, wayfarer +2.4
  (best stealth host), magnetometer rule U13 temple-front opposite
  J4, INMP441 footprint verified exact. The board in this family is
  identical to the reference — the axis is the CONSTRAINT (locked
  outline, anchors frozen: U1, J1–J7, U13, D2, U10, SW1, SW2). A
  tfd win = routes inside the locked outline. If it cannot route,
  report it as FENCED with the proof — never force it. (v17's fence
  proofs showed exactly this failure mode: a locked outline can fence
  the routing when 0.375 mm is available against 0.415 mm demanded.)

Variants (router axes, from `route_temple_f.py` evidence):

- `astar-0.1` — grid A* at its native 0.1 mm pitch (route_temple_f.py's
  own grid; the router that took 176 → 50).
- `astar-0.05` — fine raster (IMP-1 proven; v17 evidence says fine
  grazes, but the 0.5 mm J3/U2 fields may need it).
- `astar-0.02` — finest raster, QFN-field exits.
- `freerouting-mp3` — Freerouting 1.9.0, 3 passes (middle).
- `freerouting-mp10` — slowest, most thorough. Long window required:
  LAYOUT_LOG evidence is pass 1: 214 s, 161 → 116 unrouted, pass 2
  REGRESSED to 185, 15-pass run killed at 9 min with no SES written
  (Freerouting writes output only at the end).
- `gated-pairs` — DRC-gated pair router in the tf_pairs4.py style:
  real WriteDRCReport after every tentative route, bank only if
  unconnected drops with shorts 0, clearance ≤8-at-the-time (≤2 now),
  hole ≤6, edge ≤+1. This banked 13 routes clean in Stage 5 — the
  proven closer on this board.

4 families x 6 variants = 24 jobs, max-parallel 20 (last 4 queue).
`fail-fast: false` on the matrix so one family's failure never cancels
the rest — fail-fast lives per job, below.

DROPPED with evidence (do not re-add without new evidence):

- Soft-penalty retry flavour (`retry` in route_temple_f.py, soft_pen
  60): Stage 5 step 2 cut unconnected 64 → 46 but clearance exploded
  8 → 499 and GND unconnected ballooned 2 → 16 (soft paths plowed the
  pour necks and hugged every pad row). Reverted in full. Soft mode is
  not a repair tool on this board.
- `freerouting-mp1`: the shortest Freerouting run; pass 2 already
  regressed on this board and short runs fail on time, not on routing.
- F/B-only A* with via_cost 300: killed by a VM replacement with zero
  banked before the kill — inconclusive, not proven; not a variant
  until a driver run completes it. (Recorded here so nobody re-runs it
  blind.)

## Matrix — Tier B: GATED respin (QUEUED — needs Trevor's scope call)

The logs' honest next step is a placement respin around J3/U13/U2,
and that respin is TREVOR'S SCOPE CALL, still open. These four
families are fully designed but have NO board staged and NO job runs:
every entry reports status `queued` with that reason and burns no
router time. Do not stage a respin board, do not run a respin, until
Trevor rules the scope.

- `tfr1` — J3 respin. Moves: J3 (camera FPC) re-sited off the U13
  pads. Must prove: the fenced clearance pair (J3 MP ↔ U13.15/16,
  0.05 mm) can close to 0, and the J3 single-column escape opens
  enough for the CAM 13.
- `tfr2` — U13 respin. Moves: U13 (MMC5983MA) within the east field,
  staying temple-front and opposite J4 (magnetometer rule holds).
  Must prove: V3_3 U13.4 closable (today every F escape west is
  walled by CAM_3V3's via at (45.95,24.45) and U13.3's rect — free
  channel 0.45 mm where 0.6 mm is needed; every via site in reach
  violates U13 pad 3/5/6 rects by 0.05–0.15 mm or the C17/C18 GND
  via's hole clearance; east side pocketed by GND stitch copper) and
  the MAG_CAP 26 mm haul shortens.
- `tfr3` — U2 / power-field respin. Moves: U2 north-row field,
  CAM_3V3's via, and/or the GND stitch that fences U13.4. Must prove:
  the U2 set (CHG_ILIM/ISET/TMR/PGOOD), the GND pour neck, and the
  U13.4 fence all open at legal width.
- `tfr4` — combined J3+U13+U2 respin. The full honest next step.
  Must prove: DRC-clean 0/0/0 is reachable at all on this schematic
  in a 50×28 pod.

Each gated family takes the same 6 variants when it unqueues:
4 × 6 = 24 queued entries. The workflow inputs accept
`tfr1,tfr2,tfr3,tfr4` but the default family list is the now-tier only.

## Fail-fast (per job)

1. Placement gate: baseline DRC before routing. Shorts > 0 or
   clearance > 2 -> status `blocked`, no routing attempted. (IMP-1's
   gate was clearance > 0; Temple-F's floor is the 2 fenced items.)
2. Stage gate: family drivers call `check_failfast.py <prev_counts.json>
   <cur_counts.json>` after each routing stage. It prints STOP when a
   stage closed nothing while still at >= 50 unconnected, when shorts
   appear, or when clearance grows above the previous stage. The
   driver stops there and reports. Reference thresholds come from
   env `REF_UNCONNECTED` (default 50) / `REF_CLEARANCE` (default 2).
3. Job wall clock: 90 min (`timeout-minutes`) so a hung router dies.

## Family driver interface

A family lands its driver at `tools/sweep-templef/<family>/run.sh`
(executable), called as:

```
run.sh <variant> <board.kicad_pcb> <workdir>
```

- `<variant>` is one of `astar-0.1`, `astar-0.05`, `astar-0.02`,
  `freerouting-mp3`, `freerouting-mp10`, `gated-pairs`. For
  `freerouting-*`, the pass count is the number after `-mp`; use
  `export_dsn.py` / `import_ses.py` in this directory and the jar at
  `tools/freerouting/freerouting.jar` (downloaded by the workflow).
  For `astar-*`, the raster is the number after the dash (mm) — note
  `route_temple_f.py` hardcodes CELL=0.1 and a hardcoded board path,
  so a driver must parameterize it (copy + patch CELL, take the board
  path and workdir as arguments) rather than call it as-is.
  For `gated-pairs`, the driver is a DRC-gated pair router in the
  `work/tf_pairs4.py` style: WriteDRCReport after every tentative
  route, bank only on a clean gate.
- The driver routes the board **in place** and may write stage DRCs
  with `drc.py` + `parse_drc.py`. It must call `check_failfast.py`
  after each stage and stop when it prints STOP.
- The harness runs the final DRC and writes the results JSON; the
  driver must not.
- Drivers must not assume workspace paths, locks, or sibling workers —
  each job is its own runner. No absolute `/home/...` paths.

Until a family's driver is in the repo, its jobs report `blocked`
with the exact reason and burn no router time. (Today: all four
now-tier drivers are still to be written — the harness + boards land
first, drivers follow. The toolchain smoke job already proves the
reference DRC on the runner.)

### Live snapshots: NOT AVAILABLE for Temple-F (assessed honestly)

The IMP-1 A* snapshot contract (`snap_watch.py` + plan.json +
progress.jsonl + stage drc.json) cannot be met by
`route_temple_f.py` as it stands, and no Temple-F driver implements
it yet:

- `route_temple_f.py` writes NO plan.json, NO progress.jsonl, NO
  drc.json. It mutates `templef.kicad_pcb` in place per stage
  (`gnd|power|i2c|signals|retry`), prints a REPORT line to stdout
  only, hardcodes its board path (`D = "/home/hatch/workspace/..."`)
  and CELL=0.1, and depends on numpy/scipy. Its `emit_path` lays
  tracks directly into the pcbnew board; there is no cumulative plan
  object to checkpoint after every link.
- A future driver COULD implement the contract by accumulating the
  plan (add_tracks/add_vias/delete/delete_vias, same schema as
  IMP-1's route17.py) and checkpointing it atomically after every
  link, plus a progress.jsonl line per finished net and a drc.json
  per stage — that is driver work, not done here.
- Until then: NO `snap_watch.py` is started by `run_variant.sh`
  (starting it with no plan file would emit empty geometry-only
  snapshots). Live feed is results JSON per finished job + the
  final-board artifact replay. Do not claim a live snapshot feed
  exists for Temple-F.

## Live results (watcher paths)

Every job pushes its results JSON to branch `sweep-results` as soon as
it finishes (see `push-results.sh` — detached worktree, rebase retry),
namespaced per board so it never collides with IMP-1 or other lines:

- Per job (live): `results/templef/<run-number>/<family>-<variant>.json`
  e.g. `results/templef/12/tfa-astar-0.1.json`
- Toolchain smoke: `results/templef/<run-number>/toolchain-templef-baseline.json`
- Combined summary (written by the `aggregate` job after the matrix):
  `results/templef/summary.json` and
  `results/templef/history/<run-number>-summary.json`

Raw reads (no auth needed, public repo):

```
https://raw.githubusercontent.com/deadbuglabs/imp-vision/sweep-results/results/templef/summary.json
https://raw.githubusercontent.com/deadbuglabs/imp-vision/sweep-results/results/templef/<run-number>/<family>-<variant>.json
```

Result JSON schema `templef-sweep-result/1`: `family`, `variant`,
`status` (`done` | `blocked` | `failfast` | `toolchain-ok` |
`queued`), `reason`, `drc` (`unconnected`, `clearance`, `shorts`,
`total`, per-type counts), `baseline_drc`, `verdict_vs_templef`
(`beat` | `tie` | `no-beat` | `n/a`), `drc_clean` (true only at
exactly 0/0/0), `board_md5`, `finished_utc`.

Each job also uploads its board + DRC report + logs as an artifact
(`result-templef-<family>-<variant>`, 30 days) and writes a job
summary with the DRC numbers.

## Triggers

- `workflow_dispatch` (Actions tab): full now-tier matrix. Inputs
  narrow families / variants if needed (gated `tfr*` families are
  accepted as input but report `queued` until Trevor's scope call).
- `schedule` (`0 */4 * * *`, every 4 hours): same matrix as dispatch.
- Push to `.github/workflows/sweep-templef.yml`: toolchain smoke job
  only (proves install + DRC + live-results commit). The matrix never
  runs on push.

## Workflow file — browser-add only

The Muse GitHub App CANNOT create/edit anything under
`.github/workflows/` (403, lacks Workflows permission). The workflow
file is prepared and validated in the workspace at
`.github/workflows/sweep-templef.yml` (staged alongside this harness
but NEVER pushed via the API) and must be added through the GitHub
web UI. See `four-windows-templef-spec.md` for the exact browser-add
instructions and verification steps. Do not claim the workflow is
live unless it is verifiably in the repo.
