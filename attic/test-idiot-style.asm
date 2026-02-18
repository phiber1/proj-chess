; ==============================================================================
; String output using IDIOT-style timing
; Based on IDIOT monitor TYPE routine analysis
; QHI=0 means: REQ for start/space(0), SEQ for mark(1)
; Wait 1 bit time between bits using fixed delay
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
    PLO 3                   ; R3.0 = character to send

    LDI 11                  ; 11 bits: 1 start + 8 data + 2 stop
    PLO 4                   ; R4.0 = bit counter

    ; Start bit - REQ (Q low = space)
    REQ

NEXTBIT:
    ; Delay 1 bit time - like IDIOT does
    ; IDIOT uses SEP DELAY with DB 7, which does complex loop
    ; We'll use fixed NOPs - 7 NOPs = ~184 clocks at 1.75MHz for 9600 baud
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP                     ; 6 NOPs like IDIOT equalizer

    DEC 4                   ; Decrement bit count
    LDI 0                   ; Set DF=1 for SD
    SD                      ; D = M(X) - D - DF, sets DF=1

    GLO 3                   ; Get character
    SHRC                    ; Shift right through carry, LSB -> DF
    PLO 3                   ; Save shifted character

    LSDF                    ; Skip if DF=1 (bit was 1)
    REQ                     ; Bit=0: Q low (space)
    LSKP
    SEQ                     ; Bit=1: Q high (mark)
    NOP                     ; Equalize

    GLO 4                   ; Get bit count
    ANI $0F                 ; Mask low 4 bits
    BNZ NEXTBIT             ; Continue if more bits

    ; Character done, next one
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
