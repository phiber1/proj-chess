; ==============================================================================
; Visible Serial Test - Super slow so you can see each bit
; ==============================================================================
; Makes each bit last several seconds so you can watch Q toggle
; ==============================================================================

    ORG $0000

START:
    DIS

    LDI $7F
    PHI 2
    LDI $FF
    PLO 2
    SEX 2

    SEQ                 ; Q idle high

MAIN_LOOP:
    ; Send 'U' (0x55 = 01010101) - alternating bits, easy to see
    LDI $55
    PLO 13

    ; Start bit - Q LOW for ~2 seconds
    REQ
    LDI 20              ; Outer loop count
    PHI 9
DELAY_START_OUTER:
    LDI $FF
    PLO 9
DELAY_START_INNER:
    GLO 9
    SMI 1
    PLO 9
    BNZ DELAY_START_INNER
    GHI 9
    SMI 1
    PHI 9
    BNZ DELAY_START_OUTER

    ; Send 8 data bits
    LDI 8
    PLO 12

SEND_BITS:
    ; Check bit 0
    GLO 13
    ANI 1
    BZ BIT_LOW

    ; Bit is 1 - Q HIGH for ~2 seconds
    SEQ
    BR BIT_DELAY_START

BIT_LOW:
    ; Bit is 0 - Q LOW for ~2 seconds
    REQ

BIT_DELAY_START:
    LDI 20
    PHI 9
BIT_DELAY_OUTER:
    LDI $FF
    PLO 9
BIT_DELAY_INNER:
    GLO 9
    SMI 1
    PLO 9
    BNZ BIT_DELAY_INNER
    GHI 9
    SMI 1
    PHI 9
    BNZ BIT_DELAY_OUTER

    ; Shift right for next bit
    GLO 13
    SHR
    PLO 13

    ; Next bit
    GLO 12
    SMI 1
    PLO 12
    BNZ SEND_BITS

    ; Stop bit - Q HIGH for ~2 seconds
    SEQ
    LDI 20
    PHI 9
DELAY_STOP_OUTER:
    LDI $FF
    PLO 9
DELAY_STOP_INNER:
    GLO 9
    SMI 1
    PLO 9
    BNZ DELAY_STOP_INNER
    GHI 9
    SMI 1
    PHI 9
    BNZ DELAY_STOP_OUTER

    ; Long pause between characters (~4 seconds)
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
