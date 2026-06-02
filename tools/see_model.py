#!/usr/bin/env python3
"""Faithful Python reference of the SEE asm (branch see-exchange-eval).

Mirrors negamax.asm:SEE_CORRECT_STANDPAT exactly:
  - 0x88 board, piece bytes: type 1..6 = P,N,B,R,Q,K; color bit $80 = black.
  - /4-scaled byte values P25 N80 B82 R125 Q225 K250.
  - FIND_LVA scan order pawn,knight,bishop,rook,queen,king; slider scan keeps
    the min-value attacker over 8 dirs; USED squares are TRANSPARENT to slider
    scans (x-ray reveal) and skipped for leapers.
  - build V[0]=value(piece on target); V[1..n]=alternating LVA values.
  - fold: g=0; for j=n-1..0: g=max(0,V[j]-g); R=g  (centipawns = R*4).

Use this to verify the ALGORITHM independent of the 1802 asm.
"""

PIECE_VAL4 = {0:0, 1:25, 2:80, 3:82, 4:125, 5:225, 6:250}   # /4 values, K=250
NE, NW, SE, SW = 0xF1, 0xEF, 0x11, 0x0F
N, S, E, W = 0xF0, 0x10, 0x01, 0xFF
DIAG = [NE, NW, SE, SW]
ORTH = [N, S, E, W]
KNIGHT = [0xDF,0xE1,0xEE,0xF2,0x0E,0x12,0x1F,0x21]
KING8  = [N,NE,E,SE,S,SW,W,NW]

def add88(sq, off):
    return (sq + off) & 0xFF       # asm does 8-bit ADD then ANI $88 test

def onboard(sq):
    return (sq & 0x88) == 0

def ptype(p): return p & 0x0F
def pcolor(p): return p & 0x80     # 0 white, 0x80 black

def find_lva(board, target, side_color, used):
    """Return (sq, val4) of least-valuable attacker of side_color on target,
    honoring `used` (set of squares). None if no attacker."""
    # ---- PAWN ----
    if side_color == 0x00:           # white pawns attack target from NW, NE
        pawn_from = [add88(target, NW), add88(target, NE)]
        want = 0x01
    else:                            # black pawns attack target from SE, SW
        pawn_from = [add88(target, SE), add88(target, SW)]
        want = 0x81
    for s in pawn_from:
        if onboard(s) and s not in used and board.get(s,0) == want:
            return (s, 25)
    # ---- KNIGHT ----
    want = side_color | 0x02
    for off in KNIGHT:
        s = add88(target, off)
        if onboard(s) and s not in used and board.get(s,0) == want:
            return (s, 80)
    # ---- SLIDERS: min-value attacker over 8 dirs (USED transparent) ----
    best_val = 255
    best_sq = None
    for idx, d in enumerate(DIAG + ORTH):
        # slide from target in direction d, first non-empty non-used piece
        cur = target
        piece = 0
        psq = None
        while True:
            cur = add88(cur, d)
            if not onboard(cur):
                break
            occ = board.get(cur, 0)
            if occ == 0 or cur in used:
                continue            # empty OR transparent used square (x-ray)
            piece = occ; psq = cur
            break
        if piece == 0:
            continue
        if pcolor(piece) != side_color:
            continue
        t = ptype(piece)
        is_diag = idx < 4
        if is_diag:
            if t == 3:   val = 82
            elif t == 5: val = 225
            else:        continue   # not bishop/queen on a diagonal
        else:
            if t == 4:   val = 125
            elif t == 5: val = 225
            else:        continue   # not rook/queen on an orthogonal
        if val < best_val:
            best_val = val; best_sq = psq
    if best_sq is not None:
        return (best_sq, best_val)
    # ---- KING ----
    want = side_color | 0x06
    for off in KING8:
        s = add88(target, off)
        if onboard(s) and s not in used and board.get(s,0) == want:
            return (s, 250)
    return None

def see_recovery_cp(board, target, side_to_move_color):
    """Net cp the side-to-move recovers by recapturing on `target`
    (the piece currently on target is the just-moved captor)."""
    occ = board.get(target, 0)
    if occ == 0:
        return 0
    V = [PIECE_VAL4[ptype(occ)]]     # V[0]
    used = set()
    side = side_to_move_color
    while True:
        lva = find_lva(board, target, side, used)
        if lva is None:
            break
        sq, val4 = lva
        V.append(val4)
        used.add(sq)
        side ^= 0x80
        if len(V) >= 16:
            break
    n = len(V) - 1                   # number of recapturers
    g = 0
    for j in range(n-1, -1, -1):
        t = V[j] - g
        g = t if t >= 0 else 0
    return g * 4                     # centipawns

