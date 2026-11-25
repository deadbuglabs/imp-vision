"""Parse a KiCad 7 WriteDRCReport text file into counts JSON.

Usage: python3 parse_drc.py <drc.txt> <counts.json>

Headline numbers used by every IMP-1 routing log:
  unconnected = N from "** Found N unconnected pads **"
  clearance   = count of lines starting "[clearance]"
  shorts      = count of lines starting "[shorting]" (or "[short]")
  total       = N from "** Found N DRC violations **"
Plus per-type counts for every other "[type]" section present.
"""
import json, re, sys

HEADER_UNC = re.compile(r'^\*\* Found (\d+) unconnected pads \*\*')
HEADER_TOTAL = re.compile(r'^\*\* Found (\d+) DRC violations \*\*')
HEADER_FP = re.compile(r'^\*\* Found (\d+) Footprint errors \*\*')
SECTION = re.compile(r'^\[([a-z_0-9]+)\]')

def parse(path):
    counts = {'unconnected': None, 'clearance': 0, 'shorts': 0, 'total': None,
              'footprint_errors': None}
    sections = {}
    with open(path, encoding='utf-8', errors='replace') as fh:
        for line in fh:
            m = HEADER_UNC.match(line)
            if m:
                counts['unconnected'] = int(m.group(1))
                continue
            m = HEADER_TOTAL.match(line)
            if m:
                counts['total'] = int(m.group(1))
                continue
            m = HEADER_FP.match(line)
            if m:
                counts['footprint_errors'] = int(m.group(1))
                continue
            m = SECTION.match(line)
            if m:
                t = m.group(1)
                sections[t] = sections.get(t, 0) + 1
    counts['clearance'] = sections.get('clearance', 0)
    counts['shorts'] = sections.get('shorting', 0) + sections.get('short', 0)
    for t, n in sorted(sections.items()):
        if t not in ('clearance', 'shorting', 'short'):
            counts[t] = n
    if counts['unconnected'] is None:
        # Fallback: unconnected_items sections count pads+tracks, not the
        # headline. Only use it if the header line is missing, and say so.
        counts['unconnected'] = sections.get('unconnected_items', 0)
        counts['unconnected_from'] = 'unconnected_items_sections'
    else:
        counts['unconnected_from'] = 'header'
    return counts

if __name__ == '__main__':
    src, dst = sys.argv[1], sys.argv[2]
    c = parse(src)
    with open(dst, 'w') as fh:
        json.dump(c, fh, indent=2)
    print(json.dumps(c, indent=2))
