; ==============================================================================
; Simple loop matching hardcoded structure
; Output bit FIRST, then delay with NOPs
; 1 start + 8 data + 1 stop = 10 bits total
; ==============================================================================

    ORG $0000

START:
    SEQ                     ; Q idle high

WAIT_IDLE:
    BN3 WAIT_IDLE
WAIT_START:
    B3 WAIT_START
WAIT_DONE:
    BN3 WAIT_DONE

MAIN_LOOP:
    SEQ
    NOP
    NOP

    ; Load 'H' = 0x48
    LDI $48
    PLO 3                   ; R3.0 = character
    LDI 8
    PLO 4                   ; R4.0 = 8 bits

    ; Start bit (REQ + 7 NOPs)
    REQ
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP

BIT_LOOP:
    ; Get LSB into DF
    GLO 3
    SHR
    PLO 3

    ; Output bit FIRST (inverted: 0=SEQ, 1=REQ)
    BDF BIT_ONE
    SEQ                     ; bit=0
    BR BIT_DELAY
BIT_ONE:
    REQ                     ; bit=1
    BR BIT_DELAY

BIT_DELAY:
    ; 4 NOPs + 3 LDIs
    NOP
    NOP
    NOP
    NOP
    LDI 0
    LDI 0
    LDI 0

    ; Decrement bit counter
    DEC 4
    GLO 4
    BNZ BIT_LOOP

    ; Stop bit 1 (SEQ + 7 NOPs)
    SEQ
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP

    ; Stop bit 2 (SEQ + 7 NOPs)
    SEQ
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP

    ; Pause
    LDI $40
    PLO 5
PAUSE:
    DEC 5
    GLO 5
    BNZ PAUSE

    BR MAIN_LOOP

    END START
