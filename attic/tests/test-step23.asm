; ==============================================================================
; Step 23: Quiescence Search
; Adds quiescence search to avoid horizon effect
; ==============================================================================
;
; Based on step-22 (working depth-3/4 search)
; Adds quiescence at leaf nodes to search captures
;
; Test position: WKe1 WQd1 WPa2 vs BKe8 BPa7
;
; ==============================================================================

    ORG $0000
#ifdef BIOS
    LBR START           ; BIOS already set up SCRT and stack
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
SCORE_LO    EQU $5088
SCORE_HI    EQU $5089

; Ply-indexed storage (4 plies max)
PLY_BASE    EQU $5090
PLY_SIZE    EQU $10

; Offsets within each ply's storage
PLY_MOVE_PIECE  EQU 0
PLY_CAPT_PIECE  EQU 1
PLY_MOVE_FROM   EQU 2
PLY_MOVE_TO     EQU 3
PLY_ALPHA_LO    EQU 4
PLY_ALPHA_HI    EQU 5
PLY_BETA_LO     EQU 6
PLY_BETA_HI     EQU 7
PLY_PTR_LO      EQU 8
PLY_PTR_HI      EQU 9
PLY_BEST_LO     EQU 10
PLY_BEST_HI     EQU 11

; Search state
SEARCH_DEPTH    EQU $50D0
CURRENT_PLY     EQU $50D1
BEST_MOVE_FROM  EQU $50D2
BEST_MOVE_TO    EQU $50D3
BEST_SCORE_LO   EQU $50D4
BEST_SCORE_HI   EQU $50D5
NODE_COUNT_LO   EQU $50D6
NODE_COUNT_HI   EQU $50D7
CUTOFF_COUNT_LO EQU $50D8
CUTOFF_COUNT_HI EQU $50DA
TEMP_PLY        EQU $50D9      ; Save ply during movegen
SIDE_TO_MOVE    EQU $50DB      ; 0=White, 8=Black

; Additional temp storage (avoid R14)
PARENT_OFFSET   EQU $50E2      ; Parent ply offset for SETUP_PLY_BOUNDS
TEMP_COUNTER    EQU $50E3      ; Loop counter for CLEAR_BOARD
SQ_INDEX        EQU $50E4      ; Square index for EVALUATE_MATERIAL

; Per-ply move lists (32 bytes each = max 15 moves + terminator)
MOVELIST_PLY0   EQU $5100
MOVELIST_PLY1   EQU $5120
MOVELIST_PLY2   EQU $5140
MOVELIST_PLY3   EQU $5160

; Piece codes
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

; Squares
SQ_A1       EQU $00
SQ_B1       EQU $01
SQ_C1       EQU $02
SQ_D1       EQU $03
SQ_E1       EQU $04
SQ_F1       EQU $05
SQ_G1       EQU $06
SQ_H1       EQU $07
SQ_A2       EQU $10
SQ_E8       EQU $74
SQ_A7       EQU $60
SQ_H8       EQU $77

; Castling rights
CASTLE_WK   EQU $01
CASTLE_WQ   EQU $02
CASTLE_BK   EQU $04
CASTLE_BQ   EQU $08
SQ_D8       EQU $73
SQ_C8       EQU $72
SQ_B8       EQU $71
SQ_F8       EQU $75
SQ_G8       EQU $76

; Direction offsets
DIR_N   EQU $F0
DIR_S   EQU $10
DIR_E   EQU $01
DIR_W   EQU $FF
DIR_NE  EQU $F1
DIR_NW  EQU $EF
DIR_SE  EQU $11
DIR_SW  EQU $0F

