; ==============================================================================
; Simple Serial Output Test
; 1.75 MHz Membership Card, 9600 baud
; Q non-inverted: SEQ = high = mark = 1, REQ = low = space = 0
; ==============================================================================

    ORG $0000

START:
    ; Set up stack pointer
    LDI $FF
    PLO 2
    LDI $01
    PHI 2                   ; R2 = $01FF (stack)

    SEQ                     ; Q idle high (mark)

MAIN_LOOP:
    ; Character to send in R11
    LDI $56                 ; 'V'
    PLO 11

    ; Bit counter in R12
    LDI 8
    PLO 12

    ; ========== START BIT ==========
    REQ                     ; Q low = space = start bit
    ; Need ~182 clocks. REQ=16, each 2-cycle instruction=16 clocks
    ; 11 instructions = 176 clocks (close enough)
    LDI 0
    LDI 0
    LDI 0
    LDI 0
    LDI 0
    LDI 0
    LDI 0
    LDI 0
    LDI 0
    LDI 0                   ; 10 x 16 = 160 + 16 = 176 clocks

    ; ========== DATA BITS ==========
BITLOOP:
    ; Get LSB into DF
    GLO 11
    SHR
    PLO 11

    ; Output bit based on DF
    BDF SEND_ONE            ; If DF=1, send one (16 clocks)
    REQ                     ; Q low = space = 0 (16 clocks)
    BR BIT_DELAY            ; (16 clocks) - total 48 clocks

SEND_ONE:
    SEQ                     ; Q high = mark = 1 (16 clocks)
    BR BIT_DELAY            ; (16 clocks) - total 48 clocks

BIT_DELAY:
    ; Need ~182 clocks total per bit
    ; GLO+SHR+PLO = 48 clocks
    ; BDF+SEQ/REQ+BR = 48 clocks
    ; DEC+GLO+BNZ = 48 clocks
    ; Total so far = 144, need 38 more = 2 LDI (32) + some
    LDI 0
    LDI 0                   ; 32 clocks of delay
    ; Total: 176 clocks (3% fast)

    ; Decrement and loop
    DEC 12
    GLO 12
    BNZ BITLOOP

    ; ========== STOP BIT ==========
    SEQ                     ; Q high = mark = stop bit
    LDI 0
    LDI 0
    LDI 0
    LDI 0
    LDI 0
    LDI 0
    LDI 0
    LDI 0
    LDI 0
    LDI 0                   ; 176 clocks

    ; Pause between characters
    LDI $40
    PLO 7
PAUSE:
    DEC 7
    GLO 7
    BNZ PAUSE

    BR MAIN_LOOP

    END START
