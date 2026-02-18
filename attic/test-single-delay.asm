; ==============================================================================
; Single Delay Test
; ==============================================================================
; Simplest possible: LOW 2s, HIGH 2s, repeat
; This should match test-manual-pattern exactly
; ==============================================================================

    ORG $0000

START:
    DIS
    LDI $7F
    PHI 2
    LDI $FF
    PLO 2
    SEX 2

LOOP:
    ; Q LOW
    REQ
    LDI 20
    PHI 9
DELAY_LOW_O:
    LDI $FF
    PLO 9
DELAY_LOW_I:
    GLO 9
    SMI 1
    PLO 9
    BNZ DELAY_LOW_I
    GHI 9
    SMI 1
    PHI 9
    BNZ DELAY_LOW_O

    ; Q HIGH
    SEQ
    LDI 20
    PHI 9
DELAY_HIGH_O:
    LDI $FF
    PLO 9
DELAY_HIGH_I:
    GLO 9
    SMI 1
    PLO 9
    BNZ DELAY_HIGH_I
    GHI 9
    SMI 1
    PHI 9
    BNZ DELAY_HIGH_O

    BR LOOP

    END START