; Infinity
NEG_INF_LO  EQU $01
NEG_INF_HI  EQU $80
POS_INF_LO  EQU $FF
POS_INF_HI  EQU $7F

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
    CALL SERIAL_PRINT_STRING

    ; Set up position
    CALL CLEAR_BOARD
    CALL SETUP_POSITION
    CALL INIT_GAME_STATE

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
    STR 10              ; NODE_COUNT_HI = 0
    INC 10
    STR 10              ; CUTOFF_COUNT_LO = 0
    INC 10
    INC 10              ; Skip TEMP_PLY
    STR 10              ; CUTOFF_COUNT_HI = 0

    ; Set search depth to 3 (increase to 4 for deeper search on faster hardware)
    LDI HIGH(SEARCH_DEPTH)
    PHI 10
    LDI LOW(SEARCH_DEPTH)
    PLO 10
    LDI 3               ; Depth 3 for testing
    STR 10

    ; Set side to move = WHITE
    LDI HIGH(SIDE_TO_MOVE)
    PHI 10
    LDI LOW(SIDE_TO_MOVE)
    PLO 10
    LDI WHITE
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

    ; Call search
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

    ; Print nodes
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

    ; Print cutoffs
    LDI HIGH(STR_CUTOFFS)
    PHI 8
    LDI LOW(STR_CUTOFFS)
    PLO 8
    CALL SERIAL_PRINT_STRING
    LDI HIGH(CUTOFF_COUNT_HI)
    PHI 10
    LDI LOW(CUTOFF_COUNT_HI)
    PLO 10
    LDN 10
    CALL SERIAL_PRINT_HEX
    LDI HIGH(CUTOFF_COUNT_LO)
    PHI 10
    LDI LOW(CUTOFF_COUNT_LO)
    PLO 10
    LDN 10
    CALL SERIAL_PRINT_HEX
    CALL PRINT_CRLF

    ; Done
    LDI HIGH(STR_DONE)
    PHI 8
    LDI LOW(STR_DONE)
    PLO 8
    CALL SERIAL_PRINT_STRING

#ifdef BIOS
    LBR $8003           ; Return to BIOS monitor
#else
HALT:
    BR HALT
#endif

; ==============================================================================
; NEGAMAX_ROOT - Root-level search
; Generates moves using full movegen, iterates through them
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
    LDI HIGH(PLY_BASE)
    PHI 10
    LDI LOW(PLY_BASE + PLY_ALPHA_LO)
    PLO 10
    LDI NEG_INF_LO
    STR 10
    INC 10
    LDI NEG_INF_HI
    STR 10
    INC 10
    LDI POS_INF_LO
    STR 10
    INC 10
    LDI POS_INF_HI
    STR 10

    ; Generate moves for ply 0 (WHITE)
    LDI 0
    PLO 12                  ; ply = 0
    CALL GENERATE_MOVES_FOR_PLY

    ; Set move pointer for ply 0
    LDI HIGH(PLY_BASE)
    PHI 10
    LDI LOW(PLY_BASE + PLY_PTR_LO)
    PLO 10
    LDI LOW(MOVELIST_PLY0)
    STR 10
    INC 10
    LDI HIGH(MOVELIST_PLY0)
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
    PLO 9
    LDA 11
    PHI 9

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

    ; Reload and make move
    LDI 0
    PLO 12
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
    LDI 1
    PLO 12              ; R12.0 = ply 1
    CALL NEGAMAX_PLY

    ; Negate score (negamax)
    CALL NEGATE_SCORE

    ; Unmake move
    LDI 0
    PLO 12
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

    ; Update alpha at root level (for proper propagation to children)
    ; alpha = max(alpha, score)
    CALL UPDATE_ROOT_ALPHA

NR_NOT_BETTER:
    LBR NR_LOOP

NR_DONE:
    RETN

