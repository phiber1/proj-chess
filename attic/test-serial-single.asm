; ==============================================================================
; Serial Single Routine Test - All chars through ONE send routine
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
; Output "Hi" + CR + LF using table lookup
; R10 points to character table, loop sends each one
; ==============================================================================

MAIN_LOOP:
    LDI HIGH(CHARS)
    PHI 10
    LDI LOW(CHARS)
    PLO 10

NEXT_CHAR:
    LDA 10                  ; Get next char, increment pointer
    BZ MAIN_LOOP            ; If zero, restart
    PLO 13                  ; Store in R13.0

    ; === SEND CHARACTER IN R13.0 ===
    LDI 8
    PLO 12                  ; R12 = bit counter

    GLO 13
    SHR
    PLO 13

    ; Start bit - 9 NOPs = 232 clocks
    REQ
    NOP
    NOP
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

    ; Get next character
    BR NEXT_CHAR

; ==============================================================================
; Character table
; ==============================================================================

CHARS:
    DB $55                  ; U
    DB $41                  ; A
    DB $42                  ; B
    DB $43                  ; C
    DB $0D, $0A             ; CR LF
    DB 0                    ; terminator

    END START
