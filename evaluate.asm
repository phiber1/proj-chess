; ==============================================================================
; RCA 1802/1806 Chess Engine - Position Evaluation
; ==============================================================================
; Evaluate board position and return score
; Positive score favors white, negative favors black
; ==============================================================================

; ------------------------------------------------------------------------------
; Piece Values (in centipawns)
; ------------------------------------------------------------------------------
PAWN_VALUE      EQU 100
KNIGHT_VALUE    EQU 320
BISHOP_VALUE    EQU 330
ROOK_VALUE      EQU 500
QUEEN_VALUE     EQU 900
KING_VALUE      EQU 20000   ; Effectively infinite (not used in material count)

; Piece value table (indexed by piece type 0-6)
PIECE_VALUES:
    DW 0            ; Empty (type 0)
    DW 100          ; Pawn (type 1)
    DW 320          ; Knight (type 2)
    DW 330          ; Bishop (type 3)
    DW 500          ; Rook (type 4)
    DW 900          ; Queen (type 5)
    DW 0            ; King (type 6) - don't count in material

; ------------------------------------------------------------------------------
; EVALUATE - Main evaluation function
; ------------------------------------------------------------------------------
; Input:  A = board pointer (BOARD)
; Output: R9 = evaluation score (16-bit signed)
;         Positive = white advantage
;         Negative = black advantage
; NOTE:   Returns in R9, NOT R6! R6 is SCRT linkage register - off limits!
; Uses:   All registers except R6
;
; Components (in order of implementation):
;   1. Material count (DONE)
;   2. Piece-square tables (TODO)
;   3. Pawn structure (TODO)
;   4. King safety (TODO)
;   5. Mobility (TODO)
; ------------------------------------------------------------------------------
EVALUATE:
    ; Ensure X=2 for all stack/memory operations
    SEX 2

    ; Initialize score to 0
    ; NOTE: Use R9 for score, NOT R6! R6 is SCRT linkage register!
    LDI 0
    PHI 9
    PLO 9              ; R9 = 0 (score accumulator)

    ; Scan board and count material
    RLDI 10, BOARD

    ; Initialize square counter in memory (avoid R14!)
    RLDI 13, EVAL_SQ_INDEX
    LDI 0
    STR 13              ; EVAL_SQ_INDEX = 0

    ; Initialize piece counter in memory (D is still 0)
    RLDI 11, EG_PIECE_COUNT
    STR 11              ; EG_PIECE_COUNT = 0

    ; Initialize advanced pawn counters (D is still 0)
    RLDI 11, ADV_PAWN_W
    STR 11              ; ADV_PAWN_W = 0
    INC 11
    STR 11              ; ADV_PAWN_B = 0

EVAL_SCAN:
    ; Check if square is valid (R13 points to EVAL_SQ_INDEX)
    LDN 13
    ANI $88
    LBNZ EVAL_NEXT_SQUARE

    ; Load piece at square
    LDN 10
    LBZ EVAL_NEXT_SQUARE ; Empty square

    ; Get piece type and color
    ; NOTE: R13 must stay pointing to EVAL_SQ_INDEX - use R8 for piece temp!
    PLO 8               ; R8.0 = piece (temp storage)

    ; Check color
    ANI COLOR_MASK
    PLO 15              ; F.0 = color (0=white, 8=black)

    ; Get piece type
    GLO 8               ; Get piece back from R8.0
    ANI PIECE_MASK
    PLO 8               ; R8.0 = piece type (1-6)

    ; Skip king (type 6)
    XRI 6
    LBZ EVAL_NEXT_SQUARE

    ; Count non-king piece (memory variable — R12 is side-to-move, off limits)
    RLDI 11, EG_PIECE_COUNT
    LDN 11
    ADI 1
    STR 11

    ; Check if pawn for advanced pawn bonus (graduated)
    GLO 8               ; piece type (1-5)
    XRI 1
    LBNZ EVAL_NOT_ADV_PAWN  ; not a pawn (+3 instr for non-pawns)
    ; Pawn — extract rank from 0x88 square
    LDN 13              ; D = 0x88 square (from EVAL_SQ_INDEX)
    ANI $70             ; D = rank << 4 ($00-$70)
    STR 2               ; save rank<<4 on stack
    GLO 15              ; D = color (0=white, 8=black)
    LBNZ EVAL_BP_ADV
    ; === White pawn: rank 7=$60 (+96), rank 6=$50 (+64), rank 5=$40 (+32) ===
    LDN 2
    XRI $60
    LBZ EVAL_WP_R7
    LDN 2
    XRI $50
    LBZ EVAL_WP_R6
    LDN 2
    XRI $40
    LBNZ EVAL_NOT_ADV_PAWN
    LDI 32              ; rank 5
    LBR EVAL_WP_ADD
