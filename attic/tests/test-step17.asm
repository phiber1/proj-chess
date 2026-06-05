; ==============================================================================
; Step 17: Alpha-Beta Pruning with Negamax
; Configurable depth search with proper ply-indexed storage
; ==============================================================================
;
; This test implements proper negamax with alpha-beta pruning.
; Uses ply-indexed arrays for move storage to support arbitrary depth.
;
; Test position: Same as step16 (White Qd4 Ke1 vs Black Qd6 Nc4 Pa5 Ke8)
; At depth-2, should get same result as step16.
; Alpha-beta pruning will show benefit at depth-3+.
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

; Ply-indexed storage (4 plies max for depth-4)
; Each ply needs: MOVE_PIECE, CAPT_PIECE, MOVE_FROM, MOVE_TO, ALPHA_LO/HI, BETA_LO/HI
; Ply 0: $5090-$509F, Ply 1: $50A0-$50AF, Ply 2: $50B0-$50BF, Ply 3: $50C0-$50CF
PLY_BASE    EQU $5090       ; Base address for ply storage
PLY_SIZE    EQU $10         ; 16 bytes per ply

; Offsets within each ply's storage
PLY_MOVE_PIECE  EQU 0
PLY_CAPT_PIECE  EQU 1
PLY_MOVE_FROM   EQU 2
PLY_MOVE_TO     EQU 3
PLY_ALPHA_LO    EQU 4
PLY_ALPHA_HI    EQU 5
PLY_BETA_LO     EQU 6
PLY_BETA_HI     EQU 7
PLY_PTR_LO      EQU 8       ; Move list pointer for this ply
PLY_PTR_HI      EQU 9
PLY_BEST_LO     EQU 10      ; Best score found at this ply
PLY_BEST_HI     EQU 11

; Search state
SEARCH_DEPTH    EQU $50D0   ; Requested search depth
CURRENT_PLY     EQU $50D1   ; Current ply (0 = root)
BEST_MOVE_FROM  EQU $50D2   ; Best root move
BEST_MOVE_TO    EQU $50D3
BEST_SCORE_LO   EQU $50D4
BEST_SCORE_HI   EQU $50D5
NODE_COUNT_LO   EQU $50D6   ; Nodes searched (for stats)
NODE_COUNT_HI   EQU $50D7
CUTOFF_COUNT    EQU $50D8   ; Beta cutoffs (for stats)

; Move lists (hardcoded for this test)
WHITE_MOVES     EQU $5100
BLACK_MOVES_1   EQU $5120   ; After Qxd6
BLACK_MOVES_2   EQU $5140   ; After Qxc4
BLACK_MOVES_3   EQU $5160   ; After Qxa5

EMPTY       EQU $00
WHITE       EQU $00
BLACK       EQU $08
W_QUEEN     EQU $05
W_KING      EQU $06
B_PAWN      EQU $09
B_KNIGHT    EQU $0A
B_QUEEN     EQU $0D
B_KING      EQU $0E

