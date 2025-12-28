; ==============================================================================
; Step 3: Scan board and count white pieces (no move generation)
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

; Board definitions
BOARD       EQU $5000
GAME_STATE  EQU $5080

EMPTY       EQU $00
COLOR_MASK  EQU $08
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

    CALL INIT_BOARD

    LDI HIGH(STR_BOARD)
    PHI 8
    LDI LOW(STR_BOARD)
    PLO 8
    CALL SERIAL_PRINT_STRING

    ; Count white pieces
    CALL COUNT_WHITE_PIECES
    ; D = count

    CALL SERIAL_PRINT_HEX

    LDI HIGH(STR_PIECES)
    PHI 8
    LDI LOW(STR_PIECES)
    PLO 8
    CALL SERIAL_PRINT_STRING

HALT:
    BR HALT

; COUNT_WHITE_PIECES - Scan board, count pieces with color=WHITE
; Output: D = count (should be 16)
COUNT_WHITE_PIECES:
    LDI HIGH(BOARD)
    PHI 10
    LDI LOW(BOARD)
    PLO 10

    LDI 0
    PLO 14              ; E.0 = square index
    PLO 15              ; F.0 = piece count

SCAN_LOOP:
    ; Check if valid square
    GLO 14
    ANI $88
    BNZ SCAN_SKIP

    ; Get piece
    LDN 10
    BZ SCAN_SKIP        ; Empty

    ; Check if white (bit 3 = 0)
    ANI COLOR_MASK
    BNZ SCAN_SKIP       ; Black piece

    ; White piece - increment count
    INC 15

SCAN_SKIP:
    INC 10
    INC 14
    GLO 14
    ANI $80
    BZ SCAN_LOOP

    ; Return count
    GLO 15
    RETN

; INIT_BOARD - same as step 2
INIT_BOARD:
    LDI HIGH(BOARD)
    PHI 10
    LDI LOW(BOARD)
    PLO 10
    LDI 128
    PLO 13
IB_CLEAR:
    LDI EMPTY           ; Must reload EMPTY each iteration!
    STR 10
    INC 10
    DEC 13
    GLO 13
    BNZ IB_CLEAR

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

    LDI HIGH(BOARD)
    PHI 10
    LDI LOW(BOARD + $10)
    PLO 10
    LDI 8
    PLO 13
IB_WP:
    LDI W_PAWN          ; Reload each iteration!
    STR 10
    INC 10
    DEC 13
    GLO 13
    BNZ IB_WP

    LDI HIGH(BOARD)
    PHI 10
    LDI LOW(BOARD + $60)
    PLO 10
    LDI 8
    PLO 13
IB_BP:
    LDI B_PAWN          ; Reload each iteration!
    STR 10
    INC 10
    DEC 13
    GLO 13
    BNZ IB_BP

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
    DB "Step3: Count pieces", 0DH, 0AH, 0

STR_BOARD:
    DB "Board initialized", 0DH, 0AH, 0

STR_PIECES:
    DB " white pieces", 0DH, 0AH, 0

    END
