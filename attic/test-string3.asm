; ==============================================================================
; String output - match hardcoded timing exactly
; 7 NOPs (168 clocks) after each SEQ/REQ
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
    PLO 3                   ; R3.0 = character

    ; Settling time
    SEQ
    NOP
    NOP

    ; Start bit - 7 NOPs
    REQ
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP

    ; === Bit 0 ===
    GLO 3
    SHR
    PLO 3
    BDF B0_ONE
    SEQ
    BR B0_DONE
B0_ONE:
    REQ
    BR B0_DONE
B0_DONE:
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP

    ; === Bit 1 ===
    GLO 3
    SHR
    PLO 3
    BDF B1_ONE
    SEQ
    BR B1_DONE
B1_ONE:
    REQ
    BR B1_DONE
B1_DONE:
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP

    ; === Bit 2 ===
    GLO 3
    SHR
    PLO 3
    BDF B2_ONE
    SEQ
    BR B2_DONE
B2_ONE:
    REQ
    BR B2_DONE
B2_DONE:
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP

    ; === Bit 3 ===
    GLO 3
    SHR
    PLO 3
    BDF B3_ONE
    SEQ
    BR B3_DONE
B3_ONE:
    REQ
    BR B3_DONE
B3_DONE:
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP

    ; === Bit 4 ===
    GLO 3
    SHR
    PLO 3
    BDF B4_ONE
    SEQ
    BR B4_DONE
B4_ONE:
    REQ
    BR B4_DONE
B4_DONE:
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP

    ; === Bit 5 ===
    GLO 3
    SHR
    PLO 3
    BDF B5_ONE
    SEQ
    BR B5_DONE
B5_ONE:
    REQ
    BR B5_DONE
B5_DONE:
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP

    ; === Bit 6 ===
    GLO 3
    SHR
    PLO 3
    BDF B6_ONE
    SEQ
    BR B6_DONE
B6_ONE:
    REQ
    BR B6_DONE
B6_DONE:
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP

    ; === Bit 7 ===
    GLO 3
    SHR
    PLO 3
    BDF B7_ONE
    SEQ
    BR B7_DONE
B7_ONE:
    REQ
    BR B7_DONE
B7_DONE:
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP

    ; Stop bit - 7 NOPs
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
