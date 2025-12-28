; ==============================================================================
; Manual Q Pattern Test
; ==============================================================================
; Manually creates a specific Q pattern to verify timing
; Pattern: HIGH 2s, LOW 2s, HIGH 2s, LOW 2s (repeating)
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
    ; Q HIGH for 2 seconds
    SEQ
    LDI 20
    PHI 9
DELAY1_OUTER:
    LDI $FF
    PLO 9
DELAY1_INNER:
    GLO 9
    SMI 1
    PLO 9
    BNZ DELAY1_INNER
    GHI 9
    SMI 1
    PHI 9
    BNZ DELAY1_OUTER

    ; Q LOW for 2 seconds
    REQ
    LDI 20
    PHI 9
DELAY2_OUTER:
    LDI $FF
    PLO 9
DELAY2_INNER:
    GLO 9
    SMI 1
    PLO 9
    BNZ DELAY2_INNER
    GHI 9
    SMI 1
    PHI 9
    BNZ DELAY2_OUTER

    ; Q HIGH for 2 seconds
    SEQ
    LDI 20
    PHI 9
DELAY3_OUTER:
    LDI $FF
    PLO 9
DELAY3_INNER:
    GLO 9
    SMI 1
    PLO 9
    BNZ DELAY3_INNER
    GHI 9
    SMI 1
    PHI 9
    BNZ DELAY3_OUTER

    ; Q LOW for 2 seconds
    REQ
    LDI 20
    PHI 9
DELAY4_OUTER:
    LDI $FF
    PLO 9
DELAY4_INNER:
    GLO 9
    SMI 1
    PLO 9
    BNZ DELAY4_INNER
    GHI 9
    SMI 1
    PHI 9
    BNZ DELAY4_OUTER

    BR LOOP

    END START
