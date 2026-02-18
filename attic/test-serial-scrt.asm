; ==============================================================================
; Serial test WITH SCRT
; ==============================================================================

    ORG $0000

    LBR START

; ==============================================================================
; Chuck's serial output routine
; ==============================================================================
SERIAL_WRITE_CHAR:
    PLO 11

B96OUT:
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
; SCRT - Standard Call/Return Technique
; ==============================================================================
SCALL:
    GHI 6
    STXD
    GLO 6
    STXD
    GHI 3
    PHI 6
    GLO 3
    PLO 6
    LDA 6
    PHI 3
    LDA 6
    PLO 3
    SEP 3

SRET:
    GHI 6
    PHI 3
    GLO 6
    PLO 3
    IRX
    LDXA
    PLO 6
    LDX
    PHI 6
    SEP 3

; ==============================================================================
; Main
; ==============================================================================
START:
    ; Set up stack pointer (R2)
    LDI $7F
    PHI 2
    LDI $FF
    PLO 2
    SEX 2

    ; Set up SCRT
    LDI HIGH(SCALL)
    PHI 4
    LDI LOW(SCALL)
    PLO 4

    LDI HIGH(SRET)
    PHI 5
    LDI LOW(SRET)
    PLO 5

    ; Initialize R14.0 = 2 for 9600 baud
    LDI 02H
    PLO 14

    ; Set Q high (idle)
    SEQ

LOOP:
    ; Output 'H' using SCRT call
    LDI 48H
    SEP 4
    DB HIGH(SERIAL_WRITE_CHAR), LOW(SERIAL_WRITE_CHAR)

    BR LOOP

    END START
