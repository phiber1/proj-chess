; ==============================================================================
; Debug Test 8: Read 4th move from MOVE_LIST (should be Ke2 = 04-14)
; and test IS_IN_CHECK on it specifically
; ==============================================================================

    ORG $0000
    LBR MAIN

#include "serial-io.asm"

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
BOARD       EQU $5000
GAME_STATE  EQU $5080
MOVE_LIST   EQU $5200

EMPTY       EQU $00
COLOR_MASK  EQU $08
WHITE       EQU $00
BLACK       EQU $08
W_KING      EQU $06
B_QUEEN     EQU $0D
B_KING      EQU $0E
NO_EP       EQU $FF
PIECE_MASK  EQU $07

GS_SIDE     EQU 0
GS_CASTLE   EQU 1
GS_EP       EQU 2

CASTLE_WK   EQU $01
CASTLE_WQ   EQU $02
CASTLE_BK   EQU $04
CASTLE_BQ   EQU $08
ALL_CASTLING EQU $0F

DIR_N       EQU $F0
DIR_S       EQU $10
DIR_E       EQU $01
DIR_W       EQU $FF
DIR_NE      EQU $F1
DIR_NW      EQU $EF
DIR_SE      EQU $11
DIR_SW      EQU $0F

SQ_E1       EQU $04
SQ_E2       EQU $14
SQ_E8       EQU $74
SQ_D1       EQU $03
SQ_F1       EQU $05
SQ_G1       EQU $06
SQ_C1       EQU $02
SQ_B1       EQU $01
SQ_F8       EQU $75
SQ_G8       EQU $76
SQ_D8       EQU $73
SQ_C8       EQU $72
SQ_B8       EQU $71

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

    ; Setup board
    CALL CLEAR_BOARD

    LDI HIGH(BOARD)
    PHI 10
    LDI SQ_E1
    PLO 10
    LDI W_KING
    STR 10

    LDI $70
    PLO 10
    LDI B_KING
    STR 10

    LDI SQ_E8
    PLO 10
    LDI B_QUEEN
    STR 10

    ; Game state
    LDI HIGH(GAME_STATE)
    PHI 10
    LDI LOW(GAME_STATE)
    PLO 10
    LDI WHITE
    STR 10
    INC 10
    LDI 0
    STR 10
    INC 10
    LDI NO_EP
    STR 10

    ; Generate moves
    LDI HIGH(MOVE_LIST)
    PHI 9
    LDI LOW(MOVE_LIST)
    PLO 9
    LDI WHITE
    PLO 12
    CALL GENERATE_MOVES

    ; Print "Generated X moves"
    LDI HIGH(STR_GEN)
    PHI 8
    LDI LOW(STR_GEN)
    PLO 8
    CALL SERIAL_PRINT_STRING
    ; D still has count
    CALL SERIAL_PRINT_HEX
    CALL PRINT_CRLF

    ; Print all moves from list
    LDI HIGH(STR_LIST)
    PHI 8
    LDI LOW(STR_LIST)
    PLO 8
    CALL SERIAL_PRINT_STRING

    LDI HIGH(MOVE_LIST)
    PHI 10
    LDI LOW(MOVE_LIST)
    PLO 10

    ; Print 5 moves (we know there are 5)
    LDI 5
    PLO 13
PRINT_LOOP:
    GLO 13
    LBZ PRINT_DONE
    LDA 10
    CALL SERIAL_PRINT_HEX
    LDI '-'
    CALL SERIAL_WRITE_CHAR
    LDA 10
    CALL SERIAL_PRINT_HEX
    LDI ' '
    CALL SERIAL_WRITE_CHAR
    DEC 13
    LBR PRINT_LOOP

