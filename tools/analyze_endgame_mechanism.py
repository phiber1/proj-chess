#!/usr/bin/env python3
"""Losing-endgame MECHANISM analysis for elph-debug logs (post-A+B gate check).

Reproduces the 2026-07-02 corpus mechanism analysis so it can be re-run on
CURRENT-build logs and compared bucket-for-bucket against the (confounded)
pre-A+B corpus baseline. Per game it answers:

  1. How long was the game (plies)?  LONG >= 90.
  2. Final material from ELPH's POV -> LOSING (<= -500cp) / WINNING (>= +500) / BALANCED.
  3. For LOSING games, why didn't cutechess RESIGN adjudication (own score <= -1500
     for 10 consecutive moves, one-sided) end it?
        NEVER-1500  : eval never reached -1500 (capped/rosy)
        BOUNCED     : reached -1500 but max consecutive streak < 10 (oscillation)
        STREAK>=10  : resign would/did fire; length came from the earlier bleed
  4. For BALANCED long games (drawn shuffle), what fraction of the tail evals sit
     within 10/30/50 cp -> feeds the draw-threshold-widening decision (10 -> 30-40).
  5. Amp check: did the hopeless-amp fire (eval <= -1750 seen)?
  6. Eval-vs-material grounding in the tail (phantom-eval detector: the old
     king-drive bug showed as ELPH +395..+600 while being mated).

Usage: /tmp/chess_venv/bin/python tools/analyze_endgame_mechanism.py <log> [<log>...]
       add --csv to also dump per-game rows to stdout as CSV.
Dedups by final movelist (identical games counted once).
"""
import re, sys, statistics

sys.path.insert(0, "/tmp/chess_venv/lib/python3.12/site-packages")
import chess

PV = {chess.PAWN: 100, chess.KNIGHT: 320, chess.BISHOP: 330,
      chess.ROOK: 500, chess.QUEEN: 900, chess.KING: 0}

LONG_PLIES   = 90
RESIGN_CP    = -1500
RESIGN_MOVES = 10
LOSING_CP    = -500     # ~a rook or more down, matches the corpus "-5+" bucket
AMP_CP       = -1750    # amp is -2000 on top of <= -250, so anything <= -1750


def parse_searches(txt):
    """yield (moves_before_search, deepest_eval_cp_or_None, bestmove) per ELPH search."""
    pos, ev = None, None
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
                ev = int(m.group(1))          # keep the deepest (last) info line
            continue
        if "RX: 'bestmove" in line and pos is not None:
            m = re.search(r"bestmove (\S+?)'", line)
            if m:
                yield list(pos), ev, m.group(1)
            pos = None


def material_white(board):
    w = sum(PV[p.piece_type] for p in board.piece_map().values() if p.color)
    b = sum(PV[p.piece_type] for p in board.piece_map().values() if not p.color)
    return w - b


