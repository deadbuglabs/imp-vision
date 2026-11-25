#!/bin/bash
# Run one Temple-F sweep variant for one family.
#   run_variant.sh <family> <variant> <run_number> <run_id>
# Temple-F adaptation of the IMP-1 tools/sweep/run_variant.sh. Differences:
#   - Reference board: Temple-F routed final, 50 unconnected / 0 shorts /
#     2 clearance (md5 af531665acd5dc7b0f543ce80cde5273). The 2 clearance are
#     ONE fenced geometry (J3 south MP tab 0.05 mm from U13 pads 15/16,
#     both anchors, pad-to-pad). Placement gate therefore allows clearance
#     == 2 and blocks only shorts > 0 or clearance > 2.
#   - Family boards live at hardware/pcb/temple-f/templef_<family>.kicad_pcb
#     with name-matched .kicad_pro siblings. Now-tier families (tfa-tfd)
#     share the reference placement; the family identity lives in the
#     driver strategy, not the copper.
#   - Gated respin families (tfr1-tfr4) have NO board staged: their
#     placement respin is Trevor's open scope call. They report status
#     "queued" with that reason and burn no router time.
#   - NO live snapshot watcher: route_temple_f.py writes no plan.json,
#     no progress.jsonl and no drc.json — it mutates the board in place
#     per stage and prints a REPORT line to stdout only, with a hardcoded
#     board path and CELL=0.1. It cannot meet the A* snapshot contract
#     (see tools/sweep-templef/README.md). Live feed is results JSON +
#     final-board replay only. Do not start snap_watch.py here; a driver
#     that implements the plan contract is future work, not claimed.
#   - This harness owns: baseline DRC + placement gate, final DRC, verdict
#     vs the 50/0/2 reference, results JSON. It never fails the job on a
#     blocked, queued or no-beat result; those are results, not errors.
#     Hard toolchain failures (pcbnew missing, DRC crash) exit non-zero.
set -u
FAMILY=$1; VARIANT=$2; RUN_NUMBER=$3; RUN_ID=$4
ROOT=$(pwd)
OUT=$ROOT/out
mkdir -p "$OUT"
BOARD_SRC=$ROOT/hardware/pcb/temple-f/templef_${FAMILY}.kicad_pcb
PRO_SRC=$ROOT/hardware/pcb/temple-f/templef_${FAMILY}.kicad_pro
RESULT=$OUT/${FAMILY}-${VARIANT}.json

finish() { # finish <status> <reason> [counts.json] [baseline.json]
  local status=$1 reason=$2 counts=${3:-} base=${4:-}
  local args=(--family "$FAMILY" --variant "$VARIANT" --run-number "$RUN_NUMBER" --run-id "$RUN_ID" --status "$status" --reason "$reason" --out "$RESULT")
  [ -n "$counts" ] && args+=(--counts "$counts")
  [ -n "$base" ] && args+=(--baseline "$base")
  [ -f "$OUT/board.kicad_pcb" ] && args+=(--board "$OUT/board.kicad_pcb")
  python3 tools/sweep-templef/write_results.py "${args[@]}"
  echo "RESULT $status: $reason"
}

# --- 0. Gated respin families: QUEUED, no board, no router time ---
case "$FAMILY" in
  tfr1|tfr2|tfr3|tfr4)
    finish queued "QUEUED — placement respin family $FAMILY, needs Trevor's respin scope call (no respin board staged; see tools/sweep-templef/README.md Tier B)"
    exit 0
    ;;
esac

# --- 1. Family board present? ---
if [ ! -f "$BOARD_SRC" ]; then
  finish blocked "family board templef_${FAMILY}.kicad_pcb not in repo yet (family worker has not landed it)"
  exit 0
fi
if [ ! -f "$PRO_SRC" ]; then
  finish blocked "family board present but name-matched .kicad_pro missing (DRC counts would be wrong without project settings)"
  exit 0
fi
cp "$BOARD_SRC" "$PRO_SRC" "$OUT/"
mv "$OUT/templef_${FAMILY}.kicad_pcb" "$OUT/board.kicad_pcb"
mv "$OUT/templef_${FAMILY}.kicad_pro" "$OUT/board.kicad_pro"

