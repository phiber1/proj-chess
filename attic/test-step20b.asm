; ==============================================================================
; Step 20b: Depth-1 Search Diagnostic
; Tests if depth-1 works correctly before trying depth-2
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

PLY_BASE    EQU $5090
PLY_SIZE    EQU $10

PLY_MOVE_PIECE  EQU 0
PLY_CAPT_PIECE  EQU 1
PLY_MOVE_FROM   EQU 2
PLY_MOVE_TO     EQU 3

SEARCH_DEPTH    EQU $50D0
BEST_MOVE_FROM  EQU $50D2
BEST_MOVE_TO    EQU $50D3
BEST_SCORE_LO   EQU $50D4
BEST_SCORE_HI   EQU $50D5
NODE_COUNT_LO   EQU $50D6
NODE_COUNT_HI   EQU $50D7
TEMP_PLY        EQU $50D9
MOVE_PTR_LO     EQU $50DA      ; Move list pointer storage
MOVE_PTR_HI     EQU $50DB

MOVELIST_PLY0   EQU $5100

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
B_KING      EQU $0E

SQ_D1       EQU $03
SQ_E1       EQU $04
SQ_A2       EQU $10
SQ_E8       EQU $74
SQ_A7       EQU $60

CASTLE_WK   EQU $01
CASTLE_WQ   EQU $02
CASTLE_BK   EQU $04
CASTLE_BQ   EQU $08
SQ_D8       EQU $73
SQ_C8       EQU $72
SQ_B8       EQU $71
SQ_F1       EQU $05
SQ_G1       EQU $06
SQ_F8       EQU $75
SQ_G8       EQU $76

DIR_N   EQU $F0
DIR_S   EQU $10
DIR_E   EQU $01
DIR_W   EQU $FF
DIR_NE  EQU $F1
DIR_NW  EQU $EF
DIR_SE  EQU $11
DIR_SW  EQU $0F

NEG_INF_LO  EQU $01
NEG_INF_HI  EQU $80

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

    LDI HIGH(STR_BANNER)
    PHI 8
    LDI LOW(STR_BANNER)
    PLO 8
    CALL SERIAL_PRINT_STRING

    CALL CLEAR_BOARD
    CALL SETUP_POSITION
    CALL INIT_GAME_STATE

    ; Initialize counters
    LDI HIGH(NODE_COUNT_LO)
    PHI 10
    LDI LOW(NODE_COUNT_LO)
    PLO 10
    LDI 0
    STR 10
    INC 10
    STR 10

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

    ; Generate moves for White (ply 0)
    LDI HIGH(STR_GEN)
    PHI 8
    LDI LOW(STR_GEN)
    PLO 8
    CALL SERIAL_PRINT_STRING

    LDI 0
    PLO 12              ; ply = 0
    CALL GENERATE_MOVES_FOR_PLY

    ; Print move count from move list
    LDI HIGH(MOVELIST_PLY0)
    PHI 11
    LDI LOW(MOVELIST_PLY0)
    PLO 11
    LDI 0
    PLO 13              ; count
COUNT_LOOP:
    LDN 11
    XRI $FF
    LBZ COUNT_DONE
    INC 13
    INC 11
    INC 11
    LBR COUNT_LOOP
COUNT_DONE:
    GLO 13
    CALL SERIAL_PRINT_HEX
    LDI HIGH(STR_MOVES)
    PHI 8
    LDI LOW(STR_MOVES)
    PLO 8
    CALL SERIAL_PRINT_STRING

    ; Now iterate through moves - depth 1 search
    LDI HIGH(STR_D1)
    PHI 8
    LDI LOW(STR_D1)
    PLO 8
    CALL SERIAL_PRINT_STRING

    ; Set up move pointer in memory (survives serial clobbering)
    LDI HIGH(MOVE_PTR_LO)
    PHI 10
    LDI LOW(MOVE_PTR_LO)
    PLO 10
    LDI LOW(MOVELIST_PLY0)
    STR 10
    INC 10
    LDI HIGH(MOVELIST_PLY0)
    STR 10

