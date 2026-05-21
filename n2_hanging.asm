; ==============================================================================
; N2/N3 - Hanging-piece penalty (overflow page $7B00)
; ==============================================================================
; For each own non-king piece:
;   1. Check own-pawn defender on diagonally-backward adjacent squares.
;   2. If defended, skip (no penalty).
;   3. Otherwise, count opposing bishop/queen attackers via 4 diagonals.
;   4. Apply flat -50 cp per attacker (sign by side):
;        white piece -> R9 -= 50 per attacker
;        black piece -> R9 += 50 per attacker
;
; Magnitude rationale: -50 per attacker is a middle-ground signal.
;   For pawn (value 100): 1 attacker = -50 = "half a pawn loss" warning.
;   For knight/bishop (320/330): 1 attacker = -50 = small but informative.
;   For rook/queen (500/900): 1 attacker = -50 = light signal.
; Piece-value-weighted penalty was the original plan but didn't fit in the
; $7B00 256-byte overflow page along with all helpers; deferred to a future
; expansion if dead-code reclamation frees more space or we move to a different
; layout. Flat penalty is sufficient to surface the "hanging piece" condition.
;
; N2 (pawn-only, 2026-05-21): caught Bf5-attacks-c2 chronic-hanging
; pattern from the 2026-05-20 PM match.
;
; N3 (this expansion, 2026-05-21): extends N2 to ALL non-king pieces, with
; weighted penalty. Catches hanging knights/bishops/rooks/queens too.
; Useful for general "leave your own pieces undefended" patterns.
;
; Defender check is own-pawn-backward-diagonal only — for non-pawn pieces
; this misses non-pawn defenders. Accept the over-penalization risk for v1.
;
; Attack-detection limitations (deferred):
;   - Rook / queen line attacks (file/rank) not detected
;   - Knight attacks not detected
;
; Input:  R9 = current eval score
; Output: R9 = score with hanging-piece penalty applied
; Uses:   R7, R8, R10, R11, R13 (preserves R6/SCRT, R9 score, R12 stm)
;         N2_ATK_COUNT memory byte ($64F1) as per-piece scratch
; ==============================================================================

    ORG $7B00

N2_HANGING_PAWN:                ; legacy name; routine now handles all non-king pieces
    SEX 2
    RLDI 13, EVAL_SQ_INDEX
    LDI 0
    STR 13

N2_LOOP:
    LDN 13
    XRI $80
    LBZ N2_DONE

    LDN 13
    ANI $88
    LBNZ N2_INC

    LDN 13
    ADI LOW(BOARD)
    PLO 10
    LDI HIGH(BOARD)
    ADCI 0
    PHI 10
    LDN 10
    LBZ N2_INC                  ; empty

    PLO 8                       ; R8.0 = piece byte
    ANI PIECE_MASK              ; piece type 1-6
    XRI KING_TYPE
    LBZ N2_INC                  ; skip king

    GLO 8
    ANI COLOR_MASK
    PHI 8                       ; R8.1 = piece color (0=W, 8=B)

    LDN 13
    PLO 7                       ; R7.0 = piece sq

    ; --- DEFENDER CHECK (own-pawn backward-diagonal) ---
    GHI 8
    LBNZ N2_DCB
    LDI $EF
    LBR N2_DCG
N2_DCB:
    LDI $0F
N2_DCG:
    CALL N2_CHECK_DEF
    LBNZ N2_INC                 ; defended

    GHI 8
    LBNZ N2_DCB2
    LDI $F1
    LBR N2_DCG2
N2_DCB2:
    LDI $11
N2_DCG2:
    CALL N2_CHECK_DEF
    LBNZ N2_INC

    ; --- ATTACKER COUNT via 4 diagonals ---
    LDI 0
    RLDI 10, N2_ATK_COUNT
    STR 10                      ; N2_ATK_COUNT = 0

    LDI $11
    CALL N2_DIAG_WALK
    LDI $0F
    CALL N2_DIAG_WALK
    LDI $EF
    CALL N2_DIAG_WALK
    LDI $F1
    CALL N2_DIAG_WALK

    ; --- APPLY PENALTY: flat 50 cp per attacker ---
    RLDI 10, N2_ATK_COUNT
    LDN 10
    LBZ N2_INC                  ; 0 attackers

    PLO 8                       ; R8.0 = attacker count (loop)

    GHI 8                       ; piece color
    LBNZ N2_AP_PLUS

N2_AP_NEG:
    GLO 9
    SMI 50
    PLO 9
    GHI 9
    SMBI 0
    PHI 9
    DEC 8
    GLO 8
    LBNZ N2_AP_NEG
    LBR N2_INC

N2_AP_PLUS:
    GLO 9
    ADI 50
    PLO 9
    GHI 9
    ADCI 0
    PHI 9
    DEC 8
    GLO 8
    LBNZ N2_AP_PLUS

N2_INC:
    LDN 13
    ADI 1
    STR 13
    LBR N2_LOOP

N2_DONE:
    RETN

; ------------------------------------------------------------------------------
; N2_CHECK_DEF  — D=1 if own-pawn at sq=R7.0+D, else D=0
; Uses: R10, R11 (clobbered)
; ------------------------------------------------------------------------------
N2_CHECK_DEF:
    STR 2
    GLO 7
    ADD
    PLO 11
    ANI $88
    LBNZ N2_CD_NO

    GLO 11
    ADI LOW(BOARD)
    PLO 10
    LDI HIGH(BOARD)
    ADCI 0
    PHI 10
    LDN 10
    STR 2
    GHI 8
    ORI PAWN_TYPE
    XOR
    LBZ N2_CD_YES

N2_CD_NO:
    LDI 0
    RETN

N2_CD_YES:
    LDI 1
    RETN

; ------------------------------------------------------------------------------
; N2_DIAG_WALK — walk diagonal from R7.0 with delta D. If opp B/Q found,
;                increment N2_ATK_COUNT memory byte.
; Uses: R10, R11 (clobbered)
; ------------------------------------------------------------------------------
N2_DIAG_WALK:
    PLO 11                      ; R11.0 = delta
    GLO 7
    PHI 11                      ; R11.1 = walker

N2_DW_LOOP:
    GLO 11                      ; delta
    STR 2
    GHI 11                      ; walker
    ADD
    PHI 11
    ANI $88
    LBNZ N2_DW_DONE             ; off-board

    GHI 11
    ADI LOW(BOARD)
    PLO 10
    LDI HIGH(BOARD)
    ADCI 0
    PHI 10
    LDN 10
    LBZ N2_DW_LOOP              ; empty, continue

    PLO 10                      ; R10.0 = piece byte
    ANI COLOR_MASK
    STR 2
    GHI 8                       ; piece color
    XOR
    LBZ N2_DW_DONE              ; same color, blocker

    GLO 10
    ANI PIECE_MASK
    XRI BISHOP_TYPE
    LBZ N2_DW_HIT
    GLO 10
    ANI PIECE_MASK
    XRI QUEEN_TYPE
    LBNZ N2_DW_DONE

N2_DW_HIT:
    RLDI 10, N2_ATK_COUNT
    LDN 10
    ADI 1
    STR 10                      ; ++N2_ATK_COUNT

N2_DW_DONE:
    RETN

; ==============================================================================
; End of N2/N3 overflow code
; ==============================================================================
