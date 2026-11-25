"""Run KiCad DRC on a board and write the report.

Usage: python3 drc.py <board.kicad_pcb> <out_drc.txt>

KiCad 7.0.11 has no `kicad-cli pcb drc` subcommand, so DRC runs through
pcbnew.WriteDRCReport(). Must run under Xvfb (wx.App + zone filler need X).
The board's name-matched .kicad_pro sibling must sit next to it, or KiCad
falls back to default project settings and the counts inflate.
"""
import sys, pcbnew, wx
app = wx.App()
path, out = sys.argv[1], sys.argv[2]
b = pcbnew.LoadBoard(path)
filler = pcbnew.ZONE_FILLER(b)
filler.Fill(b.Zones())
ok = pcbnew.WriteDRCReport(b, out, pcbnew.EDA_UNITS_MILLIMETRES, True)
print("DRC written:", ok)
