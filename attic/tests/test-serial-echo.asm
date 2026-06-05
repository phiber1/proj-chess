; ==============================================================================
; Serial Echo Test - RCA 1802 Membership Card
; Uses Chuck Yakym's B96IN (inverted EF3) and B96OUT routines
; 9600 baud at 1.75 MHz
; ==============================================================================

    ORG $0000

; ==============================================================================
; Entry point - set R6 to main, then jump to INITCALL
; ==============================================================================
    LDI HIGH(MAIN)
    PHI 6
    LDI LOW(MAIN)
    PLO 6
    LBR INITCALL

; ==============================================================================
; Chuck's serial INPUT routine (Inverted EF3 logic)
; Returns received character in D
; R11.0 = received character (shift register)
; R14.0 = delay counter (must be 2 on entry)
; ==============================================================================
SERIAL_READ_CHAR:
B96IN:
    B3 B96IN            ; WAIT FOR STOP BIT (EF3 HIGH = idle)

    LDI 0FFH            ; INITIALIZE INPUT CHARACTER TO FFh
    PLO 11              ; STORE IT IN R11.0
    GLO 14              ; GET DELAY COUNT

B96IN1:
    BN3 B96IN1          ; WAIT FOR START BIT (EF3 LOW = start)

    SHR                 ; DELAY COUNTER DIVIDED BY 2 (.5 BIT TIME VALUE)
    SKP                 ; SKIP TO DELAY

B96IN2:
    GLO 14              ; GET DELAY COUNT
B96IN3:
    SMI 01H             ; DECREMENT DELAY COUNT
    BNZ B96IN3          ; WHEN DONE WITH DELAY D=0 AND DF=1

    B3 B96IN4           ; GET NEXT BIT
    SKP                 ; IF BIT=0 (EF3 PIN HIGH), LEAVE DF=0
B96IN4:
    SHR                 ; IF BIT=1 (EF3 PIN LOW), SET DF=1
    GLO 11              ; GET INCOMING BYTE
    SHRC                ; RING SHIFT BIT RIGHT
    PLO 11              ; STORE BYTE IN R11.0
    LBDF B96IN2         ; IF DF=1, START BIT HASN'T SHIFTED ALL THE WAY THRU

    ; DELAY BETWEEN LAST BIT AND THE STOP BIT
    GLO 14
B96IN5:
    SMI 1               ; DECREMENT DELAY COUNT
    BNZ B96IN5

    GLO 11              ; Return received character in D
    GLO 11              ; (extra timing)
    SEP 5               ; RETURN via SCRT

; ==============================================================================
; Chuck's serial OUTPUT routine - character in D on entry
; R11.0 = character to output (shift register)
; R14.0 = delay counter (hardcoded to 2)
; R15.0 = bit counter
; R13.0 = saved/restored
; ==============================================================================
SERIAL_WRITE_CHAR:
    PLO 11

B96OUT:
    LDI 02H
    PLO 14              ; R14.0 = 2 for 9600 baud (hardcoded)

    LDI 08H
    PLO 15

    GLO 11
    STR 2
    DEC 2
    GLO 13
    STR 2
    DEC 2

    DEC 14

STBIT:
    SEQ
    NOP
    NOP
    GLO 11
    SHRC
    PLO 11
    PLO 11
    NOP

    BDF STBIT1
    BR QLO

STBIT1:
    BR QHI

QLO1:
    DEC 15
    GLO 15
    BZ DONE96

    GLO 14
LDELAY:
    SMI 01H
    BZ QLO
    NOP
    NOP
    NOP
    NOP
    NOP
    SEX 2
    BR LDELAY

QLO:
    SEQ
    GLO 11
    SHRC
    PLO 11
    LBNF QLO1

QHI1:
    DEC 15
    GLO 15
    BZ DONE96

    GLO 14
HDELAY:
    SMI 01H
    BZ QHI
    NOP
    NOP
    NOP
    NOP
    NOP
    SEX 2
    BR HDELAY

QHI:
    REQ
    GLO 11
    SHRC
    PLO 11
    LBDF QHI1

    DEC 15
    GLO 15
    BZ DONE96

    GLO 14
XDELAY:
    SMI 01H
    BZ QLO
    NOP
    NOP
    NOP
    NOP
    NOP
    SEX 2
    BR XDELAY

DONE96:
    GLO 14
    GLO 14
    GLO 14

DNE961:
    REQ
    NOP
    NOP
    NOP
    NOP
    NOP
    SEX 2
    SMI 01H
    BNZ DNE961

    INC 2
    LDN 2
    PLO 13
    INC 2
    LDN 2
    PLO 11

    LDI 02H
    PLO 14

    SEP 5               ; Return via SCRT

; ==============================================================================
; Mark Abene's SCRT implementation
; ==============================================================================

; INITIALIZE SCRT
INITCALL:
    LDI HIGH(RET)
    PHI 5
    LDI LOW(RET)
    PLO 5
    LDI HIGH(CALL)
    PHI 4
    LDI LOW(CALL)
    PLO 4
    SEP 5

; SCRT CALL
    SEP 3               ; JUMP TO CALLED ROUTINE
CALL:
    PLO 7               ; SAVE D (using R7.0 as temp - R14 used by serial)
    GHI 6               ; SAVE LAST R6 TO STACK
    SEX 2
    STXD
    GLO 6
    STXD
    GHI 3               ; COPY R3 TO R6
    PHI 6
    GLO 3
    PLO 6
    LDA 6               ; GET SUBROUTINE ADDRESS
    PHI 3               ; AND PUT INTO R3
    LDA 6
    PLO 3
    GLO 7               ; RECOVER D
    BR CALL-1           ; TRANSFER CONTROL TO SUBROUTINE

; SCRT RET
    SEP 3               ; TRANSFER CONTROL BACK TO CALLER
RET:
    PLO 7               ; SAVE D
    GHI 6               ; COPY R6 TO R3
    PHI 3
    GLO 6
    PLO 3
    SEX 2
    IRX                 ; POINT TO OLD R6
    LDXA
    PLO 6
    LDX
    PHI 6
    GLO 7
    BR RET-1            ; AND PERFORM RETURN TO CALLER

; ==============================================================================
; Main program - Echo loop
; ==============================================================================
MAIN:
    ; Set up stack pointer (R2)
    LDI $7F
    PHI 2
    LDI $FF
    PLO 2
    SEX 2

    ; Set Q high (idle) - REQ = Q ON = mark = idle
    REQ

    ; Initialize R14.0 = 2 for 9600 baud
    LDI 02H
    PLO 14

ECHO_LOOP:
    ; Read a character (returns in D)
    SEP 4
    DW SERIAL_READ_CHAR

    ; Echo it back (D still has the character)
    SEP 4
    DW SERIAL_WRITE_CHAR

    BR ECHO_LOOP

    END MAIN
