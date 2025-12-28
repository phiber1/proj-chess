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

; King to edge table (penalty for king being in center - used for enemy)
; Use this when we're winning to drive enemy king to corner
KING_EDGE_TABLE:
    ; Higher penalty in center, lower on edges/corners
    ; Rank 8
    DB   0, 10, 20, 30, 30, 20, 10,  0
    ; Rank 7
    DB  10, 20, 30, 40, 40, 30, 20, 10
    ; Rank 6
    DB  20, 30, 40, 50, 50, 40, 30, 20
    ; Rank 5
    DB  30, 40, 50, 60, 60, 50, 40, 30
    ; Rank 4
    DB  30, 40, 50, 60, 60, 50, 40, 30
    ; Rank 3
    DB  20, 30, 40, 50, 50, 40, 30, 20
    ; Rank 2
    DB  10, 20, 30, 40, 40, 30, 20, 10
    ; Rank 1
    DB   0, 10, 20, 30, 30, 20, 10,  0

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
EVAL_ENDGAME:
    ; First, calculate total material to determine if we're in endgame
    ; We'll do a quick scan counting major/minor pieces
    CALL CALC_TOTAL_MATERIAL
    ; Returns: 7 = total material (both sides combined, no pawns)

    ; Compare with endgame threshold
    ; If 7 < threshold, we're in endgame
    LDI ENDGAME_THRESHOLD_LO
    STR 2
    GLO 7
    SM                  ; D = 7.0 - threshold.0
    PLO 13
    LDI ENDGAME_THRESHOLD_HI
    STR 2
    GHI 7
    SMB                 ; D = 7.1 - threshold.1 - borrow

    ; If result is negative (DF=0), we're in endgame
    LBDF EVAL_EG_DONE    ; Not in endgame, skip

    ; === IN ENDGAME ===

    ; Get our king position and add centralization bonus
    LDI HIGH(GAME_STATE)
    PHI 10
    LDI LOW(GAME_STATE + STATE_SIDE_TO_MOVE)
    PLO 10
    LDN 10               ; D = side to move

    LBZ EVAL_EG_WHITE_KING

EVAL_EG_BLACK_KING:
    ; Black to move - get black king position
    LDI HIGH(GAME_STATE)
    PHI 10
    LDI LOW(GAME_STATE + STATE_B_KING_SQ)
    PLO 10
    LDN 10               ; D = black king square
    ; Store our king square in memory (R14 is off-limits!)
    STXD                 ; Save on stack temporarily
    LDI HIGH(EVAL_TEMP1)
    PHI 8
    LDI LOW(EVAL_TEMP1)
    PLO 8
    IRX
    LDX
    STR 8               ; EVAL_TEMP1 = our king square

    ; Get enemy (white) king for edge penalty
    LDI HIGH(GAME_STATE)
    PHI 10
    LDI LOW(GAME_STATE + STATE_W_KING_SQ)
    PLO 10
    LDN 10
    PLO 15               ; F.0 = enemy king square
    LBR EVAL_EG_CALC

EVAL_EG_WHITE_KING:
    ; White to move - get white king position
    LDI HIGH(GAME_STATE)
    PHI 10
    LDI LOW(GAME_STATE + STATE_W_KING_SQ)
    PLO 10
    LDN 10
    ; Store our king square in memory (R14 is off-limits!)
    STXD                 ; Save on stack temporarily
    LDI HIGH(EVAL_TEMP1)
    PHI 8
    LDI LOW(EVAL_TEMP1)
    PLO 8
    IRX
    LDX
    STR 8               ; EVAL_TEMP1 = our king square

    ; Get enemy (black) king for edge penalty
    LDI HIGH(GAME_STATE)
    PHI 10
    LDI LOW(GAME_STATE + STATE_B_KING_SQ)
    PLO 10
    LDN 10
    PLO 15               ; F.0 = enemy king square

EVAL_EG_CALC:
    ; Convert our king square to 0-63 index (load from EVAL_TEMP1)
    LDI HIGH(EVAL_TEMP1)
    PHI 8
    LDI LOW(EVAL_TEMP1)
    PLO 8
    LDN 8               ; D = our king square
    STXD                ; Save for reuse
    ANI $07             ; File
    PLO 13
    IRX
    LDX                 ; D = king square again
    ANI $70             ; Rank * 16
    SHR                 ; Rank * 8
    STR 2
    GLO 13
    ADD                 ; Index = rank*8 + file
    PLO 13               ; D.0 = index

    ; Look up centralization bonus
    LDI HIGH(KING_CENTER_TABLE)
    PHI 11
    LDI LOW(KING_CENTER_TABLE)
    PLO 11
    GLO 13
    STR 2
    GLO 11
    ADD
    PLO 11
    GHI 11
    ADCI 0
    PHI 11
    LDN 11               ; D = centralization bonus (signed)

    ; Add to score (6) - sign extend and add using memory temps
    ; (R14 is off-limits - BIOS uses it!)
    STXD                ; Save value on stack
    LDI HIGH(EVAL_TEMP1)
    PHI 8
    LDI LOW(EVAL_TEMP1)
    PLO 8
    IRX
    LDX                 ; D = value
    STR 8               ; EVAL_TEMP1 = low byte
    ANI $80
    LBZ EVAL_EG_CENTER_POS
    LDI $FF
    BR EVAL_EG_CENTER_STORE_HI
