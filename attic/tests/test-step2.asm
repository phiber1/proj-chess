; ==============================================================================
; Step 2: Add INIT_BOARD call - verify board init works
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

; Minimal board definitions
BOARD       EQU $5000
GAME_STATE  EQU $5080
MOVE_LIST   EQU $5200

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

WHITE       EQU $00
BLACK       EQU $08
ALL_CASTLING EQU $0F
NO_EP       EQU $FF
SQ_E1       EQU $04
SQ_E8       EQU $74

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

    ; Call INIT_BOARD
    CALL INIT_BOARD

    LDI HIGH(STR_BOARD)
    PHI 8
    LDI LOW(STR_BOARD)
    PLO 8
    CALL SERIAL_PRINT_STRING

    LDI HIGH(STR_DONE)
    PHI 8
    LDI LOW(STR_DONE)
    PLO 8
    CALL SERIAL_PRINT_STRING

HALT:
    BR HALT

; Minimal INIT_BOARD - just clear and set up pieces
INIT_BOARD:
    ; Clear board
    LDI HIGH(BOARD)
    PHI 10
    LDI LOW(BOARD)
    PLO 10
    LDI 128
    PLO 13
IB_CLEAR:
    LDI EMPTY           ; Must reload each iteration!
    STR 10
    INC 10
    DEC 13
    GLO 13
    BNZ IB_CLEAR

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
    LDI LOW(BOARD + $10)
    PLO 10
    LDI 8
    PLO 13
IB_WP:
    LDI W_PAWN
    STR 10
    INC 10
    DEC 13
    GLO 13
    BNZ IB_WP

    ; Black pawns
    LDI HIGH(BOARD)
    PHI 10
    LDI LOW(BOARD + $60)
    PLO 10
    LDI 8
    PLO 13
IB_BP:
    LDI B_PAWN
    STR 10
    INC 10
    DEC 13
    GLO 13
    BNZ IB_BP

    ; Black back rank
    LDI HIGH(BOARD)
    PHI 10
    LDI LOW(BOARD + $70)
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
    INC 10
    LDI 0
    STR 10
    INC 10
    LDI 1
    STR 10
    INC 10
    LDI 0
    STR 10
    INC 10
    LDI SQ_E1
    STR 10
    INC 10
    LDI SQ_E8
    STR 10

    RETN

STR_BANNER:
    DB "Step2: Board init", 0DH, 0AH, 0

STR_BOARD:
    DB "Board initialized", 0DH, 0AH, 0

STR_DONE:
    DB "DONE", 0DH, 0AH, 0

    END
