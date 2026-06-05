; ==============================================================================
; Debug Test 13: Just 2 hardcoded iterations - no loop counter
; Check board state between iterations
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
PIECE_MASK  EQU $07

DIR_N       EQU $F0
DIR_S       EQU $10
DIR_E       EQU $01
DIR_W       EQU $FF
DIR_NE      EQU $F1
DIR_NW      EQU $EF
DIR_SE      EQU $11
DIR_SW      EQU $0F

GS_SIDE     EQU 0
GS_CASTLE   EQU 1
GS_EP       EQU 2

CASTLE_WK   EQU $01
CASTLE_WQ   EQU $02
CASTLE_BK   EQU $04
CASTLE_BQ   EQU $08

SQ_E1       EQU $04
SQ_D1       EQU $03
SQ_F1       EQU $05
SQ_E8       EQU $74
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

    ; Setup board: Ke1, BQe8, BKa8
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
    LDI $FF
    STR 10

    LDI WHITE
    PLO 12

    ; === Check board BEFORE iteration 1 ===
    LDI HIGH(STR_BEFORE1)
    PHI 8
    LDI LOW(STR_BEFORE1)
    PLO 8
    CALL SERIAL_PRINT_STRING
    CALL PRINT_E1_SQUARE

    ; === ITERATION 1: Kd1 (04->03) ===
    LDI HIGH(STR_ITER1)
    PHI 8
    LDI LOW(STR_ITER1)
    PLO 8
    CALL SERIAL_PRINT_STRING

    ; Set move in R11
    LDI SQ_E1
    PLO 11
    LDI SQ_D1
    PHI 11

    ; Save R11
    GHI 11
    STXD
    GLO 11
    STXD

    ; MAKE_MOVE
    CALL MAKE_MOVE

    ; Save R7
    GHI 7
    STXD
    GLO 7
    STXD

    ; Print "After make:"
    LDI HIGH(STR_AFTER_MAKE)
    PHI 8
    LDI LOW(STR_AFTER_MAKE)
    PLO 8
    CALL SERIAL_PRINT_STRING
    CALL PRINT_E1_SQUARE

    ; Restore R7
    IRX
    LDXA
    PLO 7
    LDX
    PHI 7

    ; Restore R11
    IRX
    LDXA
    PLO 11
    LDX
    PHI 11

    ; UNMAKE_MOVE
    CALL UNMAKE_MOVE

    ; Print "After unmake:"
    LDI HIGH(STR_AFTER_UNMAKE)
    PHI 8
    LDI LOW(STR_AFTER_UNMAKE)
    PLO 8
    CALL SERIAL_PRINT_STRING
    CALL PRINT_E1_SQUARE

    ; === ITERATION 2: Kf1 (04->05) ===
    LDI HIGH(STR_ITER2)
    PHI 8
    LDI LOW(STR_ITER2)
    PLO 8
    CALL SERIAL_PRINT_STRING

    ; Set move in R11
    LDI SQ_E1
    PLO 11
    LDI SQ_F1
    PHI 11

    ; Save R11
    GHI 11
    STXD
    GLO 11
    STXD

    ; MAKE_MOVE
    CALL MAKE_MOVE

    ; Save R7
    GHI 7
    STXD
    GLO 7
    STXD

    ; Print "After make:"
    LDI HIGH(STR_AFTER_MAKE)
    PHI 8
    LDI LOW(STR_AFTER_MAKE)
    PLO 8
    CALL SERIAL_PRINT_STRING
    CALL PRINT_E1_SQUARE

    ; Restore R7
    IRX
    LDXA
    PLO 7
    LDX
    PHI 7

    ; Restore R11
    IRX
    LDXA
    PLO 11
    LDX
    PHI 11

    ; UNMAKE_MOVE
    CALL UNMAKE_MOVE

    ; Print "After unmake:"
    LDI HIGH(STR_AFTER_UNMAKE)
    PHI 8
    LDI LOW(STR_AFTER_UNMAKE)
    PLO 8
    CALL SERIAL_PRINT_STRING
    CALL PRINT_E1_SQUARE

    LDI HIGH(STR_DONE)
    PHI 8
    LDI LOW(STR_DONE)
    PLO 8
    CALL SERIAL_PRINT_STRING

HALT:
    BR HALT

; ==============================================================================
; Print contents of E1 square (should be 06 = W_KING normally)
; ==============================================================================
PRINT_E1_SQUARE:
    LDI HIGH(BOARD)
    PHI 10
    LDI SQ_E1
    PLO 10
    LDN 10
    CALL SERIAL_PRINT_HEX
    CALL PRINT_CRLF
    RETN

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

UNMAKE_MOVE:
    LDI HIGH(BOARD)
    PHI 8
    GLO 11
    PLO 8
    GLO 7
    STR 8
    GHI 11
    PLO 8
    GHI 7
    STR 8
    RETN

#include "movegen-new.asm"

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
    DB "Debug13: Make/Unmake test", 0DH, 0AH, 0

STR_BEFORE1:
    DB "E1 before: ", 0

STR_ITER1:
    DB "=== Iter1: Kd1 ===", 0DH, 0AH, 0

STR_ITER2:
    DB "=== Iter2: Kf1 ===", 0DH, 0AH, 0

STR_AFTER_MAKE:
    DB "E1 after make: ", 0

STR_AFTER_UNMAKE:
    DB "E1 after unmake: ", 0

STR_DONE:
    DB "Done", 0DH, 0AH, 0

STR_CRLF:
    DB 0DH, 0AH, 0

    END
