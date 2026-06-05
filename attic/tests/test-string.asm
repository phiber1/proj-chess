; ==============================================================================
; String output using hardcoded bit timing
; Reads characters from memory, outputs each with 7 NOPs per bit
; Inverted data (0=SEQ, 1=REQ)
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
    ; Point R8 to string
    LDI HIGH(STRING)
    PHI 8
    LDI LOW(STRING)
    PLO 8

NEXT_CHAR:
    ; Load character
    LDA 8                   ; Get char, advance pointer
    BZ DONE_STRING          ; Zero terminator = done

    ; Store in R3.0 for output
    PLO 3

    ; === Output character in R3.0 ===

    ; Settling time
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

    ; Bit 0
    GLO 3
    SHR
    PLO 3
    LSNF                    ; Skip next if DF=0
    BR BIT0_ONE
    SEQ                     ; Bit is 0
    BR BIT0_DONE
BIT0_ONE:
    REQ                     ; Bit is 1
BIT0_DONE:
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP

    ; Bit 1
    GLO 3
    SHR
    PLO 3
    LSNF
    BR BIT1_ONE
    SEQ
    BR BIT1_DONE
BIT1_ONE:
    REQ
BIT1_DONE:
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP

    ; Bit 2
    GLO 3
    SHR
    PLO 3
    LSNF
    BR BIT2_ONE
    SEQ
    BR BIT2_DONE
BIT2_ONE:
    REQ
BIT2_DONE:
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP

    ; Bit 3
    GLO 3
    SHR
    PLO 3
    LSNF
    BR BIT3_ONE
    SEQ
    BR BIT3_DONE
BIT3_ONE:
    REQ
BIT3_DONE:
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP

    ; Bit 4
    GLO 3
    SHR
    PLO 3
    LSNF
    BR BIT4_ONE
    SEQ
    BR BIT4_DONE
BIT4_ONE:
    REQ
BIT4_DONE:
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP

    ; Bit 5
    GLO 3
    SHR
    PLO 3
    LSNF
    BR BIT5_ONE
    SEQ
    BR BIT5_DONE
BIT5_ONE:
    REQ
BIT5_DONE:
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP

    ; Bit 6
    GLO 3
    SHR
    PLO 3
    LSNF
    BR BIT6_ONE
    SEQ
    BR BIT6_DONE
BIT6_ONE:
    REQ
BIT6_DONE:
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP

    ; Bit 7
    GLO 3
    SHR
    PLO 3
    LSNF
    BR BIT7_ONE
    SEQ
    BR BIT7_DONE
BIT7_ONE:
    REQ
BIT7_DONE:
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

    ; Next character
    BR NEXT_CHAR

DONE_STRING:
    ; Pause between repeats
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
