; ==============================================================================
; Step 20: Search with Full Piece Move Generation
; Integrates movegen-new.asm with alpha-beta search framework
; ==============================================================================
;
; Test position: White Ke1 + Qd1 + Pa2 vs Black Ke8 + Pa7
; Position with multiple piece types to test full move generator
;
; Key integration:
; - R12 is used for PLY in search, but movegen-new uses R12 for side-to-move
; - Solution: Save ply to memory, set R12 = side based on ply, then restore
; - Even ply = WHITE (R12=0), Odd ply = BLACK (R12=8)
;
; ==============================================================================

    ORG $0000
    LBR MAIN

#include "serial-io.asm"

; SCRT Implementation
INITCALL:
    LDI HIGH(RET)
    PHI 5
    LDI LOW(RET)
    PLO 5
    LDI HIGH(CALL)
    PHI 4
    LDI LOW(CALL)
    PLO 4
    SEP 5
    SEP 3

CALL:
    PLO 7
    GHI 6
    SEX 2
    STXD
    GLO 6
    STXD
    GHI 3
    PHI 6
    GLO 3
    PLO 6
    LDA 6
    PHI 3
    LDA 6
    PLO 3
    GLO 7
    BR CALL-1
    SEP 3

RET:
    PLO 7
    GHI 6
    PHI 3
    GLO 6
    PLO 3
    SEX 2
    IRX
    LDXA
    PLO 6
    LDX
    PHI 6
    GLO 7
    BR RET-1

; ==============================================================================
; Constants
; ==============================================================================
BOARD       EQU $5000
GAME_STATE  EQU $5080
GS_CASTLE   EQU 0
GS_EP       EQU 1
SCORE_LO    EQU $5088
SCORE_HI    EQU $5089

; Ply-indexed storage (4 plies max)
PLY_BASE    EQU $5090
PLY_SIZE    EQU $10

; Offsets within each ply's storage
PLY_MOVE_PIECE  EQU 0
PLY_CAPT_PIECE  EQU 1
PLY_MOVE_FROM   EQU 2
PLY_MOVE_TO     EQU 3
PLY_ALPHA_LO    EQU 4
PLY_ALPHA_HI    EQU 5
PLY_BETA_LO     EQU 6
PLY_BETA_HI     EQU 7
PLY_PTR_LO      EQU 8
PLY_PTR_HI      EQU 9
PLY_BEST_LO     EQU 10
PLY_BEST_HI     EQU 11

; Search state
SEARCH_DEPTH    EQU $50D0
CURRENT_PLY     EQU $50D1
BEST_MOVE_FROM  EQU $50D2
BEST_MOVE_TO    EQU $50D3
BEST_SCORE_LO   EQU $50D4
BEST_SCORE_HI   EQU $50D5
NODE_COUNT_LO   EQU $50D6
NODE_COUNT_HI   EQU $50D7
CUTOFF_COUNT    EQU $50D8
TEMP_PLY        EQU $50D9      ; Save ply during movegen
SIDE_TO_MOVE    EQU $50DB      ; 0=White, 8=Black

; Per-ply move lists (32 bytes each = max 15 moves + terminator)
MOVELIST_PLY0   EQU $5100
MOVELIST_PLY1   EQU $5120
MOVELIST_PLY2   EQU $5140
MOVELIST_PLY3   EQU $5160

; Piece codes
EMPTY       EQU $00
WHITE       EQU $00
BLACK       EQU $08
COLOR_MASK  EQU $08
PIECE_MASK  EQU $07

W_PAWN      EQU $01
W_KNIGHT    EQU $02
W_BISHOP    EQU $03
W_ROOK      EQU $04
W_QUEEN     EQU $05
W_KING      EQU $06

B_PAWN      EQU $09
B_KNIGHT    EQU $0A
B_BISHOP    EQU $0B
B_ROOK      EQU $0C
B_QUEEN     EQU $0D
B_KING      EQU $0E

; Squares
SQ_A1       EQU $00
SQ_B1       EQU $01
SQ_C1       EQU $02
SQ_D1       EQU $03
SQ_E1       EQU $04
SQ_F1       EQU $05
SQ_G1       EQU $06
SQ_H1       EQU $07
SQ_A2       EQU $10
SQ_E8       EQU $74
SQ_A7       EQU $60
SQ_H8       EQU $77

