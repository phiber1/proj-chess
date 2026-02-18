; ==============================================================================
; Serial Output Test - Fixed timing with inverted data
; For 1.75 MHz Membership Card at 9600 baud
; Data bits INVERTED: 0=SEQ, 1=REQ
; Framing normal: Start=REQ, Stop=SEQ
; Press any key to start, then outputs 'H' repeatedly
; ==============================================================================

    ORG $0000

START:
    SEQ                     ; Q idle high (mark)

; ==============================================================================
; WAIT FOR KEYPRESS TO START
; ==============================================================================

WAIT_IDLE:
    BN3 WAIT_IDLE           ; Wait for line idle (EF3=1)

WAIT_START:
    B3 WAIT_START           ; Wait for any key (EF3=0)

WAIT_DONE:
    BN3 WAIT_DONE           ; Wait for key release (EF3=1)

; ==============================================================================
; MAIN OUTPUT LOOP - Fixed 9600 baud timing
; ==============================================================================

MAIN_LOOP:
    ; Ensure Q is high before we begin
    SEQ
    NOP
    NOP

    ; Load character to send
    LDI $48                 ; 'H'
    PLO 3                   ; R3.0 = character
    LDI 8
    PLO 4                   ; R4.0 = bit counter

    ; Start bit (Q = 0) - 10 NOPs
    REQ
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP

SEND_BIT:
    ; Get LSB, shift for next
    GLO 3
    SHR                     ; LSB -> DF
    PLO 3

    ; INVERTED: DF=1 means REQ, DF=0 means SEQ
    BDF BIT_ONE
    SEQ                     ; Bit is 0: Q high (inverted)
    BR BIT_DELAY
BIT_ONE:
    REQ                     ; Bit is 1: Q low (inverted)
    BR BIT_DELAY

BIT_DELAY:
    ; Add delay - 2 NOPs + 5 LDIs
    NOP
    NOP
    LDI 0
    LDI 0
    LDI 0
    LDI 0
    LDI 0

    ; Count bits
    DEC 4
    GLO 4
    BNZ SEND_BIT

    ; Stop bit (Q = 1)
    SEQ
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP

    ; Pause between characters
    LDI $40
    PLO 5
PAUSE:
    DEC 5
    GLO 5
    BNZ PAUSE

    BR MAIN_LOOP

    END START
