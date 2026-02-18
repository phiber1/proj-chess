; ==============================================================================
; BIOS Move Generation Test - Check if movegen works
; ==============================================================================

    ORG $0000

#ifdef BIOS
    LBR START
#else
    LBR MAIN
#endif

#include "serial-io.asm"

#ifndef BIOS
; SCRT Implementation
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
#endif

; ==============================================================================
; Constants
; ==============================================================================
BOARD       EQU $5000
GAME_STATE  EQU $5080
GS_CASTLE   EQU 0
GS_EP       EQU 1
MOVELIST    EQU $5100

EMPTY       EQU $00
WHITE       EQU $00
BLACK       EQU $08
COLOR_MASK  EQU $08
PIECE_MASK  EQU $07

W_PAWN      EQU $01
W_KNIGHT    EQU $02
W_BISHOP    EQU $03
W_ROOK      EQU $04
W_QUEEN     EQU $05
W_KING      EQU $06
B_PAWN      EQU $09
B_KNIGHT    EQU $0A
B_BISHOP    EQU $0B
B_ROOK      EQU $0C
B_QUEEN     EQU $0D
B_KING      EQU $0E

; Direction offsets for 0x88 board
DIR_N   EQU $F0
DIR_S   EQU $10
DIR_E   EQU $01
DIR_W   EQU $FF
DIR_NE  EQU $F1
DIR_NW  EQU $EF
DIR_SE  EQU $11
DIR_SW  EQU $0F

; ==============================================================================
; Main
; ==============================================================================
#ifndef BIOS
MAIN:
    LDI HIGH(START)
    PHI 6
    LDI LOW(START)
    PLO 6
    LBR INITCALL
#endif

START:
#ifndef BIOS
    LDI $7F
    PHI 2
    LDI $FF
    PLO 2
    SEX 2
    REQ
#endif

    ; Print banner
    LDI HIGH(STR_BANNER)
    PHI 8
    LDI LOW(STR_BANNER)
    PLO 8
    SEP 4
    DW SERIAL_PRINT_STRING

    ; Clear board
    SEP 4
    DW CLEAR_BOARD

    ; Set up simple position: WKe1 WQd1 WPa2 vs BKe8 BPa7
    LDI HIGH(BOARD)
    PHI 10

    ; White King e1 (0x04)
    LDI $04
    PLO 10
    LDI W_KING
    STR 10

    ; White Queen d1 (0x03)
    LDI $03
    PLO 10
    LDI W_QUEEN
    STR 10

    ; White Pawn a2 (0x10)
    LDI $10
    PLO 10
    LDI W_PAWN
    STR 10

    ; Black King e8 (0x74)
    LDI $74
    PLO 10
    LDI B_KING
    STR 10

    ; Black Pawn a7 (0x60)
    LDI $60
    PLO 10
    LDI B_PAWN
    STR 10

    ; Print position set
    LDI HIGH(STR_POS)
    PHI 8
    LDI LOW(STR_POS)
    PLO 8
    SEP 4
    DW SERIAL_PRINT_STRING

    ; Debug: Print what's at e1 (0x04) - should be 06 (W_KING)
    LDI HIGH(STR_E1)
    PHI 8
    LDI LOW(STR_E1)
    PLO 8
    SEP 4
    DW SERIAL_PRINT_STRING

    LDI HIGH(BOARD)
    PHI 10
    LDI $04
    PLO 10
    LDN 10
    SEP 4
    DW SERIAL_PRINT_HEX

    ; Debug: Print what's at d1 (0x03) - should be 05 (W_QUEEN)
    LDI HIGH(STR_D1)
    PHI 8
    LDI LOW(STR_D1)
    PLO 8
    SEP 4
    DW SERIAL_PRINT_STRING

    LDI HIGH(BOARD)
    PHI 10
    LDI $03
    PLO 10
    LDN 10
    SEP 4
    DW SERIAL_PRINT_HEX

    LDI 0DH
    SEP 4
    DW SERIAL_WRITE_CHAR
    LDI 0AH
    SEP 4
    DW SERIAL_WRITE_CHAR

    ; Generate moves for white
    LDI HIGH(MOVELIST)
    PHI 9
    LDI LOW(MOVELIST)
    PLO 9
    LDI WHITE
    PLO 12
    SEP 4
    DW GENERATE_MOVES

    ; Add terminator
    LDI $FF
    STR 9

    ; Count moves
    LDI HIGH(MOVELIST)
    PHI 9
    LDI LOW(MOVELIST)
    PLO 9
    LDI 0
    PLO 11          ; count

