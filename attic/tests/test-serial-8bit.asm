; ==============================================================================
; Serial Output Test - Using 8-bit counters (no DEC)
; ==============================================================================
; Avoids 16-bit DEC instruction, uses 8-bit arithmetic only
; ==============================================================================

    ORG $0000

; Configuration
USE_EF4 EQU 1
BIT_DELAY   EQU 207     ; For 9600 baud @ 12 MHz

START:
    DIS                 ; Disable interrupts

    ; Set up stack pointer
    LDI $7F
    PHI 2
    LDI $FF
    PLO 2
    SEX 2

    ; Set Q high (idle)
    SEQ

    ; Blink Q once
    LDI $FF
    PLO 7
BLINK1:
    GLO 7
    SMI 1
    PLO 7
    BNZ BLINK1

    REQ
    LDI $FF
    PLO 7
DELAY_START:
    GLO 7
    SMI 1
    PLO 7
    BNZ DELAY_START

    SEQ

MAIN_LOOP:
    ; Send 'A' (0x41)
    LDI 'A'
    PLO 13

    ; Start bit (low)
    REQ
    LDI BIT_DELAY
    PLO 14
DELAY1:
    GLO 14
    SMI 1
    PLO 14
    BNZ DELAY1

    ; Send 8 data bits
    LDI 8
    PLO 12

SEND_BITS:
    ; Check LSB
    GLO 13
    ANI $01
    BZ SEND_ZERO

    SEQ
    BR BIT_DONE

SEND_ZERO:
    REQ

BIT_DONE:
    ; Delay
    LDI BIT_DELAY
    PLO 14
DELAY2:
    GLO 14
    SMI 1
    PLO 14
    BNZ DELAY2

    ; Shift right
    GLO 13
    SHR
    PLO 13

    ; Decrement bit counter
    GLO 12
    SMI 1
    PLO 12
    BNZ SEND_BITS

    ; Stop bit (high)
    SEQ
    LDI BIT_DELAY
    PLO 14
DELAY3:
    GLO 14
    SMI 1
    PLO 14
    BNZ DELAY3

    ; Long delay (~1 second)
    LDI $FF
    PHI 7
    PLO 7
LONG_DELAY:
    GLO 7
    SMI 1
    PLO 7
    BNZ LONG_DELAY
    GHI 7
    SMI 1
    PHI 7
    BNZ LONG_DELAY

    ; Repeat
    BR MAIN_LOOP

    END START
