; ==============================================================================
; Minimal 1802 Test Program for Emma02/VELF
; ==============================================================================
; This minimal program tests basic execution and serial output
; ==============================================================================

    ORG $0000

START:
    DIS                 ; Disable interrupts

    ; Set up stack (R2)
    LDI $7F
    PHI 2
    LDI $FF
    PLO 2              ; R2 = $7FFF

    ; Output 'H' character
    LDI 'H'
    PHI 13              ; Save in D

OUTPUT_CHAR:
    ; Bit-bang serial output using Q
    ; This outputs one character at 9600 baud (approx)

    ; Start bit (0)
    REQ                ; Q = 0
    CALL DELAY

    ; Output 8 data bits (LSB first)
    GLO 13              ; Get character
    PLO 8              ; Save in R8.0

    LDI 8              ; 8 bits to send
    PLO 9

BIT_LOOP:
    GLO 8              ; Get current byte
    SHR                ; Shift right, bit 0 -> DF
    PLO 8              ; Save shifted byte

    BNF BIT_ZERO
    SEQ                ; Bit was 1, set Q
    BR BIT_NEXT

BIT_ZERO:
    REQ                ; Bit was 0, reset Q

BIT_NEXT:
    CALL DELAY         ; Wait one bit time

    DEC 9              ; Decrement bit counter
    GLO 9
    BNZ BIT_LOOP       ; More bits to send

    ; Stop bit (1)
    SEQ                ; Q = 1
    CALL DELAY
    CALL DELAY         ; Extra stop bit time

    ; Output 'i'
    LDI 'i'
    PLO 13
    CALL OUTPUT_CHAR_SUB

    ; Output '!'
    LDI '!'
    PLO 13
    CALL OUTPUT_CHAR_SUB

    ; Output newline
    LDI 13
    PLO 13
    CALL OUTPUT_CHAR_SUB

    LDI 10
    PLO 13
    CALL OUTPUT_CHAR_SUB

DONE:
    ; Infinite loop
    BR DONE

; Subroutine version of output
OUTPUT_CHAR_SUB:
    PHI 13              ; Save char

    ; Start bit
    REQ
    CALL DELAY

    ; 8 data bits
    GLO 13
    PLO 8

    LDI 8
    PLO 9

SUB_BIT_LOOP:
    GLO 8
    SHR
    PLO 8

    BNF SUB_BIT_ZERO
    SEQ
    BR SUB_BIT_NEXT

SUB_BIT_ZERO:
    REQ

SUB_BIT_NEXT:
    CALL DELAY

    DEC 9
    GLO 9
    BNZ SUB_BIT_LOOP

    ; Stop bit
    SEQ
    CALL DELAY

    RETN

; Delay for one bit time (9600 baud @ 12 MHz = 312 cycles)
; For emulator, use shorter delay or none at all
DELAY:
    LDI 0              ; Short delay for emulator
    PLO 10
DELAY_LOOP:
    DEC 10
    GLO 10
    BNZ DELAY_LOOP
    RETN

    END
