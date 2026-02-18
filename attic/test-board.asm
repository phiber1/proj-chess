; ==============================================================================
; Board Display Test
; ==============================================================================

    ORG $0000
    LBR MAIN

#include "serial-io.asm"
#include "board.asm"

; ==============================================================================
; Mark Abene SCRT implementation
; ==============================================================================
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
; Main program
; ==============================================================================
MAIN:
    LDI HIGH(START)
    PHI 6
    LDI LOW(START)
    PLO 6
    LBR INITCALL

START:
    ; Stack setup
    LDI $7F
    PHI 2
    LDI $FF
    PLO 2
    SEX 2

    REQ                 ; Q idle
    LDI 02H
    PLO 14              ; Baud rate

    ; Print welcome
    LDI HIGH(MSG_WELCOME)
    PHI 8
    LDI LOW(MSG_WELCOME)
    PLO 8
    SEP 4
    DW SERIAL_PRINT_STRING

    ; Initialize board
    SEP 4
    DW BOARD_INIT

    ; Print the board
    SEP 4
    DW BOARD_PRINT

    ; Print done
    LDI HIGH(MSG_DONE)
    PHI 8
    LDI LOW(MSG_DONE)
    PLO 8
    SEP 4
    DW SERIAL_PRINT_STRING

HALT:
    BR HALT

MSG_WELCOME:
    DB "1802 Chess Engine", 0DH, 0AH
    DB "Board Test", 0DH, 0AH, 0
MSG_DONE:
    DB 0DH, 0AH, "Board initialized.", 0DH, 0AH
    DB "UPPER=White, lower=black", 0DH, 0AH, 0

    END MAIN
