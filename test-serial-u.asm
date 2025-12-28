; ==============================================================================
; Test Serial with 'U' pattern (0x55 = 01010101b)
; ==============================================================================
; Sends 'U' repeatedly - this creates an alternating bit pattern
; Easy to verify with oscilloscope or logic analyzer
; ==============================================================================

    ORG $0000

START:
    SEX 2
    LDI $7F
    PHI 2
    LDI $FF
    PLO 2              ; Stack

    ; Set Q high (idle)
    SEQ

    ; Small startup delay
    LDI $10
    PHI 3
STARTUP_DELAY:
    DEC 3
    GHI 3
    BNZ STARTUP_DELAY

LOOP:
    ; Send 'U' (0x55)
    LDI $55
    PLO 13

    CALL SEND_BYTE

    ; Delay between characters
    LDI $FF
    PHI 3
CHAR_DELAY:
    DEC 3
    GHI 3
    BNZ CHAR_DELAY

    BR LOOP

; SEND_BYTE - Send one byte via Q (bit-bang serial)
; Input: D.0 = byte to send
; Uses: C, D, E
SEND_BYTE:
    ; Start bit (low)
    REQ
    LDI 50             ; Short delay for emulator
    PLO 14
DELAY1:
    DEC 14
    GLO 14
    BNZ DELAY1

    ; Send 8 data bits (LSB first)
    LDI 8
    PLO 12

BIT_LOOP:
    ; Check bit 0
    GLO 13
    ANI $01
    BZ SEND_0

    ; Send 1
    SEQ
    BR BIT_SENT

SEND_0:
    ; Send 0
    REQ

BIT_SENT:
    ; Delay
    LDI 50
    PLO 14
DELAY2:
    DEC 14
    GLO 14
    BNZ DELAY2

    ; Shift right for next bit
    GLO 13
    SHR
    PLO 13

    ; Next bit
    DEC 12
    GLO 12
    BNZ BIT_LOOP

    ; Stop bit (high)
    SEQ
    LDI 50
    PLO 14
DELAY3:
    DEC 14
    GLO 14
    BNZ DELAY3

    RETN

    END