; Castling rights
CASTLE_WK   EQU $01
CASTLE_WQ   EQU $02
CASTLE_BK   EQU $04
CASTLE_BQ   EQU $08
SQ_D8       EQU $73
SQ_C8       EQU $72
SQ_B8       EQU $71
SQ_F8       EQU $75
SQ_G8       EQU $76

; Direction offsets
DIR_N   EQU $F0
DIR_S   EQU $10
DIR_E   EQU $01
DIR_W   EQU $FF
DIR_NE  EQU $F1
DIR_NW  EQU $EF
DIR_SE  EQU $11
DIR_SW  EQU $0F

; Infinity
NEG_INF_LO  EQU $01
NEG_INF_HI  EQU $80
POS_INF_LO  EQU $FF
POS_INF_HI  EQU $7F

; ==============================================================================
; Main
; ==============================================================================
MAIN:
    LDI HIGH(START)
    PHI 6
    LDI LOW(START)
    PLO 6
    LBR INITCALL

START:
    LDI $7F
    PHI 2
    LDI $FF
    PLO 2
    SEX 2
    REQ

    ; Print banner
    LDI HIGH(STR_BANNER)
    PHI 8
    LDI LOW(STR_BANNER)
    PLO 8
    CALL SERIAL_PRINT_STRING

    ; Set up position
    CALL CLEAR_BOARD
    CALL SETUP_POSITION
    CALL INIT_GAME_STATE

    ; Print position
    LDI HIGH(STR_POS)
    PHI 8
    LDI LOW(STR_POS)
    PLO 8
    CALL SERIAL_PRINT_STRING

    ; Initialize counters
    LDI HIGH(NODE_COUNT_LO)
    PHI 10
    LDI LOW(NODE_COUNT_LO)
    PLO 10
    LDI 0
    STR 10
    INC 10
    STR 10
    INC 10
    STR 10              ; CUTOFF_COUNT = 0

    ; Set search depth to 2
    LDI HIGH(SEARCH_DEPTH)
    PHI 10
    LDI LOW(SEARCH_DEPTH)
    PLO 10
    LDI 2
    STR 10

    ; Set side to move = WHITE
    LDI HIGH(SIDE_TO_MOVE)
    PHI 10
    LDI LOW(SIDE_TO_MOVE)
    PLO 10
    LDI WHITE
    STR 10

    ; Print search info
    LDI HIGH(STR_SEARCH)
    PHI 8
    LDI LOW(STR_SEARCH)
    PLO 8
    CALL SERIAL_PRINT_STRING

    ; Initialize current ply to 0
    LDI HIGH(CURRENT_PLY)
    PHI 10
    LDI LOW(CURRENT_PLY)
    PLO 10
    LDI 0
    STR 10

    ; Call search
    CALL NEGAMAX_ROOT

    ; Print result
    LDI HIGH(STR_BEST)
    PHI 8
    LDI LOW(STR_BEST)
    PLO 8
    CALL SERIAL_PRINT_STRING

    LDI HIGH(BEST_MOVE_FROM)
    PHI 10
    LDI LOW(BEST_MOVE_FROM)
    PLO 10
    LDN 10
    CALL SERIAL_PRINT_HEX
    LDI '-'
    CALL SERIAL_WRITE_CHAR
    LDI HIGH(BEST_MOVE_TO)
    PHI 10
    LDI LOW(BEST_MOVE_TO)
    PLO 10
    LDN 10
    CALL SERIAL_PRINT_HEX
    LDI ' '
    CALL SERIAL_WRITE_CHAR

    LDI HIGH(BEST_SCORE_HI)
    PHI 10
    LDI LOW(BEST_SCORE_HI)
    PLO 10
    LDN 10
    CALL SERIAL_PRINT_HEX
    LDI HIGH(BEST_SCORE_LO)
    PHI 10
    LDI LOW(BEST_SCORE_LO)
    PLO 10
    LDN 10
    CALL SERIAL_PRINT_HEX
    CALL PRINT_CRLF

    ; Print nodes
    LDI HIGH(STR_NODES)
    PHI 8
    LDI LOW(STR_NODES)
    PLO 8
    CALL SERIAL_PRINT_STRING
    LDI HIGH(NODE_COUNT_HI)
    PHI 10
    LDI LOW(NODE_COUNT_HI)
    PLO 10
    LDN 10
    CALL SERIAL_PRINT_HEX
    LDI HIGH(NODE_COUNT_LO)
    PHI 10
    LDI LOW(NODE_COUNT_LO)
    PLO 10
    LDN 10
    CALL SERIAL_PRINT_HEX
    CALL PRINT_CRLF

    ; Done
    LDI HIGH(STR_DONE)
    PHI 8
    LDI LOW(STR_DONE)
    PLO 8
    CALL SERIAL_PRINT_STRING

