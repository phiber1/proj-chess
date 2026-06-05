; ==============================================================================
; Output "Hi" using hardcoded bit timing
; 7 NOPs per bit, inverted data (0=SEQ, 1=REQ)
; Add settling time between each character
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
    ; === 'H' = 0x48 = 01001000, LSB first: 0,0,0,1,0,0,1,0 ===

    ; Settling time before character
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

    ; === 'i' = 0x69 = 01101001, LSB first: 1,0,0,1,0,1,1,0 ===

    ; Settling time before character
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

    ; Bit 0 = 1 -> REQ
    REQ
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

    ; Bit 5 = 1 -> REQ
    REQ
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

    ; Pause between strings
    LDI $80
    PLO 5
PAUSE:
    DEC 5
    GLO 5
    BNZ PAUSE

    BR MAIN_LOOP

    END START
