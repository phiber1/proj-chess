; ==============================================================================
; Make/Unmake Move Test
; ==============================================================================

    ORG $0000
    LBR STARTUP

; Serial I/O must come first - timing critical code with short branches
#include "serial-io.asm"

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

STARTUP:
    LDI HIGH(MAIN)
    PHI 6
    LDI LOW(MAIN)
    PLO 6
    LBR INITCALL

; Other modules after SCRT
#include "board.asm"
#include "move.asm"
#include "makemove.asm"

; ==============================================================================
; Main program
; ==============================================================================
MAIN:
    ; Stack setup
    LDI $7F
    PHI 2
    LDI $FF
    PLO 2
    SEX 2

    REQ
    LDI 02H
    PLO 14

    ; Print welcome
    LDI HIGH(MSG_WELCOME)
    PHI 8
    LDI LOW(MSG_WELCOME)
    PLO 8
    SEP 4
    DW SERIAL_PRINT_STRING

    ; Initialize board
    SEP 4
    DW BOARD_INIT

GAME_LOOP:
    ; Show board
    SEP 4
    DW BOARD_PRINT

    ; Prompt for move
    LDI HIGH(MSG_MOVE)
    PHI 8
    LDI LOW(MSG_MOVE)
    PLO 8
    SEP 4
    DW SERIAL_PRINT_STRING

    ; Read input
    LDI HIGH(INPUT_BUF)
    PHI 8
    LDI LOW(INPUT_BUF)
    PLO 8
    LDI 8
    PLO 9
    SEP 4
    DW SERIAL_READ_LINE

    ; Check for 'u' (undo)
    LDI HIGH(INPUT_BUF)
    PHI 8
    LDI LOW(INPUT_BUF)
    PLO 8
    LDN 8
    SMI 'u'
    BZ DO_UNDO

    ; Parse move
    LDI HIGH(INPUT_BUF)
    PHI 8
    LDI LOW(INPUT_BUF)
    PLO 8
    SEP 4
    DW PARSE_MOVE
    BNZ INVALID_MOVE

    ; Make the move
    SEP 4
    DW MAKE_MOVE

    ; Show what we did
    LDI HIGH(MSG_MADE)
    PHI 8
    LDI LOW(MSG_MADE)
    PLO 8
    SEP 4
    DW SERIAL_PRINT_STRING

    SEP 4
    DW PRINT_MOVE

    LDI 0DH
    SEP 4
    DW SERIAL_WRITE_CHAR
    LDI 0AH
    SEP 4
    DW SERIAL_WRITE_CHAR

    BR GAME_LOOP

DO_UNDO:
    SEP 4
    DW UNMAKE_MOVE

    LDI HIGH(MSG_UNDO)
    PHI 8
    LDI LOW(MSG_UNDO)
    PLO 8
    SEP 4
    DW SERIAL_PRINT_STRING

    BR GAME_LOOP

INVALID_MOVE:
    LDI HIGH(MSG_INVALID)
    PHI 8
    LDI LOW(MSG_INVALID)
    PLO 8
    SEP 4
    DW SERIAL_PRINT_STRING
    BR GAME_LOOP

; ==============================================================================
; String data
; ==============================================================================
MSG_WELCOME:
    DB "Make/Unmake Test", 0DH, 0AH
    DB "Type move (e2e4) or 'u' to undo", 0DH, 0AH, 0
MSG_MOVE:
    DB "Move: ", 0
MSG_MADE:
    DB "Made: ", 0
MSG_UNDO:
    DB "Move undone.", 0DH, 0AH, 0
MSG_INVALID:
    DB "Invalid!", 0DH, 0AH, 0

INPUT_BUF:
    DS 8

    END MAIN
