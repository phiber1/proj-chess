; ==============================================================================
; Debug Test 15: Fix MAKE/UNMAKE to use memory instead of R7
; R7 is clobbered by SCRT CALL/RETN!
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

; Piece storage for make/unmake (replacing R7)
MOVE_PIECE  EQU $5090   ; The piece being moved
CAPT_PIECE  EQU $5091   ; The piece being captured (if any)

EMPTY       EQU $00
WHITE       EQU $00
BLACK       EQU $08
W_KING      EQU $06
B_QUEEN     EQU $0D
B_KING      EQU $0E

SQ_E1       EQU $04
SQ_D1       EQU $03
SQ_F1       EQU $05
SQ_E8       EQU $74

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
    LDI $FF
    STR 10

    LDI WHITE
    PLO 12

    ; === E1 before ===
    LDI HIGH(STR_BEFORE)
    PHI 8
    LDI LOW(STR_BEFORE)
    PLO 8
    CALL SERIAL_PRINT_STRING
    CALL PRINT_E1

    ; === ITERATION 1: Kd1 ===
    LDI HIGH(STR_ITER1)
    PHI 8
    LDI LOW(STR_ITER1)
    PLO 8
    CALL SERIAL_PRINT_STRING

    LDI SQ_E1
    PLO 11
    LDI SQ_D1
    PHI 11

    CALL MAKE_MOVE_MEM

    LDI HIGH(STR_AFTER_MAKE)
    PHI 8
    LDI LOW(STR_AFTER_MAKE)
    PLO 8
    CALL SERIAL_PRINT_STRING
    CALL PRINT_E1

    ; Need to restore R11 since serial clobbered it
    LDI SQ_E1
    PLO 11
    LDI SQ_D1
    PHI 11

    CALL UNMAKE_MOVE_MEM

    LDI HIGH(STR_AFTER_UNMAKE)
    PHI 8
    LDI LOW(STR_AFTER_UNMAKE)
    PLO 8
    CALL SERIAL_PRINT_STRING
    CALL PRINT_E1

    ; === ITERATION 2: Kf1 ===
    LDI HIGH(STR_ITER2)
    PHI 8
    LDI LOW(STR_ITER2)
    PLO 8
    CALL SERIAL_PRINT_STRING

    LDI SQ_E1
    PLO 11
    LDI SQ_F1
    PHI 11

    CALL MAKE_MOVE_MEM

    LDI HIGH(STR_AFTER_MAKE)
    PHI 8
    LDI LOW(STR_AFTER_MAKE)
    PLO 8
    CALL SERIAL_PRINT_STRING
    CALL PRINT_E1

    LDI SQ_E1
    PLO 11
    LDI SQ_F1
    PHI 11

    CALL UNMAKE_MOVE_MEM

    LDI HIGH(STR_AFTER_UNMAKE)
    PHI 8
    LDI LOW(STR_AFTER_UNMAKE)
    PLO 8
    CALL SERIAL_PRINT_STRING
    CALL PRINT_E1

    LDI HIGH(STR_DONE)
    PHI 8
    LDI LOW(STR_DONE)
    PLO 8
    CALL SERIAL_PRINT_STRING

HALT:
    BR HALT

; ==============================================================================
PRINT_E1:
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

; ==============================================================================
; MAKE_MOVE_MEM - Uses memory for piece storage instead of R7
; Input: R11.0 = from, R11.1 = to
; Saves pieces to MOVE_PIECE, CAPT_PIECE
; ==============================================================================
MAKE_MOVE_MEM:
    LDI HIGH(BOARD)
    PHI 8
    GLO 11              ; from
    PLO 8
    LDN 8               ; piece at from
    STR 2               ; temp save to stack top

    ; Save moving piece to memory
    LDI HIGH(MOVE_PIECE)
    PHI 10
    LDI LOW(MOVE_PIECE)
    PLO 10
    LDX                 ; get piece back (doesn't change SP)
    STR 10              ; MOVE_PIECE = moving piece

    ; Get captured piece
    LDI HIGH(BOARD)
    PHI 8
    GHI 11              ; to
    PLO 8
    LDN 8               ; piece at to (captured)
    INC 10              ; point to CAPT_PIECE
    STR 10              ; CAPT_PIECE = captured piece

    ; Move the piece
    LDI LOW(MOVE_PIECE)
    PLO 10
    LDN 10              ; get moving piece
    LDI HIGH(BOARD)
    PHI 8
    GHI 11              ; to
    PLO 8
    STR 8               ; board[to] = moving piece

    ; Clear from square
    GLO 11              ; from
    PLO 8
    LDI EMPTY
    STR 8

    RETN

; ==============================================================================
; UNMAKE_MOVE_MEM - Uses memory for piece storage
; Input: R11.0 = from, R11.1 = to
; Reads pieces from MOVE_PIECE, CAPT_PIECE
; ==============================================================================
UNMAKE_MOVE_MEM:
    ; Setup board pointer high byte
    LDI HIGH(BOARD)
    PHI 8

    ; Set R8 to board[from] first
    GLO 11              ; D = from
    PLO 8               ; R8 = BOARD + from

    ; Load moving piece and store to from square
    LDI HIGH(MOVE_PIECE)
    PHI 10
    LDI LOW(MOVE_PIECE)
    PLO 10
    LDN 10              ; D = moving piece
    STR 8               ; board[from] = moving piece

    ; Set R8 to board[to]
    GHI 11              ; D = to
    PLO 8               ; R8 = BOARD + to

    ; Load captured piece and store to to square
    INC 10              ; R10 points to CAPT_PIECE
    LDN 10              ; D = captured piece
    STR 8               ; board[to] = captured piece

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
    DB "Debug15: Memory-based make/unmake", 0DH, 0AH, 0

STR_BEFORE:
    DB "E1 before: ", 0

STR_ITER1:
    DB "=== Iter1 Kd1 ===", 0DH, 0AH, 0

STR_ITER2:
    DB "=== Iter2 Kf1 ===", 0DH, 0AH, 0

STR_AFTER_MAKE:
    DB "After make: ", 0

STR_AFTER_UNMAKE:
    DB "After unmake: ", 0

STR_DONE:
    DB "Done", 0DH, 0AH, 0

STR_CRLF:
    DB 0DH, 0AH, 0

    END
