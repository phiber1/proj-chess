; ==============================================================================
; Serial String Test - Output "Hello, world!" at 9600 baud
; For 1.75 MHz Membership Card
; ==============================================================================

    ORG $0000

; Register usage:
; R3 = Program counter (after SCRT setup)
; R10 = String pointer
; R12 = Bit counter
; R13 = Current byte being sent

START:
    DIS                     ; Disable interrupts
    SEQ                     ; Q idle high

    ; Initial delay to let line settle
    LDI $FF
    PLO 7
INIT_DELAY:
    DEC 7
    GLO 7
    BNZ INIT_DELAY

; ==============================================================================
; Output the string repeatedly
; ==============================================================================

MAIN_LOOP:
    ; Point R10 to the message string
    LDI HIGH(MESSAGE)
    PHI 10
    LDI LOW(MESSAGE)
    PLO 10

STRING_LOOP:
    ; Load next character
    LDA 10                  ; D = M(R10), R10++
    BZ MAIN_LOOP            ; If null terminator, restart

    ; Send the character in D
    PLO 13                  ; R13.0 = byte to send
    LDI 8
    PLO 12                  ; R12 = bit counter

    ; Prepare first bit before starting
    GLO 13                  ; Get byte
    SHR                     ; Shift right, LSB -> DF
    PLO 13                  ; Save shifted byte

    ; Start bit (Q = 0) - 184 clocks
    REQ                     ; Start bit begins (16 clocks)
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP                     ; 184 clocks for start bit

SEND_BIT:
    ; Set Q for this bit (DF has the bit value from previous shift)
    BDF BIT_ONE
    REQ                     ; Bit is 0 (16 clocks)
    BR BIT_DELAY            ; 16 clocks - total 32
BIT_ONE:
    SEQ                     ; Bit is 1 (16 clocks)
    BR BIT_DELAY            ; 16 clocks - total 32 (matched!)
BIT_DELAY:
    ; Total: 192 clocks (5% slow, within tolerance)
    NOP
    NOP
    ; Prepare next bit while still in this bit's time slot
    GLO 13
    SHR
    PLO 13
    ; Check bit counter
    DEC 12
    GLO 12
    BNZ SEND_BIT

    ; Stop bit (Q = 1) - 184 clocks
    SEQ
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP                     ; 184 clocks

    ; Brief inter-character delay
    LDI $10
    PLO 7
CHAR_PAUSE:
    DEC 7
    GLO 7
    BNZ CHAR_PAUSE

    ; Next character
    BR STRING_LOOP

; ==============================================================================
; Message string (null terminated)
; ==============================================================================

MESSAGE:
    DB "Hello!", $0D, $0A, 0

    END START
