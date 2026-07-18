#!/usr/bin/env python3
"""Compare a monitor code-space dump against the flashed binary to detect
corruption. Dump format: lines like '1A30>  5A 1A 87 5A ...' (addr> then bytes).
Usage: python3 tools/compare_codedump.py <dumpfile> [bin=chess-engine.bin] [end=0x5F23]
"""
import sys, re
dumpf = sys.argv[1]
binf  = sys.argv[2] if len(sys.argv) > 2 else "chess-engine.bin"
end   = int(sys.argv[3], 0) if len(sys.argv) > 3 else 0x5F23   # code tail
ref = open(binf, "rb").read()

mem = {}
for line in open(dumpf):
    m = re.match(r"\s*([0-9A-Fa-f]{4})\s*>\s*(.*)", line)
    if not m: continue
    addr = int(m.group(1), 16)
    for i, b in enumerate(re.findall(r"[0-9A-Fa-f]{2}", m.group(2))):
        mem[addr + i] = int(b, 16)

diffs = []
covered = 0
for a in range(0, end + 1):
    if a in mem:
        covered += 1
        if a < len(ref) and mem[a] != ref[a]:
            diffs.append((a, ref[a], mem[a]))

print(f"compared $0000-${end:04X}  ({covered} bytes present in dump, ref={binf})")
if not diffs:
    print("  *** CODE INTACT — no differences ***")
else:
    print(f"  *** {len(diffs)} BYTE(S) DIFFER — CODE CORRUPTION ***")
    for a, want, got in diffs[:60]:
        print(f"    ${a:04X}: flashed={want:02X}  in-RAM={got:02X}")
    if len(diffs) > 60:
        print(f"    ... +{len(diffs)-60} more")
    # cluster summary
    lo = min(d[0] for d in diffs); hi = max(d[0] for d in diffs)
    print(f"  corrupted span: ${lo:04X}..${hi:04X}")
