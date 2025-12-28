; ==============================================================================
; Step 12: Check Detection
; Tests IS_IN_CHECK function - determines if a king is under attack
; ==============================================================================
;
; Test cases:
; 1. Starting position - white king NOT in check (expect 00)
; 2. White king e1, black rook e8 - IN check (expect 01)
; 3. White king e4, black knight f6 - IN check (expect 01)
; 4. White king d4, black bishop h8 - IN check (expect 01)
; 5. White king d4, black pawn e5 - IN check (expect 01)
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

; Directions
DIR_N       EQU $F0     ; -16
DIR_S       EQU $10     ; +16
DIR_E       EQU $01
DIR_W       EQU $FF
DIR_NE      EQU $F1     ; -15
DIR_NW      EQU $EF     ; -17
DIR_SE      EQU $11     ; +17
DIR_SW      EQU $0F     ; +15

; Squares
SQ_E1       EQU $04
SQ_E4       EQU $34
SQ_D4       EQU $33
SQ_E5       EQU $44
SQ_F6       EQU $55
SQ_E8       EQU $74
SQ_H8       EQU $77

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
    ; Test 1: Starting position (not in check)
    ; =========================================
    LDI HIGH(STR_TEST1)
    PHI 8
    LDI LOW(STR_TEST1)
    PLO 8
    CALL SERIAL_PRINT_STRING

    CALL CLEAR_BOARD
    CALL SETUP_START_POS

    LDI WHITE
    PLO 12
    CALL IS_IN_CHECK

    CALL SERIAL_PRINT_HEX
    CALL PRINT_CRLF

    ; =========================================
    ; Test 2: White king e1, black rook e8 (rook check)
    ; =========================================
    LDI HIGH(STR_TEST2)
    PHI 8
    LDI LOW(STR_TEST2)
    PLO 8
    CALL SERIAL_PRINT_STRING

    CALL CLEAR_BOARD

    ; Place white king on e1
    LDI HIGH(BOARD)
    PHI 10
    LDI SQ_E1
    PLO 10
    LDI W_KING
    STR 10

    ; Place black rook on e8
    LDI SQ_E8
    PLO 10
    LDI B_ROOK
    STR 10

    LDI WHITE
    PLO 12
    CALL IS_IN_CHECK

    CALL SERIAL_PRINT_HEX
    CALL PRINT_CRLF

    ; =========================================
    ; Test 3: White king e4, black knight f6 (knight check)
    ; =========================================
    LDI HIGH(STR_TEST3)
    PHI 8
    LDI LOW(STR_TEST3)
    PLO 8
    CALL SERIAL_PRINT_STRING

    CALL CLEAR_BOARD

    ; Place white king on e4
    LDI HIGH(BOARD)
    PHI 10
    LDI SQ_E4
    PLO 10
    LDI W_KING
    STR 10

    ; Place black knight on f6
    LDI SQ_F6
    PLO 10
    LDI B_KNIGHT
    STR 10

    LDI WHITE
    PLO 12
    CALL IS_IN_CHECK

    CALL SERIAL_PRINT_HEX
    CALL PRINT_CRLF

    ; =========================================
    ; Test 4: White king d4, black bishop h8 (bishop check)
    ; =========================================
    LDI HIGH(STR_TEST4)
    PHI 8
    LDI LOW(STR_TEST4)
    PLO 8
    CALL SERIAL_PRINT_STRING

    CALL CLEAR_BOARD

    ; Place white king on d4
    LDI HIGH(BOARD)
    PHI 10
    LDI SQ_D4
    PLO 10
    LDI W_KING
    STR 10

    ; Place black bishop on h8
    LDI SQ_H8
    PLO 10
    LDI B_BISHOP
    STR 10

    LDI WHITE
    PLO 12
    CALL IS_IN_CHECK

    CALL SERIAL_PRINT_HEX
    CALL PRINT_CRLF

    ; =========================================
    ; Test 5: White king d4, black pawn e5 (pawn check)
    ; =========================================
    LDI HIGH(STR_TEST5)
    PHI 8
    LDI LOW(STR_TEST5)
    PLO 8
    CALL SERIAL_PRINT_STRING

    CALL CLEAR_BOARD

    ; Place white king on d4
    LDI HIGH(BOARD)
    PHI 10
    LDI SQ_D4
    PLO 10
    LDI W_KING
    STR 10

    ; Place black pawn on e5
    LDI SQ_E5
    PLO 10
    LDI B_PAWN
    STR 10

    LDI WHITE
    PLO 12
    CALL IS_IN_CHECK

    CALL SERIAL_PRINT_HEX
    CALL PRINT_CRLF

HALT:
    BR HALT

