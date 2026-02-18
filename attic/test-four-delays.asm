; ==============================================================================
; Four Delay Test - Should be 2s LOW, 8s HIGH
; ==============================================================================

    ORG $0000

START:
    DIS

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

    ; Q HIGH, then 4 delays of 2s each = 8s total
    SEQ

    ; Delay 1
    LDI 20
    PHI 9
D1_O:
    LDI $FF
    PLO 9
D1_I:
    GLO 9
    SMI 1
    PLO 9
    BNZ D1_I
    GHI 9
    SMI 1
    PHI 9
    BNZ D1_O

    ; Delay 2
    LDI 20
    PHI 9
D2_O:
    LDI $FF
    PLO 9
D2_I:
    GLO 9
    SMI 1
    PLO 9
    BNZ D2_I
    GHI 9
    SMI 1
    PHI 9
    BNZ D2_O

    ; Delay 3
    LDI 20
    PHI 9
D3_O:
    LDI $FF
    PLO 9
D3_I:
    GLO 9
    SMI 1
    PLO 9
    BNZ D3_I
    GHI 9
    SMI 1
    PHI 9
    BNZ D3_O

    ; Delay 4
    LDI 20
    PHI 9
D4_O:
    LDI $FF
    PLO 9
D4_I:
    GLO 9
    SMI 1
    PLO 9
    BNZ D4_I
    GHI 9
    SMI 1
    PHI 9
    BNZ D4_O

    BR LOOP

    END START
