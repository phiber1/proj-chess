; ==============================================================================
; Serial Loop Test - Output 4 characters using a single send routine
; For 1.75 MHz Membership Card
; ==============================================================================

    ORG $0000

START:
    DIS                     ; Disable interrupts
    SEQ                     ; Q idle high

; ==============================================================================
; AUTO-BAUD CALIBRATION
; ==============================================================================

WAIT_IDLE:
    B3 WAIT_IDLE
WAIT_LOW_BITS:
    BN3 WAIT_LOW_BITS

    LDI $00
MEASURE_LOOP:
    ADI $01
    B3 MEASURE_LOOP

    PLO 15
    SMI 3
    PLO 15

WAIT_HIGH_BITS:
    BN3 WAIT_HIGH_BITS

; ==============================================================================
; Output 4 U's then CR/LF using same send routine
; ==============================================================================

MAIN_LOOP:
    ; Send 4 U characters
    LDI 4
    PLO 14                  ; R14 = character counter

CHAR_LOOP:
    LDI $55                 ; 'U'
    PLO 13                  ; R13.0 = byte to send

    ; === SEND ONE CHARACTER ===
    LDI 8
    PLO 12                  ; R12 = bit counter

    GLO 13
    SHR
    PLO 13

    ; Start bit
    REQ
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP

SEND_BIT:
    BDF BIT_ONE
    REQ
    BR BIT_DELAY
BIT_ONE:
    SEQ
    BR BIT_DELAY
BIT_DELAY:
    NOP
    NOP
    GLO 13
    SHR
    PLO 13
    DEC 12
    GLO 12
    BNZ SEND_BIT

    ; Stop bit
    SEQ
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP

    ; Inter-character pause
    LDI $40
    PLO 7
PAUSE:
    DEC 7
    GLO 7
    BNZ PAUSE

    ; Next character
    DEC 14
    GLO 14
    BNZ CHAR_LOOP

    ; Pause before CR
    LDI $40
    PLO 7
PAUSE_CR:
    DEC 7
    GLO 7
    BNZ PAUSE_CR

    ; Send CR
    LDI $0D
    PLO 13
    LDI 8
    PLO 12
    GLO 13
    SHR
    PLO 13
    REQ
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP

SEND_BIT_CR:
    BDF BIT_ONE_CR
    REQ
    BR BIT_DELAY_CR
BIT_ONE_CR:
    SEQ
    BR BIT_DELAY_CR
BIT_DELAY_CR:
    NOP
    NOP
    GLO 13
    SHR
    PLO 13
    DEC 12
    GLO 12
    BNZ SEND_BIT_CR

    SEQ
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP

    ; Pause before LF
    LDI $40
    PLO 7
PAUSE_LF:
    DEC 7
    GLO 7
    BNZ PAUSE_LF

    ; Send LF
    LDI $0A
    PLO 13
    LDI 8
    PLO 12
    GLO 13
    SHR
    PLO 13
    REQ
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP

SEND_BIT_LF:
    BDF BIT_ONE_LF
    REQ
    BR BIT_DELAY_LF
BIT_ONE_LF:
    SEQ
    BR BIT_DELAY_LF
BIT_DELAY_LF:
    NOP
    NOP
    GLO 13
    SHR
    PLO 13
    DEC 12
    GLO 12
    BNZ SEND_BIT_LF

    SEQ
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP

    ; Long pause between lines
    LDI $FF
    PLO 7
PAUSE2:
    DEC 7
    GLO 7
    BNZ PAUSE2

    BR MAIN_LOOP

    END START
