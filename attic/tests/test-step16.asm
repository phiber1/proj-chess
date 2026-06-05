; ==============================================================================
; Step 16: Depth-2 Search Test
; Demonstrates that deeper search avoids tactical traps
; ==============================================================================
;
; Test position: White Qd4, Ke1. Black Qd6, Nc4 (defends d6), Pa5, Ke8.
;
; Depth-1 analysis (WRONG):
;   Qxd6: +480 (captures queen, doesn't see Nxd6 recapture)
;   Qxc4: -100
;   Qxa5: -320
;   Best: Qxd6 (+480) -- MISTAKE!
;
; Depth-2 analysis (CORRECT):
;   Qxd6: after Nxd6, score = -420
;   Qxc4: no recapture, score = -100
;   Qxa5: no recapture, score = -320
;   Best: Qxc4 (-100) -- Least bad option
;
; ==============================================================================

    ORG $0000
    LBR MAIN

#include "serial-io.asm"

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

; ==============================================================================
; Constants
; ==============================================================================
BOARD       EQU $5000
GAME_STATE  EQU $5080
SCORE_LO    EQU $5088
SCORE_HI    EQU $5089
MOVE_PIECE  EQU $5090       ; For Black's move (inner ply)
CAPT_PIECE  EQU $5091
WHITE_MOVE_PIECE EQU $5092  ; For White's move (outer ply)
WHITE_CAPT_PIECE EQU $5093

; Search state
BEST_MOVE_FROM  EQU $50A0
BEST_MOVE_TO    EQU $50A1
BEST_SCORE_LO   EQU $50A2
BEST_SCORE_HI   EQU $50A3
CURR_MOVE_FROM  EQU $50A4
CURR_MOVE_TO    EQU $50A5
WHITE_PTR_LO    EQU $50A6   ; White move list pointer
WHITE_PTR_HI    EQU $50A7
BLACK_PTR_LO    EQU $50A8   ; Black move list pointer
BLACK_PTR_HI    EQU $50A9
BLACK_BEST_LO   EQU $50AA   ; Black's best score (for current White move)
BLACK_BEST_HI   EQU $50AB
CURR_BLACK_FROM EQU $50AC   ; Current Black move being tried
CURR_BLACK_TO   EQU $50AD

; Move lists (hardcoded for this test)
WHITE_MOVES     EQU $5100   ; White's candidate moves
BLACK_MOVES_1   EQU $5120   ; Black responses after Qxd6
BLACK_MOVES_2   EQU $5140   ; Black responses after Qxc4
BLACK_MOVES_3   EQU $5160   ; Black responses after Qxa5

EMPTY       EQU $00
WHITE       EQU $00
BLACK       EQU $08
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

; Squares (0x88 format)
SQ_E1       EQU $04
SQ_D4       EQU $33
SQ_A5       EQU $40
SQ_D6       EQU $53
SQ_C4       EQU $32
SQ_E8       EQU $74

; Black response squares after Nxd6
SQ_B2       EQU $11
SQ_E3       EQU $24
SQ_A3       EQU $20
SQ_E5       EQU $44
SQ_B6       EQU $51
SQ_D2       EQU $13

; Infinity
NEG_INF_LO  EQU $01
NEG_INF_HI  EQU $80
POS_INF_LO  EQU $FF
POS_INF_HI  EQU $7F

; ==============================================================================
; Main
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
    LDI HIGH(STR_BANNER)
    PHI 8
    LDI LOW(STR_BANNER)
    PLO 8
    CALL SERIAL_PRINT_STRING

    ; Set up position
    CALL CLEAR_BOARD
    CALL SETUP_POSITION

    ; Set up move lists
    CALL SETUP_WHITE_MOVES
    CALL SETUP_BLACK_MOVES

    ; Print position
    LDI HIGH(STR_POS)
    PHI 8
    LDI LOW(STR_POS)
    PLO 8
    CALL SERIAL_PRINT_STRING

    ; Run depth-2 search
    LDI HIGH(STR_SEARCH)
    PHI 8
    LDI LOW(STR_SEARCH)
    PLO 8
    CALL SERIAL_PRINT_STRING

    CALL SEARCH_DEPTH2

    ; Print result
    LDI HIGH(STR_BEST)
    PHI 8
    LDI LOW(STR_BEST)
    PLO 8
    CALL SERIAL_PRINT_STRING

    LDI HIGH(BEST_MOVE_FROM)
    PHI 10
    LDI LOW(BEST_MOVE_FROM)
    PLO 10
    LDN 10
    CALL SERIAL_PRINT_HEX
    LDI '-'
    CALL SERIAL_WRITE_CHAR
    LDI HIGH(BEST_MOVE_TO)
    PHI 10
    LDI LOW(BEST_MOVE_TO)
    PLO 10
    LDN 10
    CALL SERIAL_PRINT_HEX

    LDI ' '
    CALL SERIAL_WRITE_CHAR

    LDI HIGH(BEST_SCORE_HI)
    PHI 10
    LDI LOW(BEST_SCORE_HI)
    PLO 10
    LDN 10
    CALL SERIAL_PRINT_HEX
    LDI HIGH(BEST_SCORE_LO)
    PHI 10
    LDI LOW(BEST_SCORE_LO)
    PLO 10
    LDN 10
    CALL SERIAL_PRINT_HEX

    CALL PRINT_CRLF

    ; Print expected
    LDI HIGH(STR_EXPECT)
    PHI 8
    LDI LOW(STR_EXPECT)
    PLO 8
    CALL SERIAL_PRINT_STRING

HALT:
    BR HALT

; ==============================================================================
; SEARCH_DEPTH2 - Two-ply search
; For each White move, find Black's best response, then pick best for White
; ==============================================================================
SEARCH_DEPTH2:
    SEX 2

    ; Initialize best score to -infinity
    LDI HIGH(BEST_SCORE_LO)
    PHI 10
    LDI LOW(BEST_SCORE_LO)
    PLO 10
    LDI NEG_INF_LO
    STR 10
    INC 10
    LDI NEG_INF_HI
    STR 10

    ; Initialize White move pointer
    LDI HIGH(WHITE_MOVES)
    PHI 11
    LDI LOW(WHITE_MOVES)
    PLO 11

    ; Save to memory
    LDI HIGH(WHITE_PTR_LO)
    PHI 10
    LDI LOW(WHITE_PTR_LO)
    PLO 10
    GLO 11
    STR 10
    INC 10
    GHI 11
    STR 10

    ; Move counter for selecting Black response list
    LDI 0
    PLO 13              ; R13.0 = White move index (0, 1, 2)

SD2_WHITE_LOOP:
    ; Restore White pointer
    LDI HIGH(WHITE_PTR_LO)
    PHI 10
    LDI LOW(WHITE_PTR_LO)
    PLO 10
    LDN 10
    PLO 11
    INC 10
    LDN 10
    PHI 11

    ; Check end of White moves
    LDN 11
    XRI $FF
    LBZ SD2_DONE

    ; Load White move
    LDA 11
    PLO 9               ; from
    LDA 11
    PHI 9               ; to

    ; Save updated pointer
    LDI HIGH(WHITE_PTR_LO)
    PHI 10
    LDI LOW(WHITE_PTR_LO)
    PLO 10
    GLO 11
    STR 10
    INC 10
    GHI 11
    STR 10

    ; Save current move to memory
    LDI HIGH(CURR_MOVE_FROM)
    PHI 10
    LDI LOW(CURR_MOVE_FROM)
    PLO 10
    GLO 9
    STR 10
    INC 10
    GHI 9
    STR 10

    ; Print "W: from-to"
    LDI HIGH(STR_WHITE)
    PHI 8
    LDI LOW(STR_WHITE)
    PLO 8
    CALL SERIAL_PRINT_STRING

    LDI HIGH(CURR_MOVE_FROM)
    PHI 10
    LDI LOW(CURR_MOVE_FROM)
    PLO 10
    LDN 10
    CALL SERIAL_PRINT_HEX
    LDI '-'
    CALL SERIAL_WRITE_CHAR
    LDI HIGH(CURR_MOVE_TO)
    PHI 10
    LDI LOW(CURR_MOVE_TO)
    PLO 10
    LDN 10
    CALL SERIAL_PRINT_HEX
    CALL PRINT_CRLF

    ; Reload move and make it
    LDI HIGH(CURR_MOVE_FROM)
    PHI 10
    LDI LOW(CURR_MOVE_FROM)
    PLO 10
    LDN 10
    PLO 11              ; R11.0 = from
    INC 10
    LDN 10
    PHI 11              ; R11.1 = to
    CALL MAKE_MOVE_WHITE  ; Use separate storage for White's move

    ; === Now search Black's responses ===
    ; Select Black move list based on move index
    GLO 13              ; White move index
    LBZ SD2_BLACK_LIST1
    SMI 1
    LBZ SD2_BLACK_LIST2
    LBR SD2_BLACK_LIST3

SD2_BLACK_LIST1:
    LDI HIGH(BLACK_MOVES_1)
    PHI 11
    LDI LOW(BLACK_MOVES_1)
    PLO 11
    LBR SD2_BLACK_INIT

SD2_BLACK_LIST2:
    LDI HIGH(BLACK_MOVES_2)
    PHI 11
    LDI LOW(BLACK_MOVES_2)
    PLO 11
    LBR SD2_BLACK_INIT

SD2_BLACK_LIST3:
    LDI HIGH(BLACK_MOVES_3)
    PHI 11
    LDI LOW(BLACK_MOVES_3)
    PLO 11

SD2_BLACK_INIT:
    ; Save Black pointer
    LDI HIGH(BLACK_PTR_LO)
    PHI 10
    LDI LOW(BLACK_PTR_LO)
    PLO 10
    GLO 11
    STR 10
    INC 10
    GHI 11
    STR 10

    ; Initialize Black's best to +infinity (from White's view)
    ; (Black wants to minimize White's score)
    LDI HIGH(BLACK_BEST_LO)
    PHI 10
    LDI LOW(BLACK_BEST_LO)
    PLO 10
    LDI POS_INF_LO
    STR 10
    INC 10
    LDI POS_INF_HI
    STR 10

SD2_BLACK_LOOP:
    ; Restore Black pointer
    LDI HIGH(BLACK_PTR_LO)
    PHI 10
    LDI LOW(BLACK_PTR_LO)
    PLO 10
    LDN 10
    PLO 11
    INC 10
    LDN 10
    PHI 11

    ; Check end of Black moves
    LDN 11
    XRI $FF
    LBZ SD2_BLACK_DONE

    ; Load Black move
    LDA 11
    PLO 9               ; from
    LDA 11
    PHI 9               ; to

    ; Save updated pointer
    LDI HIGH(BLACK_PTR_LO)
    PHI 10
    LDI LOW(BLACK_PTR_LO)
    PLO 10
    GLO 11
    STR 10
    INC 10
    GHI 11
    STR 10

    ; Save Black move to dedicated storage
    LDI HIGH(CURR_BLACK_FROM)
    PHI 10
    LDI LOW(CURR_BLACK_FROM)
    PLO 10
    GLO 9
    STR 10
    INC 10
    GHI 9
    STR 10

    ; Make Black's move
    GLO 9
    PLO 11
    GHI 9
    PHI 11
    CALL MAKE_MOVE_MEM

    ; Evaluate (from White's perspective)
    CALL EVALUATE_MATERIAL

    ; Print "  B: from-to score"
    LDI HIGH(STR_BLACK)
    PHI 8
    LDI LOW(STR_BLACK)
    PLO 8
    CALL SERIAL_PRINT_STRING

    ; Reload Black move for printing
    LDI HIGH(CURR_BLACK_FROM)
    PHI 10
    LDI LOW(CURR_BLACK_FROM)
    PLO 10
    LDN 10
    CALL SERIAL_PRINT_HEX
    LDI '-'
    CALL SERIAL_WRITE_CHAR
    LDI HIGH(CURR_BLACK_TO)
    PHI 10
    LDI LOW(CURR_BLACK_TO)
    PLO 10
    LDN 10
    CALL SERIAL_PRINT_HEX
    LDI ' '
    CALL SERIAL_WRITE_CHAR

    ; Evaluate again (printing clobbered registers)
    CALL EVALUATE_MATERIAL

    LDI HIGH(SCORE_HI)
    PHI 10
    LDI LOW(SCORE_HI)
    PLO 10
    LDN 10
    CALL SERIAL_PRINT_HEX
    LDI HIGH(SCORE_LO)
    PHI 10
    LDI LOW(SCORE_LO)
    PLO 10
    LDN 10
    CALL SERIAL_PRINT_HEX
    CALL PRINT_CRLF

    ; Compare: if SCORE < BLACK_BEST, update (Black minimizes White's score)
    CALL COMPARE_SCORE_LESS_THAN_BEST
    LBZ SD2_BLACK_NOT_BETTER

    ; Update Black's best
    CALL EVALUATE_MATERIAL  ; Reload score
    LDI HIGH(SCORE_LO)
    PHI 10
    LDI LOW(SCORE_LO)
    PLO 10
    LDN 10
    PLO 9
    INC 10
    LDN 10
    PHI 9

    LDI HIGH(BLACK_BEST_LO)
    PHI 10
    LDI LOW(BLACK_BEST_LO)
    PLO 10
    GLO 9
    STR 10
    INC 10
    GHI 9
    STR 10

SD2_BLACK_NOT_BETTER:
    ; Unmake Black's move - reload from dedicated storage
    LDI HIGH(CURR_BLACK_FROM)
    PHI 10
    LDI LOW(CURR_BLACK_FROM)
    PLO 10
    LDN 10
    PLO 11
    INC 10
    LDN 10
    PHI 11
    CALL UNMAKE_MOVE_MEM

    LBR SD2_BLACK_LOOP

SD2_BLACK_DONE:
    ; Black's best response is in BLACK_BEST
    ; This is the score for White's move (after Black's best reply)

    ; Print "  -> score"
    LDI HIGH(STR_RESULT)
    PHI 8
    LDI LOW(STR_RESULT)
    PLO 8
    CALL SERIAL_PRINT_STRING

    LDI HIGH(BLACK_BEST_HI)
    PHI 10
    LDI LOW(BLACK_BEST_HI)
    PLO 10
    LDN 10
    CALL SERIAL_PRINT_HEX
    LDI HIGH(BLACK_BEST_LO)
    PHI 10
    LDI LOW(BLACK_BEST_LO)
    PLO 10
    LDN 10
    CALL SERIAL_PRINT_HEX
    CALL PRINT_CRLF

    ; Compare: if BLACK_BEST > BEST_SCORE, update White's best
    CALL COMPARE_BLACK_BEST_GREATER
    LBZ SD2_WHITE_NOT_BETTER

    ; Update White's best move and score
    LDI HIGH(CURR_MOVE_FROM)
    PHI 10
    LDI LOW(CURR_MOVE_FROM)
    PLO 10
    LDN 10
    PLO 9
    INC 10
    LDN 10
    PHI 9

    LDI HIGH(BEST_MOVE_FROM)
    PHI 10
    LDI LOW(BEST_MOVE_FROM)
    PLO 10
    GLO 9
    STR 10
    INC 10
    GHI 9
    STR 10

    LDI HIGH(BLACK_BEST_LO)
    PHI 10
    LDI LOW(BLACK_BEST_LO)
    PLO 10
    LDN 10
    PLO 9
    INC 10
    LDN 10
    PHI 9

    LDI HIGH(BEST_SCORE_LO)
    PHI 10
    LDI LOW(BEST_SCORE_LO)
    PLO 10
    GLO 9
    STR 10
    INC 10
    GHI 9
    STR 10

SD2_WHITE_NOT_BETTER:
    ; Unmake White's move
    LDI HIGH(CURR_MOVE_FROM)
    PHI 10
    LDI LOW(CURR_MOVE_FROM)
    PLO 10
    LDN 10
    PLO 11
    INC 10
    LDN 10
    PHI 11
    CALL UNMAKE_MOVE_WHITE  ; Use separate storage for White's move

    ; Next White move
    INC 13              ; Increment move index
    LBR SD2_WHITE_LOOP

SD2_DONE:
    RETN

; ==============================================================================
; COMPARE_SCORE_LESS_THAN_BEST - Is SCORE < BLACK_BEST? (signed 16-bit)
; Returns D=1 if SCORE < BLACK_BEST, D=0 otherwise
; ==============================================================================
COMPARE_SCORE_LESS_THAN_BEST:
    SEX 2

    ; Load BLACK_BEST
    LDI HIGH(BLACK_BEST_HI)
    PHI 10
    LDI LOW(BLACK_BEST_HI)
    PLO 10
    LDN 10
    PHI 14              ; R14.1 = BEST_HI
    DEC 10
    LDN 10
    PLO 14              ; R14.0 = BEST_LO

    ; Load SCORE
    LDI HIGH(SCORE_HI)
    PHI 10
    LDI LOW(SCORE_HI)
    PLO 10
    LDN 10
    PHI 15              ; R15.1 = SCORE_HI
    DEC 10
    LDN 10
    PLO 15              ; R15.0 = SCORE_LO

    ; Check if signs differ
    GHI 15
    STR 2
    GHI 14
    XOR
    ANI $80
    LBNZ CSLTB_DIFF_SIGNS

    ; Same sign - unsigned compare
    ; SCORE < BEST means BEST - SCORE > 0 with no borrow
    GHI 15              ; SCORE_HI
    STR 2
    GHI 14              ; BEST_HI
    SM                  ; BEST_HI - SCORE_HI
    BDF CSLTB_CHECK_LO
    ; Borrow: BEST_HI < SCORE_HI, so SCORE > BEST
    LDI 0
    RETN

CSLTB_CHECK_LO:
    ; No borrow: BEST_HI >= SCORE_HI
    GHI 15
    STR 2
    GHI 14
    SM
    LBNZ CSLTB_SCORE_LESS  ; BEST_HI > SCORE_HI

    ; High bytes equal, check low
    GLO 15
    STR 2
    GLO 14
    SM                  ; BEST_LO - SCORE_LO
    BDF CSLTB_CHECK_EQUAL
    LDI 0
    RETN

CSLTB_CHECK_EQUAL:
    GLO 15
    STR 2
    GLO 14
    SM
    LBZ CSLTB_EQUAL     ; BEST == SCORE
    ; BEST_LO > SCORE_LO

CSLTB_SCORE_LESS:
    LDI 1
    RETN

CSLTB_EQUAL:
    LDI 0
    RETN

CSLTB_DIFF_SIGNS:
    ; Signs differ - negative is less
    GHI 15              ; SCORE_HI
    ANI $80
    LBNZ CSLTB_SCORE_LESS  ; SCORE is negative, BEST is positive
    LDI 0                   ; SCORE is positive, BEST is negative
    RETN

; ==============================================================================
; COMPARE_BLACK_BEST_GREATER - Is BLACK_BEST > BEST_SCORE? (signed 16-bit)
; Returns D=1 if BLACK_BEST > BEST_SCORE, D=0 otherwise
; ==============================================================================
COMPARE_BLACK_BEST_GREATER:
    SEX 2

    ; Load BEST_SCORE
    LDI HIGH(BEST_SCORE_HI)
    PHI 10
    LDI LOW(BEST_SCORE_HI)
    PLO 10
    LDN 10
    PHI 14
    DEC 10
    LDN 10
    PLO 14

    ; Load BLACK_BEST
    LDI HIGH(BLACK_BEST_HI)
    PHI 10
    LDI LOW(BLACK_BEST_HI)
    PLO 10
    LDN 10
    PHI 15
    DEC 10
    LDN 10
    PLO 15

    ; Is R15 > R14? (BLACK_BEST > BEST_SCORE)
    ; Check signs
    GHI 15
    STR 2
    GHI 14
    XOR
    ANI $80
    LBNZ CBBG_DIFF_SIGNS

    ; Same sign
    GHI 14              ; BEST_HI
    STR 2
    GHI 15              ; BLACK_HI
    SM                  ; BLACK_HI - BEST_HI
    BDF CBBG_CHECK_LO
    LDI 0
    RETN

CBBG_CHECK_LO:
    GHI 14
    STR 2
    GHI 15
    SM
    LBNZ CBBG_BLACK_GREATER

    GLO 14
    STR 2
    GLO 15
    SM
    BDF CBBG_CHECK_EQ
    LDI 0
    RETN

CBBG_CHECK_EQ:
    GLO 14
    STR 2
    GLO 15
    SM
    LBZ CBBG_EQUAL

CBBG_BLACK_GREATER:
    LDI 1
    RETN

CBBG_EQUAL:
    LDI 0
    RETN

CBBG_DIFF_SIGNS:
    GHI 15
    ANI $80
    LBNZ CBBG_EQUAL     ; BLACK is negative, BEST is positive
    LDI 1               ; BLACK is positive, BEST is negative
    RETN

; ==============================================================================
; PRINT_CRLF
; ==============================================================================
PRINT_CRLF:
    LDI HIGH(STR_CRLF)
    PHI 8
    LDI LOW(STR_CRLF)
    PLO 8
    CALL SERIAL_PRINT_STRING
    RETN

; ==============================================================================
; CLEAR_BOARD
; ==============================================================================
CLEAR_BOARD:
    LDI HIGH(BOARD)
    PHI 10
    LDI LOW(BOARD)
    PLO 10
    LDI 128
    PLO 14
CB_LOOP:
    LDI EMPTY
    STR 10
    INC 10
    DEC 14
    GLO 14
    LBNZ CB_LOOP
    RETN

; ==============================================================================
; SETUP_POSITION - White Qd4 Ke1, Black Qd6 Nc4 Pa5 Ke8
; ==============================================================================
SETUP_POSITION:
    LDI HIGH(BOARD)
    PHI 10

    ; White King e1
    LDI SQ_E1
    PLO 10
    LDI W_KING
    STR 10

    ; White Queen d4
    LDI SQ_D4
    PLO 10
    LDI W_QUEEN
    STR 10

    ; Black Queen d6
    LDI SQ_D6
    PLO 10
    LDI B_QUEEN
    STR 10

    ; Black Knight c4
    LDI SQ_C4
    PLO 10
    LDI B_KNIGHT
    STR 10

    ; Black Pawn a5
    LDI SQ_A5
    PLO 10
    LDI B_PAWN
    STR 10

    ; Black King e8
    LDI SQ_E8
    PLO 10
    LDI B_KING
    STR 10

    RETN

; ==============================================================================
; SETUP_WHITE_MOVES - Qxd6, Qxc4, Qxa5
; ==============================================================================
SETUP_WHITE_MOVES:
    LDI HIGH(WHITE_MOVES)
    PHI 10
    LDI LOW(WHITE_MOVES)
    PLO 10

    ; Move 1: Qxd6 (d4-d6)
    LDI SQ_D4
    STR 10
    INC 10
    LDI SQ_D6
    STR 10
    INC 10

    ; Move 2: Qxc4 (d4-c4)
    LDI SQ_D4
    STR 10
    INC 10
    LDI SQ_C4
    STR 10
    INC 10

    ; Move 3: Qxa5 (d4-a5)
    LDI SQ_D4
    STR 10
    INC 10
    LDI SQ_A5
    STR 10
    INC 10

    ; End marker
    LDI $FF
    STR 10

    RETN

; ==============================================================================
; SETUP_BLACK_MOVES - Responses for each White move
; ==============================================================================
SETUP_BLACK_MOVES:
    ; === After Qxd6: Black can Nxd6 (recapture!) or other moves ===
    LDI HIGH(BLACK_MOVES_1)
    PHI 10
    LDI LOW(BLACK_MOVES_1)
    PLO 10

    ; Nxd6 (c4-d6) - THE RECAPTURE
    LDI SQ_C4
    STR 10
    INC 10
    LDI SQ_D6
    STR 10
    INC 10

    ; Pa5-a4 (just a pawn push, worse for Black)
    LDI SQ_A5
    STR 10
    INC 10
    LDI $30             ; a4
    STR 10
    INC 10

    ; End
    LDI $FF
    STR 10

    ; === After Qxc4: No recapture possible ===
    LDI HIGH(BLACK_MOVES_2)
    PHI 10
    LDI LOW(BLACK_MOVES_2)
    PLO 10

    ; Qd6-d5 (queen move)
    LDI SQ_D6
    STR 10
    INC 10
    LDI $43             ; d5
    STR 10
    INC 10

    ; Pa5-a4
    LDI SQ_A5
    STR 10
    INC 10
    LDI $30             ; a4
    STR 10
    INC 10

    ; End
    LDI $FF
    STR 10

    ; === After Qxa5: No recapture possible ===
    LDI HIGH(BLACK_MOVES_3)
    PHI 10
    LDI LOW(BLACK_MOVES_3)
    PLO 10

    ; Qd6-d5
    LDI SQ_D6
    STR 10
    INC 10
    LDI $43             ; d5
    STR 10
    INC 10

    ; Nc4-d2
    LDI SQ_C4
    STR 10
    INC 10
    LDI SQ_D2
    STR 10
    INC 10

    ; End
    LDI $FF
    STR 10

    RETN

; ==============================================================================
; MAKE_MOVE_WHITE / UNMAKE_MOVE_WHITE - For outer ply (White's move)
; Input: R11.0 = from, R11.1 = to
; ==============================================================================
MAKE_MOVE_WHITE:
    LDI HIGH(BOARD)
    PHI 8
    LDI HIGH(WHITE_MOVE_PIECE)
    PHI 10
    LDI LOW(WHITE_MOVE_PIECE)
    PLO 10

    GLO 11
    PLO 8
    LDN 8
    STR 10

    GHI 11
    PLO 8
    LDN 8
    INC 10
    STR 10

    GHI 11
    PLO 8
    DEC 10
    LDN 10
    STR 8

    GLO 11
    PLO 8
    LDI EMPTY
    STR 8

    RETN

UNMAKE_MOVE_WHITE:
    LDI HIGH(BOARD)
    PHI 8
    LDI HIGH(WHITE_MOVE_PIECE)
    PHI 10
    LDI LOW(WHITE_MOVE_PIECE)
    PLO 10

    GLO 11
    PLO 8
    LDN 10
    STR 8

    GHI 11
    PLO 8
    INC 10
    LDN 10
    STR 8

    RETN

; ==============================================================================
; MAKE_MOVE_MEM / UNMAKE_MOVE_MEM - For inner ply (Black's move)
; Input: R11.0 = from, R11.1 = to
; ==============================================================================
MAKE_MOVE_MEM:
    LDI HIGH(BOARD)
    PHI 8
    LDI HIGH(MOVE_PIECE)
    PHI 10
    LDI LOW(MOVE_PIECE)
    PLO 10

    GLO 11
    PLO 8
    LDN 8
    STR 10

    GHI 11
    PLO 8
    LDN 8
    INC 10
    STR 10

    GHI 11
    PLO 8
    DEC 10
    LDN 10
    STR 8

    GLO 11
    PLO 8
    LDI EMPTY
    STR 8

    RETN

UNMAKE_MOVE_MEM:
    LDI HIGH(BOARD)
    PHI 8
    LDI HIGH(MOVE_PIECE)
    PHI 10
    LDI LOW(MOVE_PIECE)
    PLO 10

    GLO 11
    PLO 8
    LDN 10
    STR 8

    GHI 11
    PLO 8
    INC 10
    LDN 10
    STR 8

    RETN

; ==============================================================================
; EVALUATE_MATERIAL - Score from White's perspective
; ==============================================================================
EVALUATE_MATERIAL:
    SEX 2

    LDI HIGH(SCORE_LO)
    PHI 10
    LDI LOW(SCORE_LO)
    PLO 10
    LDI 0
    STR 10
    INC 10
    STR 10

    LDI HIGH(BOARD)
    PHI 11
    LDI LOW(BOARD)
    PLO 11

    LDI 0
    PLO 14              ; Square index

EM_LOOP:
    GLO 14
    ANI $88
    LBNZ EM_NEXT_RANK

    LDN 11
    LBZ EM_NEXT_SQ

    PLO 15              ; Save piece

    ANI $07             ; Piece type
    PLO 12

    SMI 1
    SHL
    STR 2

    LDI LOW(PIECE_VALUES)
    ADD
    PLO 8
    LDI HIGH(PIECE_VALUES)
    ADCI 0
    PHI 8

    LDA 8
    PHI 9               ; Value high
    LDN 8
    PLO 9               ; Value low

    GLO 15
    ANI $08
    LBNZ EM_SUBTRACT

EM_ADD:
    LDI HIGH(SCORE_LO)
    PHI 10
    LDI LOW(SCORE_LO)
    PLO 10

    LDN 10
    STR 2
    GLO 9
    ADD
    STR 10
    INC 10

    LDN 10
    ADCI 0
    STR 2
    GHI 9
    ADD
    STR 10

    LBR EM_NEXT_SQ

EM_SUBTRACT:
    LDI HIGH(SCORE_LO)
    PHI 10
    LDI LOW(SCORE_LO)
    PLO 10

    LDN 10
    STR 2
    GLO 9
    SD
    STR 10
    INC 10

    LDN 10
    SMBI 0
    STR 2
    GHI 9
    SD
    STR 10

    LBR EM_NEXT_SQ

EM_NEXT_SQ:
    INC 11
    INC 14
    GLO 14
    ANI $80
    LBZ EM_LOOP
    RETN

EM_NEXT_RANK:
    GLO 14
    ADI 8
    PLO 14
    ANI $80
    LBNZ EM_DONE
    GLO 11
    ADI 8
    PLO 11
    GHI 11
    ADCI 0
    PHI 11
    LBR EM_LOOP

EM_DONE:
    RETN

; ==============================================================================
; Piece Values
; ==============================================================================
PIECE_VALUES:
    DW $0064            ; Pawn   = 100
    DW $0140            ; Knight = 320
    DW $014A            ; Bishop = 330
    DW $01F4            ; Rook   = 500
    DW $0384            ; Queen  = 900
    DW $0000            ; King   = 0

; ==============================================================================
; Strings
; ==============================================================================
STR_BANNER:
    DB "Step16: Depth-2 Search", 0DH, 0AH, 0

STR_POS:
    DB "Pos: WQd4 WKe1 vs BQd6 BNc4 BPa5 BKe8", 0DH, 0AH, 0

STR_SEARCH:
    DB "Depth-2 search...", 0DH, 0AH, 0

STR_WHITE:
    DB "W: ", 0

STR_BLACK:
    DB "  B: ", 0

STR_RESULT:
    DB "  -> ", 0

STR_BEST:
    DB "Best: ", 0

STR_EXPECT:
    DB "Expect: 33-32 (Qxc4)", 0DH, 0AH, 0

STR_CRLF:
    DB 0DH, 0AH, 0

    END
