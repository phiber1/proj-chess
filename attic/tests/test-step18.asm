; ==============================================================================
; Step 18: Depth-4 Alpha-Beta with Real Move Generation
; ==============================================================================
;
; Integrates actual move generator with alpha-beta search.
; Tests deeper search (depth 3-4) with the same position as step16/17.
;
; Position: White Qd4 Ke1 vs Black Qd6 Nc4 Pa5 Ke8
; Expected best: Qxc4 (captures knight, avoids queen trade)
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
; Constants from board-0x88.asm
; ==============================================================================
EMPTY       EQU $00
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

COLOR_MASK  EQU $08
PIECE_MASK  EQU $07
WHITE       EQU $00
BLACK       EQU $08

; Direction offsets
DIR_N   EQU $F0
DIR_S   EQU $10
DIR_E   EQU $01
DIR_W   EQU $FF
DIR_NE  EQU $F1
DIR_NW  EQU $EF
DIR_SE  EQU $11
DIR_SW  EQU $0F

; Memory layout
BOARD       EQU $5000
GAME_STATE  EQU $5080
SCORE_LO    EQU $5088
SCORE_HI    EQU $5089

; Ply-indexed storage (4 plies for depth-4)
; Each ply: 16 bytes
PLY_BASE    EQU $5090
PLY_SIZE    EQU $10

; Offsets within ply storage
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
SIDE_TO_MOVE    EQU $50D9
TEMP_PLY        EQU $50DA       ; Temp storage for ply during movegen

; Move list buffers (64 bytes each, enough for ~32 moves per ply)
MOVELIST_PLY0   EQU $5100
MOVELIST_PLY1   EQU $5140
MOVELIST_PLY2   EQU $5180
MOVELIST_PLY3   EQU $51C0

; Squares
SQ_E1       EQU $04
SQ_D4       EQU $33
SQ_A5       EQU $40
SQ_D6       EQU $53
SQ_C4       EQU $32
SQ_E8       EQU $74

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

    ; Print position info
    LDI HIGH(STR_POS)
    PHI 8
    LDI LOW(STR_POS)
    PLO 8
    CALL SERIAL_PRINT_STRING

    ; Initialize
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

    ; Set search depth to 3
    LDI HIGH(SEARCH_DEPTH)
    PHI 10
    LDI LOW(SEARCH_DEPTH)
    PLO 10
    LDI 3               ; <-- Depth 3 for faster test
    STR 10

    ; White to move
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

    ; Run search
    CALL NEGAMAX_ROOT

    ; Print results
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

    ; Print stats
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

    LDI HIGH(STR_CUTS)
    PHI 8
    LDI LOW(STR_CUTS)
    PLO 8
    CALL SERIAL_PRINT_STRING
    LDI HIGH(CUTOFF_COUNT)
    PHI 10
    LDI LOW(CUTOFF_COUNT)
    PLO 10
    LDN 10
    CALL SERIAL_PRINT_HEX
    CALL PRINT_CRLF

    LDI HIGH(STR_EXPECT)
    PHI 8
    LDI LOW(STR_EXPECT)
    PLO 8
    CALL SERIAL_PRINT_STRING

HALT:
    BR HALT

