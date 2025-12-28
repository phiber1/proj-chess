; ==============================================================================
; Minimal Test at $7000 - Just toggle Q to prove execution
; ==============================================================================
; If Q toggles, we know code is executing at $7000
; ==============================================================================

    ORG $7000

TEST_7000:
    ; Just toggle Q in a loop - no SCRT, no serial, nothing fancy
    SEQ                     ; Q = 1 (high)

    ; Delay loop
    LDI $FF
    PLO 8
DELAY1:
    DEC 8
    GLO 8
    BNZ DELAY1

    REQ                     ; Q = 0 (low)

    ; Delay loop
    LDI $FF
    PLO 8
DELAY2:
    DEC 8
    GLO 8
    BNZ DELAY2

    BR TEST_7000            ; Loop forever

    END
