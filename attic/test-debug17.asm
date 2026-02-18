; ==============================================================================
; Debug Test 17: Minimal IS_IN_CHECK test
; Setup: Kd1, BQe8, BKa8 - king at d1 should NOT be in check
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

EMPTY       EQU $00
COLOR_MASK  EQU $08
WHITE       EQU $00
BLACK       EQU $08
W_KING      EQU $06
B_QUEEN     EQU $0D
B_KING      EQU $0E

SQ_D1       EQU $03
SQ_A8       EQU $70
SQ_E8       EQU $74

TEMP_KING   EQU $5090   ; Temp storage for king square

DIR_N       EQU $F0
DIR_S       EQU $10
DIR_E       EQU $01
DIR_W       EQU $FF

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

    ; Clear board
    CALL CLEAR_BOARD

    ; Setup: Kd1, BKa8, BQe8
    LDI HIGH(BOARD)
    PHI 10

    ; White king at d1
    LDI SQ_D1
    PLO 10
    LDI W_KING
    STR 10

    ; Black king at a8
    LDI SQ_A8
    PLO 10
    LDI B_KING
    STR 10

    ; Black queen at e8
    LDI SQ_E8
    PLO 10
    LDI B_QUEEN
    STR 10

    ; Print board squares for verification
    LDI HIGH(STR_D1)
    PHI 8
    LDI LOW(STR_D1)
    PLO 8
    CALL SERIAL_PRINT_STRING
    LDI HIGH(BOARD)
    PHI 10
    LDI SQ_D1
    PLO 10
    LDN 10
    CALL SERIAL_PRINT_HEX
    CALL PRINT_CRLF

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

    ; Now test IS_IN_CHECK with R12 = WHITE
    LDI WHITE
    PLO 12

    LDI HIGH(STR_CHECK)
    PHI 8
    LDI LOW(STR_CHECK)
    PLO 8
    CALL SERIAL_PRINT_STRING

    CALL IS_IN_CHECK
    CALL SERIAL_PRINT_HEX
    CALL PRINT_CRLF

    ; Also test with king at e2 (should be in check from queen)
    LDI HIGH(STR_E2TEST)
    PHI 8
    LDI LOW(STR_E2TEST)
    PLO 8
    CALL SERIAL_PRINT_STRING

    ; Move king from d1 to e2
    LDI HIGH(BOARD)
    PHI 10
    LDI SQ_D1
    PLO 10
    LDI EMPTY
    STR 10

    LDI $14             ; e2
    PLO 10
    LDI W_KING
    STR 10

    LDI WHITE
    PLO 12
    CALL IS_IN_CHECK
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
; IS_IN_CHECK - Check if current side's king is in check
; Input: R12.0 = side to check (WHITE or BLACK)
; Output: D = 1 if in check, 0 if not
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
    PLO 14              ; R14.0 = king piece code

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

    ; King not found - print debug
    LDI HIGH(STR_NOKING)
    PHI 8
    LDI LOW(STR_NOKING)
    PLO 8
    CALL SERIAL_PRINT_STRING

    LDI 0
    RETN

IIC_FOUND_KING:
    ; Print found king at square - save to memory since serial clobbers R11!
    LDI HIGH(TEMP_KING)
    PHI 10
    LDI LOW(TEMP_KING)
    PLO 10
    GLO 11
    STR 10              ; save king square to memory

    LDI HIGH(STR_KINGAT)
    PHI 8
    LDI LOW(STR_KINGAT)
    PLO 8
    CALL SERIAL_PRINT_STRING

    LDI HIGH(TEMP_KING)
    PHI 10
    LDI LOW(TEMP_KING)
    PLO 10
    LDN 10              ; D = king square
    CALL SERIAL_PRINT_HEX
    CALL PRINT_CRLF

    ; Restore R11 from memory AFTER all serial calls
    LDI HIGH(TEMP_KING)
    PHI 10
    LDI LOW(TEMP_KING)
    PLO 10
    LDN 10
    PLO 11              ; R11.0 = king square

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
ROOK_DIRS:
    DB $F0      ; N  (-16)
    DB $10      ; S  (+16)
    DB $FF      ; W  (-1)
    DB $01      ; E  (+1)

; ==============================================================================
STR_BANNER:
    DB "Debug17: IS_IN_CHECK test", 0DH, 0AH, 0

STR_D1:
    DB "D1=", 0

STR_E8:
    DB "E8=", 0

STR_CHECK:
    DB "Check: ", 0

STR_E2TEST:
    DB "E2 test: ", 0

STR_NOKING:
    DB "King not found!", 0DH, 0AH, 0

STR_KINGAT:
    DB "King at: ", 0

STR_CRLF:
    DB 0DH, 0AH, 0

    END
