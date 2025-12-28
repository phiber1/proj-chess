; ==============================================================================
; Output "Hello" using hardcoded bit timing that works
; 7 NOPs per bit, inverted data (0=SEQ, 1=REQ)
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
    ; Output 'H' = 0x48 = 01001000, LSB first: 0,0,0,1,0,0,1,0
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

    ; --- 'e' = 0x65 = 01100101, LSB first: 1,0,1,0,0,1,1,0 ---

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

    ; Bit 2 = 1 -> REQ
    REQ
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP

    ; Bit 3 = 0 -> SEQ
    SEQ
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

    ; --- 'l' = 0x6C = 01101100, LSB first: 0,0,1,1,0,1,1,0 ---

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

    ; Bit 2 = 1 -> REQ
    REQ
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

    ; --- 'l' again = 0x6C ---

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

    ; Bit 2 = 1 -> REQ
    REQ
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

    ; --- 'o' = 0x6F = 01101111, LSB first: 1,1,1,1,0,1,1,0 ---

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

    ; Bit 1 = 1 -> REQ
    REQ
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP

    ; Bit 2 = 1 -> REQ
    REQ
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

    ; --- CR = 0x0D = 00001101, LSB first: 1,0,1,1,0,0,0,0 ---

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

    ; Bit 2 = 1 -> REQ
    REQ
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

    ; Bit 6 = 0 -> SEQ
    SEQ
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

    ; --- LF = 0x0A = 00001010, LSB first: 0,1,0,1,0,0,0,0 ---

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

    ; Bit 1 = 1 -> REQ
    REQ
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

    ; Bit 6 = 0 -> SEQ
    SEQ
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
    LDI $FF
    PLO 5
PAUSE:
    DEC 5
    GLO 5
    BNZ PAUSE

    LBR MAIN_LOOP

    END START