EVAL_EG_CENTER_POS:
    LDI 0
EVAL_EG_CENTER_STORE_HI:
    INC 8               ; Point to EVAL_TEMP2
    STR 8               ; EVAL_TEMP2 = high byte (sign extension)

EVAL_EG_CENTER_ADD:
    ; Add 16-bit value from memory to R9 (score accumulator, NOT R6!)
    LDI HIGH(EVAL_TEMP1)
    PHI 8
    LDI LOW(EVAL_TEMP1)
    PLO 8
    LDN 8               ; D = low byte
    STR 2
    GLO 9
    ADD
    PLO 9
    INC 8
    LDN 8               ; D = high byte
    STR 2
    GHI 9
    ADC
    PHI 9

    ; Now check if we're winning significantly (score > 200 centipawns)
    ; If so, add bonus for enemy king being on edge
    GHI 9
    ANI $80             ; Check sign
    LBNZ EVAL_EG_DONE    ; We're losing, don't push enemy king

    ; Check if score > 200
    GHI 9
    LBNZ EVAL_EG_ENEMY_KING ; High byte > 0, definitely > 200
    GLO 9
    SMI 200
    LBNF EVAL_EG_DONE    ; Score < 200, skip enemy king bonus

EVAL_EG_ENEMY_KING:
    ; Convert enemy king square (F.0) to 0-63 index
    GLO 15
    ANI $07             ; File
    PLO 13
    GLO 15
    ANI $70             ; Rank * 16
    SHR                 ; Rank * 8
    STR 2
    GLO 13
    ADD
    PLO 13               ; D.0 = index

    ; Look up edge bonus (penalty for enemy king in center)
    LDI HIGH(KING_EDGE_TABLE)
    PHI 11
    LDI LOW(KING_EDGE_TABLE)
    PLO 11
    GLO 13
    STR 2
    GLO 11
    ADD
    PLO 11
    GHI 11
    ADCI 0
    PHI 11
    LDN 11               ; D = edge bonus

    ; Add to score (unsigned, always positive) - R9 is score!
    STR 2
    GLO 9
    ADD
    PLO 9
    GHI 9
    ADCI 0
    PHI 9

EVAL_EG_DONE:
    RETN

; ==============================================================================
; CALC_TOTAL_MATERIAL - Calculate total non-pawn material on board
; ==============================================================================
; Output: 7 = total material (knights, bishops, rooks, queens)
; Used to determine if we're in endgame
; ==============================================================================
CALC_TOTAL_MATERIAL:
    ; Initialize
    LDI 0
    PHI 7
    PLO 7               ; 7 = 0

    LDI HIGH(BOARD)
    PHI 10
    LDI LOW(BOARD)
    PLO 10

    ; Square counter in memory (R14 is off-limits!)
    LDI HIGH(EVAL_TEMP1)
    PHI 8
    LDI LOW(EVAL_TEMP1)
    PLO 8
    LDI 0
    STR 8               ; EVAL_TEMP1 = 0

CALC_MAT_LOOP:
    ; Check valid square (load from memory)
    LDI HIGH(EVAL_TEMP1)
    PHI 8
    LDI LOW(EVAL_TEMP1)
    PLO 8
    LDN 8               ; D = square counter
    ANI $88
    LBNZ CALC_MAT_NEXT

    ; Load piece
    LDN 10
    LBZ CALC_MAT_NEXT    ; Empty

    ; Get piece type
    ANI PIECE_MASK

    ; Skip pawns and kings
    XRI PAWN_TYPE
    LBZ CALC_MAT_NEXT

    GLO 10               ; Get piece again (can't, A is pointer)
    ; Actually need to reload
    LDN 10
    ANI PIECE_MASK
    XRI KING_TYPE
    LBZ CALC_MAT_NEXT

    ; It's a minor or major piece - add its value
    LDN 10
    ANI PIECE_MASK      ; Piece type
    PLO 13               ; D.0 = type

    ; Get value from table
    SHL                 ; type * 2 (16-bit values)
    PLO 11
    LDI HIGH(PIECE_VALUES)
    PHI 11
    LDI LOW(PIECE_VALUES)
    STR 2
    GLO 11
    ADD
    PLO 11
    GHI 11
    ADCI 0
    PHI 11

    LDA 11               ; High byte of value
    PHI 13
    LDN 11               ; Low byte
    PLO 13               ; D = piece value

    ; Add to total (7 = 7 + D)
    GLO 13
    STR 2
    GLO 7
    ADD
    PLO 7
    GHI 13
    STR 2
    GHI 7
    ADC
    PHI 7

CALC_MAT_NEXT:
    INC 10
    ; Increment square counter in memory (R14 is off-limits!)
    LDI HIGH(EVAL_TEMP1)
    PHI 8
    LDI LOW(EVAL_TEMP1)
    PLO 8
    LDN 8               ; D = counter
    ADI 1               ; Increment
    STR 8               ; Store back
    XRI $80             ; Check if done (128)
    LBNZ CALC_MAT_LOOP

    RETN

; ==============================================================================
; End of Endgame Heuristics
; ==============================================================================