# --- 2. Baseline DRC + placement gate (clearance floor is 2, fenced) ---
xvfb-run -a python3 tools/sweep-templef/drc.py "$OUT/board.kicad_pcb" "$OUT/baseline_drc.txt" || { finish blocked "baseline DRC crashed (toolchain)"; exit 1; }
python3 tools/sweep-templef/parse_drc.py "$OUT/baseline_drc.txt" "$OUT/baseline_counts.json"
BASE_UNC=$(python3 -c "import json; print(json.load(open('$OUT/baseline_counts.json'))['unconnected'])")
BASE_SHORTS=$(python3 -c "import json; print(json.load(open('$OUT/baseline_counts.json'))['shorts'])")
BASE_CLR=$(python3 -c "import json; print(json.load(open('$OUT/baseline_counts.json'))['clearance'])")
echo "baseline: unconnected=$BASE_UNC shorts=$BASE_SHORTS clearance=$BASE_CLR (reference 50/0/2)"
if [ "$BASE_SHORTS" != "0" ]; then
  finish blocked "placement gate: baseline has $BASE_SHORTS shorts before any routing" "" "$OUT/baseline_counts.json"
  exit 0
fi
if [ "$BASE_CLR" -gt 2 ]; then
  finish blocked "placement gate: baseline has $BASE_CLR clearance before any routing (floor is the 2 fenced J3/U13 items)" "" "$OUT/baseline_counts.json"
  exit 0
fi

# --- 3. Family driver present? ---
DRIVER=tools/sweep-templef/${FAMILY}/run.sh
if [ ! -f "$DRIVER" ]; then
  finish blocked "family driver tools/sweep-templef/${FAMILY}/run.sh not in repo yet (family worker has not landed it)" "" "$OUT/baseline_counts.json"
  exit 0
fi
chmod +x "$DRIVER" 2>/dev/null || true

# --- 4. Route (driver owns stages; it should call check_failfast.py
#         after each stage and stop early when it cannot beat 50/0/2) ---
# No snapshot watcher: no Temple-F driver implements the plan contract yet.
bash "$DRIVER" "$VARIANT" "$OUT/board.kicad_pcb" "$OUT"
DRIVER_RC=$?
if [ "$DRIVER_RC" != "0" ]; then
  finish blocked "family driver exited non-zero for variant $VARIANT" "" "$OUT/baseline_counts.json"
  exit 0
fi

# --- 5. Final DRC + verdict ---
xvfb-run -a python3 tools/sweep-templef/drc.py "$OUT/board.kicad_pcb" "$OUT/${FAMILY}-${VARIANT}_drc.txt" || { finish blocked "final DRC crashed (toolchain)"; exit 1; }
python3 tools/sweep-templef/parse_drc.py "$OUT/${FAMILY}-${VARIANT}_drc.txt" "$OUT/${FAMILY}-${VARIANT}_counts.json"
UNC=$(python3 -c "import json; print(json.load(open('$OUT/${FAMILY}-${VARIANT}_counts.json'))['unconnected'])")
CLR=$(python3 -c "import json; print(json.load(open('$OUT/${FAMILY}-${VARIANT}_counts.json'))['clearance'])")
SHORTS=$(python3 -c "import json; print(json.load(open('$OUT/${FAMILY}-${VARIANT}_counts.json'))['shorts'])")
if [ "$UNC" = "0" ] && [ "$SHORTS" = "0" ] && [ "$CLR" = "0" ]; then
  finish done "DRC-CLEAN 0/0/0 (reference was 50/0/2)" "$OUT/${FAMILY}-${VARIANT}_counts.json" "$OUT/baseline_counts.json"
elif [ "$UNC" -lt 50 ]; then
  finish done "routed to $UNC unconnected (reference is 50/0/2; clearance floor 2 stands)" "$OUT/${FAMILY}-${VARIANT}_counts.json" "$OUT/baseline_counts.json"
else
  finish done "routed to $UNC unconnected, did not beat the 50/0/2 reference" "$OUT/${FAMILY}-${VARIANT}_counts.json" "$OUT/baseline_counts.json"
fi
