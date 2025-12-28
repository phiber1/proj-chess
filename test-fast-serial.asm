; ==============================================================================
; Fast Serial Test - Single byte counter for bit delays
; ==============================================================================
; Uses simple PLO/SMI/BNZ loop (much faster than nested loops)
; Sends 'U' (0x55) at slow baud rate
; ==============================================================================

    ORG $0000

; Bit delay - just a guess, we'll measure actual baud rate
BIT_DELAY   EQU 200

START:
    DIS
    SEQ             ; Q idle high

MAIN_LOOP:
    ; Send 'U' (0x55 = 01010101)
    LDI $55
    PLO 13

    ; Start bit
    REQ
    LDI BIT_DELAY
    PLO 14
DELAY_START:
    GLO 14
    SMI 1
    PLO 14
    BNZ DELAY_START

    ; 8 data bits
    LDI 8
    PLO 12

SEND_BITS:
    GLO 13
    ANI 1
    BZ BIT_LOW

    SEQ
    BR BIT_DONE

BIT_LOW:
    REQ

BIT_DONE:
    LDI BIT_DELAY
    PLO 14
DELAY_BIT:
    GLO 14
    SMI 1
    PLO 14
    BNZ DELAY_BIT

    GLO 13
    SHR
    PLO 13

    GLO 12
    SMI 1
    PLO 12
    BNZ SEND_BITS

    ; Stop bit
    SEQ
    LDI BIT_DELAY
    PLO 14
DELAY_STOP:
    GLO 14
    SMI 1
    PLO 14
    BNZ DELAY_STOP

    ; Long pause between characters
    LDI $FF
    PHI 7
PAUSE_OUTER:
    LDI $FF
    PLO 7
PAUSE_INNER:
    GLO 7
    SMI 1
    PLO 7
    BNZ PAUSE_INNER
    GHI 7
    SMI 1
    PHI 7
    BNZ PAUSE_OUTER

    BR MAIN_LOOP

    END START