HALT:
    BR HALT

; ==============================================================================
; NEGAMAX_ROOT - Root-level search
; Generates moves using full movegen, iterates through them
; ==============================================================================
NEGAMAX_ROOT:
    SEX 2

    ; Initialize best score to -infinity
    LDI HIGH(BEST_SCORE_LO)
    PHI 10
    LDI LOW(BEST_SCORE_LO)
    PLO 10
    LDI NEG_INF_LO
    STR 10
    INC 10
    LDI NEG_INF_HI
    STR 10

    ; Set up ply 0 alpha/beta
    LDI HIGH(PLY_BASE)
    PHI 10
    LDI LOW(PLY_BASE + PLY_ALPHA_LO)
    PLO 10
    LDI NEG_INF_LO
    STR 10
    INC 10
    LDI NEG_INF_HI
    STR 10
    INC 10
    LDI POS_INF_LO
    STR 10
    INC 10
    LDI POS_INF_HI
    STR 10

    ; Generate moves for ply 0 (WHITE)
    LDI 0
    PLO 12                  ; ply = 0
    CALL GENERATE_MOVES_FOR_PLY

    ; Set move pointer for ply 0
    LDI HIGH(PLY_BASE)
    PHI 10
    LDI LOW(PLY_BASE + PLY_PTR_LO)
    PLO 10
    LDI LOW(MOVELIST_PLY0)
    STR 10
    INC 10
    LDI HIGH(MOVELIST_PLY0)
    STR 10

NR_LOOP:
    ; Get move list pointer
    LDI HIGH(PLY_BASE)
    PHI 10
    LDI LOW(PLY_BASE + PLY_PTR_LO)
    PLO 10
    LDN 10
    PLO 11
    INC 10
    LDN 10
    PHI 11

    ; Check end of moves
    LDN 11
    XRI $FF
    LBZ NR_DONE

    ; Load move
    LDA 11
    PLO 9
    LDA 11
    PHI 9

    ; Save updated pointer
    LDI LOW(PLY_BASE + PLY_PTR_LO)
    PLO 10
    GLO 11
    STR 10
    INC 10
    GHI 11
    STR 10

    ; Save move in ply storage
    LDI LOW(PLY_BASE + PLY_MOVE_FROM)
    PLO 10
    GLO 9
    STR 10
    INC 10
    GHI 9
    STR 10

    ; Print move being tried
    LDI HIGH(STR_TRY)
    PHI 8
    LDI LOW(STR_TRY)
    PLO 8
    CALL SERIAL_PRINT_STRING

    LDI HIGH(PLY_BASE)
    PHI 10
    LDI LOW(PLY_BASE + PLY_MOVE_FROM)
    PLO 10
    LDN 10
    CALL SERIAL_PRINT_HEX
    LDI '-'
    CALL SERIAL_WRITE_CHAR
    INC 10
    LDN 10
    CALL SERIAL_PRINT_HEX

    ; Reload and make move
    LDI 0
    PLO 12
    LDI HIGH(PLY_BASE)
    PHI 10
    LDI LOW(PLY_BASE + PLY_MOVE_FROM)
    PLO 10
    LDN 10
    PLO 11
    INC 10
    LDN 10
    PHI 11
    CALL MAKE_MOVE_PLY

    ; Increment node count
    CALL INC_NODE_COUNT

    ; Call negamax for opponent (ply 1)
    LDI 1
    PLO 12              ; R12.0 = ply 1
    CALL NEGAMAX_PLY

    ; Negate score (negamax)
    CALL NEGATE_SCORE

    ; Print score
    LDI ' '
    CALL SERIAL_WRITE_CHAR
    LDI HIGH(SCORE_HI)
    PHI 10
    LDI LOW(SCORE_HI)
    PLO 10
    LDN 10
    CALL SERIAL_PRINT_HEX
    DEC 10
    LDN 10
    CALL SERIAL_PRINT_HEX
    CALL PRINT_CRLF

    ; Unmake move
    LDI 0
    PLO 12
    LDI HIGH(PLY_BASE)
    PHI 10
    LDI LOW(PLY_BASE + PLY_MOVE_FROM)
    PLO 10
    LDN 10
    PLO 11
    INC 10
    LDN 10
    PHI 11
    CALL UNMAKE_MOVE_PLY

    ; Compare: if SCORE > BEST_SCORE, update
    CALL COMPARE_SCORE_GT_BEST
    LBZ NR_NOT_BETTER

    ; Update best move and score
    LDI HIGH(PLY_BASE)
    PHI 10
    LDI LOW(PLY_BASE + PLY_MOVE_FROM)
    PLO 10
    LDN 10
    PLO 9
    INC 10
    LDN 10
    PHI 9

    LDI HIGH(BEST_MOVE_FROM)
    PHI 10
    LDI LOW(BEST_MOVE_FROM)
    PLO 10
    GLO 9
    STR 10
    INC 10
    GHI 9
    STR 10

    LDI HIGH(SCORE_LO)
    PHI 10
    LDI LOW(SCORE_LO)
    PLO 10
    LDN 10
    PLO 9
    INC 10
    LDN 10
    PHI 9

    LDI HIGH(BEST_SCORE_LO)
    PHI 10
    LDI LOW(BEST_SCORE_LO)
    PLO 10
    GLO 9
    STR 10
    INC 10
    GHI 9
    STR 10

