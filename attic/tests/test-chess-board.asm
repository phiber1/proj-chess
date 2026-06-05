; ==============================================================================
; Test Chess Board Initialization (with debug)
; ==============================================================================

    ORG $0000
    LBR MAIN

#include "serial-io.asm"

; ==============================================================================
; Mark Abene's SCRT implementation (uses R7 for D, not R14!)
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
; Include chess board module
; ==============================================================================
#include "board-0x88.asm"

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
    LDI $7F
    PHI 2
    LDI $FF
    PLO 2
    SEX 2
    REQ

    ; Print banner
    LDI HIGH(MSG_BANNER)
    PHI 8
    LDI LOW(MSG_BANNER)
    PLO 8
    CALL SERIAL_PRINT_STRING

    ; Initialize board
    LDI HIGH(MSG_INIT)
    PHI 8
    LDI LOW(MSG_INIT)
    PLO 8
    CALL SERIAL_PRINT_STRING

    CALL INIT_BOARD

    ; Debug: Print first 8 bytes of board (rank 1)
    LDI HIGH(MSG_RANK1)
    PHI 8
    LDI LOW(MSG_RANK1)
    PLO 8
    CALL SERIAL_PRINT_STRING

    ; Print 8 bytes starting at BOARD
    ; Use R12 for pointer (R15 is clobbered by serial routines!)
    LDI HIGH(BOARD)
    PHI 12
    LDI LOW(BOARD)
    PLO 12
    LDI 8
    PLO 13              ; counter

PRINT_RANK1:
    LDA 12              ; get byte, inc pointer
    CALL SERIAL_PRINT_HEX
    LDI ' '
    CALL SERIAL_WRITE_CHAR
    DEC 13
    GLO 13
    BNZ PRINT_RANK1

    ; Newline
    LDI 0DH
    CALL SERIAL_WRITE_CHAR
    LDI 0AH
    CALL SERIAL_WRITE_CHAR

    ; Check white king at e1 (offset $04)
    ; Read value BEFORE serial calls (use R10 to save - not used by PRINT)
    LDI HIGH(BOARD)
    PHI 12
    LDI LOW(BOARD + $04)    ; e1
    PLO 12
    LDN 12                  ; get piece
    PLO 10                  ; save in R10.0

    LDI HIGH(MSG_E1)
    PHI 8
    LDI LOW(MSG_E1)
    PLO 8
    CALL SERIAL_PRINT_STRING

    GLO 10                  ; get saved value
    CALL SERIAL_PRINT_HEX

    LDI HIGH(MSG_EXPECT)
    PHI 8
    LDI LOW(MSG_EXPECT)
    PLO 8
    CALL SERIAL_PRINT_STRING

    LDI W_KING
    CALL SERIAL_PRINT_HEX

    LDI 0DH
    CALL SERIAL_WRITE_CHAR
    LDI 0AH
    CALL SERIAL_WRITE_CHAR

    ; Now check if it matches
    GLO 10
    XRI W_KING
    BNZ TEST_FAIL

    ; Check black queen at d8 (offset $73)
    ; Read value BEFORE serial calls
    LDI HIGH(BOARD)
    PHI 12
    LDI LOW(BOARD + $73)    ; d8
    PLO 12
    LDN 12                  ; get piece
    PLO 10                  ; save in R10.0

    LDI HIGH(MSG_D8)
    PHI 8
    LDI LOW(MSG_D8)
    PLO 8
    CALL SERIAL_PRINT_STRING

    GLO 10                  ; get saved value
    CALL SERIAL_PRINT_HEX

    LDI HIGH(MSG_EXPECT)
    PHI 8
    LDI LOW(MSG_EXPECT)
    PLO 8
    CALL SERIAL_PRINT_STRING

    LDI B_QUEEN
    CALL SERIAL_PRINT_HEX

    LDI 0DH
    CALL SERIAL_WRITE_CHAR
    LDI 0AH
    CALL SERIAL_WRITE_CHAR

    GLO 10
    XRI B_QUEEN
    BNZ TEST_FAIL

    ; All tests passed
    LDI HIGH(MSG_PASS)
    PHI 8
    LDI LOW(MSG_PASS)
    PLO 8
    CALL SERIAL_PRINT_STRING
    BR SUCCESS

TEST_FAIL:
    LDI HIGH(MSG_FAIL)
    PHI 8
    LDI LOW(MSG_FAIL)
    PLO 8
    CALL SERIAL_PRINT_STRING

FAIL_LOOP:
    REQ
    LDI $FF
    PLO 9
    PHI 9
F1: DEC 9
    GHI 9
    BNZ F1
    SEQ
    LDI $FF
    PLO 9
    PHI 9
F2: DEC 9
    GHI 9
    BNZ F2
    BR FAIL_LOOP

SUCCESS:
    REQ
    LDI $20
    PLO 9
S1: DEC 9
    GLO 9
    BNZ S1
    SEQ
    LDI $20
    PLO 9
S2: DEC 9
    GLO 9
    BNZ S2
    BR SUCCESS

MSG_BANNER:
    DB "=== Chess Board Test ===", 0DH, 0AH, 0
MSG_INIT:
    DB "Initializing board...", 0DH, 0AH, 0
MSG_RANK1:
    DB "Rank 1: ", 0
MSG_E1:
    DB "e1=", 0
MSG_D8:
    DB "d8=", 0
MSG_EXPECT:
    DB " expect ", 0
MSG_PASS:
    DB "PASS!", 0DH, 0AH, 0
MSG_FAIL:
    DB "FAIL!", 0DH, 0AH, 0

    END MAIN
