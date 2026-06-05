; ==============================================================================
; Print Hex Test - RCA 1802 Membership Card
; Tests SERIAL_PRINT_HEX routine
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
; SERIAL_PRINT_HEX - Print byte as two hex digits
; Input: D = byte to print
; Uses: R9.0 (saved byte), D
; ==============================================================================
SERIAL_PRINT_HEX:
    PLO 9               ; Save byte in R9.0

    ; Print high nibble
    SHR                 ; Shift right 4 times
    SHR
    SHR
    SHR
    SEP 4
    DW PRINT_NIBBLE

    ; Print low nibble
    GLO 9               ; Get original byte
    ANI 0FH             ; Mask low nibble
    SEP 4
    DW PRINT_NIBBLE

    SEP 5               ; Return

; ==============================================================================
; PRINT_NIBBLE - Print single hex digit (0-F)
; Input: D = value 0-15
; ==============================================================================
PRINT_NIBBLE:
    SMI 10              ; Is it >= 10?
    BDF NIBBLE_AF       ; Yes, it's A-F
    ADI 10+'0'          ; No, restore and add '0' (10 + 48 = 58, but we subtracted 10, so 48)
    SEP 4
    DW SERIAL_WRITE_CHAR
    SEP 5

NIBBLE_AF:
    ADI 'A'             ; Add 'A' (we already subtracted 10, so this gives 'A'-'F')
    SEP 4
    DW SERIAL_WRITE_CHAR
    SEP 5

; ==============================================================================
; SERIAL_PRINT_STRING - Print null-terminated string
; Input: R8 = pointer to null-terminated string
; ==============================================================================
SERIAL_PRINT_STRING:
    LDA 8
    BZ PRINT_STR_DONE
    SEP 4
    DW SERIAL_WRITE_CHAR
    BR SERIAL_PRINT_STRING
PRINT_STR_DONE:
    SEP 5

; ==============================================================================
; Chuck's serial OUTPUT routine - character in D on entry
; ==============================================================================
SERIAL_WRITE_CHAR:
    PLO 11

B96OUT:
    LDI 02H
    PLO 14

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

    SEP 5

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

    ; Print label
    LDI HIGH(MSG_TEST)
    PHI 8
    LDI LOW(MSG_TEST)
    PLO 8
    SEP 4
    DW SERIAL_PRINT_STRING

    ; Test 1: Print 00
    LDI 00H
    SEP 4
    DW SERIAL_PRINT_HEX

    LDI ' '
    SEP 4
    DW SERIAL_WRITE_CHAR

    ; Test 2: Print 42
    LDI 42H
    SEP 4
    DW SERIAL_PRINT_HEX

    LDI ' '
    SEP 4
    DW SERIAL_WRITE_CHAR

    ; Test 3: Print 9A
    LDI 9AH
    SEP 4
    DW SERIAL_PRINT_HEX

    LDI ' '
    SEP 4
    DW SERIAL_WRITE_CHAR

    ; Test 4: Print FF
    LDI 0FFH
    SEP 4
    DW SERIAL_PRINT_HEX

    ; Print newline
    LDI 0DH
    SEP 4
    DW SERIAL_WRITE_CHAR
    LDI 0AH
    SEP 4
    DW SERIAL_WRITE_CHAR

    ; Print done message
    LDI HIGH(MSG_DONE)
    PHI 8
    LDI LOW(MSG_DONE)
    PLO 8
    SEP 4
    DW SERIAL_PRINT_STRING

DONE:
    BR DONE

; ==============================================================================
; String data
; ==============================================================================
MSG_TEST:
    DB "Hex test: ", 0
MSG_DONE:
    DB "Done!", 0DH, 0AH, 0

    END MAIN
