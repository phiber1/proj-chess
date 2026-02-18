; ==============================================================================
; Hardcoded 'H' output - verify inverted data still works
; 'H' = 0x48 = 01001000 binary
; LSB first: 0,0,0,1,0,0,1,0
; INVERTED: 0=SEQ, 1=REQ
; So output: SEQ,SEQ,SEQ,REQ,SEQ,SEQ,REQ,SEQ
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

    ; Start bit
    REQ
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP

    ; Bit 0 = 0 -> SEQ
    SEQ
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP

    ; Bit 1 = 0 -> SEQ
    SEQ
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP

    ; Bit 2 = 0 -> SEQ
    SEQ
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP

    ; Bit 3 = 1 -> REQ
    REQ
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP

    ; Bit 4 = 0 -> SEQ
    SEQ
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP

    ; Bit 5 = 0 -> SEQ
    SEQ
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP

    ; Bit 6 = 1 -> REQ
    REQ
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP

    ; Bit 7 = 0 -> SEQ
    SEQ
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP

    ; Stop bit
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
