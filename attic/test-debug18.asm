; ==============================================================================
; Debug Test 18: Single iteration of legal move loop with logging
; Tests the first move only, with debug output at each step
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
MOVE_LIST   EQU $5200
MOVE_PIECE  EQU $5090
CAPT_PIECE  EQU $5091
TEMP_R13    EQU $5092   ; Save R13 across calls

EMPTY       EQU $00
COLOR_MASK  EQU $08
WHITE       EQU $00
BLACK       EQU $08
W_KING      EQU $06
B_QUEEN     EQU $0D
B_KING      EQU $0E

SQ_E1       EQU $04
SQ_D1       EQU $03
SQ_A8       EQU $70
SQ_E8       EQU $74

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

    ; Clear board and setup position
    CALL CLEAR_BOARD

    LDI HIGH(BOARD)
    PHI 10
    LDI SQ_E1
    PLO 10
    LDI W_KING
    STR 10

    LDI SQ_A8
    PLO 10
    LDI B_KING
    STR 10

    LDI SQ_E8
    PLO 10
    LDI B_QUEEN
    STR 10

    ; Manually create one move: e1-d1 (from=$04, to=$03)
    LDI HIGH(MOVE_LIST)
    PHI 10
    LDI LOW(MOVE_LIST)
    PLO 10
    LDI SQ_E1           ; from
    STR 10
    INC 10
    LDI SQ_D1           ; to
    STR 10

    ; Print: "Move: 04-03"
    LDI HIGH(STR_MOVE)
    PHI 8
    LDI LOW(STR_MOVE)
    PLO 8
    CALL SERIAL_PRINT_STRING
    LDI SQ_E1
    CALL SERIAL_PRINT_HEX
    LDI '-'
    CALL SERIAL_WRITE_CHAR
    LDI SQ_D1
    CALL SERIAL_PRINT_HEX
    CALL PRINT_CRLF

    ; ===== START OF SINGLE ITERATION =====

    ; Read move into R11
    LDI HIGH(MOVE_LIST)
    PHI 10
    LDI LOW(MOVE_LIST)
    PLO 10
    LDA 10
    PLO 11              ; R11.0 = from
    LDA 10
    PHI 11              ; R11.1 = to

    ; Print R11 contents
    LDI HIGH(STR_R11)
    PHI 8
    LDI LOW(STR_R11)
    PLO 8
    CALL SERIAL_PRINT_STRING
    GLO 11
    CALL SERIAL_PRINT_HEX
    LDI ','
    CALL SERIAL_WRITE_CHAR
    GHI 11
    CALL SERIAL_PRINT_HEX
    CALL PRINT_CRLF

    ; Reload R11 (serial clobbered it)
    LDI HIGH(MOVE_LIST)
    PHI 10
    LDI LOW(MOVE_LIST)
    PLO 10
    LDA 10
    PLO 11
    LDA 10
    PHI 11

    ; Set R12 = WHITE
    LDI WHITE
    PLO 12

    ; Make move
    LDI HIGH(STR_MAKE)
    PHI 8
    LDI LOW(STR_MAKE)
    PLO 8
    CALL SERIAL_PRINT_STRING

    ; Reload R11 again
    LDI HIGH(MOVE_LIST)
    PHI 10
    LDI LOW(MOVE_LIST)
    PLO 10
    LDA 10
    PLO 11
    LDA 10
    PHI 11

    CALL MAKE_MOVE_MEM

    ; Print board state after make
    LDI HIGH(STR_E1)
    PHI 8
    LDI LOW(STR_E1)
    PLO 8
    CALL SERIAL_PRINT_STRING
    LDI HIGH(BOARD)
    PHI 10
    LDI SQ_E1
    PLO 10
    LDN 10
    CALL SERIAL_PRINT_HEX

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

    ; Now call IS_IN_CHECK
    LDI HIGH(STR_CHECK)
    PHI 8
    LDI LOW(STR_CHECK)
    PLO 8
    CALL SERIAL_PRINT_STRING

    LDI WHITE
    PLO 12
    CALL IS_IN_CHECK
    PLO 13              ; Save result in R13.0

    ; Print check result
    GLO 13
    CALL SERIAL_PRINT_HEX
    CALL PRINT_CRLF

    ; Save R13.0 to memory before unmake
    LDI HIGH(TEMP_R13)
    PHI 10
    LDI LOW(TEMP_R13)
    PLO 10
    GLO 13
    STR 10

    ; Reload R11 for unmake
    LDI HIGH(MOVE_LIST)
    PHI 10
    LDI LOW(MOVE_LIST)
    PLO 10
    LDA 10
    PLO 11
    LDA 10
    PHI 11

    ; Unmake move
    LDI HIGH(STR_UNMAKE)
    PHI 8
    LDI LOW(STR_UNMAKE)
    PLO 8
    CALL SERIAL_PRINT_STRING

    ; Reload R11 again (serial clobbered)
    LDI HIGH(MOVE_LIST)
    PHI 10
    LDI LOW(MOVE_LIST)
    PLO 10
    LDA 10
    PLO 11
    LDA 10
    PHI 11

    CALL UNMAKE_MOVE_MEM

    ; Print board state after unmake
    LDI HIGH(STR_E1)
    PHI 8
    LDI LOW(STR_E1)
    PLO 8
    CALL SERIAL_PRINT_STRING
    LDI HIGH(BOARD)
    PHI 10
    LDI SQ_E1
    PLO 10
    LDN 10
    CALL SERIAL_PRINT_HEX

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

    ; Restore R13 from memory and print final check result
    LDI HIGH(STR_FINAL)
    PHI 8
    LDI LOW(STR_FINAL)
    PLO 8
    CALL SERIAL_PRINT_STRING

    LDI HIGH(TEMP_R13)
    PHI 10
    LDI LOW(TEMP_R13)
    PLO 10
    LDN 10
    CALL SERIAL_PRINT_HEX
    CALL PRINT_CRLF

    ; Check if legal
    LDI HIGH(TEMP_R13)
    PHI 10
    LDI LOW(TEMP_R13)
    PLO 10
    LDN 10
    LBNZ NOT_LEGAL

    LDI HIGH(STR_LEGAL)
    PHI 8
    LDI LOW(STR_LEGAL)
    PLO 8
    CALL SERIAL_PRINT_STRING
    LBR HALT

