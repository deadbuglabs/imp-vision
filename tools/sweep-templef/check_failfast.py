"""Fail-fast gate for one Temple-F routing stage.

Temple-F adaptation of the IMP-1 check_failfast.py. Differences:
  - Reference is 50 unconnected (env REF_UNCONNECTED, default 50), not 15.
  - Clearance floor is 2 (env REF_CLEARANCE, default 2): the fenced
    J3-south-MP-tab vs U13 pads 15/16 pair. A stage is STOPped only when
    clearance GROWS above the previous stage's count, never for sitting
    at the floor of 2.

Usage: python3 check_failfast.py <prev_counts.json> <cur_counts.json>
Exit 0 prints CONTINUE, exit 2 prints STOP with the reason.

STOP rules (a stage that cannot beat the 50/0/2 reference is not worth
more stages):
  - shorts appeared (> 0)
  - clearance grew vs the previous stage
  - unconnected is still >= REF_UNCONNECTED AND the stage closed nothing
    (cur.unconnected >= prev.unconnected while >= REF_UNCONNECTED)
A stage that closed at least one net, or is already below the reference,
continues.
"""
import json, os, sys

REF_UNCONNECTED = int(os.environ.get('REF_UNCONNECTED', '50'))
REF_CLEARANCE = int(os.environ.get('REF_CLEARANCE', '2'))

def main():
    prev = json.load(open(sys.argv[1]))
    cur = json.load(open(sys.argv[2]))
    if cur.get('shorts', 0) > 0:
        print('STOP: shorts appeared (%d)' % cur['shorts'])
        return 2
    if cur.get('clearance', 0) > prev.get('clearance', 0):
        print('STOP: clearance grew %d -> %d (floor is %d, fenced J3/U13 pair)'
              % (prev.get('clearance', 0), cur.get('clearance', 0), REF_CLEARANCE))
        return 2
    if cur.get('unconnected', 999) >= REF_UNCONNECTED and cur.get('unconnected', 999) >= prev.get('unconnected', 999):
        print('STOP: no improvement at %d unconnected (Temple-F reference is %d)'
              % (cur.get('unconnected', 999), REF_UNCONNECTED))
        return 2
    print('CONTINUE: unconnected %s -> %s (reference %d, clearance floor %d)'
          % (prev.get('unconnected'), cur.get('unconnected'), REF_UNCONNECTED, REF_CLEARANCE))
    return 0

if __name__ == '__main__':
    sys.exit(main())