def analyze_game(path):
    txt = open(path, errors="replace").read()
    searches = list(parse_searches(txt))
    if not searches:
        return None

    # ELPH is the side to move at its own searches
    elph_white = len(searches[0][0]) % 2 == 0

    # replay the full game: last position + last bestmove is the final state
    final_moves = searches[-1][0] + [searches[-1][2]]
    board = chess.Board()
    replay_ok = True
    for mv in final_moves:
        try:
            board.push_uci(mv)
        except Exception:
            replay_ok = False
            break

    plies = len(final_moves)
    mat_w = material_white(board) if replay_ok else None
    mat_elph = None if mat_w is None else (mat_w if elph_white else -mat_w)

    # ELPH's reported eval series (its own POV; skip book moves with no info)
    evals = [(len(mv), ev) for mv, ev, _ in searches if ev is not None]
    ev_series = [ev for _, ev in evals]

    # resign-adjudication simulation on ELPH's own scores
    max_streak = streak = 0
    first_cross = None
    for i, ev in enumerate(ev_series):
        if ev <= RESIGN_CP:
            streak += 1
            max_streak = max(max_streak, streak)
            if first_cross is None:
                first_cross = i
        else:
            streak = 0

    # tail behavior (last 20 ELPH evals)
    tail = ev_series[-20:]
    tail_pct = {t: (100 * sum(1 for e in tail if abs(e) <= t) // len(tail)) if tail else 0
                for t in (10, 30, 50)}

    # phantom detector: tail eval vs actual material (ELPH POV), pre-amp evals only
    phantom = None
    if replay_ok and tail:
        honest = [e for e in tail if abs(e) < 1500]
        if honest and mat_elph is not None:
            phantom = statistics.mean(honest) - mat_elph

    return {
        "path": path,
        "key": " ".join(final_moves),
        "elph": "W" if elph_white else "B",
        "plies": plies,
        "mat_elph": mat_elph,
        "mate": replay_ok and board.is_checkmate(),
        "n_evals": len(ev_series),
        "ev_min": min(ev_series) if ev_series else None,
        "ev_last": ev_series[-1] if ev_series else None,
        "amp_fired": any(e <= AMP_CP for e in ev_series),
        "max_streak": max_streak,
        "first_cross_move": None if first_cross is None else evals[first_cross][0] // 2 + 1,
        "tail_pct": tail_pct,
        "phantom": phantom,
        "replay_ok": replay_ok,
    }


def classify(g):
    if g["mat_elph"] is None:
        return "UNREPLAYABLE"
    # the movelist always ends with ELPH's own bestmove, so a checkmate final
    # position means ELPH delivered the mate — a win regardless of material
    # (win #31 2026-07-02: mate with material at only +100 -> read BALANCED)
    if g["mate"]:
        return "WON-MATE"
    if g["mat_elph"] <= LOSING_CP:
        return "LOSING"
    if g["mat_elph"] >= -LOSING_CP:
        return "WINNING"
    return "BALANCED"


def resign_bucket(g):
    if g["ev_min"] is None or g["ev_min"] > RESIGN_CP:
        return "NEVER-1500"
    if g["max_streak"] >= RESIGN_MOVES:
        return "STREAK>=10"
    return "BOUNCED"


def main(paths, csv=False):
    games, seen = [], set()
    for p in paths:
        try:
            g = analyze_game(p)
        except Exception as e:
            print(f"{p}: ERR {e}", file=sys.stderr)
            continue
        if g is None:
            continue
        if g["key"] in seen:
            continue
        seen.add(g["key"])
        games.append(g)

    if not games:
        print("no parseable games")
        return

    if csv:
        print("file,elph,plies,mat_elph,class,ev_min,ev_last,amp,streak,resign_bucket,"
              "tail<=10,tail<=30,tail<=50,phantom,mate")
        for g in games:
            cls = classify(g)
            print(f"{g['path'].split('/')[-1]},{g['elph']},{g['plies']},{g['mat_elph']},"
                  f"{cls},{g['ev_min']},{g['ev_last']},{int(g['amp_fired'])},"
                  f"{g['max_streak']},{resign_bucket(g) if cls=='LOSING' else ''},"
                  f"{g['tail_pct'][10]},{g['tail_pct'][30]},{g['tail_pct'][50]},"
                  f"{'' if g['phantom'] is None else round(g['phantom'])},{int(g['mate'])}")
        print()

    # ---- per-game table ----
    print(f"{'game':38s} {'E':1s} {'ply':>4s} {'matE':>6s} {'class':8s} "
          f"{'evMin':>6s} {'strk':>4s} {'resign?':10s} {'amp':3s} {'phantom':>8s}")
    for g in sorted(games, key=lambda x: -x["plies"]):
        cls = classify(g)
        ph = "" if g["phantom"] is None else f"{g['phantom']:+8.0f}"
        rb = resign_bucket(g) if cls == "LOSING" else ""
        print(f"{g['path'].split('/')[-1][:38]:38s} {g['elph']} {g['plies']:4d} "
              f"{g['mat_elph'] if g['mat_elph'] is not None else '?':>6} {cls:8s} "
              f"{g['ev_min'] if g['ev_min'] is not None else '?':>6} "
              f"{g['max_streak']:4d} {rb:10s} {'Y' if g['amp_fired'] else '.':3s} {ph:>8s}")

    # ---- aggregate, mirrors the 2026-07-02 corpus baseline ----
    n = len(games)
    long_g = [g for g in games if g["plies"] >= LONG_PLIES]
    print(f"\n== AGGREGATE ({n} unique games) ==")
    print(f"LONG (>= {LONG_PLIES} plies): {len(long_g)}/{n} "
          f"({100*len(long_g)//n}%)   [pre-A+B corpus baseline: 49%]")
    if long_g:
        losing  = [g for g in long_g if classify(g) == "LOSING"]
        winning = [g for g in long_g if classify(g) in ("WINNING", "WON-MATE")]
        bal     = [g for g in long_g if classify(g) == "BALANCED"]
        mated   = [g for g in long_g if classify(g) == "WON-MATE"]
        print(f"  of LONG: LOSING {len(losing)} ({100*len(losing)//len(long_g)}%) "
              f"WINNING {len(winning)} (incl {len(mated)} on-board mates) "
              f"BALANCED {len(bal)}   [baseline: 59/21/20%]")
        if losing:
            from collections import Counter
            c = Counter(resign_bucket(g) for g in losing)
            print(f"  LOSING resign buckets: "
                  f"NEVER-1500={c['NEVER-1500']} BOUNCED={c['BOUNCED']} "
                  f"STREAK>=10={c['STREAK>=10']}   [baseline: 35/38/28%]")
        if bal:
            for t in (10, 30, 50):
                avg = statistics.mean(g["tail_pct"][t] for g in bal)
                print(f"  BALANCED drawn-shuffle: avg {avg:.0f}% of tail evals "
                      f"within +/-{t}cp   [baseline: 12% @10, 20% @50]")
    # a positive phantom is only pathological when the game did NOT end in ELPH's
    # favor — in a won attack the eval legitimately leads material (passer/mating
    # attack, e.g. win #31's +541 before a8=Q#). Only flag non-wins.
    phantoms = [g for g in games
                if g["phantom"] is not None and g["phantom"] > 300
                and classify(g) not in ("WINNING", "WON-MATE")]
    print(f"PHANTOM-EVAL games (tail eval > material +300cp in a NON-WON game, "
          f"the old Fix-B signature): {len(phantoms)}")
    for g in phantoms:
        print(f"  ! {g['path'].split('/')[-1]}  phantom={g['phantom']:+.0f}  "
              f"(eval says better than material by this much — investigate)")


if __name__ == "__main__":
    argv = [a for a in sys.argv[1:] if a != "--csv"]
    main(argv, csv="--csv" in sys.argv)
