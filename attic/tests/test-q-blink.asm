; ==============================================================================
; Minimal Q blink test - no SCRT, no serial
; ==============================================================================
; Just blinks Q to verify basic execution
; ==============================================================================

    ORG $0000

START:
    SEQ                 ; Q high

    ; Delay
    LDI $FF
    PLO 3
DELAY1:
    DEC 3
    GLO 3
    BNZ DELAY1

    REQ                 ; Q low

    ; Delay
    LDI $FF
    PLO 3
DELAY2:
    DEC 3
    GLO 3
    BNZ DELAY2

    BR START            ; Loop forever

    END START
