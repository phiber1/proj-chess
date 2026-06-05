; ==============================================================================
; King-Only Move Generator Test
; ==============================================================================

    ORG $0000
    LBR MAIN

#include "serial-io.asm"

; SCRT
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

; Constants
BOARD       EQU $5000
MOVELIST    EQU $5100
MOVECOUNT   EQU $50F0
W_KING      EQU $06
SQ_E1       EQU $04

; Direction offsets
DIR_N   EQU $F0
DIR_S   EQU $10
DIR_E   EQU $01
DIR_W   EQU $FF
DIR_NE  EQU $F1
DIR_NW  EQU $EF
DIR_SE  EQU $11
DIR_SW  EQU $0F

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
    LDI HIGH(STR_BANNER)
    PHI 8
    LDI LOW(STR_BANNER)
    PLO 8
    CALL SERIAL_PRINT_STRING

    ; Clear board
    LDI HIGH(BOARD)
    PHI 10
    LDI LOW(BOARD)
    PLO 10
    LDI 128
    PLO 14
CLEAR:
    LDI 0
    STR 10
    INC 10
    DEC 14
    GLO 14
    BNZ CLEAR

    ; Place king at e1 ($04)
    LDI HIGH(BOARD)
    PHI 10
    LDI SQ_E1
    PLO 10
    LDI W_KING
    STR 10

    ; Print position
    LDI HIGH(STR_POS)
    PHI 8
    LDI LOW(STR_POS)
    PLO 8
    CALL SERIAL_PRINT_STRING

    ; Generate king moves
    ; Input: king is at SQ_E1
    ; Output: moves written to MOVELIST, count in MOVECOUNT
    CALL GEN_KING_MOVES

    ; Print "Moves:"
    LDI HIGH(STR_MOVES)
    PHI 8
    LDI LOW(STR_MOVES)
    PLO 8
    CALL SERIAL_PRINT_STRING

    ; Print each move
    CALL PRINT_ALL_MOVES

    ; Done
    LDI HIGH(STR_DONE)
    PHI 8
    LDI LOW(STR_DONE)
    PLO 8
    CALL SERIAL_PRINT_STRING

HALT:
    BR HALT

; ==============================================================================
; GEN_KING_MOVES - Generate all king moves from e1
; Uses only R8, R9, R10, R13 (avoids serial-clobbered registers)
; ==============================================================================
GEN_KING_MOVES:
    ; R9 = move list pointer
    LDI HIGH(MOVELIST)
    PHI 9
    LDI LOW(MOVELIST)
    PLO 9

    ; R13 = direction index (0-7)
    LDI 0
    PLO 13

GKM_DIR_LOOP:
    ; Get direction from table
    ; R8 = address of KING_DIRS[R13]
    GLO 13
    STR 2
    LDI LOW(KING_DIRS)
    ADD
    PLO 8
    LDI HIGH(KING_DIRS)
    ADCI 0
    PHI 8

    ; Load direction offset
    LDN 8
    PLO 10              ; R10.0 = direction

    ; Calculate target: SQ_E1 + direction
    LDI SQ_E1
    STR 2
    GLO 10
    ADD
    PLO 8               ; R8.0 = target square

    ; Check if on board (target & $88 == 0)
    ANI $88
    BNZ GKM_NEXT_DIR    ; Off board, skip

    ; Check if target is empty
    LDI HIGH(BOARD)
    PHI 8               ; R8 = BOARD + target
    LDN 8               ; Load piece at target
    BNZ GKM_NEXT_DIR    ; Not empty, skip (simplified - no captures)

    ; Add move to list
    LDI SQ_E1
    STR 9               ; Store 'from'
    INC 9
    GLO 8               ; target square is in R8.0
    STR 9               ; Store 'to'
    INC 9

GKM_NEXT_DIR:
    INC 13
    GLO 13
    SMI 8
    BNZ GKM_DIR_LOOP

    ; Add terminator
    LDI $FF
    STR 9

    ; Calculate and store move count
    LDI LOW(MOVELIST)
    STR 2
    GLO 9
    SM                  ; D = R9.0 - MOVELIST.0 = bytes used
    SHR                 ; Divide by 2 = move count
    PLO 10
    LDI HIGH(MOVECOUNT)
    PHI 8
    LDI LOW(MOVECOUNT)
    PLO 8
    GLO 10
    STR 8

    RETN

; ==============================================================================
; PRINT_ALL_MOVES - Print moves from MOVELIST
; ==============================================================================
PRINT_ALL_MOVES:
    ; Use memory to track position (avoid register clobber issues)
    LDI HIGH(MOVELIST)
    PHI 10
    LDI LOW(MOVELIST)
    PLO 10

PAM_LOOP:
    ; Check for terminator
    LDN 10
    XRI $FF
    LBZ PAM_DONE

    ; Save current pointer to stack area
    GLO 10
    PLO 13              ; R13.0 = current low byte
    GHI 10
    PHI 13              ; R13.1 = current high byte

    ; Load and print 'from'
    LDN 10
    CALL SERIAL_PRINT_HEX

    LDI '-'
    CALL SERIAL_WRITE_CHAR

    ; Restore pointer and advance to 'to'
    GLO 13
    PLO 10
    GHI 13
    PHI 10
    INC 10

    ; Load and print 'to'
    LDN 10
    CALL SERIAL_PRINT_HEX

    LDI ' '
    CALL SERIAL_WRITE_CHAR

    ; Advance past 'to'
    GLO 13
    ADI 2               ; Skip both from and to
    PLO 10
    GHI 13
    ADCI 0
    PHI 10

    LBR PAM_LOOP

PAM_DONE:
    ; Print newline
    LDI HIGH(STR_CRLF)
    PHI 8
    LDI LOW(STR_CRLF)
    PLO 8
    CALL SERIAL_PRINT_STRING

    ; Print count
    LDI HIGH(STR_COUNT)
    PHI 8
    LDI LOW(STR_COUNT)
    PLO 8
    CALL SERIAL_PRINT_STRING

    LDI HIGH(MOVECOUNT)
    PHI 10
    LDI LOW(MOVECOUNT)
    PLO 10
    LDN 10
    CALL SERIAL_PRINT_HEX

    LDI HIGH(STR_CRLF)
    PHI 8
    LDI LOW(STR_CRLF)
    PLO 8
    CALL SERIAL_PRINT_STRING

    RETN

; ==============================================================================
; Data
; ==============================================================================
KING_DIRS:
    DB DIR_N, DIR_NE, DIR_E, DIR_SE, DIR_S, DIR_SW, DIR_W, DIR_NW

STR_BANNER:
    DB "King MoveGen Test", 0DH, 0AH, 0

STR_POS:
    DB "King at e1 ($04)", 0DH, 0AH, 0

STR_MOVES:
    DB "Moves: ", 0

STR_COUNT:
    DB "Count: ", 0

STR_DONE:
    DB "Done!", 0DH, 0AH, 0

STR_CRLF:
    DB 0DH, 0AH, 0

    END
