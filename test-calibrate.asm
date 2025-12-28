; ==============================================================================
; Calibration Test - Measure actual timing
; ==============================================================================
; Blinks Q with known iteration counts so we can measure actual cycles
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
    ; Q high
    SEQ

    ; Delay with EXACTLY 10 outer iterations
    LDI 10
    PHI 9
OUTER_HIGH:
    ; Inner loop: 255 iterations
    LDI $FF
    PLO 9
INNER_HIGH:
    GLO 9
    SMI 1
    PLO 9
    BNZ INNER_HIGH

    GHI 9
    SMI 1
    PHI 9
    BNZ OUTER_HIGH

    ; Q low
    REQ

    ; Same delay
    LDI 10
    PHI 9
OUTER_LOW:
    LDI $FF
    PLO 9
INNER_LOW:
    GLO 9
    SMI 1
    PLO 9
    BNZ INNER_LOW

    GHI 9
    SMI 1
    PHI 9
    BNZ OUTER_LOW

    BR LOOP

    END START