; Squares
SQ_E1       EQU $04
SQ_D4       EQU $33
SQ_A5       EQU $40
SQ_D6       EQU $53
SQ_C4       EQU $32
SQ_E8       EQU $74
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

    ; Set up position and moves
    CALL CLEAR_BOARD
    CALL SETUP_POSITION
    CALL SETUP_WHITE_MOVES
    CALL SETUP_BLACK_MOVES

    ; Print position
    LDI HIGH(STR_POS)
    PHI 8
    LDI LOW(STR_POS)
    PLO 8
    CALL SERIAL_PRINT_STRING

    ; Initialize counters
    LDI HIGH(NODE_COUNT_LO)
    PHI 10
    LDI LOW(NODE_COUNT_LO)
    PLO 10
    LDI 0
    STR 10
    INC 10
    STR 10
    INC 10
    STR 10              ; CUTOFF_COUNT = 0

    ; Set search depth to 2
    LDI HIGH(SEARCH_DEPTH)
    PHI 10
    LDI LOW(SEARCH_DEPTH)
    PLO 10
    LDI 2
    STR 10

    ; Print search info
    LDI HIGH(STR_SEARCH)
    PHI 8
    LDI LOW(STR_SEARCH)
    PLO 8
    CALL SERIAL_PRINT_STRING

    ; Initialize current ply to 0
    LDI HIGH(CURRENT_PLY)
    PHI 10
    LDI LOW(CURRENT_PLY)
    PLO 10
    LDI 0
    STR 10

    ; Call negamax search
    ; Alpha = -infinity, Beta = +infinity
    CALL NEGAMAX_ROOT

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

    ; Print stats
    LDI HIGH(STR_NODES)
    PHI 8
    LDI LOW(STR_NODES)
    PLO 8
    CALL SERIAL_PRINT_STRING
    LDI HIGH(NODE_COUNT_HI)
    PHI 10
    LDI LOW(NODE_COUNT_HI)
    PLO 10
    LDN 10
    CALL SERIAL_PRINT_HEX
    LDI HIGH(NODE_COUNT_LO)
    PHI 10
    LDI LOW(NODE_COUNT_LO)
    PLO 10
    LDN 10
    CALL SERIAL_PRINT_HEX
    CALL PRINT_CRLF

    LDI HIGH(STR_CUTS)
    PHI 8
    LDI LOW(STR_CUTS)
    PLO 8
    CALL SERIAL_PRINT_STRING
    LDI HIGH(CUTOFF_COUNT)
    PHI 10
    LDI LOW(CUTOFF_COUNT)
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
; NEGAMAX_ROOT - Root-level search (ply 0)
; Handles move iteration at root specially to track best move
; ==============================================================================
NEGAMAX_ROOT:
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

    ; Set up ply 0 alpha/beta
    ; Alpha = -infinity
    LDI HIGH(PLY_BASE)
    PHI 10
    LDI LOW(PLY_BASE + PLY_ALPHA_LO)
    PLO 10
    LDI NEG_INF_LO
    STR 10
    INC 10
    LDI NEG_INF_HI
    STR 10
    ; Beta = +infinity
    INC 10              ; Now at PLY_BETA_LO
    LDI POS_INF_LO
    STR 10
    INC 10
    LDI POS_INF_HI
    STR 10

    ; Set move list pointer for ply 0
    LDI LOW(PLY_BASE + PLY_PTR_LO)
    PLO 10
    LDI LOW(WHITE_MOVES)
    STR 10
    INC 10
    LDI HIGH(WHITE_MOVES)
    STR 10

