; ==============================================================================
; Serial test using Mark Abene's SCRT implementation
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
; Chuck's serial output routine - character in D on entry
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
; Main program
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

LOOP:
    ; Output 'H' using SCRT call
    LDI 48H             ; 'H'
    SEP 4
    DW SERIAL_WRITE_CHAR

    BR LOOP

    END MAIN