NOT_LEGAL:
    LDI HIGH(STR_ILLEGAL)
    PHI 8
    LDI LOW(STR_ILLEGAL)
    PLO 8
    CALL SERIAL_PRINT_STRING

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
MAKE_MOVE_MEM:
    LDI HIGH(BOARD)
    PHI 8
    LDI HIGH(MOVE_PIECE)
    PHI 10
    LDI LOW(MOVE_PIECE)
    PLO 10

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

; ==============================================================================
UNMAKE_MOVE_MEM:
    LDI HIGH(BOARD)
    PHI 8
    LDI HIGH(MOVE_PIECE)
    PHI 10
    LDI LOW(MOVE_PIECE)
    PLO 10

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
ROOK_DIRS:
    DB $F0, $10, $FF, $01

; ==============================================================================
STR_BANNER:
    DB "Debug18: Single iteration test", 0DH, 0AH, 0

STR_MOVE:
    DB "Move: ", 0

STR_R11:
    DB "R11: ", 0

STR_MAKE:
    DB "After make: ", 0

STR_UNMAKE:
    DB "After unmake: ", 0

STR_E1:
    DB "E1=", 0

STR_D1:
    DB " D1=", 0

STR_CHECK:
    DB "Check: ", 0

STR_FINAL:
    DB "Final check: ", 0

STR_LEGAL:
    DB "LEGAL", 0DH, 0AH, 0

STR_ILLEGAL:
    DB "ILLEGAL", 0DH, 0AH, 0

STR_CRLF:
    DB 0DH, 0AH, 0

    END
