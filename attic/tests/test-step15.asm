; ==============================================================================
; Step 15: Alpha-Beta Search (Negamax)
; Basic implementation with depth-limited search
; ==============================================================================
;
; Test case: White King e4, Black Queen d4 (undefended), Black King h8
; White to move - should find Kxd4 as best move (captures queen)
;
; For simplicity, this test uses hardcoded moves rather than full movegen.
; Once validated, we'll integrate with the legal move generator.
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
MOVE_PIECE  EQU $5090
CAPT_PIECE  EQU $5091

; Search state (memory-based to survive function calls)
SEARCH_DEPTH    EQU $50A0   ; Current search depth
SEARCH_ALPHA_LO EQU $50A1   ; Alpha (16-bit)
SEARCH_ALPHA_HI EQU $50A2
SEARCH_BETA_LO  EQU $50A3   ; Beta (16-bit)
SEARCH_BETA_HI  EQU $50A4
SEARCH_BEST_LO  EQU $50A5   ; Best score found (16-bit)
SEARCH_BEST_HI  EQU $50A6
BEST_MOVE_FROM  EQU $50A7   ; Best move found
BEST_MOVE_TO    EQU $50A8
CURRENT_SIDE    EQU $50A9   ; Side to move (0=WHITE, 8=BLACK)
MOVE_INDEX      EQU $50AA   ; Current move index in search
TEMP_SCORE_LO   EQU $50AB   ; Temp score storage
TEMP_SCORE_HI   EQU $50AC
MOVE_PTR_LO     EQU $50AD   ; Move list pointer (survives serial clobbering)
MOVE_PTR_HI     EQU $50AE

; Test move list (hardcoded for this test)
TEST_MOVES      EQU $5100   ; From, To pairs

EMPTY       EQU $00
COLOR_MASK  EQU $08
PIECE_MASK  EQU $07
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

; Squares
SQ_E4       EQU $34
SQ_D4       EQU $33
SQ_H8       EQU $77
SQ_D3       EQU $23
SQ_E3       EQU $24
SQ_F3       EQU $25
SQ_D5       EQU $43
SQ_E5       EQU $44
SQ_F5       EQU $45
SQ_F4       EQU $35

; Infinity values for alpha-beta
NEG_INF_LO  EQU $01     ; -32767 = $8001
NEG_INF_HI  EQU $80
POS_INF_LO  EQU $FF     ; +32767 = $7FFF
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

    ; Set up test position
    CALL CLEAR_BOARD
    CALL SETUP_TEST_POS

    ; Print position info
    LDI HIGH(STR_POS)
    PHI 8
    LDI LOW(STR_POS)
    PLO 8
    CALL SERIAL_PRINT_STRING

    ; Set up test moves (king moves from e4)
    CALL SETUP_TEST_MOVES

    ; Do depth-1 search
    LDI HIGH(STR_SEARCH)
    PHI 8
    LDI LOW(STR_SEARCH)
    PLO 8
    CALL SERIAL_PRINT_STRING

    LDI WHITE
    PLO 12              ; R12.0 = side to move
    LDI 1
    PLO 13              ; R13.0 = depth
    CALL SEARCH_ROOT

    ; Print best move
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
    CALL PRINT_CRLF

    ; Print best score
    LDI HIGH(STR_SCORE)
    PHI 8
    LDI LOW(STR_SCORE)
    PLO 8
    CALL SERIAL_PRINT_STRING

    LDI HIGH(SEARCH_BEST_HI)
    PHI 10
    LDI LOW(SEARCH_BEST_HI)
    PLO 10
    LDN 10
    CALL SERIAL_PRINT_HEX
    LDI HIGH(SEARCH_BEST_LO)
    PHI 10
    LDI LOW(SEARCH_BEST_LO)
    PLO 10
    LDN 10
    CALL SERIAL_PRINT_HEX
    CALL PRINT_CRLF

HALT:
    BR HALT

