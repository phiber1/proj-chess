; ==============================================================================
; Slow Q Blink Test
; ==============================================================================
; Blinks Q slowly so you can see it with your eyes
; Uses simple nested loop for delay
; ==============================================================================

    ORG $0000

START:
    DIS                 ; Disable interrupts

    ; Set up X register for SMI instruction
    LDI $7F
    PHI 2
    LDI $FF
    PLO 2
    SEX 2               ; CRITICAL: SMI needs X register set!

    ; Initialize delay counter
    LDI 0
    PHI 7
    PLO 7

LOOP:
    SEQ                 ; Q high

    ; Delay (outer loop)
    LDI $FF
    PHI 7
DELAY_HIGH_OUTER:
    ; Inner loop
    LDI $FF
    PLO 7
DELAY_HIGH_INNER:
    GLO 7
    SMI 1
    PLO 7
    BNZ DELAY_HIGH_INNER

    ; Decrement outer
    GHI 7
    SMI 1
    PHI 7
    BNZ DELAY_HIGH_OUTER

    REQ                 ; Q low

    ; Delay (outer loop)
    LDI $FF
    PHI 7
DELAY_LOW_OUTER:
    ; Inner loop
    LDI $FF
    PLO 7
DELAY_LOW_INNER:
    GLO 7
    SMI 1
    PLO 7
    BNZ DELAY_LOW_INNER

    ; Decrement outer
    GHI 7
    SMI 1
    PHI 7
    BNZ DELAY_LOW_OUTER

    BR LOOP

    END START
