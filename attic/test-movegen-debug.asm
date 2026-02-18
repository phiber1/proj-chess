; ==============================================================================
; Move Generator Debug Test
; Just generate and print moves, no search
; ==============================================================================

    ORG $0000
    LBR MAIN

#include "serial-io.asm"

; SCRT
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

; Constants
EMPTY       EQU $00
W_QUEEN     EQU $05
W_KING      EQU $06
B_PAWN      EQU $09
B_KNIGHT    EQU $0A
B_QUEEN     EQU $0D
B_KING      EQU $0E
COLOR_MASK  EQU $08
PIECE_MASK  EQU $07
WHITE       EQU $00
BLACK       EQU $08

DIR_N   EQU $F0
DIR_S   EQU $10
DIR_E   EQU $01
DIR_W   EQU $FF
DIR_NE  EQU $F1
DIR_NW  EQU $EF
DIR_SE  EQU $11
DIR_SW  EQU $0F

BOARD       EQU $5000
MOVELIST    EQU $5100

SQ_E1       EQU $04
SQ_D4       EQU $33
SQ_A5       EQU $40
SQ_D6       EQU $53
SQ_C4       EQU $32
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

    ; Banner
    LDI HIGH(STR_BANNER)
    PHI 8
    LDI LOW(STR_BANNER)
    PLO 8
    CALL SERIAL_PRINT_STRING

    ; Setup board
    CALL CLEAR_BOARD
    CALL SETUP_POSITION

    ; Test White moves
    LDI HIGH(STR_WHITE)
    PHI 8
    LDI LOW(STR_WHITE)
    PLO 8
    CALL SERIAL_PRINT_STRING

    ; Generate white moves - set R9 LAST before call
    LDI WHITE
    PLO 12
    LDI HIGH(MOVELIST)
    PHI 9
    LDI LOW(MOVELIST)
    PLO 9
    CALL GENERATE_MOVES

    ; Save R9 immediately (before any serial calls)
    GLO 9
    PLO 15
    GHI 9
    PHI 15

    ; Add terminator using saved pointer
    LDI $FF
    STR 15

    ; Print moves
    LDI HIGH(MOVELIST)
    PHI 11
    LDI LOW(MOVELIST)
    PLO 11
    CALL PRINT_MOVES

    ; Test Black moves
    LDI HIGH(STR_BLACK)
    PHI 8
    LDI LOW(STR_BLACK)
    PLO 8
    CALL SERIAL_PRINT_STRING

    ; Generate black moves
    LDI BLACK
    PLO 12
    LDI HIGH(MOVELIST)
    PHI 9
    LDI LOW(MOVELIST)
    PLO 9
    CALL GENERATE_MOVES

    ; Save R9 and add terminator
    GLO 9
    PLO 15
    GHI 9
    PHI 15
    LDI $FF
    STR 15

    LDI HIGH(MOVELIST)
    PHI 11
    LDI LOW(MOVELIST)
    PLO 11
    CALL PRINT_MOVES

    LDI HIGH(STR_DONE)
    PHI 8
    LDI LOW(STR_DONE)
    PLO 8
    CALL SERIAL_PRINT_STRING

HALT:
    BR HALT

; Temp storage for move pointer (R11 clobbered by serial)
MOVE_PTR_LO EQU $50F0
MOVE_PTR_HI EQU $50F1

; Print all moves from list at R11
PRINT_MOVES:
    LDI 0
    PLO 14              ; Count

    ; Save initial R11 to memory
    LDI HIGH(MOVE_PTR_LO)
    PHI 10
    LDI LOW(MOVE_PTR_LO)
    PLO 10
    GLO 11
    STR 10
    INC 10
    GHI 11
    STR 10

PM_LOOP:
    ; Restore R11 from memory
    LDI HIGH(MOVE_PTR_LO)
    PHI 10
    LDI LOW(MOVE_PTR_LO)
    PLO 10
    LDN 10
    PLO 11
    INC 10
    LDN 10
    PHI 11

    ; Check for end
    LDN 11
    XRI $FF
    LBZ PM_DONE

    ; Load move bytes
    LDA 11
    PLO 13              ; from in R13.0
    LDA 11
    PHI 13              ; to in R13.1

    ; Save updated R11
    LDI HIGH(MOVE_PTR_LO)
    PHI 10
    LDI LOW(MOVE_PTR_LO)
    PLO 10
    GLO 11
    STR 10
    INC 10
    GHI 11
    STR 10

    ; Print move (R11 will be clobbered)
    GLO 13
    CALL SERIAL_PRINT_HEX
    LDI '-'
    CALL SERIAL_WRITE_CHAR
    GHI 13
    CALL SERIAL_PRINT_HEX
    LDI ' '
    CALL SERIAL_WRITE_CHAR

    INC 14
    GLO 14
    ANI $07
    LBNZ PM_LOOP
    ; Newline every 8 moves
    LDI HIGH(STR_CRLF)
    PHI 8
    LDI LOW(STR_CRLF)
    PLO 8
    CALL SERIAL_PRINT_STRING
    LBR PM_LOOP

PM_DONE:
    ; Print count
    LDI HIGH(STR_CRLF)
    PHI 8
    LDI LOW(STR_CRLF)
    PLO 8
    CALL SERIAL_PRINT_STRING
    LDI HIGH(STR_COUNT)
    PHI 8
    LDI LOW(STR_COUNT)
    PLO 8
    CALL SERIAL_PRINT_STRING
    GLO 14
    CALL SERIAL_PRINT_HEX
    LDI HIGH(STR_CRLF)
    PHI 8
    LDI LOW(STR_CRLF)
    PLO 8
    CALL SERIAL_PRINT_STRING
    RETN

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
; Move Generator (Queens and Kings only)
; ==============================================================================
GENERATE_MOVES:
    GLO 9
    PLO 15
    GHI 9
    PHI 15

    LDI HIGH(BOARD)
    PHI 10
    LDI LOW(BOARD)
    PLO 10

    LDI 0
    PLO 14

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

    GLO 15
    STR 2
    GLO 9
    SM
    SHR
    RETN

GM_QUEEN:
    LDI 0
    PLO 13

GM_Q_DIR:
    GLO 13
    STR 2
    LDI LOW(QUEEN_DIRS)
    ADD
    PLO 8
    LDI HIGH(QUEEN_DIRS)
    ADCI 0
    PHI 8
    LDN 8
    PLO 11

    GLO 14

GM_Q_SLIDE:
    STR 2
    GLO 11
    ADD
    PLO 8

    ANI $88
    BNZ GM_Q_NEXT_DIR

    LDI HIGH(BOARD)
    PHI 8
    LDN 8
    BZ GM_Q_ADD

    ANI COLOR_MASK
    STR 2
    GLO 12
    XOR
    BZ GM_Q_NEXT_DIR

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
    LDI 0
    PLO 13

GM_K_DIR:
    GLO 13
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

QUEEN_DIRS:
    DB DIR_N, DIR_NE, DIR_E, DIR_SE
    DB DIR_S, DIR_SW, DIR_W, DIR_NW

STR_BANNER:
    DB "MoveGen Debug Test", 0DH, 0AH
    DB "Pos: WQd4 WKe1 vs BQd6 BNc4 BPa5 BKe8", 0DH, 0AH, 0

STR_WHITE:
    DB "White moves:", 0DH, 0AH, 0

STR_BLACK:
    DB "Black moves:", 0DH, 0AH, 0

STR_COUNT:
    DB "Count: ", 0

STR_DONE:
    DB "Done.", 0DH, 0AH, 0

STR_CRLF:
    DB 0DH, 0AH, 0

    END