; ==============================================================================
; NEGAMAX_ROOT - Root search (ply 0, White to move)
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

    ; Set ply 0 alpha/beta
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

    ; Generate moves for ply 0 (White)
    LDI HIGH(MOVELIST_PLY0)
    PHI 9
    LDI LOW(MOVELIST_PLY0)
    PLO 9
    LDI WHITE
    PLO 12
    CALL GENERATE_MOVES

    ; Add terminator
    LDI $FF
    STR 9

    ; Set move pointer
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
    ; Get move pointer
    LDI HIGH(PLY_BASE)
    PHI 10
    LDI LOW(PLY_BASE + PLY_PTR_LO)
    PLO 10
    LDN 10
    PLO 11
    INC 10
    LDN 10
    PHI 11

    ; Check end
    LDN 11
    XRI $FF
    LBZ NR_DONE

    ; Load move
    LDA 11
    PLO 9
    LDA 11
    PHI 9

    ; Save pointer
    LDI LOW(PLY_BASE + PLY_PTR_LO)
    PLO 10
    GLO 11
    STR 10
    INC 10
    GHI 11
    STR 10

    ; Save move
    LDI LOW(PLY_BASE + PLY_MOVE_FROM)
    PLO 10
    GLO 9
    STR 10
    INC 10
    GHI 9
    STR 10

    ; Print move
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

    ; Make move (ply 0)
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

    CALL INC_NODE_COUNT

    ; Search (ply 1, Black)
    LDI 1
    PLO 12
    CALL NEGAMAX_PLY

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

    ; Unmake (ply 0)
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

    ; Update best?
    CALL COMPARE_SCORE_GT_BEST
    LBZ NR_NOT_BETTER

    ; Update best move/score
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

    ; Update alpha
    LDI HIGH(PLY_BASE)
    PHI 10
    LDI LOW(PLY_BASE + PLY_ALPHA_LO)
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
; NEGAMAX_PLY - Recursive search at ply R12.0
; ==============================================================================
NEGAMAX_PLY:
    SEX 2

    ; Leaf check
    LDI HIGH(SEARCH_DEPTH)
    PHI 10
    LDI LOW(SEARCH_DEPTH)
    PLO 10
    LDN 10
    STR 2
    GLO 12
    SD
    LBNF NP_EVALUATE
    LBZ NP_EVALUATE

    ; Set up bounds from parent
    CALL SETUP_PLY_BOUNDS

    ; Generate moves for this ply
    CALL SETUP_PLY_MOVES

    ; Init best = alpha
    CALL GET_PLY_ALPHA
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

NP_LOOP:
    CALL GET_PLY_PTR

    LDN 11
    XRI $FF
    LBZ NP_RETURN_BEST

    LDA 11
    PLO 9
    LDA 11
    PHI 9

    CALL SAVE_PLY_PTR
    CALL SAVE_PLY_MOVE

    CALL GET_PLY_MOVE
    CALL MAKE_MOVE_PLY

    CALL INC_NODE_COUNT

    ; Recurse
    GLO 12
    ADI 1
    PLO 12
    CALL NEGAMAX_PLY
    GLO 12
    SMI 1
    PLO 12

    CALL NEGATE_SCORE

    CALL GET_PLY_MOVE
    CALL UNMAKE_MOVE_PLY

    ; Beta cutoff?
    CALL CHECK_BETA_CUTOFF
    LBZ NP_NO_CUTOFF

    CALL INC_CUTOFF_COUNT
    CALL GET_PLY_BETA
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

NP_NO_CUTOFF:
    CALL CHECK_SCORE_GT_PLY_BEST
    LBZ NP_LOOP

    CALL UPDATE_PLY_BEST
    LBR NP_LOOP

NP_RETURN_BEST:
    CALL GET_PLY_BEST
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
    CALL EVALUATE_MATERIAL
    ; Negate if Black to move (odd ply)
    GLO 12
    ANI 1
    LBZ NP_EVAL_DONE
    CALL NEGATE_SCORE
NP_EVAL_DONE:
    RETN

; ==============================================================================
; SETUP_PLY_MOVES - Generate moves for current ply
; ==============================================================================
SETUP_PLY_MOVES:
    ; Save ply to memory (R12 will be clobbered by GENERATE_MOVES)
    LDI HIGH(TEMP_PLY)
    PHI 10
    LDI LOW(TEMP_PLY)
    PLO 10
    GLO 12
    STR 10

    ; Determine side to move (even ply = White, odd = Black)
    ANI 1
    SHL
    SHL
    SHL                 ; 0 or 8
    PLO 13              ; R13.0 = side

    ; Get move list buffer for this ply
    LDN 10              ; Reload ply
    ANI 3               ; ply mod 4
    BNZ SPM_NOT0
    LDI LOW(MOVELIST_PLY0)
    PLO 9
    LDI HIGH(MOVELIST_PLY0)
    PHI 9
    LBR SPM_GEN
