; ==============================================================================
; Debug Test 14: Save R7 to memory, not stack
; The SCRT CALL uses PLO 7, clobbering R7.0!
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
    PLO 7               ; <-- THIS CLOBBERS R7.0!
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

; Safe storage for R7 during iteration
SAVE_R7_LO  EQU $5400
SAVE_R7_HI  EQU $5401

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

    ; === Check E1 before ===
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

    ; Set move
    LDI SQ_E1
    PLO 11
    LDI SQ_D1
    PHI 11

    ; Save R11 to stack (this is fine, no CALLs between save/restore)
    GHI 11
    STXD
    GLO 11
    STXD

    ; MAKE_MOVE
    CALL MAKE_MOVE

    ; Save R7 to MEMORY (not stack!) because CALLs will clobber R7.0
    LDI HIGH(SAVE_R7_LO)
    PHI 10
    LDI LOW(SAVE_R7_LO)
    PLO 10
    GLO 7
    STR 10
    INC 10
    GHI 7
    STR 10

    ; Now we can safely print
    LDI HIGH(STR_AFTER_MAKE)
    PHI 8
    LDI LOW(STR_AFTER_MAKE)
    PLO 8
    CALL SERIAL_PRINT_STRING
    CALL PRINT_E1

    ; Restore R7 from MEMORY
    LDI HIGH(SAVE_R7_LO)
    PHI 10
    LDI LOW(SAVE_R7_LO)
    PLO 10
    LDA 10
    PLO 7
    LDN 10
    PHI 7

    ; Restore R11 from stack
    IRX
    LDXA
    PLO 11
    LDX
    PHI 11

    ; UNMAKE
    CALL UNMAKE_MOVE

    ; Print after unmake
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

    ; Set move
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

    ; Save R7 to MEMORY
    LDI HIGH(SAVE_R7_LO)
    PHI 10
    LDI LOW(SAVE_R7_LO)
    PLO 10
    GLO 7
    STR 10
    INC 10
    GHI 7
    STR 10

    ; Print
    LDI HIGH(STR_AFTER_MAKE)
    PHI 8
    LDI LOW(STR_AFTER_MAKE)
    PLO 8
    CALL SERIAL_PRINT_STRING
    CALL PRINT_E1

    ; Restore R7 from MEMORY
    LDI HIGH(SAVE_R7_LO)
    PHI 10
    LDI LOW(SAVE_R7_LO)
    PLO 10
    LDA 10
    PLO 7
    LDN 10
    PHI 7

    ; Restore R11
    IRX
    LDXA
    PLO 11
    LDX
    PHI 11

    ; UNMAKE
    CALL UNMAKE_MOVE

    ; Print
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
    DB "Debug14: R7 to memory", 0DH, 0AH, 0

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
