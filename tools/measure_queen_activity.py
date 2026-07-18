#!/usr/bin/env python3
"""Corpus measurement: queen activity (captures + checks) per side, per game.

Born 2026-07-17 from loss13 (white queen: 10 moves, 0 captures, 0 checks,
died on d4 as a forced mate-block). Key finding at birth (173 games):
  - captures near-parity (W 1.37 / B 1.53, median 1 = the queen exchange)
  - CHECKS are the discriminator: W 0.73/game median 0 (58% of games the
    white queen never checks) vs B 2.40/game — 3.3x asymmetry.
Run with the /tmp/chess_venv python (needs python-chess).
See memory: weak_queen_must_revisit.
"""
import re, glob, chess, statistics, sys

logs = sys.argv[1:] or sorted(glob.glob('elph-debug*.log'))
rows = []
for path in logs:
    try: text = open(path, errors='replace').read()
    except OSError: continue
    best = ""
    for m in re.finditer(r"TX: 'position startpos moves ([a-h1-8qrbn ]+)'", text):
        if len(m.group(1)) > len(best): best = m.group(1)
    moves = best.split()
    if len(moves) < 20: continue
    b = chess.Board(); wc = bc = wch = bch = wm = bm = 0; ok = True
    for mv in moves:
        m = chess.Move.from_uci(mv)
        if m not in b.legal_moves: ok = False; break
        p = b.piece_at(m.from_square)
        isq = p and p.piece_type == chess.QUEEN
        white = b.turn
        if isq:
            if white: wm += 1
            else: bm += 1
            if b.is_capture(m):
                if white: wc += 1
                else: bc += 1
        b.push(m)
        if isq and b.is_check():
            if white: wch += 1
            else: bch += 1
    if not ok: continue
    rows.append((path, len(moves), wm, wc, wch, bm, bc, bch))

if not rows:
    sys.exit("no usable games found")
n = len(rows)
def col(i): return [r[i] for r in rows]
print(f"games: {n}")
print(f"{'':14}{'moves':>8}{'captures':>10}{'checks':>8}{'zero-cap':>10}{'zero-chk':>10}")
for side, mi, ci, chi in (("WHITE (ELPH)",2,3,4), ("BLACK (SF)",5,6,7)):
    print(f"{side:<14}{statistics.mean(col(mi)):8.2f}{statistics.mean(col(ci)):10.2f}"
          f"{statistics.mean(col(chi)):8.2f}{sum(1 for c in col(ci) if c==0):>7}/{n}"
          f"{sum(1 for c in col(chi) if c==0):>7}/{n}")
print("\nBusiest zero-capture white queens (moves desc):")
for r in sorted((r for r in rows if r[3]==0), key=lambda r:-r[2])[:5]:
    print(f"  {r[0][:60]:<60} Qmoves {r[2]}, checks {r[4]}")