SPM_NOT0:
    SMI 1
    BNZ SPM_NOT1
    LDI LOW(MOVELIST_PLY1)
    PLO 9
    LDI HIGH(MOVELIST_PLY1)
    PHI 9
    LBR SPM_GEN
SPM_NOT1:
    SMI 1
    BNZ SPM_NOT2
    LDI LOW(MOVELIST_PLY2)
    PLO 9
    LDI HIGH(MOVELIST_PLY2)
    PHI 9
    LBR SPM_GEN
SPM_NOT2:
    LDI LOW(MOVELIST_PLY3)
    PLO 9
    LDI HIGH(MOVELIST_PLY3)
    PHI 9

SPM_GEN:
    ; Save buffer start
    GLO 9
    PLO 15
    GHI 9
    PHI 15

    ; Generate moves (R12.0 = side for generator)
    GLO 13
    PLO 12
    CALL GENERATE_MOVES

    ; Add terminator
    LDI $FF
    STR 9

    ; Restore ply from memory
    LDI HIGH(TEMP_PLY)
    PHI 10
    LDI LOW(TEMP_PLY)
    PLO 10
    LDN 10
    PLO 12              ; R12 = ply restored

    ; Store move pointer for this ply
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
    GLO 15
    STR 10
    INC 10
    GHI 15
    STR 10

    RETN

; ==============================================================================
; Helper functions (same as step17)
; ==============================================================================
GET_PLY_ALPHA:
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
    LDN 10
    PLO 9
    INC 10
    LDN 10
    PHI 9
    RETN

GET_PLY_PTR:
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
    RETN

SAVE_PLY_PTR:
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
    RETN

SAVE_PLY_MOVE:
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
    RETN

GET_PLY_MOVE:
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
    RETN

GET_PLY_BETA:
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
    LDN 10
    PLO 9
    INC 10
    LDN 10
    PHI 9
    RETN

GET_PLY_BEST:
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
    RETN

UPDATE_PLY_BEST:
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
    RETN

SETUP_PLY_BOUNDS:
    GLO 12
    SMI 1
    SHL
    SHL
    SHL
    SHL
    PLO 14

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

CHECK_BETA_CUTOFF:
    CALL GET_PLY_BETA
    LDI HIGH(SCORE_LO)
    PHI 10
    LDI LOW(SCORE_LO)
    PLO 10
    LDN 10
    PLO 15
    INC 10
    LDN 10
    PHI 15

    GHI 15
    STR 2
    GHI 9
    XOR
    ANI $80
    LBNZ CBC_DIFF

    GHI 9
    STR 2
    GHI 15
    SD
    BNZ CBC_HI_DIFF
    GLO 9
    STR 2
    GLO 15
    SD
    BZ CBC_GE
    BNF CBC_NO
CBC_GE:
    LDI 1
    RETN
CBC_HI_DIFF:
    BNF CBC_NO
    LDI 1
    RETN
CBC_DIFF:
    GHI 15
    ANI $80
    LBNZ CBC_NO
    LDI 1
    RETN
CBC_NO:
    LDI 0
    RETN

CHECK_SCORE_GT_PLY_BEST:
    CALL GET_PLY_BEST
    LDI HIGH(SCORE_LO)
    PHI 10
    LDI LOW(SCORE_LO)
    PLO 10
    LDN 10
    PLO 15
    INC 10
    LDN 10
    PHI 15

    GHI 15
    STR 2
    GHI 9
    XOR
    ANI $80
    LBNZ CSGB_DIFF

    GHI 9
    STR 2
    GHI 15
    SD
    BNZ CSGB_HI_DIFF
    GLO 9
    STR 2
    GLO 15
    SD
    BZ CSGB_NO
    BNF CSGB_NO
    LDI 1
    RETN