; ==============================================================================
; UPDATE_ROOT_ALPHA - Update ply 0 alpha if SCORE > current alpha
; ==============================================================================
UPDATE_ROOT_ALPHA:
    ; Get current alpha
    LDI HIGH(PLY_BASE)
    PHI 10
    LDI LOW(PLY_BASE + PLY_ALPHA_LO)
    PLO 10
    LDN 10
    PLO 9
    INC 10
    LDN 10
    PHI 9               ; R9 = current alpha

    ; Get score
    LDI HIGH(SCORE_LO)
    PHI 10
    LDI LOW(SCORE_LO)
    PLO 10
    LDN 10
    PLO 15
    INC 10
    LDN 10
    PHI 15              ; R15 = score

    ; Compare R15 > R9 (signed)
    GHI 15
    STR 2
    GHI 9
    XOR
    ANI $80
    LBNZ URA_DIFF_SIGN

    ; Same sign comparison
    GHI 9
    STR 2
    GHI 15
    SD
    BNZ URA_HI_DIFF
    GLO 9
    STR 2
    GLO 15
    SD
    BZ URA_NO_UPDATE
    BNF URA_UPDATE
    RETN

URA_HI_DIFF:
    BNF URA_UPDATE
    RETN

URA_DIFF_SIGN:
    GHI 15
    ANI $80
    LBNZ URA_NO_UPDATE
    ; Score is positive, alpha is negative - update

URA_UPDATE:
    ; Update alpha = score
    LDI HIGH(PLY_BASE)
    PHI 10
    LDI LOW(PLY_BASE + PLY_ALPHA_LO)
    PLO 10
    GLO 15
    STR 10
    INC 10
    GHI 15
    STR 10

URA_NO_UPDATE:
    RETN

; ==============================================================================
; NEGAMAX_PLY - Search at ply level (in R12.0)
; Returns score in SCORE_LO/HI
; NOW WITH ALPHA-BETA CUTOFFS!
; ==============================================================================
NEGAMAX_PLY:
    SEX 2

    ; Check if at leaf (depth reached)
    LDI HIGH(SEARCH_DEPTH)
    PHI 10
    LDI LOW(SEARCH_DEPTH)
    PLO 10
    LDN 10              ; D = search depth
    STR 2
    GLO 12              ; D = current ply
    SD                  ; D = depth - ply
    LBNF NP_EVALUATE    ; If ply >= depth, evaluate
    LBZ NP_EVALUATE

    ; Not at leaf - set up alpha/beta from parent
    CALL SETUP_PLY_BOUNDS

    ; Generate moves for this ply
    CALL GENERATE_MOVES_FOR_PLY

    ; Set move pointer
    GLO 12
    SHL
    SHL
    SHL
    SHL
    SHL                 ; ply * 32
    STR 2
    LDI LOW(MOVELIST_PLY0)
    ADD
    PLO 9
    LDI HIGH(MOVELIST_PLY0)
    ADCI 0
    PHI 9

    ; Store in ply's PTR
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

    ; Initialize best to -infinity
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
    LDI NEG_INF_LO
    STR 10
    INC 10
    LDI NEG_INF_HI
    STR 10

NP_LOOP:
    ; Get move pointer
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

    ; Save move in ply storage
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

    ; Make move
    DEC 10
    LDN 10
    PLO 11
    INC 10
    LDN 10
    PHI 11
    CALL MAKE_MOVE_PLY

    ; Increment node count
    CALL INC_NODE_COUNT

    ; Recurse
    INC 12
    CALL NEGAMAX_PLY
    DEC 12

    ; Negate score
    CALL NEGATE_SCORE

    ; Unmake move
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
    CALL UNMAKE_MOVE_PLY

    ; Update best if score > best
    CALL CHECK_SCORE_GT_PLY_BEST
    LBZ NP_LOOP

    ; Update PLY_BEST = SCORE
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

    ; =========================================================================
    ; ALPHA-BETA CUTOFF CHECK
    ; If best >= beta, we have a cutoff - stop searching this node
    ; =========================================================================
    CALL CHECK_BEST_GE_BETA
    LBZ NP_NO_CUTOFF

    ; CUTOFF! Increment counter and return
    CALL INC_CUTOFF_COUNT
    LBR NP_RETURN_BEST