NR_LOOP:
    ; Get move list pointer
    LDI HIGH(PLY_BASE)
    PHI 10
    LDI LOW(PLY_BASE + PLY_PTR_LO)
    PLO 10
    LDN 10
    PLO 11
    INC 10
    LDN 10
    PHI 11

    ; Check end of moves
    LDN 11
    XRI $FF
    LBZ NR_DONE

    ; Load move
    LDA 11
    PLO 9               ; from
    LDA 11
    PHI 9               ; to

    ; Save updated pointer
    LDI LOW(PLY_BASE + PLY_PTR_LO)
    PLO 10
    GLO 11
    STR 10
    INC 10
    GHI 11
    STR 10

    ; Save move in ply storage
    LDI LOW(PLY_BASE + PLY_MOVE_FROM)
    PLO 10
    GLO 9
    STR 10
    INC 10
    GHI 9
    STR 10

    ; Print move being tried
    LDI HIGH(STR_TRY)
    PHI 8
    LDI LOW(STR_TRY)
    PLO 8
    CALL SERIAL_PRINT_STRING

    LDI HIGH(PLY_BASE)
    PHI 10
    LDI LOW(PLY_BASE + PLY_MOVE_FROM)
    PLO 10
    LDN 10
    CALL SERIAL_PRINT_HEX
    LDI '-'
    CALL SERIAL_WRITE_CHAR
    INC 10
    LDN 10
    CALL SERIAL_PRINT_HEX

    ; Reload and make move (set ply=0 for root)
    LDI 0
    PLO 12              ; R12 = ply 0 for root make/unmake
    LDI HIGH(PLY_BASE)
    PHI 10
    LDI LOW(PLY_BASE + PLY_MOVE_FROM)
    PLO 10
    LDN 10
    PLO 11
    INC 10
    LDN 10
    PHI 11
    CALL MAKE_MOVE_PLY

    ; Increment node count
    CALL INC_NODE_COUNT

    ; Call negamax for opponent (ply 1)
    ; score = -negamax(depth-1, -beta, -alpha)
    LDI 1
    PLO 12              ; R12.0 = ply 1
    CALL NEGAMAX_PLY

    ; Result is in SCORE_LO/HI, negate it
    CALL NEGATE_SCORE

    ; Print score
    LDI ' '
    CALL SERIAL_WRITE_CHAR
    LDI HIGH(SCORE_HI)
    PHI 10
    LDI LOW(SCORE_HI)
    PLO 10
    LDN 10
    CALL SERIAL_PRINT_HEX
    DEC 10
    LDN 10
    CALL SERIAL_PRINT_HEX
    CALL PRINT_CRLF

    ; Unmake move (set ply=0 for root)
    LDI 0
    PLO 12              ; R12 = ply 0 for root make/unmake
    LDI HIGH(PLY_BASE)
    PHI 10
    LDI LOW(PLY_BASE + PLY_MOVE_FROM)
    PLO 10
    LDN 10
    PLO 11
    INC 10
    LDN 10
    PHI 11
    CALL UNMAKE_MOVE_PLY

    ; Compare: if SCORE > BEST_SCORE, update
    CALL COMPARE_SCORE_GT_BEST
    LBZ NR_NOT_BETTER

    ; Update best move and score
    LDI HIGH(PLY_BASE)
    PHI 10
    LDI LOW(PLY_BASE + PLY_MOVE_FROM)
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

    LDI HIGH(SCORE_LO)
    PHI 10
    LDI LOW(SCORE_LO)
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

    ; Update alpha = max(alpha, score)
    ; (At root we don't prune, but update alpha for child searches)
    LDI HIGH(PLY_BASE)
    PHI 10
    LDI LOW(PLY_BASE + PLY_ALPHA_LO)
    PLO 10
    GLO 9
    STR 10
    INC 10
    GHI 9
    STR 10

NR_NOT_BETTER:
    LBR NR_LOOP

NR_DONE:
    RETN

; ==============================================================================
; NEGAMAX_PLY - Search at ply level (in R12.0)
; Returns score in SCORE_LO/HI
; ==============================================================================
NEGAMAX_PLY:
    SEX 2

    ; Check if at leaf (depth reached)
    ; If ply >= SEARCH_DEPTH, evaluate and return
    LDI HIGH(SEARCH_DEPTH)
    PHI 10
    LDI LOW(SEARCH_DEPTH)
    PLO 10
    LDN 10              ; D = search depth
    STR 2
    GLO 12              ; D = current ply
    SD                  ; D = depth - ply
    LBNF NP_EVALUATE    ; If ply >= depth, evaluate (DF=0 means borrow)
    LBZ NP_EVALUATE     ; If ply == depth, evaluate

    ; Not at leaf - search moves
    ; First, set up alpha/beta for this ply from parent
    ; Alpha = -parent_beta, Beta = -parent_alpha
    CALL SETUP_PLY_BOUNDS

    ; Get move list for this ply
    CALL SETUP_PLY_MOVES

    ; Initialize best for this ply to alpha
    CALL GET_PLY_BASE   ; R10 = ply base
    LDI PLY_BEST_LO
    PLO 10
    LDI HIGH(PLY_BASE)
    PHI 10
    GLO 12
    SHL
    SHL
    SHL
    SHL                 ; ply * 16
    STR 2
    LDI LOW(PLY_BASE + PLY_ALPHA_LO)
    ADD
    PLO 10
    LDN 10
    PLO 9               ; alpha_lo
    INC 10
    LDN 10
    PHI 9               ; alpha_hi

    ; Store in PLY_BEST
    GLO 12
    SHL
    SHL
    SHL
    SHL
    STR 2
    LDI LOW(PLY_BASE + PLY_BEST_LO)
    ADD
    PLO 10
    GLO 9
    STR 10
    INC 10
    GHI 9
    STR 10

NP_LOOP:
    ; Get move from list
    CALL GET_PLY_PTR    ; R11 = move list pointer

    ; Check end
    LDN 11
    XRI $FF
    LBZ NP_RETURN_BEST

    ; Load move
    LDA 11
    PLO 9
    LDA 11
    PHI 9

    ; Save updated pointer
    CALL SAVE_PLY_PTR

    ; Save move
    CALL SAVE_PLY_MOVE

    ; Make move
    CALL GET_PLY_MOVE
    CALL MAKE_MOVE_PLY

    ; Increment node count
    CALL INC_NODE_COUNT

    ; Recurse: negamax(ply+1)
    GLO 12
    ADI 1
    PLO 12
    CALL NEGAMAX_PLY
    GLO 12
    SMI 1
    PLO 12

    ; Negate score
    CALL NEGATE_SCORE

    ; Unmake move
    CALL GET_PLY_MOVE
    CALL UNMAKE_MOVE_PLY

    ; Check beta cutoff: if score >= beta, prune
    CALL CHECK_BETA_CUTOFF
    LBZ NP_NO_CUTOFF

    ; Beta cutoff! Increment counter and return beta
    CALL INC_CUTOFF_COUNT
    CALL GET_PLY_BETA
    ; Store beta in SCORE for return
    LDI HIGH(SCORE_LO)
    PHI 10
    LDI LOW(SCORE_LO)
    PLO 10
    GLO 9
    STR 10
    INC 10
    GHI 9
    STR 10
    RETN

NP_NO_CUTOFF:
    ; Update best if score > best
    CALL CHECK_SCORE_GT_PLY_BEST
    LBZ NP_LOOP

    ; Update PLY_BEST = SCORE
    CALL UPDATE_PLY_BEST
    LBR NP_LOOP

NP_RETURN_BEST:
    ; Return PLY_BEST in SCORE
    CALL GET_PLY_BEST
    LDI HIGH(SCORE_LO)
    PHI 10
    LDI LOW(SCORE_LO)
    PLO 10
    GLO 9
    STR 10
    INC 10
    GHI 9
    STR 10
    RETN

NP_EVALUATE:
    ; Leaf node - evaluate position
    CALL EVALUATE_MATERIAL
    ; Score is already in SCORE_LO/HI
    RETN

; ==============================================================================
; Helper functions for ply-indexed access
; ==============================================================================

; GET_PLY_BASE - Get base address for current ply into R10
; R12.0 = ply number
GET_PLY_BASE:
    LDI HIGH(PLY_BASE)
    PHI 10
    GLO 12
    SHL
    SHL
    SHL
    SHL                 ; ply * 16
    STR 2
    LDI LOW(PLY_BASE)
    ADD
    PLO 10
    RETN

; GET_PLY_PTR - Get move list pointer for current ply into R11
GET_PLY_PTR:
    GLO 12
    SHL
    SHL
    SHL
    SHL
    STR 2
    LDI LOW(PLY_BASE + PLY_PTR_LO)
    ADD
    PLO 10
    LDI HIGH(PLY_BASE)
    PHI 10
    LDN 10
    PLO 11
    INC 10
    LDN 10
    PHI 11
    RETN

; SAVE_PLY_PTR - Save R11 as move pointer for current ply
SAVE_PLY_PTR:
    GLO 12
    SHL
    SHL
    SHL
    SHL
    STR 2
    LDI LOW(PLY_BASE + PLY_PTR_LO)
    ADD
    PLO 10
    LDI HIGH(PLY_BASE)
    PHI 10
    GLO 11
    STR 10
    INC 10
    GHI 11
    STR 10
    RETN

; SAVE_PLY_MOVE - Save R9 (from/to) as current move for ply
SAVE_PLY_MOVE:
    GLO 12
    SHL
    SHL
    SHL
    SHL
    STR 2
    LDI LOW(PLY_BASE + PLY_MOVE_FROM)
    ADD
    PLO 10
    LDI HIGH(PLY_BASE)
    PHI 10
    GLO 9
    STR 10
    INC 10
    GHI 9
    STR 10
    RETN

; GET_PLY_MOVE - Get current move for ply into R11
GET_PLY_MOVE:
    GLO 12
    SHL
    SHL
    SHL
    SHL
    STR 2
    LDI LOW(PLY_BASE + PLY_MOVE_FROM)
    ADD
    PLO 10
    LDI HIGH(PLY_BASE)
    PHI 10
    LDN 10
    PLO 11
    INC 10
    LDN 10
    PHI 11
    RETN

; GET_PLY_BETA - Get beta for current ply into R9
GET_PLY_BETA:
    GLO 12
    SHL
    SHL
    SHL
    SHL
    STR 2
    LDI LOW(PLY_BASE + PLY_BETA_LO)
    ADD
    PLO 10
    LDI HIGH(PLY_BASE)
    PHI 10
    LDN 10
    PLO 9
    INC 10
    LDN 10
    PHI 9
    RETN

; GET_PLY_BEST - Get best score for current ply into R9
GET_PLY_BEST:
    GLO 12
    SHL
    SHL
    SHL
    SHL
    STR 2
    LDI LOW(PLY_BASE + PLY_BEST_LO)
    ADD
    PLO 10
    LDI HIGH(PLY_BASE)
    PHI 10
    LDN 10
    PLO 9
    INC 10
    LDN 10
    PHI 9
    RETN

; UPDATE_PLY_BEST - Set PLY_BEST = SCORE
UPDATE_PLY_BEST:
    LDI HIGH(SCORE_LO)
    PHI 10
    LDI LOW(SCORE_LO)
    PLO 10
    LDN 10
    PLO 9
    INC 10
    LDN 10
    PHI 9

    GLO 12
    SHL
    SHL
    SHL
    SHL
    STR 2
    LDI LOW(PLY_BASE + PLY_BEST_LO)
    ADD
    PLO 10
    LDI HIGH(PLY_BASE)
    PHI 10
    GLO 9
    STR 10
    INC 10
    GHI 9
    STR 10
    RETN

; SETUP_PLY_BOUNDS - Set alpha/beta from parent (negated and swapped)
; Child alpha = -parent_beta, Child beta = -parent_alpha
SETUP_PLY_BOUNDS:
    ; Get parent ply (ply - 1)
    GLO 12
    SMI 1
    SHL
    SHL
    SHL
    SHL
    PLO 14              ; parent offset

    ; Get parent beta -> negate -> child alpha
    GLO 14
    STR 2
    LDI LOW(PLY_BASE + PLY_BETA_LO)
    ADD
    PLO 10
    LDI HIGH(PLY_BASE)
    PHI 10
    LDN 10
    PLO 9               ; parent_beta_lo
    INC 10
    LDN 10
    PHI 9               ; parent_beta_hi

    ; Negate: -x = ~x + 1
    GLO 9
    XRI $FF
    PLO 9
    GHI 9
    XRI $FF
    PHI 9
    GLO 9
    ADI 1
    PLO 9
    GHI 9
    ADCI 0
    PHI 9

    ; Store as child alpha
    GLO 12
    SHL
    SHL
    SHL
    SHL
    STR 2
    LDI LOW(PLY_BASE + PLY_ALPHA_LO)
    ADD
    PLO 10
    LDI HIGH(PLY_BASE)
    PHI 10
    GLO 9
    STR 10
    INC 10
    GHI 9
    STR 10

    ; Get parent alpha -> negate -> child beta
    GLO 14
    STR 2
    LDI LOW(PLY_BASE + PLY_ALPHA_LO)
    ADD
    PLO 10
    LDN 10
    PLO 9
    INC 10
    LDN 10
    PHI 9

    ; Negate
    GLO 9
    XRI $FF
    PLO 9
    GHI 9
    XRI $FF
    PHI 9
    GLO 9
    ADI 1
    PLO 9
    GHI 9
    ADCI 0
    PHI 9

    ; Store as child beta
    GLO 12
    SHL
    SHL
    SHL
    SHL
    STR 2
    LDI LOW(PLY_BASE + PLY_BETA_LO)
    ADD
    PLO 10
    LDI HIGH(PLY_BASE)
    PHI 10
    GLO 9
    STR 10
    INC 10
    GHI 9
    STR 10

    RETN

; SETUP_PLY_MOVES - Set move list pointer based on ply and position
; For this test, we use hardcoded lists based on which move was made
SETUP_PLY_MOVES:
    ; For ply 1, select based on ply 0's move
    GLO 12
    XRI 1
    LBNZ SPM_DEFAULT

    ; Ply 1: Check what move was made at ply 0
    LDI HIGH(PLY_BASE)
    PHI 10
    LDI LOW(PLY_BASE + PLY_MOVE_TO)
    PLO 10
    LDN 10              ; Get 'to' square of ply 0 move

    XRI SQ_D6           ; Was it Qxd6?
    LBZ SPM_LIST1
    LDN 10
    XRI SQ_C4           ; Was it Qxc4?
    LBZ SPM_LIST2
    LBR SPM_LIST3       ; Must be Qxa5

SPM_LIST1:
    LDI LOW(BLACK_MOVES_1)
    PLO 9
    LDI HIGH(BLACK_MOVES_1)
    PHI 9
    LBR SPM_STORE

SPM_LIST2:
    LDI LOW(BLACK_MOVES_2)
    PLO 9
    LDI HIGH(BLACK_MOVES_2)
    PHI 9
    LBR SPM_STORE

SPM_LIST3:
    LDI LOW(BLACK_MOVES_3)
    PLO 9
    LDI HIGH(BLACK_MOVES_3)
    PHI 9
    LBR SPM_STORE

SPM_DEFAULT:
    ; Default: no moves (will return immediately)
    LDI $FF
    PLO 9
    PHI 9

SPM_STORE:
    GLO 12
    SHL
    SHL
    SHL
    SHL
    STR 2
    LDI LOW(PLY_BASE + PLY_PTR_LO)
    ADD
    PLO 10
    LDI HIGH(PLY_BASE)
    PHI 10
    GLO 9
    STR 10
    INC 10
    GHI 9
    STR 10
    RETN

; ==============================================================================
; Comparison and arithmetic helpers
; ==============================================================================

; NEGATE_SCORE - Negate SCORE_LO/HI in place
NEGATE_SCORE:
    LDI HIGH(SCORE_LO)
    PHI 10
    LDI LOW(SCORE_LO)
    PLO 10
    LDN 10
    XRI $FF
    PLO 9
    INC 10
    LDN 10
    XRI $FF
    PHI 9
    GLO 9
    ADI 1
    PLO 9
    GHI 9
    ADCI 0
    PHI 9
    DEC 10
    GLO 9
    STR 10
    INC 10
    GHI 9
    STR 10
    RETN

; CHECK_BETA_CUTOFF - Return D=1 if SCORE >= beta (current ply)
CHECK_BETA_CUTOFF:
    CALL GET_PLY_BETA   ; R9 = beta

    ; Load SCORE
    LDI HIGH(SCORE_LO)
    PHI 10
    LDI LOW(SCORE_LO)
    PLO 10
    LDN 10
    PLO 15
    INC 10
    LDN 10
    PHI 15              ; R15 = SCORE

    ; Is R15 >= R9 (SCORE >= beta)?
    ; Check signs
    GHI 15
    STR 2
    GHI 9
    XOR
    ANI $80
    LBNZ CBC_DIFF_SIGNS

    ; Same sign - compare
    GHI 9               ; beta_hi
    STR 2
    GHI 15              ; score_hi
    SM                  ; score_hi - beta_hi
    BDF CBC_CHECK_LO
    LDI 0
    RETN

CBC_CHECK_LO:
    GHI 9
    STR 2
    GHI 15
    SM
    LBNZ CBC_GE         ; score_hi > beta_hi

    GLO 9
    STR 2
    GLO 15
    SM
    BDF CBC_GE
    LDI 0
    RETN

CBC_GE:
    LDI 1
    RETN

CBC_DIFF_SIGNS:
    ; Positive is greater
    GHI 15
    ANI $80
    LBNZ CBC_NO         ; SCORE negative, beta positive
    LDI 1               ; SCORE positive, beta negative
    RETN

CBC_NO:
    LDI 0
    RETN

; CHECK_SCORE_GT_PLY_BEST - Return D=1 if SCORE > PLY_BEST
CHECK_SCORE_GT_PLY_BEST:
    CALL GET_PLY_BEST   ; R9 = best

    LDI HIGH(SCORE_LO)
    PHI 10
    LDI LOW(SCORE_LO)
    PLO 10
    LDN 10
    PLO 15
    INC 10
    LDN 10
    PHI 15              ; R15 = SCORE

    ; Is R15 > R9?
    GHI 15
    STR 2
    GHI 9
    XOR
    ANI $80
    LBNZ CSGB_DIFF

    GHI 9
    STR 2
    GHI 15
    SM
    BDF CSGB_CHECK_LO
    LDI 0
    RETN

CSGB_CHECK_LO:
    GHI 9
    STR 2
    GHI 15
    SM
    LBNZ CSGB_GT

    GLO 9
    STR 2
    GLO 15
    SM
    BDF CSGB_MAYBE
    LDI 0
    RETN

CSGB_MAYBE:
    GLO 9
    STR 2
    GLO 15
    SM
    LBZ CSGB_NO         ; Equal, not greater

CSGB_GT:
    LDI 1
    RETN

CSGB_NO:
    LDI 0
    RETN

CSGB_DIFF:
    GHI 15
    ANI $80
    LBNZ CSGB_NO
    LDI 1
    RETN

; COMPARE_SCORE_GT_BEST - Return D=1 if SCORE > BEST_SCORE
; Signed 16-bit comparison
COMPARE_SCORE_GT_BEST:
    LDI HIGH(BEST_SCORE_LO)
    PHI 10
    LDI LOW(BEST_SCORE_LO)
    PLO 10
    LDN 10
    PLO 9
    INC 10
    LDN 10
    PHI 9               ; R9 = BEST

    LDI HIGH(SCORE_LO)
    PHI 10
    LDI LOW(SCORE_LO)
    PLO 10
    LDN 10
    PLO 15
    INC 10
    LDN 10
    PHI 15              ; R15 = SCORE

    ; Is R15 > R9? (signed comparison)
    ; Check if different signs
    GHI 15
    STR 2
    GHI 9
    XOR
    ANI $80
    LBNZ CSGB2_DIFF

    ; Same sign - use unsigned comparison (works for same-sign values)
    ; Compare high bytes first using SD (no borrow dependency)
    GHI 9               ; best_hi
    STR 2
    GHI 15              ; score_hi
    SD                  ; D = best_hi - score_hi (note: SD is M-D)
    BNZ CSGB2_HI_DIFF   ; High bytes differ

    ; High bytes equal - compare low bytes
    GLO 9               ; best_lo
    STR 2
    GLO 15              ; score_lo
    SD                  ; D = best_lo - score_lo
    BZ CSGB2_EQUAL      ; Equal
    ; DF=1 (no borrow): best_lo > score_lo -> SCORE < BEST
    ; DF=0 (borrow): best_lo < score_lo -> SCORE > BEST
    BNF CSGB2_GT        ; borrow means score_lo > best_lo
    LDI 0               ; no borrow means score_lo < best_lo
    RETN

CSGB2_HI_DIFF:
    ; DF=1 means no borrow, so best_hi > score_hi (SCORE not greater)
    ; DF=0 means borrow, so best_hi < score_hi (SCORE is greater)
    BNF CSGB2_GT        ; best_hi < score_hi -> SCORE > BEST
    LDI 0               ; best_hi > score_hi -> SCORE < BEST
    RETN

CSGB2_EQUAL:
    LDI 0
    RETN

CSGB2_GT:
    LDI 1
    RETN

CSGB2_DIFF:
    ; Different signs - positive is greater
    GHI 15
    ANI $80
    LBNZ CSGB2_EQUAL    ; SCORE negative, BEST positive -> not greater
    LDI 1               ; SCORE positive, BEST negative -> greater
    RETN

; INC_NODE_COUNT - Increment 16-bit node counter
INC_NODE_COUNT:
    LDI HIGH(NODE_COUNT_LO)
    PHI 10
    LDI LOW(NODE_COUNT_LO)
    PLO 10
    LDN 10
    ADI 1
    STR 10
    INC 10
    LDN 10
    ADCI 0
    STR 10
    RETN

; INC_CUTOFF_COUNT - Increment 8-bit cutoff counter
INC_CUTOFF_COUNT:
    LDI HIGH(CUTOFF_COUNT)
    PHI 10
    LDI LOW(CUTOFF_COUNT)
    PLO 10
    LDN 10
    ADI 1
    STR 10
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
; Board and position setup (same as step16)
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

SETUP_POSITION:
    LDI HIGH(BOARD)
    PHI 10
    LDI SQ_E1
    PLO 10
    LDI W_KING
    STR 10
    LDI SQ_D4
    PLO 10
    LDI W_QUEEN
    STR 10
    LDI SQ_D6
    PLO 10
    LDI B_QUEEN
    STR 10
    LDI SQ_C4
    PLO 10
    LDI B_KNIGHT
    STR 10
    LDI SQ_A5
    PLO 10
    LDI B_PAWN
    STR 10
    LDI SQ_E8
    PLO 10
    LDI B_KING
    STR 10
    RETN

SETUP_WHITE_MOVES:
    LDI HIGH(WHITE_MOVES)
    PHI 10
    LDI LOW(WHITE_MOVES)
    PLO 10
    LDI SQ_D4
    STR 10
    INC 10
    LDI SQ_D6
    STR 10
    INC 10
    LDI SQ_D4
    STR 10
    INC 10
    LDI SQ_C4
    STR 10
    INC 10
    LDI SQ_D4
    STR 10
    INC 10
    LDI SQ_A5
    STR 10
    INC 10
    LDI $FF
    STR 10
    RETN

SETUP_BLACK_MOVES:
    ; After Qxd6
    LDI HIGH(BLACK_MOVES_1)
    PHI 10
    LDI LOW(BLACK_MOVES_1)
    PLO 10
    LDI SQ_C4
    STR 10
    INC 10
    LDI SQ_D6
    STR 10
    INC 10
    LDI SQ_A5
    STR 10
    INC 10
    LDI $30
    STR 10
    INC 10
    LDI $FF
    STR 10

    ; After Qxc4
    LDI HIGH(BLACK_MOVES_2)
    PHI 10
    LDI LOW(BLACK_MOVES_2)
    PLO 10
    LDI SQ_D6
    STR 10
    INC 10
    LDI $43
    STR 10
    INC 10
    LDI SQ_A5
    STR 10
    INC 10
    LDI $30
    STR 10
    INC 10
    LDI $FF
    STR 10

    ; After Qxa5
    LDI HIGH(BLACK_MOVES_3)
    PHI 10
    LDI LOW(BLACK_MOVES_3)
    PLO 10
    LDI SQ_D6
    STR 10
    INC 10
    LDI $43
    STR 10
    INC 10
    LDI SQ_C4
    STR 10
    INC 10
    LDI SQ_D2
    STR 10
    INC 10
    LDI $FF
    STR 10

    RETN

; ==============================================================================
; MAKE_MOVE_PLY / UNMAKE_MOVE_PLY - Uses ply-indexed storage
; Input: R11.0 = from, R11.1 = to, R12.0 = ply
; ==============================================================================
MAKE_MOVE_PLY:
    ; Get ply storage base
    GLO 12
    SHL
    SHL
    SHL
    SHL
    STR 2
    LDI LOW(PLY_BASE + PLY_MOVE_PIECE)
    ADD
    PLO 10
    LDI HIGH(PLY_BASE)
    PHI 10

    LDI HIGH(BOARD)
    PHI 8

    GLO 11
    PLO 8
    LDN 8
    STR 10              ; Save moving piece

    GHI 11
    PLO 8
    LDN 8
    INC 10
    STR 10              ; Save captured piece

    GHI 11
    PLO 8
    DEC 10
    LDN 10              ; Get moving piece
    STR 8               ; Place at destination

    GLO 11
    PLO 8
    LDI EMPTY
    STR 8               ; Clear source

    RETN

UNMAKE_MOVE_PLY:
    GLO 12
    SHL
    SHL
    SHL
    SHL
    STR 2
    LDI LOW(PLY_BASE + PLY_MOVE_PIECE)
    ADD
    PLO 10
    LDI HIGH(PLY_BASE)
    PHI 10

    LDI HIGH(BOARD)
    PHI 8

    GLO 11
    PLO 8
    LDN 10
    STR 8               ; Restore piece at source

    GHI 11
    PLO 8
    INC 10
    LDN 10
    STR 8               ; Restore captured piece

    RETN

; ==============================================================================
; EVALUATE_MATERIAL
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
    PLO 14

EM_LOOP:
    GLO 14
    ANI $88
    LBNZ EM_NEXT_RANK
    LDN 11
    LBZ EM_NEXT_SQ
    PLO 15
    ANI $07
    PLO 13
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
    PHI 9
    LDN 8
    PLO 9
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
; Data
; ==============================================================================
PIECE_VALUES:
    DW $0064
    DW $0140
    DW $014A
    DW $01F4
    DW $0384
    DW $0000

STR_BANNER:
    DB "Step17: Alpha-Beta Negamax", 0DH, 0AH, 0

STR_POS:
    DB "Pos: WQd4 WKe1 vs BQd6 BNc4 BPa5 BKe8", 0DH, 0AH, 0

STR_SEARCH:
    DB "Depth-2 search with A-B...", 0DH, 0AH, 0

STR_TRY:
    DB "Try ", 0

STR_BEST:
    DB "Best: ", 0

STR_NODES:
    DB "Nodes: ", 0

STR_CUTS:
    DB "Cutoffs: ", 0

STR_EXPECT:
    DB "Expect: 33-32 (Qxc4)", 0DH, 0AH, 0

STR_CRLF:
    DB 0DH, 0AH, 0

    END
