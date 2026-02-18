; ==============================================================================
; Serial test WITHOUT SCRT - direct calls to Chuck's routine
; ==============================================================================

    ORG $0000

START:
    ; Set up stack pointer (R2)
    LDI $7F
    PHI 2
    LDI $FF
    PLO 2
    SEX 2

    ; Initialize R14.0 = 2 for 9600 baud
    LDI 02H
    PLO 14

    ; Set Q high (idle)
    SEQ

    ; Load 'H' to output
    LDI 48H
    PLO 11

    ; Fall through to B96OUT

; ==============================================================================
; Chuck's serial output routine - outputs character in R11.0
; ==============================================================================
B96OUT:
    LDI 08H
    PLO 15

    GLO 11
    STR 2
    DEC 2
    GLO 13
    STR 2
    DEC 2

    DEC 14              ; Set delay counter = 1

STBIT:
    SEQ                 ; Q OFF = start bit
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

    ; Loop back to output 'H' again
    LDI 48H
    PLO 11
    BR B96OUT

    END START