EVAL_WP_R7:
    LDI 96              ; rank 7
    LBR EVAL_WP_ADD
EVAL_WP_R6:
    LDI 64              ; rank 6
EVAL_WP_ADD:
    STR 2
    RLDI 11, ADV_PAWN_W
    LDN 11
    ADD
    STR 11              ; ADV_PAWN_W += bonus
    LBR EVAL_NOT_ADV_PAWN
EVAL_BP_ADV:
    ; === Black pawn: rank 2=$10 (+96), rank 3=$20 (+64), rank 4=$30 (+32) ===
    LDN 2
    XRI $10
    LBZ EVAL_BP_R2
    LDN 2
    XRI $20
    LBZ EVAL_BP_R3
    LDN 2
    XRI $30
    LBNZ EVAL_NOT_ADV_PAWN
    LDI 32              ; rank 4
    LBR EVAL_BP_ADD
EVAL_BP_R2:
    LDI 96              ; rank 2
    LBR EVAL_BP_ADD
EVAL_BP_R3:
    LDI 64              ; rank 3
EVAL_BP_ADD:
    STR 2
    RLDI 11, ADV_PAWN_B
    LDN 11
    ADD
    STR 11              ; ADV_PAWN_B += bonus
EVAL_NOT_ADV_PAWN:

    ; Get piece value from table
    ; R8.0 = piece type (1-6), need to look up in PIECE_VALUES table
    GLO 8               ; Piece type from R8.0
    SHL                 ; Multiply by 2 (16-bit table entries)
    STR 2               ; Save offset to stack
    LDI LOW(PIECE_VALUES)
    ADD                 ; D = LOW(PIECE_VALUES) + offset
    PLO 11              ; R11.0 = low byte of address
    LDI HIGH(PIECE_VALUES)
    ADCI 0              ; Add carry if low byte overflowed
    PHI 11              ; R11 = PIECE_VALUES + (type * 2)

    ; Load 16-bit value
    LDA 11
    PHI 7              ; 7.1 = value high
    LDN 11
    PLO 7              ; 7.0 = value low
                        ; 7 = piece value

    ; Add or subtract based on color
    GLO 15              ; Color
    BZ EVAL_ADD_WHITE

EVAL_ADD_BLACK:
    ; Black piece - subtract from score (negate 7)
    CALL NEG16_R7
    ; Fall through to add

EVAL_ADD_WHITE:
    ; White piece or negated black - add to score
    ; R9 = R9 + R7 (using R9 for score, not R6 which is SCRT linkage!)
    GLO 9
    STR 2
    GLO 7
    ADD
    PLO 9
    GHI 9
    STR 2
    GHI 7
    ADC
    PHI 9
    ; 6 updated with new score

EVAL_NEXT_SQUARE:
    INC 10              ; Next square
    ; Increment square counter in memory (R13 still points to EVAL_SQ_INDEX)
    LDN 13
    ADI 1
    STR 13
    SMI 128
    LBNF EVAL_SCAN      ; Continue if < 128 (DF=0 means borrow, i.e., D was < 128)