NR_NOT_BETTER:
    LBR NR_LOOP

NR_DONE:
    RETN

; ==============================================================================
; NEGAMAX_PLY - Search at ply level (in R12.0)
; Returns score in SCORE_LO/HI
; ==============================================================================
NEGAMAX_PLY:
    SEX 2

    ; Check if at leaf (depth reached)
    LDI HIGH(SEARCH_DEPTH)
    PHI 10
    LDI LOW(SEARCH_DEPTH)
    PLO 10
    LDN 10              ; D = search depth
    STR 2
    GLO 12              ; D = current ply
    SD                  ; D = depth - ply
    LBNF NP_EVALUATE    ; If ply >= depth, evaluate
    LBZ NP_EVALUATE

    ; Not at leaf - set up alpha/beta from parent
    CALL SETUP_PLY_BOUNDS

    ; Generate moves for this ply
    CALL GENERATE_MOVES_FOR_PLY

    ; Set move pointer
    GLO 12
    SHL
    SHL
    SHL
    SHL
    SHL                 ; ply * 32
    STR 2
    LDI LOW(MOVELIST_PLY0)
    ADD
    PLO 9
    LDI HIGH(MOVELIST_PLY0)
    ADCI 0
    PHI 9

    ; Store in ply's PTR
    GLO 12
    SHL
    SHL
    SHL
    SHL
    STR 2
    LDI LOW(PLY_BASE + PLY_PTR_LO)
    ADD
    PLO 10
    LDI HIGH(PLY_BASE)
    PHI 10
    GLO 9
    STR 10
    INC 10
    GHI 9
    STR 10

    ; Initialize best to -infinity
    GLO 12
    SHL
    SHL
    SHL
    SHL
    STR 2
    LDI LOW(PLY_BASE + PLY_BEST_LO)
    ADD
    PLO 10
    LDI HIGH(PLY_BASE)
    PHI 10
    LDI NEG_INF_LO
    STR 10
    INC 10
    LDI NEG_INF_HI
    STR 10

