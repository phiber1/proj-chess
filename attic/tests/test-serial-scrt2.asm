; ==============================================================================
; Serial test WITH correct SCRT from scrt.asm
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
; SCRT from scrt.asm
; ==============================================================================
SCALL:
    ; Read target address from inline data (R3 points to it)
    LDA 3               ; D = high byte, R3++
    PHI 6               ; R6.1 = target high
    LDA 3               ; D = low byte, R3++
    PLO 6               ; R6.0 = target low
    ; Now R3 points to the instruction after CALL (return address)

    ; Save return address (R3) to stack
    GHI 3
    STXD                ; Push high byte
    GLO 3
    STXD                ; Push low byte
    ; Stack now has return address

    ; Set PC (R3) to target address (R6)
    GHI 6
    PHI 3
    GLO 6
    PLO 3

    ; Jump to target
    SEP 3

SRET:
    ; Restore return address from stack to R3
    IRX                 ; R2++
    LDXA                ; D = low byte, R2++
    PLO 3               ; R3.0 = return address low
    LDX                 ; D = high byte (no increment)
    PHI 3               ; R3.1 = return address high

    ; Return to caller
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
