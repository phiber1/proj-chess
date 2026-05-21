; ==============================================================================
; N2 - Hanging-pawn penalty (overflow page $7B00)
; ==============================================================================
; For each pawn:
;   1. Check own-pawn defender on diagonally-backward adjacent squares.
;   2. If defended, skip (no penalty regardless of attackers).
;   3. Otherwise, count opposing bishop/queen attackers via 4 diagonals.
;   4. Per attacker: -25 cp (white pawn) / +25 cp (black pawn).
;
; Catches the 2026-05-20 PM match's bishop-attack blunders:
;   move 38 g2-g4 with Bf5 attacking g4 (and chronic c2 hanging on Bf5 diag)
;   move 61 e5-e6 with bishop attacking e6
;
; Knight-on-pawn attacks NOT yet checked (deferred — not seen in match data
; as a recurring pattern, and adds ~40 bytes that would overflow page $7B00).
; Can be added in a follow-up if needed.
;
; Input:  R9 = current eval score
; Output: R9 = score with N2 penalty applied
; Uses:   R7, R8, R10, R11, R13 (preserves R6/SCRT, R9 score, R12 stm)
; ==============================================================================

    ORG $7B00

N2_HANGING_PAWN:
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
    LBZ N2_INC

    PLO 8
    ANI PIECE_MASK
    XRI PAWN_TYPE
    LBNZ N2_INC

    GLO 8
    ANI COLOR_MASK
    PHI 8                       ; R8.1 = pawn color

    LDN 13
    PLO 7                       ; R7.0 = pawn sq

    ; Defender check — 2 candidates, color-dependent deltas
    GHI 8
    LBNZ N2_DCB
    LDI $EF
    LBR N2_DCG
N2_DCB:
    LDI $0F
N2_DCG:
    CALL N2_CHECK_DEF
    LBNZ N2_INC

    GHI 8
    LBNZ N2_DCB2
    LDI $F1
    LBR N2_DCG2
N2_DCB2:
    LDI $11
N2_DCG2:
    CALL N2_CHECK_DEF
    LBNZ N2_INC

    ; Attacker count
    LDI 0
    PHI 7                       ; R7.1 = 0

    LDI $11
    CALL N2_DIAG_WALK
    LDI $0F
    CALL N2_DIAG_WALK
    LDI $EF
    CALL N2_DIAG_WALK
    LDI $F1
    CALL N2_DIAG_WALK

    ; Apply penalty: 25 cp per attacker, signed by color
    GHI 7
    LBZ N2_INC                  ; 0 attackers
    PLO 8                       ; R8.0 = loop count

    GHI 8                       ; pawn color
    LBNZ N2_AP_PLUS

N2_AP_NEG:
    GLO 9
    SMI 25
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
    ADI 25
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
; N2_DIAG_WALK — walk diagonal from R7.0 with delta D; if opp B/Q found,
;                increment R7.1 (attacker count).
; Uses: R10, R11 (clobbered)
; ------------------------------------------------------------------------------
N2_DIAG_WALK:
    PLO 11                      ; R11.0 = delta
    GLO 7
    PHI 11                      ; R11.1 = walker

N2_DW_LOOP:
    GLO 11
    STR 2
    GHI 11
    ADD
    PHI 11
    ANI $88
    LBNZ N2_DW_DONE

    GHI 11
    ADI LOW(BOARD)
    PLO 10
    LDI HIGH(BOARD)
    ADCI 0
    PHI 10
    LDN 10
    LBZ N2_DW_LOOP

    PLO 10                      ; R10.0 = piece byte (reuse)
    ANI COLOR_MASK
    STR 2
    GHI 8
    XOR
    LBZ N2_DW_DONE              ; same-color blocker

    GLO 10
    ANI PIECE_MASK
    XRI BISHOP_TYPE
    LBZ N2_DW_HIT
    GLO 10
    ANI PIECE_MASK
    XRI QUEEN_TYPE
    LBNZ N2_DW_DONE

N2_DW_HIT:
    GHI 7
    ADI 1
    PHI 7

N2_DW_DONE:
    RETN

; ==============================================================================
; End of N2 overflow code
; ==============================================================================