NP_LOOP:
    ; Get move pointer
    GLO 12
    SHL
    SHL
    SHL
    SHL
    STR 2
    LDI LOW(PLY_BASE + PLY_PTR_LO)
    ADD
    PLO 10
    LDI HIGH(PLY_BASE)
    PHI 10
    LDN 10
    PLO 11
    INC 10
    LDN 10
    PHI 11

    ; Check end
    LDN 11
    XRI $FF
    LBZ NP_RETURN_BEST

    ; Load move
    LDA 11
    PLO 9
    LDA 11
    PHI 9

    ; Save updated pointer
    GLO 12
    SHL
    SHL
    SHL
    SHL
    STR 2
    LDI LOW(PLY_BASE + PLY_PTR_LO)
    ADD
    PLO 10
    LDI HIGH(PLY_BASE)
    PHI 10
    GLO 11
    STR 10
    INC 10
    GHI 11
    STR 10

    ; Save move in ply storage
    GLO 12
    SHL
    SHL
    SHL
    SHL
    STR 2
    LDI LOW(PLY_BASE + PLY_MOVE_FROM)
    ADD
    PLO 10
    LDI HIGH(PLY_BASE)
    PHI 10
    GLO 9
    STR 10
    INC 10
    GHI 9
    STR 10

    ; Make move
    DEC 10
    LDN 10
    PLO 11
    INC 10
    LDN 10
    PHI 11
    CALL MAKE_MOVE_PLY

    ; Increment node count
    CALL INC_NODE_COUNT

    ; Recurse
    GLO 12
    ADI 1
    PLO 12
    CALL NEGAMAX_PLY
    GLO 12
    SMI 1
    PLO 12

    ; Negate score
    CALL NEGATE_SCORE

    ; Unmake move
    GLO 12
    SHL
    SHL
    SHL
    SHL
    STR 2
    LDI LOW(PLY_BASE + PLY_MOVE_FROM)
    ADD
    PLO 10
    LDI HIGH(PLY_BASE)
    PHI 10
    LDN 10
    PLO 11
    INC 10
    LDN 10
    PHI 11
    CALL UNMAKE_MOVE_PLY

    ; Update best if score > best
    CALL CHECK_SCORE_GT_PLY_BEST
    LBZ NP_LOOP

    ; Update PLY_BEST = SCORE
    LDI HIGH(SCORE_LO)
    PHI 10
    LDI LOW(SCORE_LO)
    PLO 10
    LDN 10
    PLO 9
    INC 10
    LDN 10
    PHI 9

    GLO 12
    SHL
    SHL
    SHL
    SHL
    STR 2
    LDI LOW(PLY_BASE + PLY_BEST_LO)
    ADD
    PLO 10
    LDI HIGH(PLY_BASE)
    PHI 10
    GLO 9
    STR 10
    INC 10
    GHI 9
    STR 10

    LBR NP_LOOP

NP_RETURN_BEST:
    ; Return PLY_BEST in SCORE
    GLO 12
    SHL
    SHL
    SHL
    SHL
    STR 2
    LDI LOW(PLY_BASE + PLY_BEST_LO)
    ADD
    PLO 10
    LDI HIGH(PLY_BASE)
    PHI 10
    LDN 10
    PLO 9
    INC 10
    LDN 10
    PHI 9

    LDI HIGH(SCORE_LO)
    PHI 10
    LDI LOW(SCORE_LO)
    PLO 10
    GLO 9
    STR 10
    INC 10
    GHI 9
    STR 10
    RETN

