; ==============================================================================
; Step 20a: Diagnostic version - prints evaluation at leaf nodes
; Same as step20 but with debug output to trace 0000 scores
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
PLY_ALPHA_LO    EQU 4
PLY_ALPHA_HI    EQU 5
PLY_BETA_LO     EQU 6
PLY_BETA_HI     EQU 7
PLY_PTR_LO      EQU 8
PLY_PTR_HI      EQU 9
PLY_BEST_LO     EQU 10
PLY_BEST_HI     EQU 11

SEARCH_DEPTH    EQU $50D0
CURRENT_PLY     EQU $50D1
BEST_MOVE_FROM  EQU $50D2
BEST_MOVE_TO    EQU $50D3
BEST_SCORE_LO   EQU $50D4
BEST_SCORE_HI   EQU $50D5
NODE_COUNT_LO   EQU $50D6
NODE_COUNT_HI   EQU $50D7
CUTOFF_COUNT    EQU $50D8
TEMP_PLY        EQU $50D9
SIDE_TO_MOVE    EQU $50DB

MOVELIST_PLY0   EQU $5100
MOVELIST_PLY1   EQU $5120
MOVELIST_PLY2   EQU $5140
MOVELIST_PLY3   EQU $5160

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

CASTLE_WK   EQU $01
CASTLE_WQ   EQU $02
CASTLE_BK   EQU $04
CASTLE_BQ   EQU $08
SQ_D8       EQU $73
SQ_C8       EQU $72
SQ_B8       EQU $71
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
POS_INF_LO  EQU $FF
POS_INF_HI  EQU $7F

; ==============================================================================
; Main - Just test evaluation directly
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

    ; Test 1: Evaluate initial position directly
    LDI HIGH(STR_EVAL1)
    PHI 8
    LDI LOW(STR_EVAL1)
    PLO 8
    CALL SERIAL_PRINT_STRING

    CALL EVALUATE_MATERIAL

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

    ; Test 2: Make a queen move (Qd1-c2 = 03-12), evaluate, unmake
    LDI HIGH(STR_EVAL2)
    PHI 8
    LDI LOW(STR_EVAL2)
    PLO 8
    CALL SERIAL_PRINT_STRING

    ; Manual make: Qd1-c2
    LDI HIGH(BOARD)
    PHI 8
    LDI $03             ; d1
    PLO 8
    LDN 8               ; Get queen
    PLO 15              ; Save in R15.0
    LDI EMPTY
    STR 8               ; Clear d1
    LDI $12             ; c2
    PLO 8
    GLO 15
    STR 8               ; Place queen at c2

    ; Evaluate
    CALL EVALUATE_MATERIAL

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

    ; Unmake
    LDI HIGH(BOARD)
    PHI 8
    LDI $12             ; c2
    PLO 8
    LDN 8               ; Get queen
    PLO 15
    LDI EMPTY
    STR 8               ; Clear c2
    LDI $03             ; d1
    PLO 8
    GLO 15
    STR 8               ; Restore queen at d1

    ; Test 3: Make a black pawn move (a7-a6 = 60-50), evaluate
    LDI HIGH(STR_EVAL3)
    PHI 8
    LDI LOW(STR_EVAL3)
    PLO 8
    CALL SERIAL_PRINT_STRING

    ; Manual make: Pa7-a6
    LDI HIGH(BOARD)
    PHI 8
    LDI $60             ; a7
    PLO 8
    LDN 8               ; Get pawn
    PLO 15
    LDI EMPTY
    STR 8               ; Clear a7
    LDI $50             ; a6
    PLO 8
    GLO 15
    STR 8               ; Place pawn at a6

    ; Evaluate
    CALL EVALUATE_MATERIAL

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

    ; Test 4: Print what's on each key square
    LDI HIGH(STR_SQUARES)
    PHI 8
    LDI LOW(STR_SQUARES)
    PLO 8
    CALL SERIAL_PRINT_STRING

    LDI HIGH(BOARD)
    PHI 8

    ; d1
    LDI 'd'
    CALL SERIAL_WRITE_CHAR
    LDI '1'
    CALL SERIAL_WRITE_CHAR
    LDI '='
    CALL SERIAL_WRITE_CHAR
    LDI HIGH(BOARD)
    PHI 8
    LDI $03
    PLO 8
    LDN 8
    CALL SERIAL_PRINT_HEX
    LDI ' '
    CALL SERIAL_WRITE_CHAR

    ; e1
    LDI 'e'
    CALL SERIAL_WRITE_CHAR
    LDI '1'
    CALL SERIAL_WRITE_CHAR
    LDI '='
    CALL SERIAL_WRITE_CHAR
    LDI HIGH(BOARD)
    PHI 8
    LDI $04
    PLO 8
    LDN 8
    CALL SERIAL_PRINT_HEX
    LDI ' '
    CALL SERIAL_WRITE_CHAR

    ; a2
    LDI 'a'
    CALL SERIAL_WRITE_CHAR
    LDI '2'
    CALL SERIAL_WRITE_CHAR
    LDI '='
    CALL SERIAL_WRITE_CHAR
    LDI HIGH(BOARD)
    PHI 8
    LDI $10
    PLO 8
    LDN 8
    CALL SERIAL_PRINT_HEX
    LDI ' '
    CALL SERIAL_WRITE_CHAR

    ; e8
    LDI 'e'
    CALL SERIAL_WRITE_CHAR
    LDI '8'
    CALL SERIAL_WRITE_CHAR
    LDI '='
    CALL SERIAL_WRITE_CHAR
    LDI HIGH(BOARD)
    PHI 8
    LDI $74
    PLO 8
    LDN 8
    CALL SERIAL_PRINT_HEX
    LDI ' '
    CALL SERIAL_WRITE_CHAR

    ; a6 (where black pawn moved to)
    LDI 'a'
    CALL SERIAL_WRITE_CHAR
    LDI '6'
    CALL SERIAL_WRITE_CHAR
    LDI '='
    CALL SERIAL_WRITE_CHAR
    LDI HIGH(BOARD)
    PHI 8
    LDI $50
    PLO 8
    LDN 8
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
    LDI 0
    STR 10
    INC 10
    LDI $FF
    STR 10
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

PRINT_CRLF:
    LDI HIGH(STR_CRLF)
    PHI 8
    LDI LOW(STR_CRLF)
    PLO 8
    CALL SERIAL_PRINT_STRING
    RETN

; ==============================================================================
; Data
; ==============================================================================
PIECE_VALUES:
    DW $0064        ; Pawn = 100
    DW $0140        ; Knight = 320
    DW $014A        ; Bishop = 330
    DW $01F4        ; Rook = 500
    DW $0384        ; Queen = 900
    DW $0000        ; King = 0

STR_BANNER:
    DB "Step20a: Evaluation Diagnostic", 0DH, 0AH, 0

STR_POS:
    DB "WKe1 WQd1 WPa2 vs BKe8 BPa7", 0DH, 0AH, 0

STR_EVAL1:
    DB "Initial eval: ", 0

STR_EVAL2:
    DB "After Qc2: ", 0

STR_EVAL3:
    DB "After Pa6: ", 0

STR_SQUARES:
    DB "Squares: ", 0

STR_DONE:
    DB "Done!", 0DH, 0AH, 0

STR_CRLF:
    DB 0DH, 0AH, 0

    END