; ==============================================================================
; SEARCH_ROOT - Root search function
; Input: R12.0 = side to move, R13.0 = depth
; Output: BEST_MOVE_FROM/TO = best move, SEARCH_BEST = best score
; ==============================================================================
SEARCH_ROOT:
    SEX 2

    ; Save side to move
    LDI HIGH(CURRENT_SIDE)
    PHI 10
    LDI LOW(CURRENT_SIDE)
    PLO 10
    GLO 12
    STR 10

    ; Initialize best score to -infinity
    LDI HIGH(SEARCH_BEST_LO)
    PHI 10
    LDI LOW(SEARCH_BEST_LO)
    PLO 10
    LDI NEG_INF_LO
    STR 10
    INC 10
    LDI NEG_INF_HI
    STR 10

    ; Initialize alpha to -infinity
    LDI LOW(SEARCH_ALPHA_LO)
    PLO 10
    LDI NEG_INF_LO
    STR 10
    INC 10
    LDI NEG_INF_HI
    STR 10

    ; Initialize beta to +infinity
    LDI LOW(SEARCH_BETA_LO)
    PLO 10
    LDI POS_INF_LO
    STR 10
    INC 10
    LDI POS_INF_HI
    STR 10

    ; Initialize move index
    LDI LOW(MOVE_INDEX)
    PLO 10
    LDI 0
    STR 10

    ; Point to test moves and save to memory
    LDI HIGH(TEST_MOVES)
    PHI 11
    LDI LOW(TEST_MOVES)
    PLO 11

    ; Save initial move pointer to memory (survives serial clobbering)
    LDI HIGH(MOVE_PTR_LO)
    PHI 10
    LDI LOW(MOVE_PTR_LO)
    PLO 10
    GLO 11
    STR 10
    INC 10
    GHI 11
    STR 10

