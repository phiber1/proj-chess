; ==============================================================================
; Minimal Move Generator Test
; Just generate king moves and print count - no fancy stuff
; ==============================================================================

    ORG $0000
    LBR MAIN

#include "serial-io.asm"

; SCRT
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

; Constants
BOARD       EQU $5000
MOVELIST    EQU $5100
W_KING      EQU $06
SQ_E1       EQU $04
DIR_E       EQU $01

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

    ; Clear board (just first 128 bytes)
    LDI HIGH(BOARD)
    PHI 10
    LDI LOW(BOARD)
    PLO 10
    LDI 128
    PLO 14
CLEAR:
    LDI 0
    STR 10
    INC 10
    DEC 14
    GLO 14
    BNZ CLEAR

    ; Place king at e1
    LDI HIGH(BOARD)
    PHI 10
    LDI SQ_E1
    PLO 10
    LDI W_KING
    STR 10

    ; Print "King at e1"
    LDI HIGH(STR_KING)
    PHI 8
    LDI LOW(STR_KING)
    PLO 8
    CALL SERIAL_PRINT_STRING

    ; Now manually generate ONE king move: e1-f1 (04-05)
    ; Store directly to MOVELIST without calling any function
    LDI HIGH(MOVELIST)
    PHI 10
    LDI LOW(MOVELIST)
    PLO 10
    LDI SQ_E1           ; from = e1 = $04
    STR 10
    INC 10
    LDI SQ_E1
    ADI DIR_E           ; to = f1 = $05
    STR 10
    INC 10
    LDI $FF             ; terminator
    STR 10

    ; Print "Move: "
    LDI HIGH(STR_MOVE)
    PHI 8
    LDI LOW(STR_MOVE)
    PLO 8
    CALL SERIAL_PRINT_STRING

    ; Print the move from memory
    ; Load from square
    LDI HIGH(MOVELIST)
    PHI 10
    LDI LOW(MOVELIST)
    PLO 10
    LDN 10
    CALL SERIAL_PRINT_HEX

    LDI '-'
    CALL SERIAL_WRITE_CHAR

    ; Load to square
    LDI HIGH(MOVELIST)
    PHI 10
    LDI LOW(MOVELIST+1)
    PLO 10
    LDN 10
    CALL SERIAL_PRINT_HEX

    ; Newline
    LDI HIGH(STR_CRLF)
    PHI 8
    LDI LOW(STR_CRLF)
    PLO 8
    CALL SERIAL_PRINT_STRING

    ; Print done
    LDI HIGH(STR_DONE)
    PHI 8
    LDI LOW(STR_DONE)
    PLO 8
    CALL SERIAL_PRINT_STRING

HALT:
    BR HALT

STR_BANNER:
    DB "Minimal MoveGen Test", 0DH, 0AH, 0

STR_KING:
    DB "King at e1", 0DH, 0AH, 0

STR_MOVE:
    DB "Move: ", 0

STR_DONE:
    DB "Done!", 0DH, 0AH, 0

STR_CRLF:
    DB 0DH, 0AH, 0

    END
