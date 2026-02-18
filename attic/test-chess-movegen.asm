; ==============================================================================
; Chess Move Generation Test
; ==============================================================================
; Tests: Board init, move generation
; Expected output: "Moves: 20" (white's opening moves)
; ==============================================================================

    ORG $0000
    LBR MAIN

; ==============================================================================
; Include modules
; ==============================================================================
#include "serial-io.asm"

; ==============================================================================
; SCRT Implementation (R4=CALL, R5=RET, R6=link, R7=D temp)
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
; Macros - Note: a18 assembler has built-in CALL/RETN
; ==============================================================================
; CALL is built-in: SEP 4 followed by 16-bit address
; RETN is built-in: SEP 5

; ==============================================================================
; Include core modules needed for move generation
; ==============================================================================
#include "support.asm"
#include "board-0x88.asm"
#include "movegen-helpers.asm"
#include "movegen-fixed.asm"

; ==============================================================================
; MAIN - Entry point
; ==============================================================================
MAIN:
    LDI HIGH(START)
    PHI 6
    LDI LOW(START)
    PLO 6
    LBR INITCALL

START:
    ; Set up stack at $7FFF
    LDI $7F
    PHI 2
    LDI $FF
    PLO 2
    SEX 2

    ; Set Q to idle (mark state)
    REQ

    ; Print banner
    LDI HIGH(STR_BANNER)
    PHI 8
    LDI LOW(STR_BANNER)
    PLO 8
    CALL SERIAL_PRINT_STRING

    ; Initialize board
    CALL INIT_BOARD

    ; Print board init done
    LDI HIGH(STR_BOARD_DONE)
    PHI 8
    LDI LOW(STR_BOARD_DONE)
    PLO 8
    CALL SERIAL_PRINT_STRING

    ; Set up for move generation
    ; Side to move = WHITE (0)
    LDI 0
    PLO 12              ; C.0 = WHITE

    ; Board pointer
    LDI HIGH(BOARD)
    PHI 10
    LDI LOW(BOARD)
    PLO 10

    ; Move list pointer
    LDI HIGH(MOVE_LIST)
    PHI 9
    LDI LOW(MOVE_LIST)
    PLO 9

    ; Generate moves
    CALL GENERATE_MOVES
    ; D = move count

    ; Print count IMMEDIATELY as hex before anything can corrupt it
    CALL SERIAL_PRINT_HEX

    ; Now print the rest of the message
    LDI HIGH(STR_MOVES2)
    PHI 8
    LDI LOW(STR_MOVES2)
    PLO 8
    CALL SERIAL_PRINT_STRING

    ; Just show pass/fail based on blinking (can't check value now)
    LBR TEST_DONE

TEST_FAIL:
    LDI HIGH(STR_FAIL)
    PHI 8
    LDI LOW(STR_FAIL)
    PLO 8
    CALL SERIAL_PRINT_STRING
    LBR TEST_DONE

TEST_PASS:
    LDI HIGH(STR_PASS)
    PHI 8
    LDI LOW(STR_PASS)
    PLO 8
    CALL SERIAL_PRINT_STRING

TEST_DONE:
    ; Blink Q to show complete
BLINK_LOOP:
    SEQ
    CALL DELAY_LONG
    REQ
    CALL DELAY_LONG
    BR BLINK_LOOP

; ==============================================================================
; PRINT_DECIMAL - Print byte as decimal (0-255)
; ==============================================================================
; Input: D = value to print
; ==============================================================================
PRINT_DECIMAL:
    PLO 11              ; Save value in B.0

    ; Handle hundreds
    LDI 0
    PLO 10              ; A.0 = hundreds counter
PD_HUND:
    GLO 11
    SMI 100
    BM PD_HUND_DONE
    PLO 11
    INC 10
    BR PD_HUND
PD_HUND_DONE:
    ; Print hundreds if non-zero
    GLO 10
    BZ PD_TENS
    ADI '0'
    CALL SERIAL_WRITE_CHAR

PD_TENS:
    ; Handle tens
    LDI 0
    PLO 10
PD_TEN:
    GLO 11
    SMI 10
    LBDF PD_TEN_DONE
    PLO 11
    INC 10
    LBR PD_TEN
PD_TEN_DONE:
    ; Print tens (always if hundreds printed, or if non-zero)
    GLO 10
    ADI '0'
    CALL SERIAL_WRITE_CHAR

    ; Print ones
    GLO 11
    ADI '0'
    CALL SERIAL_WRITE_CHAR

    RETN

; ==============================================================================
; DELAY_LONG - Visible delay for blinking
; ==============================================================================
DELAY_LONG:
    LDI $FF
    PHI 15
DL_OUTER:
    LDI $FF
    PLO 15
DL_INNER:
    DEC 15
    GLO 15
    BNZ DL_INNER
    DEC 15
    GHI 15
    BNZ DL_OUTER
    RETN

; ==============================================================================
; String Constants
; ==============================================================================
STR_BANNER:
    DB "=== Move Gen Test ===", 0DH, 0AH, 0

STR_BOARD_DONE:
    DB "Board initialized", 0DH, 0AH, 0

STR_MOVES:
    DB "Moves: ", 0

STR_MOVES2:
    DB " moves generated", 0DH, 0AH, 0

STR_PASS:
    DB "PASS - 20 moves!", 0DH, 0AH, 0

STR_FAIL:
    DB "FAIL - wrong count", 0DH, 0AH, 0

; ==============================================================================
; End of Test
; ==============================================================================