CSGB_HI_DIFF:
    BNF CSGB_NO
    LDI 1
    RETN
CSGB_DIFF:
    GHI 15
    ANI $80
    LBNZ CSGB_NO
    LDI 1
    RETN
CSGB_NO:
    LDI 0
    RETN

COMPARE_SCORE_GT_BEST:
    LDI HIGH(BEST_SCORE_LO)
    PHI 10
    LDI LOW(BEST_SCORE_LO)
    PLO 10
    LDN 10
    PLO 9
    INC 10
    LDN 10
    PHI 9

    LDI HIGH(SCORE_LO)
    PHI 10
    LDI LOW(SCORE_LO)
    PLO 10
    LDN 10
    PLO 15
    INC 10
    LDN 10
    PHI 15

    GHI 15
    STR 2
    GHI 9
    XOR
    ANI $80
    LBNZ CSGB2_DIFF

    GHI 9
    STR 2
    GHI 15
    SD
    BNZ CSGB2_HI_DIFF
    GLO 9
    STR 2
    GLO 15
    SD
    BZ CSGB2_NO
    BNF CSGB2_NO
    LDI 1
    RETN
CSGB2_HI_DIFF:
    BNF CSGB2_NO
    LDI 1
    RETN
CSGB2_DIFF:
    GHI 15
    ANI $80
    LBNZ CSGB2_NO
    LDI 1
    RETN
CSGB2_NO:
    LDI 0
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

INC_CUTOFF_COUNT:
    LDI HIGH(CUTOFF_COUNT)
    PHI 10
    LDI LOW(CUTOFF_COUNT)
    PLO 10
    LDN 10
    ADI 1
    STR 10
    RETN

; ==============================================================================
; Make/Unmake with ply storage
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
    STR 10

    GHI 11
    PLO 8
    LDN 8
    INC 10
    STR 10

    GHI 11
    PLO 8
    DEC 10
    LDN 10
    STR 8

    GLO 11
    PLO 8
    LDI EMPTY
    STR 8

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
    STR 8

    GHI 11
    PLO 8
    INC 10
    LDN 10
    STR 8

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
    LDI SQ_E1
    PLO 10
    LDI W_KING
    STR 10
    LDI SQ_D4
    PLO 10
    LDI W_QUEEN
    STR 10
    LDI SQ_D6
    PLO 10
    LDI B_QUEEN
    STR 10
    LDI SQ_C4
    PLO 10
    LDI B_KNIGHT
    STR 10
    LDI SQ_A5
    PLO 10
    LDI B_PAWN
    STR 10
    LDI SQ_E8
    PLO 10
    LDI B_KING
    STR 10
    RETN

; ==============================================================================
; Evaluation
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
    ANI $80
    LBNZ EM_DONE
    GLO 11
    ADI 8
    PLO 11
    GHI 11
    ADCI 0
    PHI 11
    LBR EM_LOOP

EM_DONE:
    RETN

PRINT_CRLF:
    LDI HIGH(STR_CRLF)
    PHI 8
    LDI LOW(STR_CRLF)
    PLO 8
    CALL SERIAL_PRINT_STRING
    RETN

; ==============================================================================
; Move Generator (simplified - queens and kings only for this test)
; ==============================================================================
GENERATE_MOVES:
    ; R9 = move list buffer
    ; R12.0 = side to move (0=White, 8=Black)
    GLO 9
    PLO 15
    GHI 9
    PHI 15              ; Save start

    LDI HIGH(BOARD)
    PHI 10
    LDI LOW(BOARD)
    PLO 10

    LDI 0
    PLO 14              ; Square index

GM_SCAN:
    GLO 14
    ANI $88
    BNZ GM_SKIP

    LDN 10
    BZ GM_SKIP

    ANI COLOR_MASK
    STR 2
    GLO 12
    XOR
    BNZ GM_SKIP

    LDN 10
    ANI PIECE_MASK

    SMI 5
    LBZ GM_QUEEN
    SMI 1
    LBZ GM_KING