# ---- helpers to build a board from algebraic squares ----
def sq88(name):
    f = ord(name[0]) - ord('a')
    r = int(name[1]) - 1
    return r*16 + f                  # rank0=back-rank-white side; 0x88 layout

W = 0x00; B = 0x80
P,Kn,Bi,R,Q,Kg = 1,2,3,4,5,6

def show(label, got, exp):
    ok = "OK " if got == exp else "FAIL"
    print(f"[{ok}] {label}: got {got}cp, expected {exp}cp")

if __name__ == "__main__":
    # Case 1: Nxc6, c6 = white knight (just captured), defended by black b7 pawn.
    # Black to move recovers the knight (320). 1-level == full here.
    b = { sq88('c6'): W|Kn, sq88('b7'): B|P }
    show("Nxc6 / b7-pawn recapture", see_recovery_cp(b, sq88('c6'), B), 320)

    # Case 2: two-level. White Q sits on d5 (just captured). Black has pawn (c6)
    # AND knight (f6) attacking d5; white has pawn (e4) defending d5.
    # Black recaptures Q with pawn(c6)->gains 900? scaled: V0=225(Q),
    # black pawn(25) takes -> white pawn(25) retakes -> black knight(80) retakes.
    # V=[225,25,25,80]; fold: g=0;j=2:max(0,25-0)=25;j=1:max(0,25-25)=0;
    #   j=0:max(0,225-0)=225 -> 900cp. Black wins the queen for a pawn.
    b = { sq88('d5'): W|Q, sq88('c6'): B|P, sq88('f6'): B|Kn, sq88('e4'): W|P }
    show("Q on d5, multi-level", see_recovery_cp(b, sq88('d5'), B), 900)

    # Case 3: defended capture that should NOT be recovered (R=0).
    # White pawn on e5 (just captured), black knight d7 attacks e5? no.
    # Use: white knight on e5 (val 320), black has ONLY a queen attacking (d6? )
    # Black recaptures N(320) with Q(900): V=[80,225]; fold j=0:max(0,80-0)=80
    #   wait that's >0 -> R=320. Black happily takes a knight with queen if no
    #   white recapture. Add white pawn f4 defending e5:
    #   V=[80,225,... white pawn? pawn on f4 attacks e5]; black Q takes N,
    #   white P takes Q: V=[80,225,25]; fold g=0;j=1:max(0,225-0)=225;
    #   j=0:max(0,80-225)=0 -> R=0. Black should NOT take (loses Q for N).
    b = { sq88('e5'): W|Kn, sq88('d6'): B|Q, sq88('f4'): W|P }
    show("N on e5 defended by f4 pawn (Q recapture loses)", see_recovery_cp(b, sq88('e5'), B), 0)

    # Case 4: x-ray battery. White R on a4 (just captured). Black rook a8 with
    # black rook a7 BEHIND it (battery), white has nothing else.
    # Black Ra7?->no, least valuable first: both rooks val125. takes with a-file
    # rook (first slider hit = a-file). After it's used, x-ray reveals the rook
    # behind. White has no recapture. V=[125,125]; fold j=0:max(0,125-0)=125
    #   -> R=500. Black wins the rook (no white recapture).
    b = { sq88('a4'): W|R, sq88('a8'): B|R, sq88('a6'): B|R }
    show("x-ray: black rook battery on a-file recovers R", see_recovery_cp(b, sq88('a4'), B), 500)

    # Case 5: the deterministic engine test. After 1.e4 e5 2.Nf3 Nc6, white plays
    # Nxe5 (knight now on e5, won the pawn). Black Nc6 recaptures the knight.
    # SEE: black recovers the white knight (320). White net for Nxe5 = +100(pawn)
    # -320 = -220 -> a losing capture the engine must avoid at depth 1.
    b = { sq88('e5'): W|Kn, sq88('c6'): B|Kn }
    show("post-Nxe5: black Nc6 recaptures the knight", see_recovery_cp(b, sq88('e5'), B), 320)
