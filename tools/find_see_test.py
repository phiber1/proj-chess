#!/usr/bin/env python3
"""!!! KNOWN BUG (2026-06-01): the move applier / movelist extraction
mis-reconstructs positions on long real-game movelists (verified: a KQK-game
position it built evaluated to White -340 material while the engine had it at
+35 -> the reconstructed board diverged from reality). DO NOT trust the
positions/phantoms this emits until apply_move + the log-movelist extraction are
debugged (suspect castling/EP/promotion or filtered-token parity drift). The SEE
*algorithm* reference in see_model.py is separate and validated.

Apply a UCI 'position startpos moves ...' line, and at each ply report the
non-king piece count and any LOSING capture available to the side to move
(SEE < 0 = phantom: capturing wins a piece on paper but loses more to the
recapture sequence). Used to pick a deterministic endgame SEE test position.

Reuses the SEE swap from see_model.py (the validated algorithm reference).
Board: see_model 0x88, piece = type(1-6) | 0x80 if black. rank0 = white back.
"""
import sys
from see_model import (sq88, add88, onboard, ptype, pcolor, find_lva,
                       see_recovery_cp, W, B, P, Kn, Bi, R, Q, Kg)

VAL = {1:100, 2:320, 3:330, 4:500, 5:900, 6:0}
PROMO = {'q':Q, 'r':R, 'b':Bi, 'n':Kn}

def start_board():
    b = {}
    back = [R,Kn,Bi,Q,Kg,Bi,Kn,R]
    for f in range(8):
        b[sq88(chr(ord('a')+f)+'1')] = W|back[f]
        b[sq88(chr(ord('a')+f)+'2')] = W|P
        b[sq88(chr(ord('a')+f)+'7')] = B|P
        b[sq88(chr(ord('a')+f)+'8')] = B|back[f]
    return b

def apply_move(b, mv, side):
    """side: 0 white / 0x80 black (mover). Returns new side."""
    frm = sq88(mv[0:2]); to = sq88(mv[2:4])
    piece = b.pop(frm)
    t = ptype(piece)
    # en passant: pawn moves diagonally to an empty square
    if t == P and (to & 0x0F) != (frm & 0x0F) and to not in b:
        cap_sq = (frm & 0xF0) | (to & 0x0F)   # captured pawn on mover's rank
        b.pop(cap_sq, None)
    # castling: king moves two files -> move the rook
    if t == Kg and abs((to & 0x0F) - (frm & 0x0F)) == 2:
        rank = frm & 0xF0
        if (to & 0x0F) == 6:        # king side: h-rook -> f
            b[rank|5] = b.pop(rank|7)
        else:                       # queen side: a-rook -> d
            b[rank|3] = b.pop(rank|0)
    # promotion
    if len(mv) == 5:
        piece = (pcolor(piece)) | PROMO[mv[4]]
    b[to] = piece                   # normal capture overwrites
    return side ^ 0x80

def piece_count_nonking(b):
    return sum(1 for p in b.values() if ptype(p) != Kg)

def losing_captures(b, side):
    """For the side to move, find captures with SEE net < 0. Returns list of
    (capture_str, victim_val, net_cp)."""
    out = []
    opp = side ^ 0x80
    for sq, vic in list(b.items()):
        if pcolor(vic) == side or ptype(vic) == Kg:
            continue                # only enemy non-king pieces are targets
        lva = find_lva(b, sq, side, set())   # cheapest attacker of this square
        if lva is None:
            continue
        afrm, aval4 = lva
        v = VAL[ptype(vic)]
        # simulate the capture: attacker moves onto sq
        b2 = dict(b); attacker = b2.pop(afrm); b2[sq] = attacker
        # legality: a KING cannot capture into a square the opponent still
        # attacks (illegal — move generator never produces it). Skip those.
        if ptype(attacker) == Kg and find_lva(b2, sq, opp, set()) is not None:
            continue
        R_recover = see_recovery_cp(b2, sq, opp)
        net = v - R_recover
        if net < 0:
            name = sqname(afrm)+sqname(sq)
            out.append((name, v, net))
    out.sort(key=lambda x: x[2])
    return out

def sqname(sq):
    return chr(ord('a')+(sq & 0x0F)) + str((sq >> 4)+1)

if __name__ == "__main__":
    line = open(sys.argv[1]).read().split()
    moves = line[line.index('moves')+1:]
    b = start_board(); side = W
    print(f"{len(moves)} moves total")
    for i, mv in enumerate(moves):
        side = apply_move(b, mv, side)   # side now = side to move at ply i+1
        pc = piece_count_nonking(b)
        if pc < 12:                      # endgame only (SEE phase gate)
            lc = losing_captures(b, side)
            if lc:
                stm = 'b' if side else 'w'
                worst = lc[0]
                print(f"ply {i+1}: {pc} pieces, {stm} to move, "
                      f"LOSING capture {worst[0]} (takes {worst[1]}cp, net {worst[2]}cp); "
                      f"all={lc}")