SR_LOOP:
    ; *** RESTORE R11 from memory (serial clobbers R11.0) ***
    LDI HIGH(MOVE_PTR_LO)
    PHI 10
    LDI LOW(MOVE_PTR_LO)
    PLO 10
    LDN 10
    PLO 11
    INC 10
    LDN 10
    PHI 11
    ; Check if end of move list (from = $FF)
    LDN 11
    XRI $FF
    LBZ SR_DONE

    ; Load move into R9 (from=R9.0, to=R9.1)
    LDA 11
    PLO 9               ; from
    LDA 11
    PHI 9               ; to

    ; *** SAVE R11 to MOVE_PTR (now points to next move) ***
    LDI HIGH(MOVE_PTR_LO)
    PHI 10
    LDI LOW(MOVE_PTR_LO)
    PLO 10
    GLO 11
    STR 10
    INC 10
    GHI 11
    STR 10

    ; *** SAVE current move to TEMP storage (serial clobbers R9 too) ***
    LDI HIGH(TEMP_SCORE_LO)     ; Reuse TEMP_SCORE as move storage temp
    PHI 10
    LDI LOW(TEMP_SCORE_LO)
    PLO 10
    GLO 9
    STR 10                      ; TEMP_SCORE_LO = from
    INC 10
    GHI 9
    STR 10                      ; TEMP_SCORE_HI = to

    ; Debug: print move being tried
    LDI HIGH(STR_TRY)
    PHI 8
    LDI LOW(STR_TRY)
    PLO 8
    CALL SERIAL_PRINT_STRING

    ; Reload from from memory, print it
    LDI HIGH(TEMP_SCORE_LO)
    PHI 10
    LDI LOW(TEMP_SCORE_LO)
    PLO 10
    LDN 10
    CALL SERIAL_PRINT_HEX

    LDI '-'
    CALL SERIAL_WRITE_CHAR

    ; Reload to from memory, print it
    LDI HIGH(TEMP_SCORE_HI)
    PHI 10
    LDI LOW(TEMP_SCORE_HI)
    PLO 10
    LDN 10
    CALL SERIAL_PRINT_HEX

    ; Reload R9 from memory for make_move
    LDI HIGH(TEMP_SCORE_LO)
    PHI 10
    LDI LOW(TEMP_SCORE_LO)
    PLO 10
    LDN 10
    PLO 9               ; from
    INC 10
    LDN 10
    PHI 9               ; to

    ; Make the move (R11 format: from=R11.0, to=R11.1 for MAKE_MOVE_MEM)
    GLO 9
    PLO 11
    GHI 9
    PHI 11
    CALL MAKE_MOVE_MEM

    ; Evaluate the position
    CALL EVALUATE_MATERIAL

    ; For white, score is positive good
    ; For black, we'd negate - but this is depth 1, white to move

    ; Print score
    LDI ' '
    CALL SERIAL_WRITE_CHAR
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

    ; Compare score with best: if SCORE > SEARCH_BEST, update best
    CALL COMPARE_SCORE_WITH_BEST
    ; Returns D=1 if SCORE > BEST, D=0 otherwise
    LBZ SR_NOT_BETTER

    ; *** New best move found - reload from TEMP storage ***
    LDI HIGH(TEMP_SCORE_LO)
    PHI 10
    LDI LOW(TEMP_SCORE_LO)
    PLO 10
    LDN 10
    PLO 9               ; from
    INC 10
    LDN 10
    PHI 9               ; to

    ; Store as best move
    LDI HIGH(BEST_MOVE_FROM)
    PHI 10
    LDI LOW(BEST_MOVE_FROM)
    PLO 10
    GLO 9
    STR 10
    INC 10
    GHI 9
    STR 10

    ; Update best score from SCORE
    LDI HIGH(SCORE_LO)
    PHI 10
    LDI LOW(SCORE_LO)
    PLO 10
    LDN 10
    PLO 9               ; SCORE_LO
    INC 10
    LDN 10
    PHI 9               ; SCORE_HI

    LDI HIGH(SEARCH_BEST_LO)
    PHI 10
    LDI LOW(SEARCH_BEST_LO)
    PLO 10
    GLO 9
    STR 10
    INC 10
    GHI 9
    STR 10

    LBR SR_UNMAKE

SR_NOT_BETTER:
    ; Not better, continue to unmake

SR_UNMAKE:
    ; *** Unmake the move - reload from TEMP storage ***
    LDI HIGH(TEMP_SCORE_LO)
    PHI 10
    LDI LOW(TEMP_SCORE_LO)
    PLO 10
    LDN 10
    PLO 9               ; from
    INC 10
    LDN 10
    PHI 9               ; to

    ; Set up R11 for UNMAKE_MOVE_MEM (from=R11.0, to=R11.1)
    GLO 9
    PLO 11
    GHI 9
    PHI 11
    CALL UNMAKE_MOVE_MEM

    ; Loop to next move (MOVE_PTR saved at start, will be restored at SR_LOOP)
    LBR SR_LOOP

SR_DONE:
    RETN

; ==============================================================================
; COMPARE_SCORE_WITH_BEST - Compare SCORE with SEARCH_BEST
; Returns D=1 if SCORE > SEARCH_BEST, D=0 otherwise
; This is signed 16-bit comparison
; ==============================================================================
COMPARE_SCORE_WITH_BEST:
    SEX 2

    ; Load SEARCH_BEST into temp
    LDI HIGH(SEARCH_BEST_HI)
    PHI 10
    LDI LOW(SEARCH_BEST_HI)
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
    PHI 13              ; R13.1 = SCORE_HI
    DEC 10
    LDN 10
    PLO 13              ; R13.0 = SCORE_LO

    ; Signed comparison: SCORE > BEST ?
    ; First compare high bytes
    GHI 13              ; SCORE_HI
    STR 2
    GHI 14              ; BEST_HI
    SM                  ; BEST_HI - SCORE_HI
    ; If BEST_HI < SCORE_HI (signed), then SCORE > BEST

    ; For signed comparison, we need to handle sign bits
    ; Simplified: XOR high bytes to check if signs differ
    GHI 13
    STR 2
    GHI 14
    XOR
    ANI $80             ; Check if signs differ
    LBNZ CSB_DIFF_SIGNS

    ; Same sign - can do unsigned comparison
    GHI 13
    STR 2
    GHI 14
    SM                  ; BEST_HI - SCORE_HI
    BDF CSB_CHECK_LO    ; If no borrow, BEST_HI >= SCORE_HI
    ; BEST_HI < SCORE_HI, so SCORE > BEST
    LDI 1
    RETN

