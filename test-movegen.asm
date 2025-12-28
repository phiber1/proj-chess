; ==============================================================================
; Move Generation Test
; Tests GENERATE_MOVES from starting position
; Expected: 20 legal moves for white
; ==============================================================================

    ORG $0000
    LBR MAIN

; Include modules via preprocessor
#include "serial-io.asm"
#include "board-0x88.asm"
#include "movegen-helpers.asm"
#include "movegen-fixed.asm"

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

    ; Initialize board
    SEP 4
    DW INIT_BOARD

    ; Print "Board initialized"
    LDI HIGH(MSG_INIT)
    PHI 8
    LDI LOW(MSG_INIT)
    PLO 8
    SEP 4
    DW SERIAL_PRINT_STRING

    ; Set up for move generation
    ; R9 = move list pointer
    LDI HIGH(MOVE_LIST)
    PHI 9
    LDI LOW(MOVE_LIST)
    PLO 9

    ; C = side to move (WHITE = 0)
    LDI WHITE
    PLO 12

    ; Print "Generating moves..."
    LDI HIGH(MSG_GENERATING)
    PHI 8
    LDI LOW(MSG_GENERATING)
    PLO 8
    SEP 4
    DW SERIAL_PRINT_STRING

    ; Call move generator
    SEP 4
    DW GENERATE_MOVES
    ; D = move count returned

    ; Save move count
    PLO 11               ; B.0 = move count

    ; Print "Moves: "
    LDI HIGH(MSG_MOVES)
    PHI 8
    LDI LOW(MSG_MOVES)
    PLO 8
    SEP 4
    DW SERIAL_PRINT_STRING

    ; Print move count as hex
    GLO 11
    SEP 4
    DW SERIAL_PRINT_HEX

    ; Print newline
    LDI 0DH
    SEP 4
    DW SERIAL_WRITE_CHAR
    LDI 0AH
    SEP 4
    DW SERIAL_WRITE_CHAR

    ; Check if expected count (20 = $14)
    GLO 11
    SMI $14
    BZ TEST_PASS

    ; Wrong count
    LDI HIGH(MSG_FAIL)
    PHI 8
    LDI LOW(MSG_FAIL)
    PLO 8
    SEP 4
    DW SERIAL_PRINT_STRING
    BR DONE

TEST_PASS:
    LDI HIGH(MSG_PASS)
    PHI 8
    LDI LOW(MSG_PASS)
    PLO 8
    SEP 4
    DW SERIAL_PRINT_STRING

DONE:
    ; Print done
    LDI HIGH(MSG_DONE)
    PHI 8
    LDI LOW(MSG_DONE)
    PLO 8
    SEP 4
    DW SERIAL_PRINT_STRING

    ; Halt
HALT:
    BR HALT

; ==============================================================================
; String data
; ==============================================================================
MSG_WELCOME:
    DB 0DH, 0AH
    DB "=== Move Generation Test ===", 0DH, 0AH, 0

MSG_INIT:
    DB "Board initialized", 0DH, 0AH, 0

MSG_GENERATING:
    DB "Generating moves...", 0DH, 0AH, 0

MSG_MOVES:
    DB "Move count: ", 0

MSG_PASS:
    DB "PASS (20 moves)", 0DH, 0AH, 0

MSG_FAIL:
    DB "FAIL (expected 20)", 0DH, 0AH, 0

MSG_DONE:
    DB "Done.", 0DH, 0AH, 0

; ==============================================================================
; End of test
; ==============================================================================