NP_NO_CUTOFF:
    ; Update alpha = max(alpha, best)
    CALL UPDATE_PLY_ALPHA
    LBR NP_LOOP

NP_RETURN_BEST:
    ; Return PLY_BEST in SCORE
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
    ; Leaf node - do quiescence search
    CALL QUIESCENCE_SEARCH
    RETN

; ==============================================================================
; QUIESCENCE_SEARCH - Search captures at leaf nodes
; Avoids horizon effect by continuing to search captures
; Input: R12.0 = current ply
; Output: SCORE_LO/HI = best score
; ==============================================================================
QUIESCENCE_SEARCH:
    SEX 2

    ; Stand-pat: evaluate current position
    CALL EVALUATE_MATERIAL
    ; Negate if odd ply (black's perspective)
    GLO 12
    ANI $01
    LBZ QS_NO_NEG_SP
    CALL NEGATE_SCORE
QS_NO_NEG_SP:
    ; Stand-pat score is in SCORE_LO/HI - save to QS_BEST for later
    ; (GENERATE_MOVES will clobber R15 which we'd otherwise use)
    ; QS_BEST is at $50E0-$50E1
    LDI HIGH(SCORE_LO)
    PHI 10
    LDI LOW(SCORE_LO)
    PLO 10
    LDN 10
    PLO 15              ; R15.0 = score_lo (temp)
    INC 10
    LDN 10
    PHI 15              ; R15.1 = score_hi (temp)
    ; Save to QS_BEST
    LDI $50
    PHI 10
    LDI $E0
    PLO 10
    GLO 15
    STR 10
    INC 10
    GHI 15
    STR 10

    ; Generate moves for this ply
    GLO 12
    STR 2               ; Save ply
    LDI HIGH(TEMP_PLY)
    PHI 10
    LDI LOW(TEMP_PLY)
    PLO 10
    LDN 2
    STR 10              ; Save ply to TEMP_PLY

    CALL GENERATE_MOVES_FOR_PLY

    ; Restore ply from TEMP_PLY
    LDI HIGH(TEMP_PLY)
    PHI 10
    LDI LOW(TEMP_PLY)
    PLO 10
    LDN 10
    PLO 12

    ; Restore stand-pat (best) to R15
    LDI $50
    PHI 10
    LDI $E0
    PLO 10
    LDN 10
    PLO 15
    INC 10
    LDN 10
    PHI 15

    ; Set up move list pointer
    GLO 12
    SHL
    SHL
    SHL
    SHL
    SHL                 ; ply * 32
    STR 2
    LDI LOW(MOVELIST_PLY0)
    ADD
    PLO 9
    LDI HIGH(MOVELIST_PLY0)
    ADCI 0
    PHI 9               ; R9 = move list pointer

QS_LOOP:
    ; Check for end of move list
    LDN 9
    XRI $FF
    LBZ QS_RETURN

    ; Load from/to
    LDA 9
    PLO 11              ; R11.0 = from
    LDA 9
    PHI 11              ; R11.1 = to

    ; Check if capture: target square must have piece
    GHI 11              ; to square
    STR 2
    LDI HIGH(BOARD)
    PHI 8
    LDN 2
    PLO 8
    LDN 8               ; piece at target
    LBZ QS_LOOP         ; empty, not a capture - skip

    ; Check if enemy piece (not own piece)
    ANI $08             ; color bit of target
    STR 2
    GLO 12              ; ply
    ANI $01             ; 0=white moving, 1=black moving
    SHL
    SHL
    SHL                 ; 0 or 8 (our color)
    XOR                 ; XOR with target color
    LBZ QS_LOOP         ; same color = own piece, skip

    ; It's a capture!
    ; Save R9 and R15
    GHI 9
    STXD
    GLO 9
    STXD
    GHI 15
    STXD
    GLO 15
    STXD

    ; Save move to ply storage for make/unmake
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
    GLO 11
    STR 10              ; from
    INC 10
    GHI 11
    STR 10              ; to

    ; Make move
    CALL MAKE_MOVE_PLY

    ; Evaluate position after capture
    CALL EVALUATE_MATERIAL

    ; Negate if odd ply
    GLO 12
    ANI $01
    LBZ QS_NO_NEG_EVAL
    CALL NEGATE_SCORE
QS_NO_NEG_EVAL:

    ; Unmake move
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
    PLO 11              ; from
    INC 10
    LDN 10
    PHI 11              ; to
    CALL UNMAKE_MOVE_PLY

    ; Restore R15 (best score)
    IRX
    LDXA
    PLO 15
    LDXA
    PHI 15
    ; Restore R9 (move pointer) - still on stack
    LDXA
    PLO 9
    LDX
    PHI 9

    ; Compare SCORE with best (R15)
    ; If SCORE > R15, update R15
    ; Load SCORE into R13 (F_TYPE saves/restores R13, unlike R14)
    LDI HIGH(SCORE_LO)
    PHI 10
    LDI LOW(SCORE_LO)
    PLO 10
    LDN 10
    PLO 13              ; R13.0 = score_lo
    INC 10
    LDN 10
    PHI 13              ; R13.1 = score_hi

    ; Signed comparison: R13 > R15?
    GHI 13
    STR 2
    GHI 15
    XOR
    ANI $80
    LBNZ QS_DIFF_SIGN

    ; Same sign - compare normally
    GHI 15
    STR 2
    GHI 13
    SD
    BNZ QS_HI_DIFF
    ; High bytes equal, compare low
    GLO 15
    STR 2
    GLO 13
    SD
    LBZ QS_LOOP         ; equal, don't update
    LBNF QS_UPDATE      ; score > best
    LBR QS_LOOP         ; score < best

QS_HI_DIFF:
    LBNF QS_UPDATE      ; score > best
    LBR QS_LOOP         ; score < best

QS_DIFF_SIGN:
    ; Different signs - positive is greater
    GHI 13
    ANI $80
    LBNZ QS_LOOP        ; score negative, best positive - don't update
    ; score positive, best negative - update

QS_UPDATE:
    ; best = score
    GLO 13
    PLO 15
    GHI 13
    PHI 15
    LBR QS_LOOP

QS_RETURN:
    ; Store best (R15) to SCORE
    LDI HIGH(SCORE_LO)
    PHI 10
    LDI LOW(SCORE_LO)
    PLO 10
    GLO 15
    STR 10
    INC 10
    GHI 15
    STR 10
    RETN

; ==============================================================================
; CHECK_BEST_GE_BETA - Return D=1 if PLY_BEST >= PLY_BETA (signed)
; This is the cutoff condition for alpha-beta
; ==============================================================================
CHECK_BEST_GE_BETA:
    ; Get PLY_BEST into R9
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
    PHI 9               ; R9 = best

    ; Get PLY_BETA into R15
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
    PLO 15
    INC 10
    LDN 10
    PHI 15              ; R15 = beta

    ; Compare: R9 >= R15? (best >= beta?)
    ; This is equivalent to: NOT (best < beta)
    ; Or: best - beta >= 0

    ; Check if different signs
    GHI 9
    STR 2
    GHI 15
    XOR
    ANI $80
    LBNZ CBGB_DIFF_SIGN

    ; Same sign - subtract and check
    GLO 15
    STR 2
    GLO 9
    SM              ; D = best_lo - beta_lo (DF set for borrow)

    GHI 15
    STR 2
    GHI 9
    SMB             ; D = best_hi - beta_hi - borrow

    ; If high byte result >= 0, and no underflow, best >= beta
    LBNF CBGB_YES   ; If no borrow, best >= beta
    LDI 0
    RETN

CBGB_DIFF_SIGN:
    ; Different signs
    ; If best is positive (bit 7 = 0) and beta is negative (bit 7 = 1), best >= beta
    ; If best is negative (bit 7 = 1) and beta is positive (bit 7 = 0), best < beta
    GHI 9
    ANI $80
    LBNZ CBGB_NO    ; best is negative, beta positive -> best < beta

CBGB_YES:
    LDI 1
    RETN

CBGB_NO:
    LDI 0
    RETN

; ==============================================================================
; UPDATE_PLY_ALPHA - Set alpha = max(alpha, best) for current ply
; ==============================================================================
UPDATE_PLY_ALPHA:
    ; Get PLY_BEST into R9
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
    PHI 9               ; R9 = best

    ; Get PLY_ALPHA into R15
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
    LDN 10
    PLO 15
    INC 10
    LDN 10
    PHI 15              ; R15 = alpha

    ; If best > alpha, update alpha = best
    GHI 9
    STR 2
    GHI 15
    XOR
    ANI $80
    LBNZ UPA_DIFF_SIGN

    ; Same sign comparison
    GHI 15
    STR 2
    GHI 9
    SD
    LBNZ UPA_HI_DIFF
    GLO 15
    STR 2
    GLO 9
    SD
    LBZ UPA_NO_UPDATE
    LBNF UPA_UPDATE
    RETN

UPA_HI_DIFF:
    LBNF UPA_UPDATE
    RETN

UPA_DIFF_SIGN:
    GHI 9
    ANI $80
    LBNZ UPA_NO_UPDATE
    ; best is positive, alpha is negative - update

UPA_UPDATE:
    ; Update alpha = best
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

UPA_NO_UPDATE:
    RETN

; ==============================================================================
; INC_CUTOFF_COUNT - Increment the cutoff counter
; ==============================================================================
INC_CUTOFF_COUNT:
    LDI HIGH(CUTOFF_COUNT_LO)
    PHI 10
    LDI LOW(CUTOFF_COUNT_LO)
    PLO 10
    LDN 10
    ADI 1
    STR 10
    INC 10
    INC 10          ; Skip TEMP_PLY to get to CUTOFF_COUNT_HI
    LDN 10
    ADCI 0
    STR 10
    RETN

; ==============================================================================
; GENERATE_MOVES_FOR_PLY - Wrapper for GENERATE_MOVES
; Input: R12.0 = ply
; Output: Moves written to ply's move list, terminated with $FF
; ==============================================================================
GENERATE_MOVES_FOR_PLY:
    SEX 2

    ; Save ply to memory (GENERATE_MOVES will clobber R12)
    LDI HIGH(TEMP_PLY)
    PHI 10
    LDI LOW(TEMP_PLY)
    PLO 10
    GLO 12
    STR 10              ; Save ply

    ; Calculate move list address for this ply
    ; Ply 0: $5100, Ply 1: $5120, Ply 2: $5140, Ply 3: $5160
    SHL
    SHL
    SHL
    SHL
    SHL                 ; ply * 32
    STR 2
    LDI LOW(MOVELIST_PLY0)
    ADD
    PLO 9
    LDI HIGH(MOVELIST_PLY0)
    ADCI 0
    PHI 9               ; R9 = move list pointer for GENERATE_MOVES

    ; Set R12 = side to move based on ply (even = WHITE/0, odd = BLACK/8)
    LDI HIGH(TEMP_PLY)
    PHI 10
    LDI LOW(TEMP_PLY)
    PLO 10
    LDN 10              ; Get ply back
    ANI $01             ; Odd = black
    LBZ GMFP_WHITE
    LDI BLACK           ; $08
    LBR GMFP_SET_SIDE
GMFP_WHITE:
    LDI WHITE           ; $00
GMFP_SET_SIDE:
    PLO 12              ; R12.0 = side to move for GENERATE_MOVES

    ; Call the full move generator
    CALL GENERATE_MOVES

    ; D now contains move count - we don't need it, moves are in list
    ; Add terminator to move list (R9 is already past last move)
    LDI $FF
    STR 9

    ; Restore ply to R12
    LDI HIGH(TEMP_PLY)
    PHI 10
    LDI LOW(TEMP_PLY)
    PLO 10
    LDN 10
    PLO 12

    RETN

; ==============================================================================
; SETUP_PLY_BOUNDS - Set alpha/beta from parent (negated and swapped)
; ==============================================================================
SETUP_PLY_BOUNDS:
    ; Get parent ply offset and store in memory (avoid R14)
    GLO 12
    SMI 1
    SHL
    SHL
    SHL
    SHL
    STR 2               ; parent offset in M(R2)
    LDI HIGH(PARENT_OFFSET)
    PHI 10
    LDI LOW(PARENT_OFFSET)
    PLO 10
    LDN 2
    STR 10              ; Save parent offset to memory

    ; Get parent beta -> negate -> child alpha
    LDN 10              ; Get parent offset from memory
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
    LDI HIGH(PARENT_OFFSET)
    PHI 10
    LDI LOW(PARENT_OFFSET)
    PLO 10
    LDN 10              ; Get parent offset from memory
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

; ==============================================================================
; NEGATE_SCORE - Negate SCORE_LO/HI in place
; ==============================================================================
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

; ==============================================================================
; CHECK_SCORE_GT_PLY_BEST - Return D=1 if SCORE > PLY_BEST
; ==============================================================================
CHECK_SCORE_GT_PLY_BEST:
    ; Get PLY_BEST into R9
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

    ; Get SCORE into R15
    LDI HIGH(SCORE_LO)
    PHI 10
    LDI LOW(SCORE_LO)
    PLO 10
    LDN 10
    PLO 15
    INC 10
    LDN 10
    PHI 15

    ; Compare R15 > R9?
    GHI 15
    STR 2
    GHI 9
    XOR
    ANI $80
    LBNZ CSPB_DIFF

    ; Same sign
    GHI 9
    STR 2
    GHI 15
    SD
    BNZ CSPB_HI_DIFF
    GLO 9
    STR 2
    GLO 15
    SD
    BZ CSPB_EQ
    LBNF CSPB_GT
    LDI 0
    RETN

CSPB_HI_DIFF:
    LBNF CSPB_GT
    LDI 0
    RETN

CSPB_EQ:
    LDI 0
    RETN

CSPB_GT:
    LDI 1
    RETN

CSPB_DIFF:
    GHI 15
    ANI $80
    LBNZ CSPB_EQ
    LDI 1
    RETN

; ==============================================================================
; Helpers
; ==============================================================================

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
    GHI 15
    STR 2
    GHI 9
    XOR
    ANI $80
    LBNZ CSGB_DIFF

    ; Same sign
    GHI 9               ; best_hi
    STR 2
    GHI 15              ; score_hi
    SD                  ; D = best_hi - score_hi
    BNZ CSGB_HI_DIFF

    ; High bytes equal
    GLO 9
    STR 2
    GLO 15
    SD
    BZ CSGB_EQUAL
    BNF CSGB_GT
    LDI 0
    RETN

CSGB_HI_DIFF:
    BNF CSGB_GT
    LDI 0
    RETN

CSGB_EQUAL:
    LDI 0
    RETN

CSGB_GT:
    LDI 1
    RETN

CSGB_DIFF:
    GHI 15
    ANI $80
    LBNZ CSGB_EQUAL
    LDI 1
    RETN

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

PRINT_CRLF:
    LDI HIGH(STR_CRLF)
    PHI 8
    LDI LOW(STR_CRLF)
    PLO 8
    CALL SERIAL_PRINT_STRING
    RETN

; ==============================================================================
; Board setup
; ==============================================================================
CLEAR_BOARD:
    LDI HIGH(BOARD)
    PHI 10
    LDI LOW(BOARD)
    PLO 10
    ; Store counter in memory (avoid R14)
    LDI HIGH(TEMP_COUNTER)
    PHI 8
    LDI LOW(TEMP_COUNTER)
    PLO 8
    LDI 128
    STR 8
CB_LOOP:
    LDI EMPTY
    STR 10
    INC 10
    ; Decrement counter in memory
    LDN 8
    SMI 1
    STR 8
    LBNZ CB_LOOP
    RETN

SETUP_POSITION:
    LDI HIGH(BOARD)
    PHI 10

    ; White King at e1 ($04)
    LDI SQ_E1
    PLO 10
    LDI W_KING
    STR 10

    ; White Queen at d1 ($03)
    LDI SQ_D1
    PLO 10
    LDI W_QUEEN
    STR 10

    ; White Pawn at a2 ($10)
    LDI SQ_A2
    PLO 10
    LDI W_PAWN
    STR 10

    ; Black King at e8 ($74)
    LDI SQ_E8
    PLO 10
    LDI B_KING
    STR 10

    ; Black Pawn at a7 ($60)
    LDI SQ_A7
    PLO 10
    LDI B_PAWN
    STR 10

    RETN

INIT_GAME_STATE:
    LDI HIGH(GAME_STATE)
    PHI 10
    LDI LOW(GAME_STATE)
    PLO 10
    ; No castling rights (kings not on original squares with rooks)
    LDI 0
    STR 10
    INC 10
    ; No en passant
    LDI $FF             ; $FF = no EP square
    STR 10
    RETN

; ==============================================================================
; MAKE_MOVE_PLY / UNMAKE_MOVE_PLY
; Input: R11.0 = from, R11.1 = to, R12.0 = ply
; ==============================================================================
MAKE_MOVE_PLY:
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
; EVALUATE_MATERIAL - Simple material count
; Uses SQ_INDEX in memory instead of R14 (BIOS clobbers R14)
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
    ; Initialize square index in memory
    LDI HIGH(SQ_INDEX)
    PHI 13
    LDI LOW(SQ_INDEX)
    PLO 13
    LDI 0
    STR 13              ; SQ_INDEX = 0

EM_LOOP:
    LDN 13              ; Get square index
    ANI $88
    LBNZ EM_NEXT_RANK
    LDN 11
    LBZ EM_NEXT_SQ
    PLO 15
    ANI $07
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
    ; Increment square index in memory
    LDN 13
    ADI 1
    STR 13
    ANI $80
    LBZ EM_LOOP
    RETN

EM_NEXT_RANK:
    ; Skip to next rank (add 8 to skip invalid squares)
    LDN 13
    ADI 8
    STR 13
    PLO 15              ; Temp save for later check
    GLO 11
    ADI 8
    PLO 11
    GHI 11
    ADCI 0
    PHI 11
    GLO 15              ; Get index back
    ANI $80
    LBNZ EM_DONE
    LBR EM_LOOP

EM_DONE:
    RETN

; ==============================================================================
; Include full move generator
; ==============================================================================
#include "movegen-new.asm"

; ==============================================================================
; Data Tables
; ==============================================================================

PIECE_VALUES:
    DW $0064        ; Pawn = 100
    DW $0140        ; Knight = 320
    DW $014A        ; Bishop = 330
    DW $01F4        ; Rook = 500
    DW $0384        ; Queen = 900
    DW $0000        ; King = 0

STR_BANNER:
    DB "Step23: Quiescence Search", 0DH, 0AH, 0

STR_POS:
    DB "WKe1 WQd1 WPa2 vs BKe8 BPa7", 0DH, 0AH, 0

STR_SEARCH:
    DB "Depth-3 + quiescence...", 0DH, 0AH, 0

STR_BEST:
    DB "Best: ", 0

STR_NODES:
    DB "Nodes: ", 0

STR_CUTOFFS:
    DB "Cutoffs: ", 0

STR_DONE:
    DB "Done!", 0DH, 0AH, 0

STR_CRLF:
    DB 0DH, 0AH, 0

    END