NP_EVALUATE:
    ; Leaf node - evaluate
    ; Even ply = white's perspective, odd = black's
    CALL EVALUATE_MATERIAL
    ; If odd ply, negate (we evaluate from white's view)
    GLO 12
    ANI $01
    LBZ NP_EVAL_DONE
    CALL NEGATE_SCORE
NP_EVAL_DONE:
    RETN

; ==============================================================================
; GENERATE_MOVES_FOR_PLY - Wrapper for GENERATE_MOVES
; Input: R12.0 = ply
; Output: Moves written to ply's move list, terminated with $FF
; ==============================================================================
GENERATE_MOVES_FOR_PLY:
    SEX 2

    ; Save ply to memory (GENERATE_MOVES will clobber R12)
    LDI HIGH(TEMP_PLY)
    PHI 10
    LDI LOW(TEMP_PLY)
    PLO 10
    GLO 12
    STR 10              ; Save ply

    ; Calculate move list address for this ply
    ; Ply 0: $5100, Ply 1: $5120, Ply 2: $5140, Ply 3: $5160
    SHL
    SHL
    SHL
    SHL
    SHL                 ; ply * 32
    STR 2
    LDI LOW(MOVELIST_PLY0)
    ADD
    PLO 9
    LDI HIGH(MOVELIST_PLY0)
    ADCI 0
    PHI 9               ; R9 = move list pointer for GENERATE_MOVES

    ; Set R12 = side to move based on ply (even = WHITE/0, odd = BLACK/8)
    LDI HIGH(TEMP_PLY)
    PHI 10
    LDI LOW(TEMP_PLY)
    PLO 10
    LDN 10              ; Get ply back
    ANI $01             ; Odd = black
    LBZ GMFP_WHITE
    LDI BLACK           ; $08
    LBR GMFP_SET_SIDE
GMFP_WHITE:
    LDI WHITE           ; $00
GMFP_SET_SIDE:
    PLO 12              ; R12.0 = side to move for GENERATE_MOVES

    ; Call the full move generator
    CALL GENERATE_MOVES

    ; D now contains move count - we don't need it, moves are in list
    ; Add terminator to move list (R9 is already past last move)
    LDI $FF
    STR 9

    ; Restore ply to R12
    LDI HIGH(TEMP_PLY)
    PHI 10
    LDI LOW(TEMP_PLY)
    PLO 10
    LDN 10
    PLO 12

    RETN

; ==============================================================================
; SETUP_PLY_BOUNDS - Set alpha/beta from parent (negated and swapped)
; ==============================================================================
SETUP_PLY_BOUNDS:
    ; Get parent ply offset
    GLO 12
    SMI 1
    SHL
    SHL
    SHL
    SHL
    PLO 14              ; parent offset

    ; Get parent beta -> negate -> child alpha
    GLO 14
    STR 2
    LDI LOW(PLY_BASE + PLY_BETA_LO)
    ADD
    PLO 10
    LDI HIGH(PLY_BASE)
    PHI 10
    LDN 10
    PLO 9
    INC 10
    LDN 10
    PHI 9

    ; Negate
    GLO 9
    XRI $FF
    PLO 9
    GHI 9
    XRI $FF
    PHI 9
    GLO 9
    ADI 1
    PLO 9
    GHI 9
    ADCI 0
    PHI 9

    ; Store as child alpha
    GLO 12
    SHL
    SHL
    SHL
    SHL
    STR 2
    LDI LOW(PLY_BASE + PLY_ALPHA_LO)
    ADD
    PLO 10
    LDI HIGH(PLY_BASE)
    PHI 10
    GLO 9
    STR 10
    INC 10
    GHI 9
    STR 10

    ; Get parent alpha -> negate -> child beta
    GLO 14
    STR 2
    LDI LOW(PLY_BASE + PLY_ALPHA_LO)
    ADD
    PLO 10
    LDN 10
    PLO 9
    INC 10
    LDN 10
    PHI 9

    ; Negate
    GLO 9
    XRI $FF
    PLO 9
    GHI 9
    XRI $FF
    PHI 9
    GLO 9
    ADI 1
    PLO 9
    GHI 9
    ADCI 0
    PHI 9

    ; Store as child beta
    GLO 12
    SHL
    SHL
    SHL
    SHL
    STR 2
    LDI LOW(PLY_BASE + PLY_BETA_LO)
    ADD
    PLO 10
    LDI HIGH(PLY_BASE)
    PHI 10
    GLO 9
    STR 10
    INC 10
    GHI 9
    STR 10

    RETN

; ==============================================================================
; NEGATE_SCORE - Negate SCORE_LO/HI in place
; ==============================================================================
NEGATE_SCORE:
    LDI HIGH(SCORE_LO)
    PHI 10
    LDI LOW(SCORE_LO)
    PLO 10
    LDN 10
    XRI $FF
    PLO 9
    INC 10
    LDN 10
    XRI $FF
    PHI 9
    GLO 9
    ADI 1
    PLO 9
    GHI 9
    ADCI 0
    PHI 9
    DEC 10
    GLO 9
    STR 10
    INC 10
    GHI 9
    STR 10
    RETN

; ==============================================================================
; CHECK_SCORE_GT_PLY_BEST - Return D=1 if SCORE > PLY_BEST
; ==============================================================================
CHECK_SCORE_GT_PLY_BEST:
    ; Get PLY_BEST into R9
    GLO 12
    SHL
    SHL
    SHL
    SHL
    STR 2
    LDI LOW(PLY_BASE + PLY_BEST_LO)
    ADD
    PLO 10
    LDI HIGH(PLY_BASE)
    PHI 10
    LDN 10
    PLO 9
    INC 10
    LDN 10
    PHI 9

    ; Get SCORE into R15
    LDI HIGH(SCORE_LO)
    PHI 10
    LDI LOW(SCORE_LO)
    PLO 10
    LDN 10
    PLO 15
    INC 10
    LDN 10
    PHI 15

    ; Compare R15 > R9?
    GHI 15
    STR 2
    GHI 9
    XOR
    ANI $80
    LBNZ CSPB_DIFF

    ; Same sign
    GHI 9
    STR 2
    GHI 15
    SD
    BNZ CSPB_HI_DIFF
    GLO 9
    STR 2
    GLO 15
    SD
    BZ CSPB_EQ
    BNF CSPB_GT
    LDI 0
    RETN

CSPB_HI_DIFF:
    BNF CSPB_GT
    LDI 0
    RETN

CSPB_EQ:
    LDI 0
    RETN

CSPB_GT:
    LDI 1
    RETN

CSPB_DIFF:
    GHI 15
    ANI $80
    LBNZ CSPB_EQ
    LDI 1
    RETN

; ==============================================================================
; Helpers
; ==============================================================================

COMPARE_SCORE_GT_BEST:
    LDI HIGH(BEST_SCORE_LO)
    PHI 10
    LDI LOW(BEST_SCORE_LO)
    PLO 10
    LDN 10
    PLO 9
    INC 10
    LDN 10
    PHI 9               ; R9 = BEST

    LDI HIGH(SCORE_LO)
    PHI 10
    LDI LOW(SCORE_LO)
    PLO 10
    LDN 10
    PLO 15
    INC 10
    LDN 10
    PHI 15              ; R15 = SCORE

    ; Is R15 > R9? (signed comparison)
    GHI 15
    STR 2
    GHI 9
    XOR
    ANI $80
    LBNZ CSGB_DIFF

    ; Same sign
    GHI 9               ; best_hi
    STR 2
    GHI 15              ; score_hi
    SD                  ; D = best_hi - score_hi
    BNZ CSGB_HI_DIFF

    ; High bytes equal
    GLO 9
    STR 2
    GLO 15
    SD
    BZ CSGB_EQUAL
    BNF CSGB_GT
    LDI 0
    RETN

CSGB_HI_DIFF:
    BNF CSGB_GT
    LDI 0
    RETN

CSGB_EQUAL:
    LDI 0
    RETN

CSGB_GT:
    LDI 1
    RETN

CSGB_DIFF:
    GHI 15
    ANI $80
    LBNZ CSGB_EQUAL
    LDI 1
    RETN

INC_NODE_COUNT:
    LDI HIGH(NODE_COUNT_LO)
    PHI 10
    LDI LOW(NODE_COUNT_LO)
    PLO 10
    LDN 10
    ADI 1
    STR 10
    INC 10
    LDN 10
    ADCI 0
    STR 10
    RETN

PRINT_CRLF:
    LDI HIGH(STR_CRLF)
    PHI 8
    LDI LOW(STR_CRLF)
    PLO 8
    CALL SERIAL_PRINT_STRING
    RETN

; ==============================================================================
; Board setup
; ==============================================================================
CLEAR_BOARD:
    LDI HIGH(BOARD)
    PHI 10
    LDI LOW(BOARD)
    PLO 10
    LDI 128
    PLO 14
CB_LOOP:
    LDI EMPTY
    STR 10
    INC 10
    DEC 14
    GLO 14
    LBNZ CB_LOOP
    RETN

SETUP_POSITION:
    LDI HIGH(BOARD)
    PHI 10

    ; White King at e1 ($04)
    LDI SQ_E1
    PLO 10
    LDI W_KING
    STR 10

    ; White Queen at d1 ($03)
    LDI SQ_D1
    PLO 10
    LDI W_QUEEN
    STR 10

    ; White Pawn at a2 ($10)
    LDI SQ_A2
    PLO 10
    LDI W_PAWN
    STR 10

    ; Black King at e8 ($74)
    LDI SQ_E8
    PLO 10
    LDI B_KING
    STR 10

    ; Black Pawn at a7 ($60)
    LDI SQ_A7
    PLO 10
    LDI B_PAWN
    STR 10

    RETN

INIT_GAME_STATE:
    LDI HIGH(GAME_STATE)
    PHI 10
    LDI LOW(GAME_STATE)
    PLO 10
    ; No castling rights (kings not on original squares with rooks)
    LDI 0
    STR 10
    INC 10
    ; No en passant
    LDI $FF             ; $FF = no EP square
    STR 10
    RETN

; ==============================================================================
; MAKE_MOVE_PLY / UNMAKE_MOVE_PLY
; Input: R11.0 = from, R11.1 = to, R12.0 = ply
; ==============================================================================
MAKE_MOVE_PLY:
    GLO 12
    SHL
    SHL
    SHL
    SHL
    STR 2
    LDI LOW(PLY_BASE + PLY_MOVE_PIECE)
    ADD
    PLO 10
    LDI HIGH(PLY_BASE)
    PHI 10

    LDI HIGH(BOARD)
    PHI 8

    GLO 11
    PLO 8
    LDN 8
    STR 10              ; Save moving piece

    GHI 11
    PLO 8
    LDN 8
    INC 10
    STR 10              ; Save captured piece

    GHI 11
    PLO 8
    DEC 10
    LDN 10              ; Get moving piece
    STR 8               ; Place at destination

    GLO 11
    PLO 8
    LDI EMPTY
    STR 8               ; Clear source

    RETN

UNMAKE_MOVE_PLY:
    GLO 12
    SHL
    SHL
    SHL
    SHL
    STR 2
    LDI LOW(PLY_BASE + PLY_MOVE_PIECE)
    ADD
    PLO 10
    LDI HIGH(PLY_BASE)
    PHI 10

    LDI HIGH(BOARD)
    PHI 8

    GLO 11
    PLO 8
    LDN 10
    STR 8               ; Restore piece at source

    GHI 11
    PLO 8
    INC 10
    LDN 10
    STR 8               ; Restore captured piece

    RETN

; ==============================================================================
; EVALUATE_MATERIAL - Simple material count
; ==============================================================================
EVALUATE_MATERIAL:
    SEX 2
    LDI HIGH(SCORE_LO)
    PHI 10
    LDI LOW(SCORE_LO)
    PLO 10
    LDI 0
    STR 10
    INC 10
    STR 10

    LDI HIGH(BOARD)
    PHI 11
    LDI LOW(BOARD)
    PLO 11
    LDI 0
    PLO 14

EM_LOOP:
    GLO 14
    ANI $88
    LBNZ EM_NEXT_RANK
    LDN 11
    LBZ EM_NEXT_SQ
    PLO 15
    ANI $07
    SMI 1
    SHL
    STR 2
    LDI LOW(PIECE_VALUES)
    ADD
    PLO 8
    LDI HIGH(PIECE_VALUES)
    ADCI 0
    PHI 8
    LDA 8
    PHI 9
    LDN 8
    PLO 9
    GLO 15
    ANI $08
    LBNZ EM_SUBTRACT

EM_ADD:
    LDI HIGH(SCORE_LO)
    PHI 10
    LDI LOW(SCORE_LO)
    PLO 10
    LDN 10
    STR 2
    GLO 9
    ADD
    STR 10
    INC 10
    LDN 10
    ADCI 0
    STR 2
    GHI 9
    ADD
    STR 10
    LBR EM_NEXT_SQ

EM_SUBTRACT:
    LDI HIGH(SCORE_LO)
    PHI 10
    LDI LOW(SCORE_LO)
    PLO 10
    LDN 10
    STR 2
    GLO 9
    SD
    STR 10
    INC 10
    LDN 10
    SMBI 0
    STR 2
    GHI 9
    SD
    STR 10
    LBR EM_NEXT_SQ

EM_NEXT_SQ:
    INC 11
    INC 14
    GLO 14
    ANI $80
    LBZ EM_LOOP
    RETN

EM_NEXT_RANK:
    GLO 14
    ADI 8
    PLO 14
    GLO 11
    ADI 8
    PLO 11
    GHI 11
    ADCI 0
    PHI 11
    GLO 14
    ANI $80
    LBNZ EM_DONE
    LBR EM_LOOP

EM_DONE:
    RETN

; ==============================================================================
; Include full move generator
; ==============================================================================
#include "movegen-new.asm"

; ==============================================================================
; Data Tables
; ==============================================================================

PIECE_VALUES:
    DW $0064        ; Pawn = 100
    DW $0140        ; Knight = 320
    DW $014A        ; Bishop = 330
    DW $01F4        ; Rook = 500
    DW $0384        ; Queen = 900
    DW $0000        ; King = 0

STR_BANNER:
    DB "Step20: Full MoveGen + Search", 0DH, 0AH, 0

STR_POS:
    DB "WKe1 WQd1 WPa2 vs BKe8 BPa7", 0DH, 0AH, 0

STR_SEARCH:
    DB "Depth-2 with all pieces...", 0DH, 0AH, 0

STR_TRY:
    DB "Try ", 0

STR_BEST:
    DB "Best: ", 0

STR_NODES:
    DB "Nodes: ", 0

STR_DONE:
    DB "Done!", 0DH, 0AH, 0

STR_CRLF:
    DB 0DH, 0AH, 0

    END
