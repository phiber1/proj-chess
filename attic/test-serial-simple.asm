; ==============================================================================
; Simplest Serial Test - No subroutines, just inline code
; ==============================================================================
; Sends 'A' once and stops - no CALL/RETN complications
; ==============================================================================

    ORG $0000

START:
    SEX 2              ; X = R2
    LDI $7F
    PHI 2
    LDI $FF
    PLO 2              ; Stack

    ; Set Q high (idle)
    SEQ

    ; Wait a moment
    LDI $20
    PLO 3
WAIT1:
    DEC 3
    GLO 3
    BNZ WAIT1

    ; Character to send: 'A' (0x41)
    LDI $41
    PLO 4              ; R4.0 = character

    ; START BIT (low)
    REQ

    ; Delay (try very short for emulator)
    LDI 10
    PLO 3
DLY1:
    DEC 3
    GLO 3
    BNZ DLY1

    ; BIT 0
    GLO 4
    ANI $01
    BNZ BIT0_HIGH
    REQ
    BR BIT0_DONE
BIT0_HIGH:
    SEQ
BIT0_DONE:
    LDI 10
    PLO 3
DLY2:
    DEC 3
    GLO 3
    BNZ DLY2
    GLO 4
    SHR
    PLO 4

    ; BIT 1
    GLO 4
    ANI $01
    BNZ BIT1_HIGH
    REQ
    BR BIT1_DONE
BIT1_HIGH:
    SEQ
BIT1_DONE:
    LDI 10
    PLO 3
DLY3:
    DEC 3
    GLO 3
    BNZ DLY3
    GLO 4
    SHR
    PLO 4

    ; BIT 2
    GLO 4
    ANI $01
    BNZ BIT2_HIGH
    REQ
    BR BIT2_DONE
BIT2_HIGH:
    SEQ
BIT2_DONE:
    LDI 10
    PLO 3
DLY4:
    DEC 3
    GLO 3
    BNZ DLY4
    GLO 4
    SHR
    PLO 4

    ; BIT 3
    GLO 4
    ANI $01
    BNZ BIT3_HIGH
    REQ
    BR BIT3_DONE
BIT3_HIGH:
    SEQ
BIT3_DONE:
    LDI 10
    PLO 3
DLY5:
    DEC 3
    GLO 3
    BNZ DLY5
    GLO 4
    SHR
    PLO 4

    ; BIT 4
    GLO 4
    ANI $01
    BNZ BIT4_HIGH
    REQ
    BR BIT4_DONE
BIT4_HIGH:
    SEQ
BIT4_DONE:
    LDI 10
    PLO 3
DLY6:
    DEC 3
    GLO 3
    BNZ DLY6
    GLO 4
    SHR
    PLO 4

    ; BIT 5
    GLO 4
    ANI $01
    BNZ BIT5_HIGH
    REQ
    BR BIT5_DONE
BIT5_HIGH:
    SEQ
BIT5_DONE:
    LDI 10
    PLO 3
DLY7:
    DEC 3
    GLO 3
    BNZ DLY7
    GLO 4
    SHR
    PLO 4

    ; BIT 6
    GLO 4
    ANI $01
    BNZ BIT6_HIGH
    REQ
    BR BIT6_DONE
BIT6_HIGH:
    SEQ
BIT6_DONE:
    LDI 10
    PLO 3
DLY8:
    DEC 3
    GLO 3
    BNZ DLY8
    GLO 4
    SHR
    PLO 4

    ; BIT 7
    GLO 4
    ANI $01
    BNZ BIT7_HIGH
    REQ
    BR BIT7_DONE
BIT7_HIGH:
    SEQ
BIT7_DONE:
    LDI 10
    PLO 3
DLY9:
    DEC 3
    GLO 3
    BNZ DLY9

    ; STOP BIT (high)
    SEQ
    LDI 10
    PLO 3
DLY10:
    DEC 3
    GLO 3
    BNZ DLY10

DONE:
    ; Done - just idle
    SEQ                ; Make sure Q is high
    BR DONE

    END
