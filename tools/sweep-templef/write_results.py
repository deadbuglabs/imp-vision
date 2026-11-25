"""Assemble one Temple-F sweep job's results JSON.

Temple-F adaptation of the IMP-1 write_results.py. Differences:
  - Reference is the Temple-F routed final: 50 unconnected / 0 shorts /
    2 clearance (the 2 are ONE fenced geometry: J3 south MP tab 0.05 mm
    from U13 pads 15/16, both anchors, pad-to-pad — no copper can change
    it). Clearance floor is 2, not 0.
  - Schema 'templef-sweep-result/1'; reference key 'templef_reference'.
  - Status 'queued' is a real outcome: a gated-respin family (tfr1-tfr4)
    whose board is not staged because Trevor's respin scope call is still
    open. Queued jobs carry no DRC and verdict 'n/a'.
  - 'drc_clean' flag: true only at exactly 0/0/0. No now-tier job can set
    it (clearance floor 2); only a respin-tier board can.

Usage:
  python3 write_results.py --family tfa --variant astar-0.1 \
    --run-number 12 --run-id 123456789 --counts out/counts.json \
    --board out/board.kicad_pcb --status done|blocked|failfast|toolchain-ok|queued \
    --reason '...' --out out/tfa-astar-0.1.json [--baseline out/base_counts.json]

Verdict vs the Temple-F reference (50 unconnected / 0 shorts / 2 clearance):
  beat    unconnected < 50 and shorts == 0 and clearance <= 2
  tie     unconnected == 50 and shorts == 0 and clearance <= 2
  no-beat anything else (or no DRC at all -> n/a)
"""
import argparse, datetime, hashlib, json, os, sys

REF = {'unconnected': 50, 'shorts': 0, 'clearance': 2}

def md5(path):
    h = hashlib.md5()
    with open(path, 'rb') as fh:
        for chunk in iter(lambda: fh.read(1 << 20), b''):
            h.update(chunk)
    return h.hexdigest()

def verdict(drc):
    if drc is None:
        return 'n/a'
    u = drc.get('unconnected')
    if u is None:
        return 'n/a'
    if u < REF['unconnected'] and drc.get('shorts', 0) == 0 and drc.get('clearance', 0) <= REF['clearance']:
        return 'beat'
    if u == REF['unconnected'] and drc.get('shorts', 0) == 0 and drc.get('clearance', 0) <= REF['clearance']:
        return 'tie'
    return 'no-beat'

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--family', required=True)
    ap.add_argument('--variant', required=True)
    ap.add_argument('--run-number', required=True)
    ap.add_argument('--run-id', required=True)
    ap.add_argument('--counts', required=False, default=None)
    ap.add_argument('--baseline', required=False, default=None)
    ap.add_argument('--board', required=False, default=None)
    ap.add_argument('--status', required=True)
    ap.add_argument('--reason', required=True)
    ap.add_argument('--out', required=True)
    a = ap.parse_args()

    drc = json.load(open(a.counts)) if a.counts and os.path.exists(a.counts) else None
    base = json.load(open(a.baseline)) if a.baseline and os.path.exists(a.baseline) else None
    clean = bool(drc is not None and drc.get('unconnected') == 0
                 and drc.get('shorts', 0) == 0 and drc.get('clearance', 0) == 0)
    res = {
        'schema': 'templef-sweep-result/1',
        'run_number': int(a.run_number),
        'run_id': a.run_id,
        'family': a.family,
        'variant': a.variant,
        'status': a.status,
        'reason': a.reason,
        'templef_reference': REF,
        'verdict_vs_templef': verdict(drc),
        'drc_clean': clean,
        'drc': drc,
        'baseline_drc': base,
        'board_md5': md5(a.board) if a.board and os.path.exists(a.board) else None,
        'finished_utc': datetime.datetime.now(datetime.timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
    }
    with open(a.out, 'w') as fh:
        json.dump(res, fh, indent=2)
    print(json.dumps(res, indent=2))

if __name__ == '__main__':
    main()
