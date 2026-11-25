"""Export a board to Specctra DSN for Freerouting.

Usage: python3 export_dsn.py <board.kicad_pcb> <out.dsn>
"""
import sys, pcbnew
path, out = sys.argv[1], sys.argv[2]
b = pcbnew.LoadBoard(path)
print('loaded footprints:', len(list(b.GetFootprints())), flush=True)
ok = pcbnew.ExportSpecctraDSN(b, out)
print('dsn exported:', ok, flush=True)
