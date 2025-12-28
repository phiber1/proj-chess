; ==============================================================================
; Loop version matching hardcoded timing
; Key insight: output bit FIRST, then do shift/count during the delay
; This makes every bit period identical
; ==============================================================================

    ORG $0000

START:
    SEQ                     ; Q idle high (mark)

WAIT_IDLE:
    BN3 WAIT_IDLE           ; Wait for line idle (EF3=1)

WAIT_START:
    B3 WAIT_START           ; Wait for any key (EF3=0)

WAIT_DONE:
    BN3 WAIT_DONE           ; Wait for key release (EF3=1)

MAIN_LOOP:
    SEQ
    NOP
    NOP

    ; Load character to send
    LDI $48                 ; 'H' = 01001000
    PLO 3                   ; R3.0 = character
    LDI 8
    PLO 4                   ; R4.0 = bit counter

    ; Start bit - 7 NOPs like hardcoded
    REQ
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP

SEND_BIT:
    ; Get LSB, output it immediately
    GLO 3
    SHR                     ; LSB -> DF
    PLO 3

    ; INVERTED: DF=1 means REQ, DF=0 means SEQ
    BDF BIT_IS_ONE
    SEQ                     ; Bit is 0: Q high (inverted)
    BR BIT_SENT
BIT_IS_ONE:
    REQ                     ; Bit is 1: Q low (inverted)
    BR BIT_SENT             ; Keep both paths same length

BIT_SENT:
    ; Try 4 NOPs + 3 LDIs
    NOP
    NOP
    NOP
    NOP
    LDI 0
    LDI 0
    LDI 0

    ; Count bits
    DEC 4
    GLO 4
    BNZ SEND_BIT

    ; Stop bit - 7 NOPs like hardcoded
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
