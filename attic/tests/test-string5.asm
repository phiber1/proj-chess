; ==============================================================================
; String output using exact hardcoded timing
; Using INVERTED data like test-h-hardcoded:
;   Start bit: REQ (normal)
;   Data 0: SEQ (inverted)
;   Data 1: REQ (inverted)
;   Stop bit: SEQ (normal)
; 7 NOPs between each bit transition
; ==============================================================================

    ORG $0000

START:
    SEQ                     ; Q idle high (mark)

WAIT_IDLE:
    BN3 WAIT_IDLE           ; Wait for line idle

WAIT_START:
    B3 WAIT_START           ; Wait for key

WAIT_DONE:
    BN3 WAIT_DONE           ; Wait for release

MAIN_LOOP:
    LDI HIGH(STRING)
    PHI 8
    LDI LOW(STRING)
    PLO 8

NEXT_CHAR:
    LDA 8                   ; Get char
    BZ DONE_STRING
    PLO 3                   ; R3.0 = char

    ; Settling
    SEQ
    NOP
    NOP

    ; Start bit (REQ) + 7 NOPs
    REQ
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP

    ; Bit 0
    GLO 3
    SHR
    PLO 3
    BDF BIT0_ONE
    SEQ                     ; 0 -> SEQ (inverted)
    BR BIT0_D
BIT0_ONE:
    REQ                     ; 1 -> REQ (inverted)
    BR BIT0_D
BIT0_D:
    NOP
    NOP
    NOP
    NOP
    NOP

    ; Bit 1
    GLO 3
    SHR
    PLO 3
    BDF BIT1_ONE
    SEQ
    BR BIT1_D
BIT1_ONE:
    REQ
    BR BIT1_D
BIT1_D:
    NOP
    NOP
    NOP
    NOP
    NOP

    ; Bit 2
    GLO 3
    SHR
    PLO 3
    BDF BIT2_ONE
    SEQ
    BR BIT2_D
BIT2_ONE:
    REQ
    BR BIT2_D
BIT2_D:
    NOP
    NOP
    NOP
    NOP
    NOP

    ; Bit 3
    GLO 3
    SHR
    PLO 3
    BDF BIT3_ONE
    SEQ
    BR BIT3_D
BIT3_ONE:
    REQ
    BR BIT3_D
BIT3_D:
    NOP
    NOP
    NOP
    NOP
    NOP

    ; Bit 4
    GLO 3
    SHR
    PLO 3
    BDF BIT4_ONE
    SEQ
    BR BIT4_D
BIT4_ONE:
    REQ
    BR BIT4_D
BIT4_D:
    NOP
    NOP
    NOP
    NOP
    NOP

    ; Bit 5
    GLO 3
    SHR
    PLO 3
    BDF BIT5_ONE
    SEQ
    BR BIT5_D
BIT5_ONE:
    REQ
    BR BIT5_D
BIT5_D:
    NOP
    NOP
    NOP
    NOP
    NOP

    ; Bit 6
    GLO 3
    SHR
    PLO 3
    BDF BIT6_ONE
    SEQ
    BR BIT6_D
BIT6_ONE:
    REQ
    BR BIT6_D
BIT6_D:
    NOP
    NOP
    NOP
    NOP
    NOP

    ; Bit 7
    GLO 3
    SHR
    PLO 3
    BDF BIT7_ONE
    SEQ
    BR BIT7_D
BIT7_ONE:
    REQ
    BR BIT7_D
BIT7_D:
    NOP
    NOP
    NOP
    NOP
    NOP

    ; Stop bit (SEQ) + 7 NOPs
    SEQ
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP

    BR NEXT_CHAR

DONE_STRING:
    LDI $FF
    PLO 5
PAUSE:
    DEC 5
    GLO 5
    BNZ PAUSE
    BR MAIN_LOOP

STRING:
    DB "Hi", $0D, $0A, 0

    END START
