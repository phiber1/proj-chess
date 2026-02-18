; ==============================================================================
; Loop Counter Test
; ==============================================================================
; Tests if loop counter (SMI + BNZ) works correctly
; Should toggle Q 8 times (8 × 2s = 16s total)
; ==============================================================================

    ORG $0000

START:
    DIS
    LDI $7F
    PHI 2
    LDI $FF
    PLO 2
    SEX 2

MAIN_LOOP:
    ; Q LOW for 2s
    REQ
    LDI 20
    PHI 9
START_DELAY_O:
    LDI $FF
    PLO 9
START_DELAY_I:
    GLO 9
    SMI 1
    PLO 9
    BNZ START_DELAY_I
    GHI 9
    SMI 1
    PHI 9
    BNZ START_DELAY_O

    ; Initialize counter to 8
    LDI 8
    PLO 12

    ; Q HIGH and stay HIGH for 8 × 2s = 16s
    SEQ

LOOP_8_TIMES:
    ; Delay 2 seconds
    LDI 20
    PHI 9
DELAY_OUTER:
    LDI $FF
    PLO 9
DELAY_INNER:
    GLO 9
    SMI 1
    PLO 9
    BNZ DELAY_INNER
    GHI 9
    SMI 1
    PHI 9
    BNZ DELAY_OUTER

    ; Decrement counter
    GLO 12
    SMI 1
    PLO 12
    BNZ LOOP_8_TIMES

    ; Long pause (4s)
    LDI 40
    PHI 9
PAUSE_OUTER:
    LDI $FF
    PLO 9
PAUSE_INNER:
    GLO 9
    SMI 1
    PLO 9
    BNZ PAUSE_INNER
    GHI 9
    SMI 1
    PHI 9
    BNZ PAUSE_OUTER

    BR MAIN_LOOP

    END START