PRINT_DONE:
    CALL PRINT_CRLF

    ; Now specifically test the 4th move (index 3 = offset 6)
    ; which should be 04-14 (Ke2)
    LDI HIGH(STR_TEST)
    PHI 8
    LDI LOW(STR_TEST)
    PLO 8
    CALL SERIAL_PRINT_STRING

    ; Read 4th move from list
    LDI HIGH(MOVE_LIST)
    PHI 10
    LDI LOW(MOVE_LIST)+6   ; Skip first 3 moves (6 bytes)
    PLO 10

    LDA 10
    PLO 11              ; from
    LDA 10
    PHI 11              ; to

    ; Print what we got
    GLO 11
    CALL SERIAL_PRINT_HEX
    LDI '-'
    CALL SERIAL_WRITE_CHAR
    GHI 11
    CALL SERIAL_PRINT_HEX
    CALL PRINT_CRLF

    ; Now do the full make/check/unmake
    LDI HIGH(STR_RESULT)
    PHI 8
    LDI LOW(STR_RESULT)
    PLO 8
    CALL SERIAL_PRINT_STRING

    ; Make the move (R11 still has from/to from print)
    ; But serial clobbered R11! Need to reload
    LDI HIGH(MOVE_LIST)
    PHI 10
    LDI LOW(MOVE_LIST)+6
    PLO 10
    LDA 10
    PLO 11
    LDA 10
    PHI 11

    ; Make move
    CALL MAKE_MOVE

    ; Check
    LDI WHITE
    PLO 12
    CALL IS_IN_CHECK

    ; Print result
    CALL SERIAL_PRINT_HEX
    CALL PRINT_CRLF

HALT:
    BR HALT

; ==============================================================================
PRINT_CRLF:
    LDI HIGH(STR_CRLF)
    PHI 8
    LDI LOW(STR_CRLF)
    PLO 8
    CALL SERIAL_PRINT_STRING
    RETN

MAKE_MOVE:
    LDI HIGH(BOARD)
    PHI 8
    GLO 11
    PLO 8
    LDN 8
    PLO 7
    GHI 11
    PLO 8
    LDN 8
    PHI 7
    GLO 7
    STR 8
    GLO 11
    PLO 8
    LDI EMPTY
    STR 8
    RETN

#include "movegen-new.asm"

; ==============================================================================
IS_IN_CHECK:
    LDI HIGH(BOARD)
    PHI 10
    LDI LOW(BOARD)
    PLO 10

    LDI 6
    STR 2
    GLO 12
    ADD
    PLO 14

    LDI 0
    PLO 11

IIC_FIND_KING:
    GLO 11
    ANI $88
    LBNZ IIC_FIND_NEXT

    LDN 10
    STR 2
    GLO 14
    SM
    LBZ IIC_FOUND_KING

IIC_FIND_NEXT:
    INC 10
    INC 11
    GLO 11
    ANI $80
    LBZ IIC_FIND_KING

    LDI 0
    RETN

IIC_FOUND_KING:
    GLO 12
    XRI BLACK
    PLO 13

    LDI HIGH(ROOK_DIRS)
    PHI 8
    LDI LOW(ROOK_DIRS)
    PLO 8

    LDI 4
    PLO 14

    LDI 4
    STR 2
    GLO 13
    ADD
    PHI 14

IIC_ORTH_DIR:
    LDN 8
    PHI 13

    GLO 11
    PLO 7

IIC_ORTH_RAY:
    GLO 7
    STR 2
    GHI 13
    ADD
    PLO 7

    ANI $88
    LBNZ IIC_ORTH_NEXT

    LDI HIGH(BOARD)
    PHI 10
    GLO 7
    PLO 10
    LDN 10
    LBZ IIC_ORTH_RAY

    PLO 10
    STR 2
    GHI 14
    SM
    LBZ IIC_IN_CHECK

    GHI 14
    ADI 1
    STR 2
    GLO 10
    SM
    LBZ IIC_IN_CHECK

    LBR IIC_ORTH_NEXT

IIC_ORTH_NEXT:
    INC 8
    DEC 14
    GLO 14
    LBNZ IIC_ORTH_DIR

    LDI 0
    RETN

IIC_IN_CHECK:
    LDI 1
    RETN

; ==============================================================================
CLEAR_BOARD:
    LDI HIGH(BOARD)
    PHI 10
    LDI LOW(BOARD)
    PLO 10
    LDI 128
    PLO 13
CB_LOOP:
    LDI EMPTY
    STR 10
    INC 10
    DEC 13
    GLO 13
    LBNZ CB_LOOP
    RETN

; ==============================================================================
STR_BANNER:
    DB "Debug8: Check 4th move", 0DH, 0AH, 0

STR_GEN:
    DB "Generated: ", 0

STR_LIST:
    DB "Moves: ", 0

STR_TEST:
    DB "4th move: ", 0

STR_RESULT:
    DB "In check: ", 0

STR_CRLF:
    DB 0DH, 0AH, 0

    END
