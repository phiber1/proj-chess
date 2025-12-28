; ==============================================================================
; Membership Card Serial Test - 1.76 MHz, 9600 baud
; ==============================================================================
; Sends "A" character once per second
; ==============================================================================

    ORG $0000

; Timing for 9600 baud at 1.76 MHz:
; Bit time = 104 µs = 183 cycles
; Using SMI loop: GLO(2) + SMI(2) + PLO(2) + BNZ(2) = 8 cycles/iter
; Need: (183 - 4 overhead) / 8 = 22 iterations
BIT_DELAY   EQU 22

START:
    DIS

    ; Set up for SMI
    LDI $7F
    PHI 2
    LDI $FF
    PLO 2
    SEX 2

    ; Set Q high (idle)
    SEQ

    ; Blink Q to show we're running (visible slow blink)
    REQ
    LDI $80
    PHI 9
STARTUP_OUTER:
    LDI $FF
    PLO 9
STARTUP_INNER:
    GLO 9
    SMI 1
    PLO 9
    BNZ STARTUP_INNER
    GHI 9
    SMI 1
    PHI 9
    BNZ STARTUP_OUTER
    SEQ

MAIN_LOOP:
    ; Send 'A' (0x41 = 01000001)
    LDI 'A'
    PLO 13

    ; Start bit (low)
    REQ
    LDI BIT_DELAY
    PLO 14
DELAY_START:
    GLO 14
    SMI 1
    PLO 14
    BNZ DELAY_START

    ; Send 8 bits (LSB first)
    LDI 8
    PLO 12

SEND_BITS:
    ; Check bit 0
    GLO 13
    ANI 1
    BZ BIT_LOW

    ; Bit is 1 - set Q high
    SEQ
    BR BIT_DONE

BIT_LOW:
    ; Bit is 0 - set Q low
    REQ

BIT_DONE:
    ; Delay one bit time
    LDI BIT_DELAY
    PLO 14
DELAY_BIT:
    GLO 14
    SMI 1
    PLO 14
    BNZ DELAY_BIT

    ; Shift right for next bit
    GLO 13
    SHR
    PLO 13

    ; Next bit
    GLO 12
    SMI 1
    PLO 12
    BNZ SEND_BITS

    ; Stop bit (high)
    SEQ
    LDI BIT_DELAY
    PLO 14
DELAY_STOP:
    GLO 14
    SMI 1
    PLO 14
    BNZ DELAY_STOP

    ; Long delay (~1 second)
    LDI $80
    PHI 7
LONG_OUTER:
    LDI $FF
    PLO 7
LONG_INNER:
    GLO 7
    SMI 1
    PLO 7
    BNZ LONG_INNER
    GHI 7
    SMI 1
    PHI 7
    BNZ LONG_OUTER

    BR MAIN_LOOP

    END START
