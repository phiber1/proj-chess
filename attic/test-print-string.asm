; ==============================================================================
; Print String Test - RCA 1802 Membership Card
; Tests SERIAL_PRINT_STRING routine
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
; SERIAL_PRINT_STRING - Print null-terminated string
; Input: R8 = pointer to null-terminated string
; Uses: R8 (incremented through string), D
; ==============================================================================
SERIAL_PRINT_STRING:
    LDA 8               ; Load byte from string, increment R8
    BZ PRINT_DONE       ; If null terminator, we're done
    SEP 4               ; Call SERIAL_WRITE_CHAR
    DW SERIAL_WRITE_CHAR
    BR SERIAL_PRINT_STRING  ; Next character
PRINT_DONE:
    SEP 5               ; Return

; ==============================================================================
; Chuck's serial OUTPUT routine - character in D on entry
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

    SEP 3
CALL:
    PLO 7
    GHI 6
    SEX 2
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
    GLO 7
    BR CALL-1

    SEP 3
RET:
    PLO 7
    GHI 6
    PHI 3
    GLO 6
    PLO 3
    SEX 2
    IRX
    LDXA
    PLO 6
    LDX
    PHI 6
    GLO 7
    BR RET-1

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

    ; Set Q high (idle)
    REQ

    ; Initialize R14.0 = 2 for 9600 baud
    LDI 02H
    PLO 14

    ; Print welcome message
    LDI HIGH(MSG_HELLO)
    PHI 8
    LDI LOW(MSG_HELLO)
    PLO 8
    SEP 4
    DW SERIAL_PRINT_STRING

    ; Print second message
    LDI HIGH(MSG_READY)
    PHI 8
    LDI LOW(MSG_READY)
    PLO 8
    SEP 4
    DW SERIAL_PRINT_STRING

DONE:
    BR DONE             ; Halt

; ==============================================================================
; String data
; ==============================================================================
MSG_HELLO:
    DB "Hello from 1802!", 0DH, 0AH, 0
MSG_READY:
    DB "Serial I/O ready.", 0DH, 0AH, 0

    END MAIN
