#!/usr/bin/env python3
"""Corpus re-occurrence measurement: ENEMY-RUNNER BLINDNESS (7/2 candidate).

Hypothesis from the 7/2 adjudicated loss: RUNNER_BONUS's queen-ramp (150/350/600)
is white-only; an ENEMY pawn one step from promotion is priced at only ~250cp, so
ELPH's eval stays rosy while the enemy runner marches, then cliffs on promotion.

Per game: find the first ply an ENEMY pawn stands on its PENULTIMATE rank
(rank 2 for black when ELPH=White; rank 7 for white when ELPH=Black), then look
at ELPH's reported evals from that ply until the promotion (or game end):

  BLIND  = max ELPH eval in that window >= 0   (thought it was fine/winning)
  SEEN   = all window evals < 0                 (already knew it was bad)

Also reports whether the enemy actually promoted and how far the eval fell
within 6 plies after promotion (the "cliff").

Usage: /tmp/chess_venv/bin/python tools/measure_enemy_runner_blindness.py <logs...>
"""
import re, sys

sys.path.insert(0, "/tmp/chess_venv/lib/python3.12/site-packages")
import chess


def parse(txt):
    """return (evals_by_prefix_len, final_moves). evals use the deepest info line."""
    evals, pos, ev, final = {}, None, None, []
    for line in txt.splitlines():
        if "TX: 'position startpos" in line:
            m = re.search(r"position startpos(?: moves ([a-h1-8qrbnk ]+))?'", line)
            if m:
                pos = m.group(1).split() if m.group(1) else []
                ev = None
            continue
        if "RX: 'info" in line:
            m = re.search(r"score cp (-?\d+)", line)
            if m:
                ev = int(m.group(1))
            continue
        if "RX: 'bestmove" in line and pos is not None:
            m = re.search(r"bestmove (\S+?)'", line)
            if m:
                if ev is not None:
                    evals[len(pos)] = ev
                final = pos + [m.group(1)]
            pos = None
    return evals, final


def analyze(path):
    evals, moves = parse(open(path, errors="replace").read())
    if not moves or not evals:
        return None
    elph_white = min(evals) % 2 == 0 if evals else True
    enemy_is_white = not elph_white
    penult_rank = 6 if enemy_is_white else 1          # rank index 0-7
    promo_suffix = re.compile(r"^[a-h][1-8][a-h][1-8][qrbn]$")

    board = chess.Board()
    first_deep = None       # ply where an enemy pawn first reaches penultimate rank
    promo_ply = None        # ply of the enemy promotion move (if any)
    for i, mv in enumerate(moves):
        enemy_move = (i % 2 == 1) if elph_white else (i % 2 == 0)
        if enemy_move and promo_ply is None and promo_suffix.match(mv):
            promo_ply = i + 1
        try:
            board.push_uci(mv)
        except Exception:
            return None
        if first_deep is None:
            for sq in board.pieces(chess.PAWN, enemy_is_white):
                if chess.square_rank(sq) == penult_rank:
                    first_deep = i + 1
                    break
        if first_deep is not None and promo_ply is not None:
            break

    if first_deep is None:
        return {"path": path, "event": False}

    window_end = promo_ply if promo_ply is not None else len(moves)
    window = [e for p, e in evals.items() if first_deep <= p <= window_end]
    after = [e for p, e in evals.items() if promo_ply and promo_ply <= p <= promo_ply + 6]
    if not window:
        return {"path": path, "event": False}
    max_ev = max(window)
    cliff = (min(after) - max_ev) if after else None
    return {
        "path": path, "event": True, "blind": max_ev >= 0,
        "max_ev": max_ev, "promoted": promo_ply is not None,
        "cliff": cliff, "deep_ply": first_deep,
        "final_ev": evals[max(evals)],
    }


def main(paths):
    rows, dead = [], 0
    for p in paths:
        try:
            r = analyze(p)
        except Exception as e:
            print(f"{p}: ERR {e}", file=sys.stderr)
            continue
        if r is None:
            dead += 1
            continue
        rows.append(r)

    events = [r for r in rows if r["event"]]
    blind = [r for r in events if r["blind"]]
    print(f"games parsed: {len(rows)} (unparseable: {dead})")
    print(f"ENEMY pawn reached penultimate rank: {len(events)}/{len(rows)} "
          f"({100*len(events)//max(1,len(rows))}%)")
    if events:
        promoted = [r for r in events if r["promoted"]]
        print(f"  ...and actually promoted: {len(promoted)}")
        print(f"  BLIND (ELPH eval >= 0 during the run-in): {len(blind)}/{len(events)}")
        print(f"  SEEN  (eval already negative):            {len(events)-len(blind)}/{len(events)}")
    if blind:
        print(f"\n{'game':44s} {'maxEv':>6s} {'promo':5s} {'cliff':>7s} {'finalEv':>8s}")
        for r in sorted(blind, key=lambda x: -(x["max_ev"])):
            cl = f"{r['cliff']:+7d}" if r["cliff"] is not None else "      -"
            print(f"{r['path'].split('/')[-1][:44]:44s} {r['max_ev']:+6d} "
                  f"{'YES' if r['promoted'] else 'no ':5s} {cl} {r['final_ev']:+8d}")


if __name__ == "__main__":
    main(sys.argv[1:])
