; ==============================================================================
; Ultra-Simple Test - Just toggle Q to verify execution
; ==============================================================================
; If this works, you'll hear tone changes or see LED blink
; If this doesn't work, there's a fundamental emulator config issue
; ==============================================================================

    ORG $0000

START:
    SEX 2              ; Set X register

    LDI $7F
    PHI 2
    LDI $FF
    PLO 2              ; R2 = stack

    ; Slow toggle to verify it's running
LOOP:
    SEQ                ; Q = 1

    ; Delay
    LDI $FF
    PHI 3
    LDI $FF
    PLO 3
DELAY1:
    DEC 3
    GLO 3
    BNZ DELAY1
    GHI 3
    BNZ DELAY1

    REQ                ; Q = 0

    ; Delay
    LDI $FF
    PHI 3
    LDI $FF
    PLO 3
DELAY2:
    DEC 3
    GLO 3
    BNZ DELAY2
    GHI 3
    BNZ DELAY2

    BR LOOP

    END
