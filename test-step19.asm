; ==============================================================================
; Step 19: Search with Generated King Moves
; Integrates working king move generator with alpha-beta search
; ==============================================================================
;
; Test position: White Ke4 + Qf3 vs Black Kh8
; Simple position where we generate ACTUAL king moves (not hardcoded)
; Expected: King moves that don't lose queen should score best
;
; Key fix: Generate moves to ply-specific move lists ($5100, $5120, etc.)
; and save/restore ply around move generation (which doesn't use R12)
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
KING_SQUARE     EQU $50DA      ; Current king square for movegen
SIDE_TO_MOVE    EQU $50DB      ; 0=White, 8=Black

; Per-ply move lists (32 bytes each = max 15 moves + terminator)
MOVELIST_PLY0   EQU $5100
MOVELIST_PLY1   EQU $5120
MOVELIST_PLY2   EQU $5140
MOVELIST_PLY3   EQU $5160

EMPTY       EQU $00
WHITE       EQU $00
BLACK       EQU $08
W_QUEEN     EQU $05
W_KING      EQU $06
B_PAWN      EQU $09
B_KING      EQU $0E

; Squares
SQ_E4       EQU $34
SQ_F3       EQU $25
SQ_D5       EQU $43      ; Black pawn for king to capture
SQ_H8       EQU $77

; Direction offsets for king
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

    ; Set search depth to 2 (test opponent response)
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
; For this test, generates king moves only
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

    ; Generate moves for ply 0
    ; Find our king first
    CALL FIND_WHITE_KING     ; Sets KING_SQUARE

    ; Generate king moves to MOVELIST_PLY0
    LDI 0
    PLO 12                  ; ply = 0
    CALL GENERATE_KING_MOVES_FOR_PLY

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

    ; Find appropriate king (even ply = white, odd = black)
    GLO 12
    ANI $01
    LBZ NP_WHITE_KING
    CALL FIND_BLACK_KING
    LBR NP_GEN_MOVES
NP_WHITE_KING:
    CALL FIND_WHITE_KING

NP_GEN_MOVES:
    ; Generate king moves for this ply
    CALL GENERATE_KING_MOVES_FOR_PLY

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

    ; Initialize best to -infinity (will update with alpha later)
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
; FIND_WHITE_KING - Find white king on board, store in KING_SQUARE
; ==============================================================================
FIND_WHITE_KING:
    LDI HIGH(BOARD)
    PHI 10
    LDI 0
    PLO 10
    PLO 13              ; R13 = square counter

FWK_LOOP:
    GLO 13
    ANI $88
    LBNZ FWK_NEXT_RANK

    LDN 10
    XRI W_KING
    LBZ FWK_FOUND

    INC 10
    INC 13
    GLO 13
    ANI $80
    LBZ FWK_LOOP
    LBR FWK_NOT_FOUND

FWK_NEXT_RANK:
    GLO 13
    ADI 8
    PLO 13
    GLO 10
    ADI 8
    PLO 10
    GHI 10
    ADCI 0
    PHI 10
    GLO 13
    ANI $80
    LBZ FWK_LOOP

FWK_NOT_FOUND:
    LDI $FF             ; No king found
    LBR FWK_STORE

FWK_FOUND:
    GLO 13

FWK_STORE:
    PLO 14              ; Save in R14 temporarily
    LDI HIGH(KING_SQUARE)
    PHI 10
    LDI LOW(KING_SQUARE)
    PLO 10
    GLO 14
    STR 10
    RETN

; ==============================================================================
; FIND_BLACK_KING - Find black king on board, store in KING_SQUARE
; ==============================================================================
FIND_BLACK_KING:
    LDI HIGH(BOARD)
    PHI 10
    LDI 0
    PLO 10
    PLO 13              ; R13 = square counter

FBK_LOOP:
    GLO 13
    ANI $88
    LBNZ FBK_NEXT_RANK

    LDN 10
    XRI B_KING
    LBZ FBK_FOUND

    INC 10
    INC 13
    GLO 13
    ANI $80
    LBZ FBK_LOOP
    LBR FBK_NOT_FOUND

FBK_NEXT_RANK:
    GLO 13
    ADI 8
    PLO 13
    GLO 10
    ADI 8
    PLO 10
    GHI 10
    ADCI 0
    PHI 10
    GLO 13
    ANI $80
    LBZ FBK_LOOP

FBK_NOT_FOUND:
    LDI $FF             ; No king found
    LBR FBK_STORE

FBK_FOUND:
    GLO 13

FBK_STORE:
    PLO 14
    LDI HIGH(KING_SQUARE)
    PHI 10
    LDI LOW(KING_SQUARE)
    PLO 10
    GLO 14
    STR 10
    RETN

; ==============================================================================
; GENERATE_KING_MOVES_FOR_PLY - Generate king moves to ply's move list
; Input: R12.0 = ply number (used to select move list)
; Uses KING_SQUARE for source
; ==============================================================================
GENERATE_KING_MOVES_FOR_PLY:
    ; Determine move list address based on ply
    ; Ply 0: $5100, Ply 1: $5120, Ply 2: $5140, Ply 3: $5160
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
    PHI 9               ; R9 = move list pointer

    ; Get king square
    LDI HIGH(KING_SQUARE)
    PHI 10
    LDI LOW(KING_SQUARE)
    PLO 10
    LDN 10
    PLO 14              ; R14.0 = king square

    ; R13 = direction index (0-7)
    LDI 0
    PLO 13

GKM_DIR_LOOP:
    ; Get direction from table
    GLO 13
    STR 2
    LDI LOW(KING_DIRS)
    ADD
    PLO 8
    LDI HIGH(KING_DIRS)
    ADCI 0
    PHI 8

    ; Load direction offset
    LDN 8
    PLO 10              ; R10.0 = direction

    ; Calculate target: KING_SQUARE + direction
    GLO 14              ; king square
    STR 2
    GLO 10              ; direction
    ADD
    PLO 8               ; R8.0 = target square

    ; Check if on board (target & $88 == 0)
    ANI $88
    LBNZ GKM_NEXT_DIR    ; Off board, skip

    ; Check if target is empty or enemy
    ; Even ply = white (can capture black $08), odd ply = black (can capture white $00)
    LDI HIGH(BOARD)
    PHI 8               ; R8 = BOARD + target
    LDN 8               ; Load piece at target
    LBZ GKM_ADD_MOVE    ; Empty, add move

    ; Check if enemy piece (can capture)
    PLO 15              ; Save piece in R15.0
    ANI $08             ; Get color bit
    STR 2               ; Store target piece color
    GLO 12              ; Get ply
    ANI $01             ; Odd = black moving, even = white moving
    SHL
    SHL
    SHL                 ; Convert to $08 for black, $00 for white
    XOR                 ; XOR with target color
    LBNZ GKM_ADD_MOVE   ; Different color = enemy, can capture
    LBR GKM_NEXT_DIR    ; Same color = own piece, skip

GKM_ADD_MOVE:
    ; Add move to list
    GLO 14              ; from = king square
    STR 9
    INC 9
    GLO 8               ; to = target square
    STR 9
    INC 9

GKM_NEXT_DIR:
    INC 13
    GLO 13
    SMI 8
    LBNZ GKM_DIR_LOOP

    ; Add terminator
    LDI $FF
    STR 9

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
    ; White King at e4
    LDI SQ_E4
    PLO 10
    LDI W_KING
    STR 10
    ; White Queen at f3
    LDI SQ_F3
    PLO 10
    LDI W_QUEEN
    STR 10
    ; Black Pawn at d5 (capturable by king!)
    LDI SQ_D5
    PLO 10
    LDI B_PAWN
    STR 10
    ; Black King at h8
    LDI SQ_H8
    PLO 10
    LDI B_KING
    STR 10
    RETN

; ==============================================================================
; MAKE_MOVE_PLY / UNMAKE_MOVE_PLY
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
; Data
; ==============================================================================
KING_DIRS:
    DB DIR_N, DIR_NE, DIR_E, DIR_SE, DIR_S, DIR_SW, DIR_W, DIR_NW

PIECE_VALUES:
    DW $0064        ; Pawn = 100
    DW $0140        ; Knight = 320
    DW $014A        ; Bishop = 330
    DW $01F4        ; Rook = 500
    DW $0384        ; Queen = 900
    DW $0000        ; King = 0

STR_BANNER:
    DB "Step19: Search + King MoveGen", 0DH, 0AH, 0

STR_POS:
    DB "WKe4 WQf3 vs BPd5 BKh8", 0DH, 0AH, 0

STR_SEARCH:
    DB "Depth-2 with generated moves...", 0DH, 0AH, 0

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
