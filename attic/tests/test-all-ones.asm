; ==============================================================================
; Serial Test - Send 0xFF (all 1s)
; ==============================================================================
; Sends 0xFF = 11111111
; Expected: START(LOW 2s), then HIGH for 16s (8 bits), STOP(HIGH 2s), PAUSE(4s)
; Total: LOW 2s, HIGH 22s, repeat
; ==============================================================================

    ORG $0000

START:
    DIS
    LDI $7F
    PHI 2
    LDI $FF
    PLO 2
    SEX 2
    SEQ

MAIN_LOOP:
    ; Send 0xFF (all ones)
    LDI $FF
    PLO 13

    ; Start bit - LOW
    REQ
    LDI 20
    PHI 9
DELAY_START_O:
    LDI $FF
    PLO 9
DELAY_START_I:
    GLO 9
    SMI 1
    PLO 9
    BNZ DELAY_START_I
    GHI 9
    SMI 1
    PHI 9
    BNZ DELAY_START_O

    ; 8 data bits
    LDI 8
    PLO 12

SEND_BITS:
    GLO 13
    ANI 1
    BZ BIT_LOW

    SEQ
    BR BIT_DELAY

BIT_LOW:
    REQ

BIT_DELAY:
    LDI 20
    PHI 9
BIT_DELAY_O:
    LDI $FF
    PLO 9
BIT_DELAY_I:
    GLO 9
    SMI 1
    PLO 9
    BNZ BIT_DELAY_I
    GHI 9
    SMI 1
    PHI 9
    BNZ BIT_DELAY_O

    GLO 13
    SHR
    PLO 13

    GLO 12
    SMI 1
    PLO 12
    BNZ SEND_BITS

    ; Stop bit - HIGH
    SEQ
    LDI 20
    PHI 9
DELAY_STOP_O:
    LDI $FF
    PLO 9
DELAY_STOP_I:
    GLO 9
    SMI 1
    PLO 9
    BNZ DELAY_STOP_I
    GHI 9
    SMI 1
    PHI 9
    BNZ DELAY_STOP_O

    ; Pause - HIGH
    LDI 40
    PHI 9
PAUSE_O:
    LDI $FF
    PLO 9
PAUSE_I:
    GLO 9
    SMI 1
    PLO 9
    BNZ PAUSE_I
    GHI 9
    SMI 1
    PHI 9
    BNZ PAUSE_O

    BR MAIN_LOOP

    END START
