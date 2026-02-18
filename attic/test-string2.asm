; ==============================================================================
; String output - simpler approach
; Read char, shift out bits with consistent timing
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
    BR B0_DELAY
B0_ONE:
    REQ
    NOP                     ; Equalize path length
B0_DELAY:
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
    BR B1_DELAY
B1_ONE:
    REQ
    NOP
B1_DELAY:
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
    BR B2_DELAY
B2_ONE:
    REQ
    NOP
B2_DELAY:
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
    BR B3_DELAY
B3_ONE:
    REQ
    NOP
B3_DELAY:
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
    BR B4_DELAY
B4_ONE:
    REQ
    NOP
B4_DELAY:
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
    BR B5_DELAY
B5_ONE:
    REQ
    NOP
B5_DELAY:
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
    BR B6_DELAY
B6_ONE:
    REQ
    NOP
B6_DELAY:
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
    BR B7_DELAY
B7_ONE:
    REQ
    NOP
B7_DELAY:
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