CSB_CHECK_LO:
    ; High bytes equal or BEST_HI > SCORE_HI
    ; Check if equal
    GHI 13
    STR 2
    GHI 14
    SM
    LBNZ CSB_BEST_BIGGER  ; BEST_HI > SCORE_HI

    ; High bytes equal, compare low bytes
    GLO 13              ; SCORE_LO
    STR 2
    GLO 14              ; BEST_LO
    SM                  ; BEST_LO - SCORE_LO
    BDF CSB_BEST_BIGGER ; If no borrow, BEST_LO >= SCORE_LO
    ; SCORE_LO > BEST_LO
    LDI 1
    RETN

CSB_BEST_BIGGER:
    LDI 0
    RETN

CSB_DIFF_SIGNS:
    ; Signs differ - the positive one is bigger
    ; If SCORE is positive (bit 7 = 0), SCORE > BEST
    GHI 13
    ANI $80
    LBNZ CSB_BEST_BIGGER  ; SCORE is negative, BEST is positive
    LDI 1                   ; SCORE is positive, BEST is negative
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
    PLO 13
CB_LOOP:
    LDI EMPTY
    STR 10
    INC 10
    DEC 13
    GLO 13
    LBNZ CB_LOOP
    RETN

; ==============================================================================
; SETUP_TEST_POS - White Ke4, Black Qd4 (free!), Black Kh8
; ==============================================================================
SETUP_TEST_POS:
    LDI HIGH(BOARD)
    PHI 10

    ; White king on e4
    LDI SQ_E4
    PLO 10
    LDI W_KING
    STR 10

    ; Black queen on d4 (undefended!)
    LDI SQ_D4
    PLO 10
    LDI B_QUEEN
    STR 10

    ; Black king on h8
    LDI SQ_H8
    PLO 10
    LDI B_KING
    STR 10

    RETN

; ==============================================================================
; SETUP_TEST_MOVES - King moves from e4
; Valid moves: d3, e3, f3, d4 (capture!), f4, d5, e5, f5
; ==============================================================================
SETUP_TEST_MOVES:
    LDI HIGH(TEST_MOVES)
    PHI 10
    LDI LOW(TEST_MOVES)
    PLO 10

    ; Move 1: e4-d3
    LDI SQ_E4
    STR 10
    INC 10
    LDI SQ_D3
    STR 10
    INC 10

    ; Move 2: e4-e3
    LDI SQ_E4
    STR 10
    INC 10
    LDI SQ_E3
    STR 10
    INC 10

    ; Move 3: e4-f3
    LDI SQ_E4
    STR 10
    INC 10
    LDI SQ_F3
    STR 10
    INC 10

    ; Move 4: e4-d4 (CAPTURE QUEEN!)
    LDI SQ_E4
    STR 10
    INC 10
    LDI SQ_D4
    STR 10
    INC 10

    ; Move 5: e4-f4
    LDI SQ_E4
    STR 10
    INC 10
    LDI SQ_F4
    STR 10
    INC 10

    ; Move 6: e4-d5
    LDI SQ_E4
    STR 10
    INC 10
    LDI SQ_D5
    STR 10
    INC 10

    ; Move 7: e4-e5
    LDI SQ_E4
    STR 10
    INC 10
    LDI SQ_E5
    STR 10
    INC 10

    ; Move 8: e4-f5
    LDI SQ_E4
    STR 10
    INC 10
    LDI SQ_F5
    STR 10
    INC 10

    ; End marker
    LDI $FF
    STR 10

    RETN