EVAL_DONE:
    ; R9 contains material score
    ; Add piece-square table bonuses
    CALL EVAL_PST

    ; ==================================================================
    ; Castling Rights Bonus
    ; +20cp per side that still has castling rights remaining
    ; Incentivizes preserving the option to castle
    ; ==================================================================
    RLDI 11, GAME_STATE + STATE_CASTLING
    LDN 11              ; D = castling rights byte
    STR 2               ; save for reuse
    ANI $03             ; white bits (WK|WQ)
    LBZ EVAL_NO_W_CASTLE
    GLO 9
    ADI 20
    PLO 9
    GHI 9
    ADCI 0
    PHI 9               ; R9 += 20 (white has castling rights)
EVAL_NO_W_CASTLE:
    LDN 2               ; reload castling byte
    ANI $0C             ; black bits (BK|BQ)
    LBZ EVAL_NO_B_CASTLE
    GLO 9
    SMI 20
    PLO 9
    GHI 9
    SMBI 0
    PHI 9               ; R9 -= 20 (black has castling rights)
EVAL_NO_B_CASTLE:

    ; ==================================================================
    ; Endgame King Centralization
    ; If few pieces remain (<=10 non-king), add centralization bonuses
    ; using KING_CENTER_TABLE (in endgame.asm) scaled 4x via SHL SHL.
    ; Overcomes PST_KING middlegame values in endgame positions.
    ; ==================================================================

    RLDI 11, EG_PIECE_COUNT
    LDN 11              ; D = piece count
    SMI 21              ; compare: count - 21
    LBDF BKS_DONE       ; DF=1 means count >= 21, not endgame, skip

    ; === White king centralization ===
    RLDI 10, GAME_STATE + STATE_W_KING_SQ
    LDN 10              ; D = white king 0x88 square
    ; Convert 0x88 to 0-63 index
    PLO 13              ; save square
    SHR
    SHR
    SHR
    SHR                 ; D = rank (0-7)
    SHL
    SHL
    SHL                 ; D = rank * 8
    STXD                ; push rank*8
    GLO 13
    ANI $07             ; D = file (0-7)
    IRX
    ADD                 ; D = rank*8 + file = index
    PLO 15              ; save white king index in R15.0
    ; Look up centralization value
    STR 2               ; save index on stack
    RLDI 11, KING_CENTER_TABLE
    GLO 11
    ADD                 ; D = LOW(table) + index
    PLO 11
    GHI 11
    ADCI 0
    PHI 11              ; R11 = &KING_CENTER_TABLE[index]
    LDN 11              ; D = table value (-30 to +30)
    SHL                 ; D = value * 2
    SHL                 ; D = value * 4 (-120 to +120)
    ; Sign-extend to 16 bits and add to R9
    PLO 7               ; R7.0 = bonus low byte
    ANI $80             ; check sign
    LBZ EG_W_POS
    LDI $FF
    LBR EG_W_HI
EG_W_POS:
    LDI 0
EG_W_HI:
    PHI 7               ; R7 = sign-extended 16-bit bonus
    ; R9 = R9 + R7 (add white king centralization)
    GLO 9
    STR 2
    GLO 7
    ADD
    PLO 9
    GHI 9
    STR 2
    GHI 7
    ADC
    PHI 9

    ; === Black king centralization ===
    RLDI 10, GAME_STATE + STATE_B_KING_SQ
    LDN 10              ; D = black king 0x88 square
    ; Convert 0x88 to 0-63 index
    PLO 13              ; save square
    SHR
    SHR
    SHR
    SHR                 ; D = rank
    SHL
    SHL
    SHL                 ; D = rank * 8
    STXD                ; push rank*8
    GLO 13
    ANI $07             ; D = file
    IRX
    ADD                 ; D = index
    PHI 15              ; save black king index in R15.1
    ; Look up centralization value
    STR 2
    RLDI 11, KING_CENTER_TABLE
    GLO 11
    ADD
    PLO 11
    GHI 11
    ADCI 0
    PHI 11              ; R11 = &KING_CENTER_TABLE[index]
    LDN 11              ; D = table value (-30 to +30)
    SHL                 ; D * 2
    SHL                 ; D * 4 (-120 to +120)
    ; Sign-extend to 16 bits into R7
    PLO 7
    ANI $80
    LBZ EG_B_POS
    LDI $FF
    LBR EG_B_HI
EG_B_POS:
    LDI 0
