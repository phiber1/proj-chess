; ==============================================================================
; Membership Card Serial - 300 BAUD (slow but reliable)
; ==============================================================================
; Based on measured timing: 2550 iterations = 1 second
; For 300 baud: bit time = 3.33ms, need ~8.5 iterations
; ==============================================================================

    ORG $0000

BIT_DELAY   EQU 8       ; ~3.1ms per bit (320 baud actual)

START:
    DIS

    LDI $7F
    PHI 2
    LDI $FF
    PLO 2
    SEX 2

    SEQ                 ; Q idle high

MAIN_LOOP:
    ; Send 'A'
    LDI 'A'
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

    ; Delay between characters (~1 sec)
    LDI $FF
    PHI 7
CHAR_OUTER:
    LDI $FF
    PLO 7
CHAR_INNER:
    GLO 7
    SMI 1
    PLO 7
    BNZ CHAR_INNER
    GHI 7
    SMI 1
    PHI 7
    BNZ CHAR_OUTER

    BR MAIN_LOOP

    END START