; ==============================================================================
; PRINT_CRLF - Print carriage return + line feed
; ==============================================================================
PRINT_CRLF:
    LDI HIGH(STR_CRLF)
    PHI 8
    LDI LOW(STR_CRLF)
    PLO 8
    CALL SERIAL_PRINT_STRING
    RETN

; ==============================================================================
; IS_IN_CHECK - Check if the given side's king is under attack
; ==============================================================================
; Input:  R12.0 = side to check (0=WHITE, 8=BLACK)
; Output: D = 1 if in check, 0 if not
; Clobbers: R7, R8, R10, R11, R13, R14
; ==============================================================================
IS_IN_CHECK:
    ; First, find the king
    LDI HIGH(BOARD)
    PHI 10
    LDI LOW(BOARD)
    PLO 10

    ; King piece code = 6 + side color
    LDI 6
    STR 2
    GLO 12
    ADD                 ; D = W_KING (6) or B_KING (14)
    PLO 14              ; R14.0 = king piece code to find

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

    ; King not found - shouldn't happen, return 0
    LDI 0
    RETN

IIC_FOUND_KING:
    ; R11.0 = king's square
    ; Now check for attacks from enemy pieces

    ; Calculate enemy color
    GLO 12
    XRI BLACK           ; Toggle color: WHITE->BLACK, BLACK->WHITE
    PLO 13              ; R13.0 = enemy color

    ; --- Check pawn attacks ---
    ; Pawns attack diagonally. If we're checking WHITE king,
    ; enemy BLACK pawns attack from squares NW and NE of king
    ; If checking BLACK king, enemy WHITE pawns attack from SW and SE

    GLO 12
    LBNZ IIC_PAWN_BLACK_KING

IIC_PAWN_WHITE_KING:
    ; White king - check for black pawns at SE and SW of king
    ; (Black pawns attack northward, so attacker is south of king)
    GLO 11
    ADI DIR_SE          ; king + SE
    PLO 14
    ANI $88
    LBNZ IIC_PAWN_SW

    LDI HIGH(BOARD)
    PHI 7
    GLO 14
    PLO 7
    LDN 7
    SMI B_PAWN
    LBZ IIC_IN_CHECK

IIC_PAWN_SW:
    GLO 11
    ADI DIR_SW          ; king + SW
    PLO 14
    ANI $88
    LBNZ IIC_CHECK_KNIGHTS

    LDI HIGH(BOARD)
    PHI 7
    GLO 14
    PLO 7
    LDN 7
    SMI B_PAWN
    LBZ IIC_IN_CHECK
    LBR IIC_CHECK_KNIGHTS

IIC_PAWN_BLACK_KING:
    ; Black king - check for white pawns at NE and NW of king
    ; (White pawns attack southward, so attacker is north of king)
    GLO 11
    ADI DIR_NE          ; king + NE
    PLO 14
    ANI $88
    LBNZ IIC_PAWN_NW

    LDI HIGH(BOARD)
    PHI 7
    GLO 14
    PLO 7
    LDN 7
    SMI W_PAWN
    LBZ IIC_IN_CHECK

IIC_PAWN_NW:
    GLO 11
    ADI DIR_NW          ; king + NW
    PLO 14
    ANI $88
    LBNZ IIC_CHECK_KNIGHTS

    LDI HIGH(BOARD)
    PHI 7
    GLO 14
    PLO 7
    LDN 7
    SMI W_PAWN
    LBZ IIC_IN_CHECK

    ; --- Check knight attacks ---
IIC_CHECK_KNIGHTS:
    LDI HIGH(KNIGHT_OFFSETS)
    PHI 8
    LDI LOW(KNIGHT_OFFSETS)
    PLO 8

    LDI 8
    PLO 14              ; Loop counter

    ; Enemy knight = 2 + enemy color
    LDI 2
    STR 2
    GLO 13              ; Enemy color
    ADD
    PHI 14              ; R14.1 = enemy knight piece code

IIC_KN_LOOP:
    LDN 8
    STR 2
    GLO 11              ; King square
    ADD
    PLO 7               ; Target square

    ANI $88
    LBNZ IIC_KN_NEXT

    LDI HIGH(BOARD)
    PHI 7
    LDN 7
    STR 2
    GHI 14              ; Enemy knight code
    SM
    LBZ IIC_IN_CHECK

IIC_KN_NEXT:
    INC 8
    DEC 14
    GLO 14
    LBNZ IIC_KN_LOOP

    ; --- Check diagonal attacks (bishop/queen) ---
    LDI HIGH(BISHOP_DIRS)
    PHI 8
    LDI LOW(BISHOP_DIRS)
    PLO 8

    LDI 4
    PLO 14

    ; Enemy bishop = 3 + enemy color, enemy queen = 5 + enemy color
    LDI 3
    STR 2
    GLO 13
    ADD
    PHI 14              ; R14.1 = enemy bishop

