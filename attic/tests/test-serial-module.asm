; ==============================================================================
; Comprehensive Serial I/O Module Test
; Tests all routines in serial-io.asm
; ==============================================================================

    ORG $0000
    LBR MAIN

#include "serial-io.asm"

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
    ; Set R6 to continue after INITCALL
    LDI HIGH(START)
    PHI 6
    LDI LOW(START)
    PLO 6
    LBR INITCALL

START:
    ; Stack setup
    LDI $7F
    PHI 2
    LDI $FF
    PLO 2
    SEX 2

    REQ                 ; Q idle
    LDI 02H
    PLO 14              ; Baud rate

    ; ==========================================
    ; TEST 1: SERIAL_PRINT_STRING
    ; ==========================================
    LDI HIGH(MSG_BANNER)
    PHI 8
    LDI LOW(MSG_BANNER)
    PLO 8
    SEP 4
    DW SERIAL_PRINT_STRING

    ; ==========================================
    ; TEST 2: SERIAL_PRINT_HEX
    ; ==========================================
    LDI HIGH(MSG_HEX)
    PHI 8
    LDI LOW(MSG_HEX)
    PLO 8
    SEP 4
    DW SERIAL_PRINT_STRING

    ; Test values: 00, 5A, A5, FF
    LDI 00H
    SEP 4
    DW SERIAL_PRINT_HEX
    LDI ' '
    SEP 4
    DW SERIAL_WRITE_CHAR

    LDI 5AH
    SEP 4
    DW SERIAL_PRINT_HEX
    LDI ' '
    SEP 4
    DW SERIAL_WRITE_CHAR

    LDI 0A5H
    SEP 4
    DW SERIAL_PRINT_HEX
    LDI ' '
    SEP 4
    DW SERIAL_WRITE_CHAR

    LDI 0FFH
    SEP 4
    DW SERIAL_PRINT_HEX

    ; Newline
    LDI 0DH
    SEP 4
    DW SERIAL_WRITE_CHAR
    LDI 0AH
    SEP 4
    DW SERIAL_WRITE_CHAR

    ; ==========================================
    ; TEST 3: SERIAL_READ_CHAR + SERIAL_WRITE_CHAR (echo)
    ; ==========================================
    LDI HIGH(MSG_ECHO)
    PHI 8
    LDI LOW(MSG_ECHO)
    PLO 8
    SEP 4
    DW SERIAL_PRINT_STRING

    ; Echo 5 characters
    LDI 5
    PLO 10              ; Counter in R10.0

ECHO_LOOP:
    SEP 4
    DW SERIAL_READ_CHAR
    SEP 4
    DW SERIAL_WRITE_CHAR
    DEC 10
    GLO 10
    BNZ ECHO_LOOP

    ; Newline
    LDI 0DH
    SEP 4
    DW SERIAL_WRITE_CHAR
    LDI 0AH
    SEP 4
    DW SERIAL_WRITE_CHAR

    ; ==========================================
    ; TEST 4: SERIAL_READ_LINE (loop)
    ; ==========================================
LINE_TEST:
    LDI HIGH(MSG_LINE)
    PHI 8
    LDI LOW(MSG_LINE)
    PLO 8
    SEP 4
    DW SERIAL_PRINT_STRING

    ; Read line into buffer
    LDI HIGH(INPUT_BUF)
    PHI 8
    LDI LOW(INPUT_BUF)
    PLO 8
    LDI 16
    PLO 9
    SEP 4
    DW SERIAL_READ_LINE

    ; Print "You typed: "
    LDI HIGH(MSG_TYPED)
    PHI 8
    LDI LOW(MSG_TYPED)
    PLO 8
    SEP 4
    DW SERIAL_PRINT_STRING

    ; Print the input
    LDI HIGH(INPUT_BUF)
    PHI 8
    LDI LOW(INPUT_BUF)
    PLO 8
    SEP 4
    DW SERIAL_PRINT_STRING

    ; Newline
    LDI 0DH
    SEP 4
    DW SERIAL_WRITE_CHAR
    LDI 0AH
    SEP 4
    DW SERIAL_WRITE_CHAR

    ; Loop back for more line input
    BR LINE_TEST

; ==============================================================================
; String data
; ==============================================================================
MSG_BANNER:
    DB "=== Serial I/O Module Test ===", 0DH, 0AH, 0
MSG_HEX:
    DB "Hex test: ", 0
MSG_ECHO:
    DB "Type 5 chars: ", 0
MSG_LINE:
    DB "> ", 0
MSG_TYPED:
    DB "You typed: ", 0

INPUT_BUF:
    DS 16

    END MAIN