GM_SKIP:
    INC 10
    INC 14
    GLO 14
    ANI $80
    LBZ GM_SCAN

    ; Return move count
    GLO 15
    STR 2
    GLO 9
    SM
    SHR
    RETN

GM_QUEEN:
    ; Generate queen moves (8 directions, sliding)
    LDI 0
    PLO 13              ; Direction index

GM_Q_DIR:
    GLO 13
    SHL
    STR 2
    LDI LOW(QUEEN_DIRS)
    ADD
    PLO 8
    LDI HIGH(QUEEN_DIRS)
    ADCI 0
    PHI 8
    LDN 8
    PLO 11              ; Direction offset

    GLO 14              ; Current square

GM_Q_SLIDE:
    STR 2
    GLO 11
    ADD
    PLO 8               ; Target square

    ANI $88
    BNZ GM_Q_NEXT_DIR

    ; Check target
    LDI HIGH(BOARD)
    PHI 8
    LDN 8
    BZ GM_Q_ADD         ; Empty - can move

    ; Occupied - check color
    ANI COLOR_MASK
    STR 2
    GLO 12
    XOR
    BZ GM_Q_NEXT_DIR    ; Own piece - stop

    ; Enemy piece - can capture, then stop
    GLO 14
    STR 9
    INC 9
    GLO 8
    STR 9
    INC 9
    LBR GM_Q_NEXT_DIR

GM_Q_ADD:
    GLO 14
    STR 9
    INC 9
    GLO 8
    STR 9
    INC 9
    GLO 8
    LBR GM_Q_SLIDE

GM_Q_NEXT_DIR:
    INC 13
    GLO 13
    SMI 8
    BNZ GM_Q_DIR
    LBR GM_SKIP

GM_KING:
    ; Generate king moves (8 directions, 1 step)
    LDI 0
    PLO 13

GM_K_DIR:
    GLO 13
    SHL
    STR 2
    LDI LOW(QUEEN_DIRS)
    ADD
    PLO 8
    LDI HIGH(QUEEN_DIRS)
    ADCI 0
    PHI 8
    LDN 8
    STR 2
    GLO 14
    ADD
    PLO 8

    ANI $88
    BNZ GM_K_NEXT

    LDI HIGH(BOARD)
    PHI 8
    LDN 8
    BZ GM_K_ADD

    ANI COLOR_MASK
    STR 2
    GLO 12
    XOR
    BZ GM_K_NEXT

GM_K_ADD:
    GLO 14
    STR 9
    INC 9
    GLO 8
    STR 9
    INC 9

GM_K_NEXT:
    INC 13
    GLO 13
    SMI 8
    BNZ GM_K_DIR
    LBR GM_SKIP

; ==============================================================================
; Data
; ==============================================================================
QUEEN_DIRS:
    DB DIR_N, DIR_NE, DIR_E, DIR_SE
    DB DIR_S, DIR_SW, DIR_W, DIR_NW

PIECE_VALUES:
    DW $0064            ; Pawn = 100
    DW $0140            ; Knight = 320
    DW $014A            ; Bishop = 330
    DW $01F4            ; Rook = 500
    DW $0384            ; Queen = 900
    DW $0000            ; King = 0

STR_BANNER:
    DB "Step18: Depth-3 with MoveGen", 0DH, 0AH, 0

STR_POS:
    DB "Pos: WQd4 WKe1 vs BQd6 BNc4 BPa5 BKe8", 0DH, 0AH, 0

STR_SEARCH:
    DB "Depth-3 alpha-beta search...", 0DH, 0AH, 0

STR_TRY:
    DB "Try ", 0

STR_BEST:
    DB "Best: ", 0

STR_NODES:
    DB "Nodes: ", 0

STR_CUTS:
    DB "Cutoffs: ", 0

STR_EXPECT:
    DB "Expect: Qxc4 or similar", 0DH, 0AH, 0

STR_CRLF:
    DB 0DH, 0AH, 0

    END
