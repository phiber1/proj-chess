; ==============================================================================
; Two Delay Test - Should be 2s LOW, 4s HIGH
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
    ; Q LOW for 2s
    REQ
    LDI 20
    PHI 9
D_LOW_O:
    LDI $FF
    PLO 9
D_LOW_I:
    GLO 9
    SMI 1
    PLO 9
    BNZ D_LOW_I
    GHI 9
    SMI 1
    PHI 9
    BNZ D_LOW_O

    ; Q HIGH for 2s (first delay)
    SEQ
    LDI 20
    PHI 9
D_HIGH1_O:
    LDI $FF
    PLO 9
D_HIGH1_I:
    GLO 9
    SMI 1
    PLO 9
    BNZ D_HIGH1_I
    GHI 9
    SMI 1
    PHI 9
    BNZ D_HIGH1_O

    ; Q still HIGH for 2s more (second delay)
    LDI 20
    PHI 9
D_HIGH2_O:
    LDI $FF
    PLO 9
D_HIGH2_I:
    GLO 9
    SMI 1
    PLO 9
    BNZ D_HIGH2_I
    GHI 9
    SMI 1
    PHI 9
    BNZ D_HIGH2_O

    BR LOOP

    END START
