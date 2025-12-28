; ==============================================================================
; Debug Test 3: Include GENERATE_MOVES like real GEN_LEGAL_MOVES
; ==============================================================================
; This includes movegen-new.asm and calls GENERATE_MOVES first
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
LEGAL_LIST  EQU $5300

GS_SIDE     EQU 0
GS_CASTLE   EQU 1
GS_EP       EQU 2

CASTLE_WK   EQU $01
CASTLE_WQ   EQU $02
CASTLE_BK   EQU $04
CASTLE_BQ   EQU $08
ALL_CASTLING EQU $0F

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
SQ_D1       EQU $03
SQ_F1       EQU $05
SQ_E2       EQU $14
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

    ; =========================================
    ; Call GENERATE_MOVES (like GEN_LEGAL_MOVES)
    ; =========================================
    LDI HIGH(STR_GEN)
    PHI 8
    LDI LOW(STR_GEN)
    PLO 8
    CALL SERIAL_PRINT_STRING

    LDI HIGH(MOVE_LIST)
    PHI 9
    LDI LOW(MOVE_LIST)
    PLO 9

    LDI WHITE
    PLO 12

    CALL GENERATE_MOVES
    PLO 15              ; R15.0 = pseudo-legal count

    ; Print count
    GLO 15
    CALL SERIAL_PRINT_HEX
    CALL PRINT_CRLF

    ; =========================================
    ; Now set up for checking first move
    ; =========================================
    LDI HIGH(MOVE_LIST)
    PHI 10
    LDI LOW(MOVE_LIST)
    PLO 10

    ; Print first move
    LDI HIGH(STR_FIRST)
    PHI 8
    LDI LOW(STR_FIRST)
    PLO 8
    CALL SERIAL_PRINT_STRING

    LDN 10
    CALL SERIAL_PRINT_HEX
    LDI ' '
    CALL SERIAL_WRITE_CHAR
    INC 10
    LDN 10
    CALL SERIAL_PRINT_HEX
    CALL PRINT_CRLF
    DEC 10              ; Back to start of move

    ; =========================================
    ; Check R12 before save/restore
    ; =========================================
    LDI HIGH(STR_R12_PRE)
    PHI 8
    LDI LOW(STR_R12_PRE)
    PLO 8
    CALL SERIAL_PRINT_STRING
    GLO 12
    CALL SERIAL_PRINT_HEX
    CALL PRINT_CRLF

    ; =========================================
    ; Do the save/make/check/unmake/restore sequence
    ; =========================================
    LDI 0
    PLO 14              ; Legal count

    ; Get from/to
    LDA 10
    PLO 11
    LDA 10
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

    ; Print R12 before IS_IN_CHECK
    LDI HIGH(STR_R12_BEFORE)
    PHI 8
    LDI LOW(STR_R12_BEFORE)
    PLO 8
    CALL SERIAL_PRINT_STRING
    GLO 12
    CALL SERIAL_PRINT_HEX
    CALL PRINT_CRLF

    ; Call IS_IN_CHECK
    CALL IS_IN_CHECK
    PLO 13

    ; Print result
    LDI HIGH(STR_CHECK)
    PHI 8
    LDI LOW(STR_CHECK)
    PLO 8
    CALL SERIAL_PRINT_STRING
    GLO 13
    CALL SERIAL_PRINT_HEX
    CALL PRINT_CRLF

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

    ; Print R12 after
    LDI HIGH(STR_R12_AFTER)
    PHI 8
    LDI LOW(STR_R12_AFTER)
    PLO 8
    CALL SERIAL_PRINT_STRING
    GLO 12
    CALL SERIAL_PRINT_HEX
    CALL PRINT_CRLF

HALT:
    BR HALT

; ==============================================================================
; Helper functions
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

; ==============================================================================
; Include move generator
; ==============================================================================
#include "movegen-new.asm"

; ==============================================================================
; IS_IN_CHECK (simplified - orthogonal only for this test)
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

    LDI 0
    RETN

IIC_FOUND_KING:
    GLO 12
    XRI BLACK
    PLO 13              ; R13.0 = enemy color

    ; --- Check orthogonal attacks ---
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
    PHI 14              ; R14.1 = enemy rook

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
; Strings
; ==============================================================================
STR_BANNER:
    DB "Debug3: With GENERATE_MOVES", 0DH, 0AH, 0

STR_GEN:
    DB "Pseudo-legal: ", 0

STR_FIRST:
    DB "First move: ", 0

STR_R12_PRE:
    DB "R12 pre-save: ", 0

STR_R12_BEFORE:
    DB "R12 pre-IIC: ", 0

STR_R12_AFTER:
    DB "R12 post-restore: ", 0

STR_CHECK:
    DB "Check result: ", 0

STR_CRLF:
    DB 0DH, 0AH, 0

    END
