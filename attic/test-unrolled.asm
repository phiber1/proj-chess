; ==============================================================================
; Unrolled Loop Test - NO loop counter
; ==============================================================================
; Manually creates: LOW 2s, HIGH 16s (8 × 2s delays), pause 4s
; Should see: LOW 2s, HIGH 20s, repeat
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
    ; === Q LOW for 2s ===
    REQ
    LDI 20
    PHI 9
D0_O:
    LDI $FF
    PLO 9
D0_I:
    GLO 9
    SMI 1
    PLO 9
    BNZ D0_I
    GHI 9
    SMI 1
    PHI 9
    BNZ D0_O

    ; === Q HIGH, then 8 delays of 2s each ===
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

    ; Delay 5
    LDI 20
    PHI 9
D5_O:
    LDI $FF
    PLO 9
D5_I:
    GLO 9
    SMI 1
    PLO 9
    BNZ D5_I
    GHI 9
    SMI 1
    PHI 9
    BNZ D5_O

    ; Delay 6
    LDI 20
    PHI 9
D6_O:
    LDI $FF
    PLO 9
D6_I:
    GLO 9
    SMI 1
    PLO 9
    BNZ D6_I
    GHI 9
    SMI 1
    PHI 9
    BNZ D6_O

    ; Delay 7
    LDI 20
    PHI 9
D7_O:
    LDI $FF
    PLO 9
D7_I:
    GLO 9
    SMI 1
    PLO 9
    BNZ D7_I
    GHI 9
    SMI 1
    PHI 9
    BNZ D7_O

    ; Delay 8
    LDI 20
    PHI 9
D8_O:
    LDI $FF
    PLO 9
D8_I:
    GLO 9
    SMI 1
    PLO 9
    BNZ D8_I
    GHI 9
    SMI 1
    PHI 9
    BNZ D8_O

    ; === Pause 4s (Q still HIGH) ===
    LDI 40
    PHI 9
DP_O:
    LDI $FF
    PLO 9
DP_I:
    GLO 9
    SMI 1
    PLO 9
    BNZ DP_I
    GHI 9
    SMI 1
    PHI 9
    BNZ DP_O

    BR MAIN_LOOP

    END START
