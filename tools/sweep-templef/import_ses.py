"""Import a Freerouting SES session back into a board.

Usage: python3 import_ses.py <board.kicad_pcb> <session.ses>

pcbnew.ImportSpecctraSES applies the session to the currently loaded board.
Reports the unconnected count after import, then saves.
"""
import sys, pcbnew
path, ses = sys.argv[1], sys.argv[2]
b = pcbnew.LoadBoard(path)
print('loaded footprints:', len(list(b.GetFootprints())), flush=True)
ok = pcbnew.ImportSpecctraSES(ses)
print('ses imported:', ok, flush=True)
b.BuildConnectivity()
print('unconnected after import:', b.GetConnectivity().GetUnconnectedCount(True), flush=True)
print('tracks:', len(list(b.GetTracks())),
      'vias:', len([t for t in b.GetTracks() if t.GetClass() == 'PCB_VIA']), flush=True)
pcbnew.SaveBoard(path, b)
print('saved routed board', flush=True)
