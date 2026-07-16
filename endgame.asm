; ==============================================================================
; RCA 1802/1806 Chess Engine - Endgame Heuristics
; ==============================================================================
; Special evaluation bonuses for endgame positions:
; 1. King centralization when material is low
; 2. Drive enemy king to edge/corner in winning positions
; 3. Passed pawn bonus
; ==============================================================================

; Endgame threshold (in centipawns of total material)
; Below this, we're in the endgame
; Roughly: 2 rooks + 2 minor = 2*500 + 2*325 = 1650
ENDGAME_THRESHOLD_LO    EQU $68     ; 1640 = $0668
ENDGAME_THRESHOLD_HI    EQU $06

; King centralization table (bonus for king being in center during endgame)
; Higher values in center, lower on edges
KING_CENTER_TABLE:
    ; Rank 8
    DB -30,-20,-10,  0,  0,-10,-20,-30
    ; Rank 7
    DB -20,-10,  0, 10, 10,  0,-10,-20
    ; Rank 6
    DB -10,  0, 10, 20, 20, 10,  0,-10
    ; Rank 5
    DB   0, 10, 20, 30, 30, 20, 10,  0
    ; Rank 4
    DB   0, 10, 20, 30, 30, 20, 10,  0
    ; Rank 3
    DB -10,  0, 10, 20, 20, 10,  0,-10
    ; Rank 2
    DB -20,-10,  0, 10, 10,  0,-10,-20
    ; Rank 1
    DB -30,-20,-10,  0,  0,-10,-20,-30

; King to edge table (bonus for enemy king on edge/corner — drive-to-mate)
; Use this when we're winning to drive enemy king to corner.
; Higher values at edges/corners, lower in center.
; Retuned 2026-06-15: steepened ~1.5x toward corners (proven mate-shuffle:
; R+Q+5P vs lone K dawdled ~22 moves, eval flat — the edge gradient was too
; shallow to actively squeeze the enemy king to a corner). Max 90, SHL'd to
; 180cp at the corner (still <256, no byte overflow). Zero new bytes.
KING_EDGE_TABLE:
    ; Rank 8
    DB  90, 75, 60, 45, 45, 60, 75, 90
    ; Rank 7
    DB  75, 60, 45, 30, 30, 45, 60, 75
    ; Rank 6
    DB  60, 45, 30, 15, 15, 30, 45, 60
    ; Rank 5
    DB  45, 30, 15,  0,  0, 15, 30, 45
    ; Rank 4
    DB  45, 30, 15,  0,  0, 15, 30, 45
    ; Rank 3
    DB  60, 45, 30, 15, 15, 30, 45, 60
    ; Rank 2
    DB  75, 60, 45, 30, 30, 45, 60, 75
    ; Rank 1
    DB  90, 75, 60, 45, 45, 60, 75, 90

; ------------------------------------------------------------------------------
; KING_PROX_BONUS - friendly-king-to-enemy-king proximity, indexed by Chebyshev
; distance (0-7). The missing mating ingredient: edging the enemy king alone
; never mates — the winning side's king must march up to support. Small-distance
; = high bonus gives the shallow search a downhill gradient to walk the king in.
; Kings can never be adjacent (dist<2 illegal), so 2 = closest = max pull.
; ------------------------------------------------------------------------------
; Retuned 2026-06-15: ~4x stronger (was 0,0,40,32,24,16,8,0 = 8cp/step).
; PROVEN bottleneck: in the R+Q+5P vs K mate the winning king refused to march
; (g1<->h1<->f1 shuffle for ~11 moves) because closing toward the enemy king
; netted only +8cp — tied with shuffling, so the engine wouldn't commit. The
; mate appeared the instant the king finally reached the enemy. Now ~30-35cp/
; step so each marching step clearly beats a wait move. Max 150 < passer/runner
; bonuses (250-600) so this never pulls the king off a passer in a K+P race.
KING_PROX_BONUS:
    DB   0,  0,150,115, 80, 50, 25,  0   ; dist 0..7 (~30-35cp/step march)

; ==============================================================================
; EVAL_ENDGAME - Add endgame-specific bonuses
; ==============================================================================
; Input:  6 = current score (material + PST)
;         7 = total material on board (calculated externally, or we calculate)
; Output: 6 = score with endgame bonuses
; Uses:   A, B, D, E, F
;
; Logic:
;   1. Check if we're in endgame (material below threshold)
;   2. If endgame:
;      - Add king centralization bonus for friendly king
;      - If winning significantly, add enemy king edge bonus
; ==============================================================================
; (EVAL_ENDGAME + CALC_TOTAL_MATERIAL REMOVED 2026-07-15 — symmetry audit)
; Both had ZERO call sites (the 'removed king-drive'); the live endgame king
; logic is in evaluate.asm's pc<12 block. The dead code ALSO contained
; side-to-move-relative sign bugs (mover's centralization credited to white;
; winning gate read raw R9) — deleted rather than fixed. git-revert restores.
; KING_CENTER_TABLE / KING_EDGE_TABLE below remain LIVE (evaluate.asm uses them).
; ==============================================================================


; ==============================================================================
; End of Endgame Heuristics
; ==============================================================================
