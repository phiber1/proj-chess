#!/usr/bin/env python3
"""Post-build audit: data tables vs page boundaries.

a18 catches short-branch-out-of-page errors but NOT table lookups whose
base+index crosses a $xx00 page boundary when the access code doesn't
propagate the carry (ADI LOW / PLO / LDI HIGH *without* ADCI reads the
wrong page — silently). Any size-changing edit shifts every downstream
table, so run this after EVERY build alongside `grep "^[A-Z]" chess-engine.lst`.

Checks, per data table found in chess-engine.lst/asm:
  1. does the table span a page boundary NOW?
  2. is any access site missing carry propagation (no ADCI near the ADI LOW)?
  3. NEAR-EDGE warning: table ends within 16 bytes of a page boundary
     (the next insertion upstream may push it across).

Exit code 1 if any table crosses a page with an unguarded access site.
Usage: python3 tools/audit_table_pages.py
"""
import re, sys

LST = "chess-engine.lst"
ASM = "chess-engine.asm"

lst_lines = open(LST, errors="replace").read().splitlines()
src = open(ASM, errors="replace").read()
addr_re = re.compile(r"^   ([0-9a-f]{4})\s+((?:[0-9a-f]{2} ?)+)?\s*(.*)$")

labels = []
for ln in lst_lines:
    m = addr_re.match(ln)
    if not m:
        continue
    t = (m.group(3) or "").strip()
    lm = re.match(r"^(\w+):", t)
    if lm:
        labels.append((lm.group(1), int(m.group(1), 16)))
labels.sort(key=lambda kv: kv[1])

data_tables = {}
for name, addr in labels:
    if re.search(rf"^{name}:\s*\n(?:\s*;.*\n)*(\s+D[BW]\b)", src, re.M):
        nxt = min((a for n, a in labels if a > addr), default=addr + 1)
        data_tables[name] = (addr, nxt - 1)

bad = 0
warn = 0
for name, (a, e) in sorted(data_tables.items(), key=lambda kv: kv[1][0]):
    crosses = (a >> 8) != (e >> 8)
    near = not crosses and (0x100 - (e & 0xFF)) <= 16
    # classify access sites: an ADI LOW(name) without ADCI within the next 3 lines
    unguarded = []
    for m in re.finditer(rf"ADI LOW\({name}\)", src):
        window = src[m.start():m.start() + 160]
        if "ADCI" not in window:
            line_no = src[:m.start()].count("\n") + 1
            unguarded.append(line_no)
    if crosses and unguarded:
        print(f"FAIL  {name:24s} {a:04x}-{e:04x} CROSSES page, unguarded ADI LOW at line(s) {unguarded}")
        bad += 1
    elif crosses:
        print(f"ok    {name:24s} {a:04x}-{e:04x} crosses page (all access sites carry-guarded)")
    elif near:
        print(f"NEAR  {name:24s} {a:04x}-{e:04x} ends {0x100 - (e & 0xFF)} B from page edge"
              f"{' + UNGUARDED access at ' + str(unguarded) if unguarded else ''}")
        warn += 1
        if unguarded:
            bad += 1   # unguarded + near-edge = one insertion away from silent corruption

print(f"\n{len(data_tables)} data tables audited: {bad} FAIL, {warn} near-edge")
sys.exit(1 if bad else 0)
