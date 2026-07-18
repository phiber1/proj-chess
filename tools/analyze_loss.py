#!/usr/bin/env python3
"""Replay every (position, eval, bestmove) triple from an elph-debug log with
python-chess and compare the engine's reported d5 eval to the ACTUAL material on
the board. Separates shuffle/loss root causes by grounding eval against reality.

Run with the venv python: /tmp/chess_venv/bin/python tools/analyze_loss.py <log>...
"""
import re, sys
sys.path.insert(0, "/tmp/chess_venv/lib/python3*/site-packages")
import chess

PV = {chess.PAWN:100, chess.KNIGHT:320, chess.BISHOP:330,
      chess.ROOK:500, chess.QUEEN:900, chess.KING:0}

def material_stm(board):
    """material balance in cp from side-to-move's perspective."""
    w = sum(PV[p.piece_type] for p in board.piece_map().values() if p.color)
    b = sum(PV[p.piece_type] for p in board.piece_map().values() if not p.color)
    bal = w - b
    return bal if board.turn == chess.WHITE else -bal

def replay(moves):
    bd = chess.Board()
    for m in moves:
        try: bd.push_uci(m)
        except Exception: return None
    return bd

def searches(txt):
    """yield (moves_list, d5_eval_or_None, bestmove) per engine search."""
    pos, ev = None, None
    for line in txt.splitlines():
        m = re.search(r"position startpos moves ([a-h1-8qrbn ]+)", line)
        if m: pos = m.group(1).split(); ev = None; continue
        m = re.search(r"info depth 5 score cp (-?\d+)", line)
        if m: ev = int(m.group(1)); continue
        m = re.search(r"bestmove (\S+)", line)
        if m and pos is not None:
            yield pos, ev, m.group(1).strip().strip("'")

def analyze(path):
    txt = open(path).read()
    rows = []
    for moves, ev, bm in searches(txt):
        if ev is None or abs(ev) > 1800:   # skip book + hopeless-amp/mate
            continue
        bd = replay(moves)
        if bd is None: continue
        rows.append((len(moves), ev, material_stm(bd)))
    if not rows:
        print(f"{path.split('/')[-1][:46]:46s}  (no usable searches)"); return
    elph = "W" if rows[0][0] % 2 == 0 else "B"   # ELPH to move at its searches
    opt = [ev - mat for _, ev, mat in rows]       # eval - actual material (cp)
    mats = [mat for _, _, mat in rows]
    evs  = [ev for _, ev, _ in rows]
    import statistics
    avg_opt = statistics.mean(opt)
    early_mat = statistics.mean(mats[:6])
    # classify
    if early_mat < -150 and statistics.mean(evs[:6]) > early_mat + 200:
        cls = "EVAL-MISCAL: down early but eval too rosy"
    elif early_mat < -150:
        cls = "LOST-EARLY (honest eval): bad moves -> lost, eval agrees"
    elif min(mats) < -250 and avg_opt > 200:
        cls = "EVAL-MISCAL: material craters, eval lags rosy"
    elif min(mats) < -250:
        cls = "LOST-LATER (honest): was ok, lost material, eval agrees"
    elif min(mats) > -100:
        cls = "STAYED-EQUAL/AHEAD: drift/conversion, not material loss"
    else:
        cls = "mixed"
    print(f"{path.split('/')[-1][:46]:46s} ELPH={elph} n={len(rows):3d} "
          f"mat[1st6]={early_mat:+5.0f} mat_min={min(mats):+5d} "
          f"eval-mat_avg={avg_opt:+5.0f}  -> {cls}")

if __name__ == "__main__":
    for p in sys.argv[1:]:
        try: analyze(p)
        except Exception as e: print(f"{p}: ERR {e}")

def trace(path):
    txt = open(path).read()
    prev = None
    print(f"--- {path.split('/')[-1]} : per-move (eval / actual material, stm POV); * = sharp swing ---")
    seq=[]
    for moves, ev, bm in searches(txt):
        if ev is None or abs(ev) > 1800: continue
        bd = replay(moves)
        if bd is None: continue
        seq.append((len(moves)//1, ev, material_stm(bd), bm))
    for i,(ply,ev,mat,bm) in enumerate(seq):
        swing = ""
        if i>0:
            d = mat - (-seq[i-1][2])   # prev material was opp POV; flip to this stm
            # simpler: compare |mat| jumps
        seq_disp = f"  mv{i+1:3d} eval={ev:+5d} mat={mat:+5d} {bm}"
        # flag sharp material drop vs 2 moves ago (same side to move)
        if i>=2 and seq[i-2][2]-mat >= 250:
            seq_disp += f"   *** material dropped {seq[i-2][2]-mat} vs 2-ply-ago ***"
        print(seq_disp)
