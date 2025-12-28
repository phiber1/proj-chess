; ==============================================================================
; Serial Output Test - Membership Card (1.76 MHz, 9600 baud)
; ==============================================================================
; Sends "OK\r\n" repeatedly to verify serial output
; Uses Q for TX output, EF3 for RX input (not used in this test)
; ==============================================================================

    ORG $0000

; Membership Card Configuration
USE_EF3     EQU 1           ; Membership Card uses EF3
CPU_CLOCK   EQU 1.76        ; 1.76 MHz
BAUD_RATE   EQU 9600
; Bit time = 1/9600 = 104.17 µs
; Cycles per bit = 104.17 µs × 1.76 = 183 cycles
; Delay loop: GLO (2) + SMI (2) + PLO (2) + BNZ (2) = 8 cycles/iteration
; Initial: LDI (2) + PLO (2) = 4 cycles
; So: (183 - 4) / 8 = 22.4 iterations
BIT_DELAY   EQU 22          ; 22 iterations × 8 + 4 = 180 cycles (~102 µs)

START:
    DIS                     ; Disable interrupts

    ; Set up stack pointer
    LDI $7F
    PHI 2
    LDI $FF
    PLO 2
    SEX 2

    ; Set Q high (idle state for serial)
    SEQ

    ; Blink Q 3 times to signal startup
    LDI 3
    PLO 9                   ; Blink counter

BLINK_LOOP:
    REQ                     ; Q low
    LDI $FF
    PLO 7
BLINK_DELAY1:
    GLO 7
    SMI 1
    PLO 7
    BNZ BLINK_DELAY1

    SEQ                     ; Q high
    LDI $FF
    PLO 7
BLINK_DELAY2:
    GLO 7
    SMI 1
    PLO 7
    BNZ BLINK_DELAY2

    GLO 9
    SMI 1
    PLO 9
    BNZ BLINK_LOOP

MAIN_LOOP:
    ; Send "OK\r\n" - inline, no subroutine calls

    ; Send 'O'
    LDI 'O'
    PLO 13
    BR SEND_CHAR_O

CHAR_O_SENT:
    ; Send 'K'
    LDI 'K'
    PLO 13
    BR SEND_CHAR_K

CHAR_K_SENT:
    ; Send CR
    LDI 13
    PLO 13
    BR SEND_CHAR_CR

CHAR_CR_SENT:
    ; Send LF
    LDI 10
    PLO 13
    BR SEND_CHAR_LF

CHAR_LF_SENT:
    ; Long delay before repeating (~2 seconds)
    LDI $FF
    PHI 8
    PLO 8
LONG_DELAY:
    GLO 8
    SMI 1
    PLO 8
    BNZ LONG_DELAY
    GHI 8
    SMI 1
    PHI 8
    BNZ LONG_DELAY

    BR MAIN_LOOP

; ==============================================================================
; SEND_CHAR_O - Send character 'O'
; ==============================================================================
SEND_CHAR_O:
    ; Start bit (low)
    REQ
    LDI BIT_DELAY
    PLO 14
DELAY_START:
    GLO 14
    SMI 1
    PLO 14
    BNZ DELAY_START

    ; Send 8 data bits (LSB first)
    LDI 8
    PLO 12

SEND_BITS:
    ; Check LSB
    GLO 13
    ANI $01
    BZ SEND_ZERO

    ; Send 1 (high)
    SEQ
    BR BIT_SENT

SEND_ZERO:
    ; Send 0 (low)
    REQ

BIT_SENT:
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

    ; Decrement bit counter
    GLO 12
    SMI 1
    PLO 12
    BNZ SEND_BITS

    ; Stop bit (high)
    SEQ
    LDI BIT_DELAY
    PLO 14
DELAY_STOP_O:
    GLO 14
    SMI 1
    PLO 14
    BNZ DELAY_STOP_O

    BR CHAR_O_SENT

; Copy of send routine for 'K'
SEND_CHAR_K:
    REQ
    LDI BIT_DELAY
    PLO 14
DELAY_START_K:
    GLO 14
    SMI 1
    PLO 14
    BNZ DELAY_START_K
    LDI 8
    PLO 12
SEND_BITS_K:
    GLO 13
    ANI $01
    BZ SEND_ZERO_K
    SEQ
    BR BIT_SENT_K
SEND_ZERO_K:
    REQ
BIT_SENT_K:
    LDI BIT_DELAY
    PLO 14
DELAY_BIT_K:
    GLO 14
    SMI 1
    PLO 14
    BNZ DELAY_BIT_K
    GLO 13
    SHR
    PLO 13
    GLO 12
    SMI 1
    PLO 12
    BNZ SEND_BITS_K
    SEQ
    LDI BIT_DELAY
    PLO 14
DELAY_STOP_K:
    GLO 14
    SMI 1
    PLO 14
    BNZ DELAY_STOP_K
    BR CHAR_K_SENT

; Copy of send routine for CR
SEND_CHAR_CR:
    REQ
    LDI BIT_DELAY
    PLO 14
DELAY_START_CR:
    GLO 14
    SMI 1
    PLO 14
    BNZ DELAY_START_CR
    LDI 8
    PLO 12
SEND_BITS_CR:
    GLO 13
    ANI $01
    BZ SEND_ZERO_CR
    SEQ
    BR BIT_SENT_CR
SEND_ZERO_CR:
    REQ
BIT_SENT_CR:
    LDI BIT_DELAY
    PLO 14
DELAY_BIT_CR:
    GLO 14
    SMI 1
    PLO 14
    BNZ DELAY_BIT_CR
    GLO 13
    SHR
    PLO 13
    GLO 12
    SMI 1
    PLO 12
    BNZ SEND_BITS_CR
    SEQ
    LDI BIT_DELAY
    PLO 14
DELAY_STOP_CR:
    GLO 14
    SMI 1
    PLO 14
    BNZ DELAY_STOP_CR
    BR CHAR_CR_SENT

; Copy of send routine for LF
SEND_CHAR_LF:
    REQ
    LDI BIT_DELAY
    PLO 14
DELAY_START_LF:
    GLO 14
    SMI 1
    PLO 14
    BNZ DELAY_START_LF
    LDI 8
    PLO 12
SEND_BITS_LF:
    GLO 13
    ANI $01
    BZ SEND_ZERO_LF
    SEQ
    BR BIT_SENT_LF
SEND_ZERO_LF:
    REQ
BIT_SENT_LF:
    LDI BIT_DELAY
    PLO 14
DELAY_BIT_LF:
    GLO 14
    SMI 1
    PLO 14
    BNZ DELAY_BIT_LF
    GLO 13
    SHR
    PLO 13
    GLO 12
    SMI 1
    PLO 12
    BNZ SEND_BITS_LF
    SEQ
    LDI BIT_DELAY
    PLO 14
DELAY_STOP_LF:
    GLO 14
    SMI 1
    PLO 14
    BNZ DELAY_STOP_LF
    BR CHAR_LF_SENT

    END START
