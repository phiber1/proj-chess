; ==============================================================================
; Debug Test: Isolate the Ke1-e2 check detection issue
; ==============================================================================
; Setup: White Ke1, Black Qe8, Black Ka8
; Make move Ke1-e2
; Check if IS_IN_CHECK detects the queen attack on e2
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

EMPTY       EQU $00
COLOR_MASK  EQU $08
PIECE_MASK  EQU $07
WHITE       EQU $00
BLACK       EQU $08

W_KING      EQU $06
B_QUEEN     EQU $0D
B_KING      EQU $0E

; Directions
DIR_N       EQU $F0
DIR_S       EQU $10
DIR_E       EQU $01
DIR_W       EQU $FF
DIR_NE      EQU $F1
DIR_NW      EQU $EF
DIR_SE      EQU $11
DIR_SW      EQU $0F

; Squares
SQ_E1       EQU $04
SQ_E2       EQU $14
SQ_E8       EQU $74

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

    ; =========================================
    ; Setup board: Ke1, BQe8, BKa8
    ; =========================================
    CALL CLEAR_BOARD

    ; White king e1
    LDI HIGH(BOARD)
    PHI 10
    LDI SQ_E1
    PLO 10
    LDI W_KING
    STR 10

    ; Black king a8
    LDI $70
    PLO 10
    LDI B_KING
    STR 10

    ; Black queen e8
    LDI SQ_E8
    PLO 10
    LDI B_QUEEN
    STR 10

    ; =========================================
    ; Test 1: Check before move (should be 01)
    ; =========================================
    LDI HIGH(STR_BEFORE)
    PHI 8
    LDI LOW(STR_BEFORE)
    PLO 8
    CALL SERIAL_PRINT_STRING

    LDI WHITE
    PLO 12
    CALL IS_IN_CHECK
    CALL SERIAL_PRINT_HEX
    CALL PRINT_CRLF

    ; =========================================
    ; Test 2: Make move Ke1-e2, check (should be 01)
    ; =========================================
    LDI HIGH(STR_AFTER)
    PHI 8
    LDI LOW(STR_AFTER)
    PLO 8
    CALL SERIAL_PRINT_STRING

    ; Make the move manually
    LDI HIGH(BOARD)
    PHI 10

    ; Clear e1
    LDI SQ_E1
    PLO 10
    LDI EMPTY
    STR 10

    ; Place king on e2
    LDI SQ_E2
    PLO 10
    LDI W_KING
    STR 10

    ; Now check
    LDI WHITE
    PLO 12
    CALL IS_IN_CHECK
    CALL SERIAL_PRINT_HEX
    CALL PRINT_CRLF

    ; =========================================
    ; Test 3: Print R12 value to verify
    ; =========================================
    LDI HIGH(STR_R12)
    PHI 8
    LDI LOW(STR_R12)
    PLO 8
    CALL SERIAL_PRINT_STRING

    GLO 12
    CALL SERIAL_PRINT_HEX
    CALL PRINT_CRLF

    ; =========================================
    ; Test 4: Print what's at e8
    ; =========================================
    LDI HIGH(STR_E8)
    PHI 8
    LDI LOW(STR_E8)
    PLO 8
    CALL SERIAL_PRINT_STRING

    LDI HIGH(BOARD)
    PHI 10
    LDI SQ_E8
    PLO 10
    LDN 10
    CALL SERIAL_PRINT_HEX
    CALL PRINT_CRLF

HALT:
    BR HALT

; ==============================================================================
; PRINT_CRLF
; ==============================================================================
PRINT_CRLF:
    LDI HIGH(STR_CRLF)
    PHI 8
    LDI LOW(STR_CRLF)
    PLO 8
    CALL SERIAL_PRINT_STRING
    RETN

; ==============================================================================
; IS_IN_CHECK - Check if king is under attack
; ==============================================================================
IS_IN_CHECK:
    ; Find the king
    LDI HIGH(BOARD)
    PHI 10
    LDI LOW(BOARD)
    PLO 10

    LDI 6
    STR 2
    GLO 12
    ADD
    PLO 14              ; R14.0 = king piece code

    LDI 0
    PLO 11              ; R11.0 = square index

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

    ; King not found
    LDI 0
    RETN

IIC_FOUND_KING:
    ; R11.0 = king's square
    GLO 12
    XRI BLACK
    PLO 13              ; R13.0 = enemy color

    ; --- Check orthogonal attacks (rook/queen) ---
    LDI HIGH(ROOK_DIRS)
    PHI 8
    LDI LOW(ROOK_DIRS)
    PLO 8

    LDI 4
    PLO 14              ; R14.0 = loop counter

    LDI 4
    STR 2
    GLO 13
    ADD
    PHI 14              ; R14.1 = enemy rook

IIC_ORTH_DIR:
    LDN 8
    PHI 13              ; R13.1 = direction

    GLO 11
    PLO 7               ; R7.0 = king square

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

    ; Not in check
    LDI 0
    RETN

IIC_IN_CHECK:
    LDI 1
    RETN

; ==============================================================================
; CLEAR_BOARD
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
; Data Tables
; ==============================================================================
ROOK_DIRS:
    DB DIR_N, DIR_S, DIR_W, DIR_E

; ==============================================================================
; Strings
; ==============================================================================
STR_BANNER:
    DB "Debug: Ke1-e2 check", 0DH, 0AH, 0

STR_BEFORE:
    DB "Before move: ", 0

STR_AFTER:
    DB "After Ke2: ", 0

STR_R12:
    DB "R12 value: ", 0

STR_E8:
    DB "Piece at e8: ", 0

STR_CRLF:
    DB 0DH, 0AH, 0

    END
