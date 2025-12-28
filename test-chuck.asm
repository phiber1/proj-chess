; ==============================================================================
; Test based on Chuck Yakym's 9600 baud output routine
; Adapted for 1.75 MHz Membership Card
; Q non-inverted: SEQ = Q high = mark = 1, REQ = Q low = space = 0
; EF3 inverted: EF3 high = idle, EF3 low = active
; ==============================================================================

    ORG $0000

; Register numbers
; R11 = Character to output
; R14 = Delay counter
; R15 = Bit counter

START:
    SEQ                     ; Q idle high (mark)
    ; Skip DIS - may cause issues if X not set up

    ; Initialize delay counter for 9600 baud
    LDI $01
    PLO 14                  ; R14.0 = 1 for 9600 baud

; Skip calibration - just start outputting

; ==============================================================================
; Main loop - output 'V' repeatedly
; ==============================================================================

MAIN_LOOP:
    LDI $56                 ; 'V'
    PLO 11

    ; Call output routine (inline for now)

; ==============================================================================
; Chuck's B96OUT - INVERTED LOGIC output routine
; REQ = start bit, SEQ = mark/1
; ==============================================================================

B96OUT:
    LDI $08
    PLO 15                  ; R15.0 = 8 bits

STBIT:
    REQ                     ; 1   START BIT
    NOP                     ; 2.5
    GLO 11                  ; 3.5
    SHR                     ; 4.5  First shift uses SHR to clear DF first
    PLO 11                  ; 5.5
    NOP                     ; 7
    NOP                     ; 8.5
    NOP                     ; 10 INSTRUCTIONS SINCE START BIT

    ; DETERMINE FIRST BIT AND OUTPUT IT
    BDF STBIT1              ; DF = 1, IF BIT IS HIGH THEN JUMP
    BR QLO                  ; JUMP AT 11.5 INSTRUCTION TIME, Q=OFF (0)

STBIT1:
    BR QHI                  ; JUMP AT 11.5 INSTRUCTION TIME, Q=ON (1)


QLO1:
    DEC 15
    GLO 15
    BZ DONE96               ; AT 8.5 INSTRUCTIONS EITHER DONE OR REQ

    ; DELAY
    GLO 14
LDELAY:
    SMI $01
    BZ QLO                  ; IF DELAY IS DONE THEN TURN Q OFF
    ; WASTE 9.5 INSTRUCTION TIMES
    NOP                     ; 1.5
    NOP                     ; 3
    NOP                     ; 4.5
    NOP                     ; 6
    NOP                     ; 7.5
    SEX 2                   ; 8.5
    BR LDELAY               ; AT 9.5 INSTRUCTION TIMES JUMP TO LDELAY

QLO:
    REQ                     ; Q OFF (bit = 0)
    GLO 11
    SHR                     ; PUT NEXT BIT IN DF
    PLO 11
    LBNF QLO1               ; 5.5 TURN Q OFF AFTER 6 MORE INSTRUCTION TIMES

QHI1:
    DEC 15
    GLO 15
    BZ DONE96               ; AT 8.5 INSTRUCTIONS EITHER DONE OR SEQ

    ; DELAY
    GLO 14
HDELAY:
    SMI $01
    BZ QHI                  ; IF DELAY IS DONE THEN TURN Q ON
    ; WASTE 9.5 INSTRUCTION TIMES
    NOP                     ; 1.5
    NOP                     ; 3
    NOP                     ; 4.5
    NOP                     ; 6
    NOP                     ; 7.5
    SEX 2                   ; 8.5
    BR HDELAY               ; AT 9.5 INSTRUCTION TIMES JUMP TO HDELAY

    ; BIT IS HI 11.5 INSTRUCTIONS TURN Q ON
QHI:
    SEQ                     ; Q ON (bit = 1)
    GLO 11
    SHR                     ; PUT NEXT BIT IN DF
    PLO 11
    LBDF QHI1               ; 5.5 TURN Q ON AFTER 6 MORE INSTRUCTION TIMES

    DEC 15
    GLO 15
    BZ DONE96               ; AT 8.5 INSTRUCTIONS EITHER DONE OR REQ

    ; DELAY
    GLO 14
XDELAY:
    SMI $01
    BZ QLO                  ; IF DELAY IS DONE THEN TURN Q OFF
    ; WASTE 9.5 INSTRUCTION TIMES
    NOP                     ; 1.5
    NOP                     ; 3
    NOP                     ; 4.5
    NOP                     ; 6
    NOP                     ; 7.5
    SEX 2                   ; 8.5
    BR XDELAY               ; AT 9.5 INSTRUCTION TIMES JUMP TO XDELAY

    ; FINISH LAST BIT TIMING
DONE96:
    GLO 14
    GLO 14
    GLO 14

DNE961:
    SEQ                     ; 1 SEND STOP BIT
    NOP                     ; 2.5
    NOP                     ; 4
    NOP                     ; 5.5
    NOP                     ; 7
    NOP                     ; 8.5
    SEX 2                   ; 9.5
    SMI $01                 ; 10.5
    BNZ DNE961              ; 11.5

    ; Pause between characters
    LDI $40
    PLO 7
PAUSE:
    DEC 7
    GLO 7
    BNZ PAUSE

    BR MAIN_LOOP

    END START