EG_B_HI:
    PHI 7               ; R7 = sign-extended 16-bit bonus
    ; R9 = R9 - R7 (subtract black king centralization)
    GLO 7
    STR 2
    GLO 9
    SM                  ; D = R9.0 - R7.0
    PLO 9
    GHI 7
    STR 2
    GHI 9
    SMB                 ; D = R9.1 - R7.1 - borrow
    PHI 9

    ; ==================================================================
    ; Advanced Pawn Bonus (endgame only)
    ; Graduated: +32/+64/+96 cp based on distance from promotion
    ; ==================================================================

    ; White advanced pawn bonus (accumulated)
    RLDI 11, ADV_PAWN_W
    LDN 11              ; D = accumulated white bonus (0-255)
    LBZ EG_NO_W_ADV     ; none, skip
    STR 2               ; save bonus on stack
    GLO 9
    ADD                 ; R9.0 + bonus
    PLO 9
    GHI 9
    ADCI 0
    PHI 9               ; R9 += white pawn bonus
EG_NO_W_ADV:

    ; Black advanced pawn bonus (accumulated)
    RLDI 11, ADV_PAWN_B
    LDN 11
    LBZ EG_NO_B_ADV     ; none, skip
    STR 2               ; save bonus on stack
    GLO 9
    SM                  ; D = R9.0 - bonus
    PLO 9
    GHI 9
    SMBI 0
    PHI 9               ; R9 -= black pawn bonus
EG_NO_B_ADV:

    ; ==================================================================
    ; Enemy King Edge Penalty (endgame only, when winning)
    ; Uses KING_EDGE_TABLE (already in binary, 64 bytes)
    ; Values: 0 at edges/corners, 60 at center
    ; Scaled 2x via SHL for effective range 0-120cp
    ; ==================================================================

    ; Check if white is winning significantly (score > 200)
    GHI 9
    ANI $80             ; sign bit
    LBNZ EG_CHECK_BLACK ; negative, check if black winning
    GHI 9
    LBNZ EG_DRIVE_BLACK ; high byte > 0 → score > 255
    GLO 9
    SMI 200
    LBNF EG_EDGE_DONE   ; score < 200, skip

EG_DRIVE_BLACK:
    ; White winning — penalize black king for being in center
    ; R15.1 = black king index (saved during centralization)
    GHI 15              ; D = black king 0-63 index
    STR 2               ; save on stack
    RLDI 11, KING_EDGE_TABLE
    GLO 11
    ADD
    PLO 11
    GHI 11
    ADCI 0
    PHI 11              ; R11 = &KING_EDGE_TABLE[black_king]
    LDN 11              ; D = edge value (0-60)
    SHL                 ; D = value * 2 (0-120)
    STR 2               ; save bonus
    GLO 9
    ADD
    PLO 9
    GHI 9
    ADCI 0
    PHI 9               ; R9 += edge bonus (always positive, no sign extend)
    LBR EG_EDGE_DONE

EG_CHECK_BLACK:
    ; Check if black is winning (score < -200)
    ; Score is negative. Check if <= -201 (i.e., high byte < $FF or low byte <= $37)
    GHI 9
    XRI $FF
    LBNZ EG_DRIVE_WHITE ; high byte < $FF → score < -255
    GLO 9
    ADI 200             ; if score_lo + 200 overflows, score_lo > 55 → score > -201
    LBDF EG_EDGE_DONE   ; score > -201, not winning enough

EG_DRIVE_WHITE:
    ; Black winning — penalize white king for being in center
    ; R15.0 = white king index (saved during centralization)
    GLO 15              ; D = white king 0-63 index
    STR 2
    RLDI 11, KING_EDGE_TABLE
    GLO 11
    ADD
    PLO 11
    GHI 11
    ADCI 0
    PHI 11              ; R11 = &KING_EDGE_TABLE[white_king]
    LDN 11              ; D = edge value (0-60)
    SHL                 ; D = value * 2 (0-120)
    STR 2               ; save penalty
    GLO 9
    SM                  ; R9.0 - penalty (SM = D - M(R(X)))
    PLO 9
    GHI 9
    SMBI 0
    PHI 9               ; R9 -= edge penalty

