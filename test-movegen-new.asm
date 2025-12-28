; ==============================================================================
; Test: movegen-new.asm integration test
; Verifies both white and black move generation
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
MOVE_LIST   EQU $5200

; Game state offsets
GS_SIDE     EQU 0
GS_CASTLE   EQU 1
GS_EP       EQU 2

; Castling bits
CASTLE_WK   EQU $01
CASTLE_WQ   EQU $02
CASTLE_BK   EQU $04
CASTLE_BQ   EQU $08
ALL_CASTLING EQU $0F

; Piece definitions
EMPTY       EQU $00
COLOR_MASK  EQU $08
PIECE_MASK  EQU $07
WHITE       EQU $00
BLACK       EQU $08

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

NO_EP       EQU $FF

; Squares
SQ_A1       EQU $00
SQ_B1       EQU $01
SQ_C1       EQU $02
SQ_D1       EQU $03
SQ_E1       EQU $04
SQ_F1       EQU $05
SQ_G1       EQU $06
SQ_H1       EQU $07
SQ_A8       EQU $70
SQ_B8       EQU $71
SQ_C8       EQU $72
SQ_D8       EQU $73
SQ_E8       EQU $74
SQ_F8       EQU $75
SQ_G8       EQU $76
SQ_H8       EQU $77

; Directions
DIR_N       EQU $F0     ; -16
DIR_S       EQU $10     ; +16
DIR_E       EQU $01
DIR_W       EQU $FF
DIR_NE      EQU $F1     ; -15
DIR_NW      EQU $EF     ; -17
DIR_SE      EQU $11     ; +17
DIR_SW      EQU $0F     ; +15

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

    ; Initialize board
    CALL INIT_BOARD

    ; === Test 1: White moves from starting position ===
    LDI HIGH(STR_TEST1)
    PHI 8
    LDI LOW(STR_TEST1)
    PLO 8
    CALL SERIAL_PRINT_STRING

    LDI HIGH(MOVE_LIST)
    PHI 9
    LDI LOW(MOVE_LIST)
    PLO 9

    LDI WHITE
    PLO 12              ; Side to move = WHITE

    CALL GENERATE_MOVES
    ; D = move count

    CALL SERIAL_PRINT_HEX

    LDI HIGH(STR_MOVES)
    PHI 8
    LDI LOW(STR_MOVES)
    PLO 8
    CALL SERIAL_PRINT_STRING

    ; === Test 2: Black moves from starting position ===
    LDI HIGH(STR_TEST2)
    PHI 8
    LDI LOW(STR_TEST2)
    PLO 8
    CALL SERIAL_PRINT_STRING

    LDI HIGH(MOVE_LIST)
    PHI 9
    LDI LOW(MOVE_LIST)
    PLO 9

    LDI BLACK
    PLO 12              ; Side to move = BLACK

    CALL GENERATE_MOVES

    CALL SERIAL_PRINT_HEX

    LDI HIGH(STR_MOVES)
    PHI 8
    LDI LOW(STR_MOVES)
    PLO 8
    CALL SERIAL_PRINT_STRING

    ; === Test 3: White after 1.e4 (should be 30 = 0x1E) ===
    LDI HIGH(STR_TEST3)
    PHI 8
    LDI LOW(STR_TEST3)
    PLO 8
    CALL SERIAL_PRINT_STRING

    ; Move e2 pawn to e4
    LDI HIGH(BOARD)
    PHI 10
    LDI $14             ; e2
    PLO 10
    LDI EMPTY
    STR 10

    LDI $34             ; e4
    PLO 10
    LDI W_PAWN
    STR 10

    LDI HIGH(MOVE_LIST)
    PHI 9
    LDI LOW(MOVE_LIST)
    PLO 9

    LDI WHITE
    PLO 12

    CALL GENERATE_MOVES

    CALL SERIAL_PRINT_HEX

    LDI HIGH(STR_MOVES)
    PHI 8
    LDI LOW(STR_MOVES)
    PLO 8
    CALL SERIAL_PRINT_STRING

HALT:
    BR HALT

; ==============================================================================
; Include movegen-new
; ==============================================================================
#include "movegen-new.asm"

; ==============================================================================
; INIT_BOARD
; ==============================================================================
INIT_BOARD:
    LDI HIGH(BOARD)
    PHI 10
    LDI LOW(BOARD)
    PLO 10
    LDI 128
    PLO 13
IB_CLEAR:
    LDI EMPTY
    STR 10
    INC 10
    DEC 13
    GLO 13
    LBNZ IB_CLEAR

    ; White back rank
    LDI HIGH(BOARD)
    PHI 10
    LDI LOW(BOARD)
    PLO 10
    LDI W_ROOK
    STR 10
    INC 10
    LDI W_KNIGHT
    STR 10
    INC 10
    LDI W_BISHOP
    STR 10
    INC 10
    LDI W_QUEEN
    STR 10
    INC 10
    LDI W_KING
    STR 10
    INC 10
    LDI W_BISHOP
    STR 10
    INC 10
    LDI W_KNIGHT
    STR 10
    INC 10
    LDI W_ROOK
    STR 10

    ; White pawns
    LDI HIGH(BOARD)
    PHI 10
    LDI $10
    PLO 10
    LDI 8
    PLO 13
IB_WP:
    LDI W_PAWN
    STR 10
    INC 10
    DEC 13
    GLO 13
    LBNZ IB_WP

    ; Black pawns
    LDI HIGH(BOARD)
    PHI 10
    LDI $60
    PLO 10
    LDI 8
    PLO 13
IB_BP:
    LDI B_PAWN
    STR 10
    INC 10
    DEC 13
    GLO 13
    LBNZ IB_BP

    ; Black back rank
    LDI HIGH(BOARD)
    PHI 10
    LDI $70
    PLO 10
    LDI B_ROOK
    STR 10
    INC 10
    LDI B_KNIGHT
    STR 10
    INC 10
    LDI B_BISHOP
    STR 10
    INC 10
    LDI B_QUEEN
    STR 10
    INC 10
    LDI B_KING
    STR 10
    INC 10
    LDI B_BISHOP
    STR 10
    INC 10
    LDI B_KNIGHT
    STR 10
    INC 10
    LDI B_ROOK
    STR 10

    ; Game state
    LDI HIGH(GAME_STATE)
    PHI 10
    LDI LOW(GAME_STATE)
    PLO 10
    LDI WHITE
    STR 10
    INC 10
    LDI ALL_CASTLING
    STR 10
    INC 10
    LDI NO_EP
    STR 10

    RETN

; ==============================================================================
; Strings
; ==============================================================================
STR_BANNER:
    DB "Movegen-new test", 0DH, 0AH, 0

STR_TEST1:
    DB "White start: ", 0

STR_TEST2:
    DB "Black start: ", 0

STR_TEST3:
    DB "White 1.e4: ", 0

STR_MOVES:
    DB " moves", 0DH, 0AH, 0

    END
