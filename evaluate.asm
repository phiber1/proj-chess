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
    ; DEBUG WF: No debug output here - using breakpoint in negamax

    ; Initialize score to 0
    ; NOTE: Use R9 for score, NOT R6! R6 is SCRT linkage register!
    LDI 0
    PHI 9
    PLO 9              ; R9 = 0 (score accumulator)

    ; Scan board and count material
    LDI HIGH(BOARD)
    PHI 10
    LDI LOW(BOARD)
    PLO 10              ; A = board start

    ; Initialize square counter in memory (avoid R14!)
    LDI HIGH(EVAL_SQ_INDEX)
    PHI 13
    LDI LOW(EVAL_SQ_INDEX)
    PLO 13
    LDI 0
    STR 13              ; EVAL_SQ_INDEX = 0

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
    ; TEMPORARILY BYPASS PST/ENDGAME to isolate bug
    ; CALL EVAL_PST
    ; CALL EVAL_ENDGAME

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
    LDI HIGH(BOARD)
    PHI 10
    LDI LOW(BOARD)
    PLO 10

    ; Initialize square counter in memory (avoid R14!)
    LDI HIGH(EVAL_SQ_INDEX)
    PHI 13
    LDI LOW(EVAL_SQ_INDEX)
    PLO 13
    LDI 0
    STR 13              ; Square counter = 0
    PHI 8
    PLO 8              ; 8 = PST score accumulator

EVAL_PST_SCAN:
    LDN 13              ; Get square counter from memory
    ANI $88
    BNZ EVAL_PST_NEXT

    LDN 10
    BZ EVAL_PST_NEXT

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