EG_EDGE_DONE:

BKS_DONE:
    RETN

; ------------------------------------------------------------------------------
; EVALUATE_MATERIAL - Material-only evaluation (fast version)
; ------------------------------------------------------------------------------
; Simplified evaluation for leaf nodes where speed is critical
; Input:  A = board pointer
; Output: R9 = material score (NOT R6 - R6 is SCRT linkage, off limits!)
; ------------------------------------------------------------------------------
EVALUATE_MATERIAL:
    ; Alias to main evaluate for now
    ; Later can optimize this path
    LBR EVALUATE

; ------------------------------------------------------------------------------
; PST Evaluation (Piece-Square Tables) - TODO
; ------------------------------------------------------------------------------
; Adds positional bonuses based on piece placement
; Tables stored in ROM/fixed RAM
;
; Structure:
;   - 6 tables (pawn, knight, bishop, rook, queen, king)
;   - Each table: 64 bytes (one per square)
;   - Values: signed offsets to add to material
;
; Total size: 6 * 64 = 384 bytes
; Location: $2000-$217F (from memory map)
; ------------------------------------------------------------------------------

; PST table labels defined in pst.asm (follow code placement)

EVAL_WITH_PST:
    ; Call material evaluation first
    CALL EVALUATE_MATERIAL
    ; Returns in R9 (NOT R6 - R6 is SCRT linkage, off limits!)

    ; Save material score (R9) to stack
    GLO 9
    STXD
    GHI 9
    STXD

    ; Scan board again for PST bonuses
    RLDI 10, BOARD

    ; Initialize square counter in memory (avoid R14!)
    RLDI 13, EVAL_SQ_INDEX
    LDI 0
    STR 13              ; Square counter = 0
    PHI 8
    PLO 8              ; 8 = PST score accumulator

EVAL_PST_SCAN:
    LDN 13              ; Get square counter from memory
    ANI $88
    LBNZ EVAL_PST_NEXT

    LDN 10
    LBZ EVAL_PST_NEXT

    ; TODO: Implement PST lookup and addition
    ; 1. Get piece type and color
    ; 2. Calculate PST table address
    ; 3. Convert 0x88 square to 0-63 index
    ; 4. Load PST value
    ; 5. Add/subtract based on color

EVAL_PST_NEXT:
    INC 10
    ; Increment square counter in memory
    LDN 13
    ADI 1
    STR 13
    SMI 128
    LBNF EVAL_PST_SCAN  ; Long branch - BM can't reach target

    ; Add PST score to material score
    ; Restore material score from stack into R9
    IRX
    LDXA
    PHI 9
    LDX
    PLO 9              ; R9 = material score restored

    ; R9 = R9 + R8 (PST score) via R7
    GLO 8
    PLO 7
    GHI 8
    PHI 7
    ; ADD16 inline: R9 = R9 + R7
    GLO 9
    STR 2
    GLO 7
    ADD
    PLO 9
    GHI 9
    STR 2
    GHI 7
    ADC
    PHI 9              ; R9 = total score (material + PST)

    RETN

; ------------------------------------------------------------------------------
; Evaluation Helpers
; ------------------------------------------------------------------------------

; SQUARE_0x88_TO_0x40 - Convert 0x88 square to 0-63 index
; Input:  D = 0x88 square
; Output: D = 0-63 index
; Uses stack instead of R14
SQUARE_0x88_TO_0x40:
    SEX 2               ; Ensure X=2 for stack operations
    PLO 13              ; Save square

    ; Rank = square >> 4
    SHR
    SHR
    SHR
    SHR                 ; D = rank (0-7)

    ; Multiply rank by 8 (shift left 3)
    SHL
    SHL
    SHL                 ; D = rank * 8

    STXD                ; Save rank*8 to stack

    ; File = square & 7
    GLO 13
    ANI $07             ; D = file (0-7)

    ; Index = rank * 8 + file
    IRX
    ADD                 ; D = (rank * 8) + file

    RETN

; ==============================================================================
; End of Evaluation
; ==============================================================================