; ==============================================================================
; MAKE_MOVE_MEM / UNMAKE_MOVE_MEM - from test-debug16
; Input: R11.0 = from, R11.1 = to
; ==============================================================================
MAKE_MOVE_MEM:
    LDI HIGH(BOARD)
    PHI 8
    LDI HIGH(MOVE_PIECE)
    PHI 10
    LDI LOW(MOVE_PIECE)
    PLO 10

    GLO 11              ; from square
    PLO 8
    LDN 8               ; piece at from
    STR 10              ; save to MOVE_PIECE

    GHI 11              ; to square
    PLO 8
    LDN 8               ; piece at to (captured)
    INC 10
    STR 10              ; save to CAPT_PIECE

    GHI 11              ; to square
    PLO 8
    DEC 10
    LDN 10              ; get moving piece
    STR 8               ; place at to

    GLO 11              ; from square
    PLO 8
    LDI EMPTY
    STR 8               ; clear from

    RETN

UNMAKE_MOVE_MEM:
    LDI HIGH(BOARD)
    PHI 8
    LDI HIGH(MOVE_PIECE)
    PHI 10
    LDI LOW(MOVE_PIECE)
    PLO 10

    GLO 11              ; from square
    PLO 8
    LDN 10              ; get moving piece
    STR 8               ; restore at from

    GHI 11              ; to square
    PLO 8
    INC 10
    LDN 10              ; get captured piece
    STR 8               ; restore at to

    RETN

; ==============================================================================
; EVALUATE_MATERIAL - from test-step14
; Output: SCORE_HI:SCORE_LO = 16-bit signed score
; ==============================================================================
EVALUATE_MATERIAL:
    SEX 2

    ; Initialize score to 0
    LDI HIGH(SCORE_LO)
    PHI 10
    LDI LOW(SCORE_LO)
    PLO 10
    LDI 0
    STR 10
    INC 10
    STR 10

    ; Set up board scan
    LDI HIGH(BOARD)
    PHI 11
    LDI LOW(BOARD)
    PLO 11

    LDI 0
    PLO 13

EM_LOOP:
    GLO 13
    ANI $88
    LBNZ EM_NEXT_RANK

    LDN 11
    LBZ EM_NEXT_SQ

    PLO 14

    ANI PIECE_MASK
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
    PHI 15
    LDN 8
    PLO 15

    GLO 14
    ANI COLOR_MASK
    LBNZ EM_SUBTRACT

EM_ADD:
    LDI HIGH(SCORE_LO)
    PHI 10
    LDI LOW(SCORE_LO)
    PLO 10

    LDN 10
    STR 2
    GLO 15
    ADD
    STR 10
    INC 10

    LDN 10
    ADCI 0
    STR 2
    GHI 15
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
    GLO 15
    SD
    STR 10
    INC 10

    LDN 10
    SMBI 0
    STR 2
    GHI 15
    SD
    STR 10

    LBR EM_NEXT_SQ

EM_NEXT_SQ:
    INC 11
    INC 13
    GLO 13
    ANI $80
    LBZ EM_LOOP
    RETN

EM_NEXT_RANK:
    GLO 13
    ADI 8
    PLO 13
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
; Piece Value Table
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
    DB "Step15: Alpha-Beta Search", 0DH, 0AH, 0

STR_POS:
    DB "Pos: Ke4 vs Qd4+Kh8", 0DH, 0AH, 0

STR_SEARCH:
    DB "Searching depth 1...", 0DH, 0AH, 0

STR_TRY:
    DB "Try ", 0

STR_BEST:
    DB "Best: ", 0

STR_SCORE:
    DB "Score: ", 0

STR_CRLF:
    DB 0DH, 0AH, 0

    END
