; ==============================================================================
; Minimal SCRT + Serial Test - Using Friday's working pattern exactly
; ==============================================================================

    ORG $0000
    LBR MAIN

#include "serial-io.asm"

; ==============================================================================
; Mark Abene's SCRT implementation (uses R7 for D, not R14!)
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
    ; Set R6 to continue after INITCALL
    LDI HIGH(START)
    PHI 6
    LDI LOW(START)
    PLO 6
    LBR INITCALL

START:
    ; Stack setup - AFTER INITCALL
    LDI $7F
    PHI 2
    LDI $FF
    PLO 2
    SEX 2

    REQ                 ; Q idle

    ; Output "OK" and newline
    LDI HIGH(MSG_OK)
    PHI 8
    LDI LOW(MSG_OK)
    PLO 8
    SEP 4
    DW SERIAL_PRINT_STRING

    ; Success - fast blink
SUCCESS:
    REQ
    LDI $20
    PLO 9
S1: DEC 9
    GLO 9
    BNZ S1
    SEQ
    LDI $20
    PLO 9
S2: DEC 9
    GLO 9
    BNZ S2
    BR SUCCESS

MSG_OK:
    DB "OK", 0DH, 0AH, 0

    END MAIN