COUNT_LOOP:
    LDN 9
    XRI $FF
    LBZ COUNT_DONE
    INC 9
    INC 9
    INC 11
    LBR COUNT_LOOP

COUNT_DONE:
    ; Print count
    LDI HIGH(STR_MOVES)
    PHI 8
    LDI LOW(STR_MOVES)
    PLO 8
    SEP 4
    DW SERIAL_PRINT_STRING

    GLO 11
    SEP 4
    DW SERIAL_PRINT_HEX

    ; Newline
    LDI 0DH
    SEP 4
    DW SERIAL_WRITE_CHAR
    LDI 0AH
    SEP 4
    DW SERIAL_WRITE_CHAR

    ; Print moves
    LDI HIGH(MOVELIST)
    PHI 9
    LDI LOW(MOVELIST)
    PLO 9
    LDI 0
    PLO 13              ; R13.0 = move counter

; Memory location to save R9 (avoid stack issues with BIOS)
SAVE_R9_LO  EQU $50E0
SAVE_R9_HI  EQU $50E1
SAVE_CNT    EQU $50E2   ; Move counter save

PRINT_MOVES:
    LDA 9           ; from
    XRI $FF
    LBZ PRINT_DONE
    XRI $FF         ; restore
    PLO 11          ; save from in R11.0
    LDA 9           ; to
    PHI 11          ; save to in R11.1
    ; Increment and save move counter
    INC 13
    ; Save R9 and R13.0 to memory
    LDI HIGH(SAVE_R9_LO)
    PHI 8
    LDI LOW(SAVE_R9_LO)
    PLO 8
    GLO 9
    STR 8
    INC 8
    GHI 9
    STR 8
    INC 8
    GLO 13
    STR 8           ; Save counter at $50E2
    ; Print move number first
    GLO 13
    SEP 4
    DW SERIAL_PRINT_HEX
    LDI ':'
    SEP 4
    DW SERIAL_WRITE_CHAR
    ; Print from
    GLO 11
    SEP 4
    DW SERIAL_PRINT_HEX
    LDI '-'
    SEP 4
    DW SERIAL_WRITE_CHAR
    ; Print to
    GHI 11
    SEP 4
    DW SERIAL_PRINT_HEX
    LDI ' '
    SEP 4
    DW SERIAL_WRITE_CHAR
    ; Restore R9 and R13.0 from memory
    LDI HIGH(SAVE_R9_LO)
    PHI 8
    LDI LOW(SAVE_R9_LO)
    PLO 8
    LDA 8
    PLO 9
    LDA 8
    PHI 9
    LDN 8
    PLO 13
    ; Newline every 8 moves
    GLO 13
    ANI $07
    LBNZ PRINT_MOVES
    LDI 0DH
    SEP 4
    DW SERIAL_WRITE_CHAR
    LDI 0AH
    SEP 4
    DW SERIAL_WRITE_CHAR
    LBR PRINT_MOVES

PRINT_DONE:
    LDI 0DH
    SEP 4
    DW SERIAL_WRITE_CHAR
    LDI 0AH
    SEP 4
    DW SERIAL_WRITE_CHAR

    ; Exit
#ifdef BIOS
    LBR $8003
#else
DONE:
    BR DONE
#endif

; ==============================================================================
; Strings
; ==============================================================================
STR_BANNER:
    DB "BIOS Movegen Test",0DH,0AH,0
STR_POS:
    DB "Position set",0DH,0AH,0
STR_E1:
    DB "e1=",0
STR_D1:
    DB " d1=",0
STR_MOVES:
    DB "Move count: ",0

; ==============================================================================
; CLEAR_BOARD - Fill board with EMPTY
; ==============================================================================
CLEAR_BOARD:
    LDI HIGH(BOARD)
    PHI 10
    LDI 0
    PLO 10
    LDI $80         ; 128 bytes
    PLO 13
CB_LOOP:
    LDI EMPTY
    STR 10
    INC 10
    DEC 13
    GLO 13
    LBNZ CB_LOOP
    SEP 5

; ==============================================================================
; Include move generator
; ==============================================================================
#include "movegen-new.asm"
