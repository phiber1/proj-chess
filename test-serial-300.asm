; ==============================================================================
; Serial Test - 300 baud (calculated for 1.75 MHz)
; ==============================================================================

    ORG $0000

BIT_DELAY   EQU 91      ; For 300 baud @ 1.75 MHz

START:
    DIS
    SEQ             ; Q idle high

MAIN_LOOP:
    ; Send 'U' (0x55)
    LDI $55
    PLO 13

    ; Start bit
    REQ
    LDI BIT_DELAY
    PLO 14
DS:
    GLO 14
    SMI 1
    PLO 14
    BNZ DS

    ; 8 data bits
    LDI 8
    PLO 12

SB:
    GLO 13
    ANI 1
    BZ BL
    SEQ
    BR BD
BL:
    REQ
BD:
    LDI BIT_DELAY
    PLO 14
DB:
    GLO 14
    SMI 1
    PLO 14
    BNZ DB

    GLO 13
    SHR
    PLO 13
    GLO 12
    SMI 1
    PLO 12
    BNZ SB

    ; Stop bit
    SEQ
    LDI BIT_DELAY
    PLO 14
DST:
    GLO 14
    SMI 1
    PLO 14
    BNZ DST

    ; Pause
    LDI $FF
    PHI 7
PO:
    LDI $FF
    PLO 7
PI:
    GLO 7
    SMI 1
    PLO 7
    BNZ PI
    GHI 7
    SMI 1
    PHI 7
    BNZ PO

    BR MAIN_LOOP

    END START
