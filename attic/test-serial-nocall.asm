; ==============================================================================
; Serial Output Test - NO CALL/RETN (inline code only)
; ==============================================================================
; Tests serial output without using SCRT at all
; Sends "A" repeatedly every ~1 second
; ==============================================================================

    ORG $0000

; Configuration
USE_EF4 EQU 1
BIT_DELAY   EQU 207     ; For 9600 baud @ 12 MHz
HALF_DELAY  EQU 104

START:
    DIS                 ; Disable interrupts

    ; Set up stack pointer (even though we won't use it)
    LDI $7F
    PHI 2
    LDI $FF
    PLO 2
    SEX 2

    ; Set Q high (idle)
    SEQ

    ; Blink Q once to show we're starting
    LDI $FF
    PLO 3
BLINK1:
    DEC 3
    GLO 3
    BNZ BLINK1
    REQ

    LDI $FF
    PLO 3
DELAY_START:
    DEC 3
    GLO 3
    BNZ DELAY_START
    SEQ

MAIN_LOOP:
    ; Send 'A' (0x41)
    LDI 'A'
    PLO 13               ; Save character in D.0

    ; Start bit (low)
    REQ
    ; Delay one bit time
    LDI 0
    PHI 14               ; Clear high byte!
    LDI BIT_DELAY
    PLO 14
DELAY1:
    DEC 14
    GLO 14
    BNZ DELAY1

    ; Send 8 data bits (LSB first)
    LDI 8
    PLO 12               ; Bit counter

SEND_BITS:
    ; Check LSB
    GLO 13
    ANI $01
    BZ SEND_ZERO

    ; Send 1
    SEQ
    BR BIT_DONE

SEND_ZERO:
    ; Send 0
    REQ

BIT_DONE:
    ; Delay one bit time
    LDI 0
    PHI 14               ; Clear high byte!
    LDI BIT_DELAY
    PLO 14
DELAY2:
    DEC 14
    GLO 14
    BNZ DELAY2

    ; Shift right for next bit
    GLO 13
    SHR
    PLO 13

    ; Decrement bit counter
    DEC 12
    GLO 12
    BNZ SEND_BITS

    ; Stop bit (high)
    SEQ
    LDI 0
    PHI 14               ; Clear high byte!
    LDI BIT_DELAY
    PLO 14
DELAY3:
    DEC 14
    GLO 14
    BNZ DELAY3

    ; Send CR (0x0D)
    LDI $0D
    PLO 13

    ; Start bit
    REQ
    LDI 0
    PHI 14               ; Clear high byte!
    LDI BIT_DELAY
    PLO 14
DELAY4:
    DEC 14
    GLO 14
    BNZ DELAY4

    ; Send 8 bits
    LDI 8
    PLO 12

SEND_BITS2:
    GLO 13
    ANI $01
    BZ SEND_ZERO2

    SEQ
    BR BIT_DONE2

SEND_ZERO2:
    REQ

BIT_DONE2:
    LDI BIT_DELAY
    LDI 0
    PHI 14               ; Clear high byte!
    PLO 14
DELAY5:
    DEC 14
    GLO 14
    BNZ DELAY5

    GLO 13
    SHR
    PLO 13

    DEC 12
    GLO 12
    BNZ SEND_BITS2

    ; Stop bit
    SEQ
    LDI BIT_DELAY
    LDI 0
    PHI 14               ; Clear high byte!
    PLO 14
DELAY6:
    DEC 14
    GLO 14
    BNZ DELAY6

    ; Send LF (0x0A)
    LDI $0A
    PLO 13

    ; Start bit
    REQ
    LDI BIT_DELAY
    LDI 0
    PHI 14               ; Clear high byte!
    PLO 14
DELAY7:
    DEC 14
    GLO 14
    BNZ DELAY7

    ; Send 8 bits
    LDI 8
    PLO 12

SEND_BITS3:
    GLO 13
    ANI $01
    BZ SEND_ZERO3

    SEQ
    BR BIT_DONE3

SEND_ZERO3:
    REQ

BIT_DONE3:
    LDI BIT_DELAY
    LDI 0
    PHI 14               ; Clear high byte!
    PLO 14
DELAY8:
    DEC 14
    GLO 14
    BNZ DELAY8

    GLO 13
    SHR
    PLO 13

    DEC 12
    GLO 12
    BNZ SEND_BITS3

    ; Stop bit
    SEQ
    LDI BIT_DELAY
    PLO 14
DELAY9:
    LDI 0
    PHI 14               ; Clear high byte!
    DEC 14
    GLO 14
    BNZ DELAY9

    ; Long delay before next character (~1 second)
    LDI $FF
    PHI 7
    LDI $FF
    PLO 7
LONG_DELAY:
    DEC 7
    GLO 7
    BNZ LONG_DELAY
    GHI 7
    BNZ LONG_DELAY

    ; Repeat forever
    BR MAIN_LOOP

    END START