IIC_DIAG_DIR:
    LDN 8
    PHI 13              ; R13.1 = direction (R13.0 = enemy color, still valid)

    GLO 11              ; Start from king square
    PLO 7

IIC_DIAG_RAY:
    GLO 7
    STR 2
    GHI 13
    ADD
    PLO 7

    ANI $88
    LBNZ IIC_DIAG_NEXT

    LDI HIGH(BOARD)
    PHI 10
    GLO 7
    PLO 10
    LDN 10
    LBZ IIC_DIAG_RAY    ; Empty, continue ray

    ; Piece found - check if enemy bishop or queen
    PLO 10              ; Save piece temporarily
    STR 2
    GHI 14              ; Enemy bishop
    SM
    LBZ IIC_IN_CHECK

    ; Check for queen (bishop + 2)
    GHI 14
    ADI 2               ; Enemy queen = enemy bishop + 2
    STR 2
    GLO 10              ; Restore piece
    SM
    LBZ IIC_IN_CHECK

    ; Blocked by other piece, try next direction
    LBR IIC_DIAG_NEXT

IIC_DIAG_NEXT:
    INC 8
    DEC 14
    GLO 14
    LBNZ IIC_DIAG_DIR

    ; --- Check orthogonal attacks (rook/queen) ---
    LDI HIGH(ROOK_DIRS)
    PHI 8
    LDI LOW(ROOK_DIRS)
    PLO 8

    LDI 4
    PLO 14

    ; Enemy rook = 4 + enemy color
    LDI 4
    STR 2
    GLO 13
    ADD
    PHI 14              ; R14.1 = enemy rook

IIC_ORTH_DIR:
    LDN 8
    PHI 13              ; R13.1 = direction

    GLO 11              ; Start from king square
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
    LBZ IIC_ORTH_RAY    ; Empty, continue ray

    ; Piece found - check if enemy rook or queen
    PLO 10              ; Save piece
    STR 2
    GHI 14              ; Enemy rook
    SM
    LBZ IIC_IN_CHECK

    ; Check for queen (rook + 1)
    GHI 14
    ADI 1               ; Enemy queen = enemy rook + 1
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

    ; --- Check king attacks (adjacent squares) ---
    LDI HIGH(KING_OFFSETS)
    PHI 8
    LDI LOW(KING_OFFSETS)
    PLO 8

    LDI 8
    PLO 14

    ; Enemy king = 6 + enemy color
    LDI 6
    STR 2
    GLO 13
    ADD
    PHI 14              ; R14.1 = enemy king

IIC_KI_LOOP:
    LDN 8
    STR 2
    GLO 11
    ADD
    PLO 7

    ANI $88
    LBNZ IIC_KI_NEXT

    LDI HIGH(BOARD)
    PHI 7
    LDN 7
    STR 2
    GHI 14
    SM
    LBZ IIC_IN_CHECK

IIC_KI_NEXT:
    INC 8
    DEC 14
    GLO 14
    LBNZ IIC_KI_LOOP

    ; No attacks found
    LDI 0
    RETN

IIC_IN_CHECK:
    LDI 1
    RETN

; ==============================================================================
; CLEAR_BOARD - Clear all squares to EMPTY
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
; SETUP_START_POS - Set up starting position (simplified - just kings)
; For full test, we need both kings to avoid "king not found"
; ==============================================================================
SETUP_START_POS:
    LDI HIGH(BOARD)
    PHI 10

    ; White king on e1
    LDI SQ_E1
    PLO 10
    LDI W_KING
    STR 10

    ; Black king on e8
    LDI SQ_E8
    PLO 10
    LDI B_KING
    STR 10

    ; Add some pawns to block
    LDI $14             ; e2
    PLO 10
    LDI W_PAWN
    STR 10

    LDI $64             ; e7
    PLO 10
    LDI B_PAWN
    STR 10

    RETN

; ==============================================================================
; Data Tables
; ==============================================================================
KNIGHT_OFFSETS:
    DB $DF, $E1, $EE, $F2, $0E, $12, $1F, $21

KING_OFFSETS:
    DB $EF, $F0, $F1, $FF, $01, $0F, $10, $11

BISHOP_DIRS:
    DB $EF, $F1, $0F, $11

ROOK_DIRS:
    DB $F0, $10, $FF, $01

; ==============================================================================
; Strings
; ==============================================================================
STR_BANNER:
    DB "Step12: Check detection", 0DH, 0AH, 0

STR_TEST1:
    DB "Start pos: ", 0

STR_TEST2:
    DB "Rook check: ", 0

STR_TEST3:
    DB "Knight check: ", 0

STR_TEST4:
    DB "Bishop check: ", 0

STR_TEST5:
    DB "Pawn check: ", 0

STR_CRLF:
    DB 0DH, 0AH, 0

    END
