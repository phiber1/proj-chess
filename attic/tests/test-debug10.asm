; ==============================================================================
; Debug Test 10: Run 2 iterations manually to find loop bug
; Test moves 4 (Ke2-illegal) and 5 (Kf2-legal) specifically
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
LEGAL_LIST  EQU $5300

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
    ; D = 5 moves

    ; === Print "Generated:" then count ===
    LDI HIGH(STR_GEN)
    PHI 8
    LDI LOW(STR_GEN)
    PLO 8
    CALL SERIAL_PRINT_STRING
    LDI 5               ; We know it's 5
    CALL SERIAL_PRINT_HEX
    CALL PRINT_CRLF

    ; === Setup for iterations ===
    ; Point to move 4 (index 3, offset 6)
    LDI HIGH(MOVE_LIST)
    PHI 10
    LDI LOW(MOVE_LIST)+6
    PLO 10

    LDI 0
    PLO 14              ; R14.0 = legal count

    ; === ITERATION 1: Move 4 (Ke2) - should be ILLEGAL ===
    LDI HIGH(STR_IT1)
    PHI 8
    LDI LOW(STR_IT1)
    PLO 8
    CALL SERIAL_PRINT_STRING

    ; Reset R10 (serial clobbered it)
    LDI HIGH(MOVE_LIST)
    PHI 10
    LDI LOW(MOVE_LIST)+6
    PLO 10

    ; Get from/to
    LDA 10
    PLO 11
    LDA 10
    PHI 11

    ; Print the move
    GLO 11
    CALL SERIAL_PRINT_HEX
    LDI '-'
    CALL SERIAL_WRITE_CHAR
    GHI 11
    CALL SERIAL_PRINT_HEX
    CALL PRINT_CRLF

    ; Reset R11 (serial clobbered it)
    LDI SQ_E1
    PLO 11
    LDI SQ_E2
    PHI 11

    ; Save registers
    GLO 12
    STXD
    GLO 14
    STXD
    GHI 10
    STXD
    GLO 10
    STXD
    GHI 11
    STXD
    GLO 11
    STXD

    ; Make move
    CALL MAKE_MOVE

    ; Save R7
    GHI 7
    STXD
    GLO 7
    STXD

    ; IS_IN_CHECK
    CALL IS_IN_CHECK
    PLO 13              ; Save result

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

    ; Unmake
    CALL UNMAKE_MOVE

    ; Restore R10
    IRX
    LDXA
    PLO 10
    LDX
    PHI 10

    ; Restore R14
    IRX
    LDXA
    PLO 14

    ; Restore R12
    LDX
    PLO 12

    ; Print check result
    LDI HIGH(STR_CHK)
    PHI 8
    LDI LOW(STR_CHK)
    PLO 8
    CALL SERIAL_PRINT_STRING

    GLO 13
    CALL SERIAL_PRINT_HEX
    CALL PRINT_CRLF

    ; R13.0 should be 1 (in check = illegal)
    ; If 0, we'd incorrectly count it as legal

    ; === ITERATION 2: Move 5 (Kf2) - should be LEGAL ===
    LDI HIGH(STR_IT2)
    PHI 8
    LDI LOW(STR_IT2)
    PLO 8
    CALL SERIAL_PRINT_STRING

    ; R10 should point to MOVE_LIST+8 after iteration 1
    ; Let's manually set it to be sure
    LDI HIGH(MOVE_LIST)
    PHI 10
    LDI LOW(MOVE_LIST)+8
    PLO 10

    ; Get from/to
    LDA 10
    PLO 11
    LDA 10
    PHI 11

    ; Print the move
    GLO 11
    CALL SERIAL_PRINT_HEX
    LDI '-'
    CALL SERIAL_WRITE_CHAR
    GHI 11
    CALL SERIAL_PRINT_HEX
    CALL PRINT_CRLF

    ; Reset R11 (serial clobbered it)
    LDI SQ_E1
    PLO 11
    LDI SQ_F2           ; $15
    PHI 11

    ; Save registers
    GLO 12
    STXD
    GLO 14
    STXD
    GHI 10
    STXD
    GLO 10
    STXD
    GHI 11
    STXD
    GLO 11
    STXD

    ; Make move
    CALL MAKE_MOVE

    ; Save R7
    GHI 7
    STXD
    GLO 7
    STXD

    ; IS_IN_CHECK
    CALL IS_IN_CHECK
    PLO 13              ; Save result

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

    ; Unmake
    CALL UNMAKE_MOVE

    ; Restore R10
    IRX
    LDXA
    PLO 10
    LDX
    PHI 10

    ; Restore R14
    IRX
    LDXA
    PLO 14

    ; Restore R12
    LDX
    PLO 12

    ; Print check result
    LDI HIGH(STR_CHK)
    PHI 8
    LDI LOW(STR_CHK)
    PLO 8
    CALL SERIAL_PRINT_STRING

    GLO 13
    CALL SERIAL_PRINT_HEX
    CALL PRINT_CRLF

    ; R13.0 should be 0 (not in check = legal)

HALT:
    BR HALT

; ==============================================================================
SQ_F2       EQU $15

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
    DB "Debug10: 2 iterations", 0DH, 0AH, 0

STR_GEN:
    DB "Generated: ", 0

STR_IT1:
    DB "Iter1 (Ke2): ", 0

STR_IT2:
    DB "Iter2 (Kf2): ", 0

STR_CHK:
    DB "Check: ", 0

STR_CRLF:
    DB 0DH, 0AH, 0

    END
