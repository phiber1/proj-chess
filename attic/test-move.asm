; ==============================================================================
; Move Parsing Test
; ==============================================================================

    ORG $0000
    LBR MAIN

#include "serial-io.asm"
#include "board.asm"
#include "move.asm"

; ==============================================================================
; Mark Abene SCRT implementation
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

    ; Print welcome
    LDI HIGH(MSG_WELCOME)
    PHI 8
    LDI LOW(MSG_WELCOME)
    PLO 8
    SEP 4
    DW SERIAL_PRINT_STRING

    ; Initialize and display board
    SEP 4
    DW BOARD_INIT
    SEP 4
    DW BOARD_PRINT

MOVE_LOOP:
    ; Prompt for move
    LDI HIGH(MSG_PROMPT)
    PHI 8
    LDI LOW(MSG_PROMPT)
    PLO 8
    SEP 4
    DW SERIAL_PRINT_STRING

    ; Read move input
    LDI HIGH(INPUT_BUF)
    PHI 8
    LDI LOW(INPUT_BUF)
    PLO 8
    LDI 8               ; Max 8 chars
    PLO 9
    SEP 4
    DW SERIAL_READ_LINE

    ; Parse the move
    LDI HIGH(INPUT_BUF)
    PHI 8
    LDI LOW(INPUT_BUF)
    PLO 8
    SEP 4
    DW PARSE_MOVE

    ; Check if valid
    BNZ MOVE_INVALID

    ; Valid move - print confirmation
    LDI HIGH(MSG_PARSED)
    PHI 8
    LDI LOW(MSG_PARSED)
    PLO 8
    SEP 4
    DW SERIAL_PRINT_STRING

    ; Print the move back
    SEP 4
    DW PRINT_MOVE

    ; Print indices
    LDI HIGH(MSG_FROM)
    PHI 8
    LDI LOW(MSG_FROM)
    PLO 8
    SEP 4
    DW SERIAL_PRINT_STRING

    ; Print from index as hex
    LDI HIGH(MOVE_FROM)
    PHI 8
    LDI LOW(MOVE_FROM)
    PLO 8
    LDN 8
    SEP 4
    DW SERIAL_PRINT_HEX

    LDI HIGH(MSG_TO)
    PHI 8
    LDI LOW(MSG_TO)
    PLO 8
    SEP 4
    DW SERIAL_PRINT_STRING

    ; Print to index as hex
    LDI HIGH(MOVE_TO)
    PHI 8
    LDI LOW(MOVE_TO)
    PLO 8
    LDN 8
    SEP 4
    DW SERIAL_PRINT_HEX

    ; Newline
    LDI 0DH
    SEP 4
    DW SERIAL_WRITE_CHAR
    LDI 0AH
    SEP 4
    DW SERIAL_WRITE_CHAR

    BR MOVE_LOOP

MOVE_INVALID:
    LDI HIGH(MSG_INVALID)
    PHI 8
    LDI LOW(MSG_INVALID)
    PLO 8
    SEP 4
    DW SERIAL_PRINT_STRING
    BR MOVE_LOOP

; ==============================================================================
; String data
; ==============================================================================
MSG_WELCOME:
    DB "Move Parser Test", 0DH, 0AH, 0
MSG_PROMPT:
    DB "Enter move (e.g. e2e4): ", 0
MSG_PARSED:
    DB "Parsed: ", 0
MSG_FROM:
    DB " (from=", 0
MSG_TO:
    DB ", to=", 0
MSG_INVALID:
    DB "Invalid move!", 0DH, 0AH, 0

INPUT_BUF:
    DS 8

    END MAIN