D1_LOOP:
    ; Restore move pointer from memory
    LDI HIGH(MOVE_PTR_LO)
    PHI 10
    LDI LOW(MOVE_PTR_LO)
    PLO 10
    LDN 10
    PLO 11
    INC 10
    LDN 10
    PHI 11

    ; Check end
    LDN 11
    XRI $FF
    LBZ D1_DONE

    ; Load move
    LDA 11
    PLO 9               ; from
    LDA 11
    PHI 9               ; to

    ; Save updated pointer to memory
    LDI HIGH(MOVE_PTR_LO)
    PHI 10
    LDI LOW(MOVE_PTR_LO)
    PLO 10
    GLO 11
    STR 10
    INC 10
    GHI 11
    STR 10

    ; Save move in ply storage
    LDI HIGH(PLY_BASE + PLY_MOVE_FROM)
    PHI 10
    LDI LOW(PLY_BASE + PLY_MOVE_FROM)
    PLO 10
    GLO 9
    STR 10
    INC 10
    GHI 9
    STR 10

    ; Print move
    GLO 9
    CALL SERIAL_PRINT_HEX
    LDI '-'
    CALL SERIAL_WRITE_CHAR
    GHI 9
    CALL SERIAL_PRINT_HEX
    LDI ' '
    CALL SERIAL_WRITE_CHAR

    ; Reload move (serial clobbers registers)
    LDI HIGH(PLY_BASE + PLY_MOVE_FROM)
    PHI 10
    LDI LOW(PLY_BASE + PLY_MOVE_FROM)
    PLO 10
    LDN 10
    PLO 9
    INC 10
    LDN 10
    PHI 9

    ; Make move - from in R9.0, to in R9.1
    ; Set up R11 for make/unmake
    GLO 9
    PLO 11              ; R11.0 = from
    GHI 9
    PHI 11              ; R11.1 = to
    LDI 0
    PLO 12              ; ply = 0
    CALL MAKE_MOVE_PLY

    ; Increment node count
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

    ; Evaluate (depth 1 = evaluate immediately)
    CALL EVALUATE_MATERIAL

    ; Print score
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
    LDI HIGH(PLY_BASE + PLY_MOVE_FROM)
    PHI 10
    LDI LOW(PLY_BASE + PLY_MOVE_FROM)
    PLO 10
    LDN 10
    PLO 11
    INC 10
    LDN 10
    PHI 11
    LDI 0
    PLO 12
    CALL UNMAKE_MOVE_PLY

    ; Compare and update best
    CALL COMPARE_SCORE_GT_BEST
    LBZ D1_NOT_BETTER

    ; Update best
    LDI HIGH(PLY_BASE + PLY_MOVE_FROM)
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

D1_NOT_BETTER:
    ; Continue with next move (pointer already saved in memory)
    LBR D1_LOOP

D1_DONE:
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
    INC 10
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
    DEC 10
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
    DEC 10
    LDN 10
    CALL SERIAL_PRINT_HEX
    CALL PRINT_CRLF

    LDI HIGH(STR_DONE)
    PHI 8
    LDI LOW(STR_DONE)
    PLO 8
    CALL SERIAL_PRINT_STRING

HALT:
    BR HALT

; ==============================================================================
; GENERATE_MOVES_FOR_PLY
; ==============================================================================
GENERATE_MOVES_FOR_PLY:
    SEX 2

    LDI HIGH(TEMP_PLY)
    PHI 10
    LDI LOW(TEMP_PLY)
    PLO 10
    GLO 12
    STR 10

    SHL
    SHL
    SHL
    SHL
    SHL
    STR 2
    LDI LOW(MOVELIST_PLY0)
    ADD
    PLO 9
    LDI HIGH(MOVELIST_PLY0)
    ADCI 0
    PHI 9

    LDI HIGH(TEMP_PLY)
    PHI 10
    LDI LOW(TEMP_PLY)
    PLO 10
    LDN 10
    ANI $01
    LBZ GMFP_WHITE
    LDI BLACK
    LBR GMFP_SET_SIDE
GMFP_WHITE:
    LDI WHITE
GMFP_SET_SIDE:
    PLO 12

    CALL GENERATE_MOVES

    LDI $FF
    STR 9

    LDI HIGH(TEMP_PLY)
    PHI 10
    LDI LOW(TEMP_PLY)
    PLO 10
    LDN 10
    PLO 12

    RETN

; ==============================================================================
; COMPARE_SCORE_GT_BEST
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
; EVALUATE_MATERIAL
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
    LDI SQ_D1
    PLO 10
    LDI W_QUEEN
    STR 10
    LDI SQ_A2
    PLO 10
    LDI W_PAWN
    STR 10
    LDI SQ_E8
    PLO 10
    LDI B_KING
    STR 10
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
    LDI 0
    STR 10
    INC 10
    LDI $FF
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
; Include move generator
; ==============================================================================
#include "movegen-new.asm"

; ==============================================================================
; Data
; ==============================================================================
PIECE_VALUES:
    DW $0064
    DW $0140
    DW $014A
    DW $01F4
    DW $0384
    DW $0000

STR_BANNER:
    DB "Step20b: Depth-1 Test", 0DH, 0AH, 0

STR_GEN:
    DB "Generating... ", 0

STR_MOVES:
    DB " moves", 0DH, 0AH, 0

STR_D1:
    DB "Depth-1 search:", 0DH, 0AH, 0

STR_BEST:
    DB "Best: ", 0

STR_NODES:
    DB "Nodes: ", 0

STR_DONE:
    DB "Done!", 0DH, 0AH, 0

STR_CRLF:
    DB 0DH, 0AH, 0

    END
