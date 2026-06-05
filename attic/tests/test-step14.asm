; ==============================================================================
; Step 14: Material Evaluation
; Scans board, sums piece values for each side
; Returns score in centipawns (positive = white ahead)
; ==============================================================================
;
; Piece values (centipawns):
;   Pawn   = 100 ($0064)
;   Knight = 320 ($0140)
;   Bishop = 330 ($014A)
;   Rook   = 500 ($01F4)
;   Queen  = 900 ($0384)
;   King   = 0   ($0000)
;
; Test cases:
; 1. Starting position - score = 0 (equal material)
; 2. White up a pawn - score = +100 ($0064)
; 3. White up a queen - score = +900 ($0384)
; 4. Black up a rook - score = -500 ($FE0C in 2's complement)
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
SCORE_LO    EQU $5088       ; 16-bit score storage
SCORE_HI    EQU $5089

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
    ; Test 1: Starting position (equal material)
    ; Expected: 0000
    ; =========================================
    LDI HIGH(STR_TEST1)
    PHI 8
    LDI LOW(STR_TEST1)
    PLO 8
    CALL SERIAL_PRINT_STRING

    CALL CLEAR_BOARD
    CALL SETUP_START_POS

    CALL EVALUATE_MATERIAL
    ; Result in SCORE_HI:SCORE_LO
    CALL PRINT_SCORE
    CALL PRINT_CRLF

    ; =========================================
    ; Test 2: White up a pawn (+100 = $0064)
    ; =========================================
    LDI HIGH(STR_TEST2)
    PHI 8
    LDI LOW(STR_TEST2)
    PLO 8
    CALL SERIAL_PRINT_STRING

    CALL CLEAR_BOARD
    CALL SETUP_START_POS

    ; Remove black pawn from d7
    LDI HIGH(BOARD)
    PHI 10
    LDI $63             ; d7
    PLO 10
    LDI EMPTY
    STR 10

    CALL EVALUATE_MATERIAL
    CALL PRINT_SCORE
    CALL PRINT_CRLF

    ; =========================================
    ; Test 3: White up a queen (+900 = $0384)
    ; =========================================
    LDI HIGH(STR_TEST3)
    PHI 8
    LDI LOW(STR_TEST3)
    PLO 8
    CALL SERIAL_PRINT_STRING

    CALL CLEAR_BOARD
    CALL SETUP_START_POS

    ; Remove black queen from d8
    LDI HIGH(BOARD)
    PHI 10
    LDI $73             ; d8
    PLO 10
    LDI EMPTY
    STR 10

    CALL EVALUATE_MATERIAL
    CALL PRINT_SCORE
    CALL PRINT_CRLF

    ; =========================================
    ; Test 4: Black up a rook (-500 = $FE0C)
    ; =========================================
    LDI HIGH(STR_TEST4)
    PHI 8
    LDI LOW(STR_TEST4)
    PLO 8
    CALL SERIAL_PRINT_STRING

    CALL CLEAR_BOARD
    CALL SETUP_START_POS

    ; Remove white rook from h1
    LDI HIGH(BOARD)
    PHI 10
    LDI $07             ; h1
    PLO 10
    LDI EMPTY
    STR 10

    CALL EVALUATE_MATERIAL
    CALL PRINT_SCORE
    CALL PRINT_CRLF

HALT:
    BR HALT

; ==============================================================================
; EVALUATE_MATERIAL - Calculate material score
; Output: SCORE_HI:SCORE_LO = 16-bit signed score (centipawns)
; ==============================================================================
EVALUATE_MATERIAL:
    SEX 2               ; Ensure X=2 for ADD/SD operations

    ; Initialize score to 0
    LDI HIGH(SCORE_LO)
    PHI 10
    LDI LOW(SCORE_LO)
    PLO 10
    LDI 0
    STR 10
    INC 10
    STR 10              ; SCORE_HI = 0

    ; Set up board scan
    LDI HIGH(BOARD)
    PHI 11
    LDI LOW(BOARD)
    PLO 11              ; R11 = board pointer

    LDI 0
    PLO 13              ; R13.0 = square index

EM_LOOP:
    ; Check if on board (0x88 test)
    GLO 13
    ANI $88
    LBNZ EM_NEXT_RANK

    ; Get piece at this square
    LDN 11
    LBZ EM_NEXT_SQ      ; Empty square, skip

    ; Got a piece - save it
    PLO 14              ; R14.0 = piece code

    ; Get piece type (mask off color)
    ANI PIECE_MASK
    PLO 12              ; R12.0 = piece type (1-6)

    ; Look up value in table (each entry is 2 bytes)
    ; Index = (piece_type - 1) * 2
    SMI 1               ; piece_type - 1
    SHL                 ; * 2
    STR 2               ; Save offset

    LDI LOW(PIECE_VALUES)
    ADD                 ; Add offset
    PLO 8
    LDI HIGH(PIECE_VALUES)
    ADCI 0              ; Add carry
    PHI 8               ; R8 = pointer to value

    ; Load 16-bit value (DW is big-endian: high byte first)
    LDA 8
    PHI 15              ; R15.1 = value high
    LDN 8
    PLO 15              ; R15.0 = value low

    ; Check piece color
    GLO 14              ; Get piece code back
    ANI COLOR_MASK
    LBNZ EM_SUBTRACT    ; Black piece - subtract

EM_ADD:
    ; White piece - add value to score
    ; SCORE += R15
    LDI HIGH(SCORE_LO)
    PHI 10
    LDI LOW(SCORE_LO)
    PLO 10

    LDN 10              ; Get SCORE_LO
    STR 2
    GLO 15              ; Value low
    ADD
    STR 10              ; Store new SCORE_LO
    INC 10

    LDN 10              ; Get SCORE_HI
    ADCI 0              ; Add carry
    STR 2
    GHI 15              ; Value high
    ADD
    STR 10              ; Store new SCORE_HI

    LBR EM_NEXT_SQ

EM_SUBTRACT:
    ; Black piece - subtract value from score
    ; SCORE -= R15
    LDI HIGH(SCORE_LO)
    PHI 10
    LDI LOW(SCORE_LO)
    PLO 10

    LDN 10              ; Get SCORE_LO
    STR 2
    GLO 15              ; Value low
    SD                  ; SCORE_LO - value_low
    STR 10              ; Store new SCORE_LO
    INC 10

    LDN 10              ; Get SCORE_HI
    SMBI 0              ; Subtract borrow
    STR 2
    GHI 15              ; Value high
    SD                  ; (SCORE_HI - borrow) - value_high
    STR 10              ; Store new SCORE_HI

    LBR EM_NEXT_SQ

EM_NEXT_SQ:
    INC 11              ; Next board position
    INC 13              ; Next square index
    GLO 13
    ANI $80
    LBZ EM_LOOP         ; Continue if index < 128
    RETN

EM_NEXT_RANK:
    ; Add 8 to skip invalid squares (go from $x8 to $x0+$10)
    GLO 13
    ADI 8
    PLO 13
    ANI $80             ; Check if we've passed row 7
    LBNZ EM_DONE        ; If >= $80, we're done
    GLO 11
    ADI 8
    PLO 11
    GHI 11
    ADCI 0
    PHI 11
    LBR EM_LOOP

EM_DONE:
    RETN

; ==============================================================================
; PRINT_SCORE - Print 16-bit score as 4 hex digits
; ==============================================================================
PRINT_SCORE:
    LDI HIGH(SCORE_HI)
    PHI 10
    LDI LOW(SCORE_HI)
    PLO 10
    LDN 10
    CALL SERIAL_PRINT_HEX

    LDI HIGH(SCORE_LO)
    PHI 10
    LDI LOW(SCORE_LO)
    PLO 10
    LDN 10
    CALL SERIAL_PRINT_HEX

    RETN

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
; SETUP_START_POS - Set up standard starting position
; ==============================================================================
SETUP_START_POS:
    LDI HIGH(BOARD)
    PHI 10

    ; White pieces - rank 1
    LDI $00             ; a1
    PLO 10
    LDI W_ROOK
    STR 10

    LDI $01             ; b1
    PLO 10
    LDI W_KNIGHT
    STR 10

    LDI $02             ; c1
    PLO 10
    LDI W_BISHOP
    STR 10

    LDI $03             ; d1
    PLO 10
    LDI W_QUEEN
    STR 10

    LDI $04             ; e1
    PLO 10
    LDI W_KING
    STR 10

    LDI $05             ; f1
    PLO 10
    LDI W_BISHOP
    STR 10

    LDI $06             ; g1
    PLO 10
    LDI W_KNIGHT
    STR 10

    LDI $07             ; h1
    PLO 10
    LDI W_ROOK
    STR 10

    ; White pawns - rank 2
    LDI $10             ; a2
    PLO 10
    LDI 8
    PLO 13              ; Counter
SSP_WP:
    LDI W_PAWN
    STR 10
    INC 10
    DEC 13
    GLO 13
    LBNZ SSP_WP

    ; Black pieces - rank 8
    LDI $70             ; a8
    PLO 10
    LDI B_ROOK
    STR 10

    LDI $71             ; b8
    PLO 10
    LDI B_KNIGHT
    STR 10

    LDI $72             ; c8
    PLO 10
    LDI B_BISHOP
    STR 10

    LDI $73             ; d8
    PLO 10
    LDI B_QUEEN
    STR 10

    LDI $74             ; e8
    PLO 10
    LDI B_KING
    STR 10

    LDI $75             ; f8
    PLO 10
    LDI B_BISHOP
    STR 10

    LDI $76             ; g8
    PLO 10
    LDI B_KNIGHT
    STR 10

    LDI $77             ; h8
    PLO 10
    LDI B_ROOK
    STR 10

    ; Black pawns - rank 7
    LDI $60             ; a7
    PLO 10
    LDI 8
    PLO 13              ; Counter
SSP_BP:
    LDI B_PAWN
    STR 10
    INC 10
    DEC 13
    GLO 13
    LBNZ SSP_BP

    RETN

; ==============================================================================
; Piece Value Table (16-bit, low byte first)
; Index by piece type - 1 (so pawn=0, knight=1, etc.)
; ==============================================================================
PIECE_VALUES:
    DW $0064            ; Pawn   = 100
    DW $0140            ; Knight = 320
    DW $014A            ; Bishop = 330
    DW $01F4            ; Rook   = 500
    DW $0384            ; Queen  = 900
    DW $0000            ; King   = 0

; ==============================================================================
; Strings
; ==============================================================================
STR_BANNER:
    DB "Step14: Material evaluation", 0DH, 0AH, 0

STR_TEST1:
    DB "Start pos: ", 0

STR_TEST2:
    DB "White +pawn: ", 0

STR_TEST3:
    DB "White +queen: ", 0

STR_TEST4:
    DB "Black +rook: ", 0

STR_CRLF:
    DB 0DH, 0AH, 0

    END
