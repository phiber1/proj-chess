; ==============================================================================
; IDIOT TYPE bit logic with fixed NOP delays (no DELAY subroutine)
; Using 7 NOPs per bit like our working hardcoded 'H' test
; ==============================================================================

    ORG $0000

ASCII   EQU 15      ; RF.1 = character, RF.0 = bit count

START:
    DIS
    DB 0

    LDI HIGH(MAIN)
    PHI 3
    LDI LOW(MAIN)
    PLO 3
    SEP 3

MAIN:
    SEQ                     ; Q idle high (mark)

    ; Set up X=R2 for SD instruction
    LDI $01
    PHI 2
    LDI $FF
    PLO 2
    SEX 2

    ; Wait for keypress to start
WAIT_IDLE:
    BN3 WAIT_IDLE
WAIT_START:
    B3 WAIT_START
WAIT_DONE:
    BN3 WAIT_DONE

OUTPUT_LOOP:
    ; Load 'H' into ASCII.1
    LDI 'H'
    PHI ASCII

    ; Set up for 11 bits: 1 start + 8 data + 2 stop
    LDI $0B
    PLO ASCII

    ; Get character into RD.0
    GHI ASCII
    PLO 13

    ; Start bit (REQ = Q low = space)
    REQ
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP

NEXTBIT:
    DEC ASCII               ; Decrement bit count
    LDI 0
    SD                      ; Sets DF=1
    GLO 13                  ; Get character byte
    SHRC                    ; Shift right through carry, LSB -> DF
    PLO 13

    ; Output bit based on DF
    ; INVERTED: DF=0 -> SEQ, DF=1 -> REQ
    LSDF
    SEQ                     ; DF=0 (bit=0): Q high (inverted)
    LSKP
    REQ                     ; DF=1 (bit=1): Q low (inverted)
    NOP

    ; Delay - 9 NOPs + 2 LDIs
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    LDI 0
    LDI 0

    GLO ASCII
    ANI $0F
    BNZ NEXTBIT

    ; Character done, pause and repeat
    LDI $60
    PLO 5
PAUSE:
    DEC 5
    GLO 5
    BNZ PAUSE

    BR OUTPUT_LOOP

    END START
