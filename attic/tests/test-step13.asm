; ==============================================================================
; Step 13: Legal Move Filtering
; Generate only legal moves (filter out moves that leave king in check)
; ==============================================================================
;
; Test cases:
; 1. Starting position - 20 legal moves (14 hex)
; 2. King e1 vs Queen e8 - few legal moves (king escapes + blocks)
; 3. Pinned rook - rook on e2 can't move (pinned by rook on e8)
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
MOVE_LIST   EQU $5200
LEGAL_LIST  EQU $5300       ; Filtered legal moves

GS_SIDE     EQU 0
GS_CASTLE   EQU 1
GS_EP       EQU 2

CASTLE_WK   EQU $01
CASTLE_WQ   EQU $02
CASTLE_BK   EQU $04
CASTLE_BQ   EQU $08
ALL_CASTLING EQU $0F

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

NO_EP       EQU $FF

; Directions
DIR_N       EQU $F0
DIR_S       EQU $10
DIR_E       EQU $01
DIR_W       EQU $FF
DIR_NE      EQU $F1
DIR_NW      EQU $EF
DIR_SE      EQU $11
DIR_SW      EQU $0F

; Squares
SQ_E1       EQU $04
SQ_E2       EQU $14
SQ_D1       EQU $03
SQ_F1       EQU $05
SQ_E8       EQU $74

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

    LDI HIGH(STR_BANNER)
    PHI 8
    LDI LOW(STR_BANNER)
    PLO 8
    CALL SERIAL_PRINT_STRING

    ; =========================================
    ; Test 1: Starting position (20 legal moves)
    ; =========================================
    LDI HIGH(STR_TEST1)
    PHI 8
    LDI LOW(STR_TEST1)
    PLO 8
    CALL SERIAL_PRINT_STRING

    CALL CLEAR_BOARD
    CALL SETUP_START_POS

    LDI WHITE
    PLO 12
    CALL GEN_LEGAL_MOVES

    CALL SERIAL_PRINT_HEX
    CALL PRINT_CRLF

    ; =========================================
    ; Test 2: King e1 vs Queen e8 (queen gives check)
    ; White has: Kd1, Kf1, Kd2, Kf2, and blocking with pieces
    ; With just kings + queen: Kd1, Kf1 = 2 moves
    ; =========================================
    LDI HIGH(STR_TEST2)
    PHI 8
    LDI LOW(STR_TEST2)
    PLO 8
    CALL SERIAL_PRINT_STRING

    CALL CLEAR_BOARD

    ; White king e1
    LDI HIGH(BOARD)
    PHI 10
    LDI SQ_E1
    PLO 10
    LDI W_KING
    STR 10

    ; Black king (required) on a8
    LDI $70
    PLO 10
    LDI B_KING
    STR 10

    ; Black queen e8 - giving check
    LDI SQ_E8
    PLO 10
    LDI B_QUEEN
    STR 10

    ; Init game state
    LDI HIGH(GAME_STATE)
    PHI 10
    LDI LOW(GAME_STATE)
    PLO 10
    LDI WHITE
    STR 10
    INC 10
    LDI 0               ; No castling
    STR 10
    INC 10
    LDI NO_EP
    STR 10

    LDI WHITE
    PLO 12
    CALL GEN_LEGAL_MOVES

    CALL SERIAL_PRINT_HEX
    CALL PRINT_CRLF

    ; =========================================
    ; Test 3: Pinned rook (rook e2 pinned by rook e8)
    ; King e1, white rook e2, black rook e8
    ; Rook can't move at all (only along pin line, but blocked by king)
    ; Legal moves: King d1, f1, d2, f2 = 4 moves
    ; =========================================
    LDI HIGH(STR_TEST3)
    PHI 8
    LDI LOW(STR_TEST3)
    PLO 8
    CALL SERIAL_PRINT_STRING

    CALL CLEAR_BOARD

    ; White king e1
    LDI HIGH(BOARD)
    PHI 10
    LDI SQ_E1
    PLO 10
    LDI W_KING
    STR 10

    ; White rook e2 (pinned)
    LDI SQ_E2
    PLO 10
    LDI W_ROOK
    STR 10

    ; Black king on a8
    LDI $70
    PLO 10
    LDI B_KING
    STR 10

    ; Black rook e8 (pinning)
    LDI SQ_E8
    PLO 10
    LDI B_ROOK
    STR 10

    ; Init game state
    LDI HIGH(GAME_STATE)
    PHI 10
    LDI LOW(GAME_STATE)
    PLO 10
    LDI WHITE
    STR 10
    INC 10
    LDI 0
    STR 10
    INC 10
    LDI NO_EP
    STR 10

    LDI WHITE
    PLO 12
    CALL GEN_LEGAL_MOVES

    CALL SERIAL_PRINT_HEX
    CALL PRINT_CRLF

HALT:
    BR HALT

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
; GEN_LEGAL_MOVES - Generate legal moves only
; ==============================================================================
; Input:  R12.0 = side to move
; Output: D = legal move count
; ==============================================================================
GEN_LEGAL_MOVES:
    ; First generate all pseudo-legal moves
    LDI HIGH(MOVE_LIST)
    PHI 9
    LDI LOW(MOVE_LIST)
    PLO 9

    CALL GENERATE_MOVES
    PLO 15              ; R15.0 = pseudo-legal count

    ; Now filter: for each move, make it, check, unmake it
    LDI HIGH(MOVE_LIST)
    PHI 10              ; R10 = source (pseudo-legal list)
    LDI LOW(MOVE_LIST)
    PLO 10

    LDI HIGH(LEGAL_LIST)
    PHI 9               ; R9 = dest (legal list)
    LDI LOW(LEGAL_LIST)
    PLO 9

    LDI 0
    PLO 14              ; R14.0 = legal move count

GLM_LOOP:
    GLO 15
    LBZ GLM_DONE        ; No more moves

    ; Get from/to squares
    LDA 10              ; from
    PLO 11
    LDA 10              ; to
    PHI 11              ; R11 = from (low), to (high)

    ; Save registers on stack (IS_IN_CHECK clobbers R7, R10, R11, R14)
    GLO 12              ; Save side to move (critical!)
    STXD
    GLO 14              ; Save legal count
    STXD
    GHI 10
    STXD
    GLO 10
    STXD
    GHI 11
    STXD
    GLO 11
    STXD

    ; Make the move
    CALL MAKE_MOVE

    ; Save R7 (piece info needed for unmake)
    GHI 7
    STXD
    GLO 7
    STXD

    ; Check if in check
    CALL IS_IN_CHECK
    PLO 13              ; Save check result in R13.0

    ; Restore R7
    IRX
    LDXA
    PLO 7
    LDX
    PHI 7

    ; Restore R11 for unmake
    IRX
    LDXA
    PLO 11
    LDX
    PHI 11

    ; Unmake the move (always)
    CALL UNMAKE_MOVE

    ; Restore R10 from stack
    IRX
    LDXA
    PLO 10
    LDX
    PHI 10

    ; Restore R14.0 (legal count)
    IRX
    LDXA
    PLO 14

    ; Restore R12.0 (side to move)
    LDX
    PLO 12

    ; Check result
    GLO 13
    LBNZ GLM_NEXT       ; In check = illegal, skip

GLM_LEGAL:

    ; Add to legal list
    GLO 11              ; from
    STR 9
    INC 9
    GHI 11              ; to
    STR 9
    INC 9
    INC 14              ; count++

GLM_NEXT:
    DEC 15
    LBR GLM_LOOP

GLM_DONE:
    GLO 14              ; Return legal count
    RETN

; ==============================================================================
; MAKE_MOVE - Make a move on the board
; ==============================================================================
; Input:  R11.0 = from, R11.1 = to
; Saves captured piece in R7.1 for unmake
; ==============================================================================
MAKE_MOVE:
    LDI HIGH(BOARD)
    PHI 8

    ; Get piece at 'from'
    GLO 11
    PLO 8
    LDN 8
    PLO 7               ; R7.0 = moving piece

    ; Get piece at 'to' (captured, if any)
    GHI 11
    PLO 8
    LDN 8
    PHI 7               ; R7.1 = captured piece

    ; Place moving piece at 'to'
    GLO 7
    STR 8

    ; Clear 'from'
    GLO 11
    PLO 8
    LDI EMPTY
    STR 8

    RETN

; ==============================================================================
; UNMAKE_MOVE - Undo a move
; ==============================================================================
; Input:  R11.0 = from, R11.1 = to
;         R7.0 = moving piece, R7.1 = captured piece
; ==============================================================================
UNMAKE_MOVE:
    LDI HIGH(BOARD)
    PHI 8

    ; Restore piece to 'from'
    GLO 11
    PLO 8
    GLO 7               ; moving piece
    STR 8

    ; Restore captured piece (or empty) to 'to'
    GHI 11
    PLO 8
    GHI 7               ; captured piece
    STR 8

    RETN

; ==============================================================================
; Include movegen-new.asm (GENERATE_MOVES)
; ==============================================================================
#include "movegen-new.asm"

; ==============================================================================
; IS_IN_CHECK - Check if king is under attack
; ==============================================================================
; (Copied from test-step12 with proper pawn directions)
; Input:  R12.0 = side to check
; Output: D = 1 if in check, 0 if not
; ==============================================================================
IS_IN_CHECK:
    ; Find the king
    LDI HIGH(BOARD)
    PHI 10
    LDI LOW(BOARD)
    PLO 10

    LDI 6
    STR 2
    GLO 12
    ADD
    PLO 14              ; R14.0 = king piece code

    LDI 0
    PLO 11              ; R11.0 = square index

IIC_FIND_KING:
    GLO 11
    ANI $88
    LBNZ IIC_FIND_NEXT

    LDN 10
    STR 2
    GLO 14
    SM
    LBZ IIC_FOUND_KING

IIC_FIND_NEXT:
    INC 10
    INC 11
    GLO 11
    ANI $80
    LBZ IIC_FIND_KING

    LDI 0
    RETN

IIC_FOUND_KING:
    ; R11.0 = king's square
    GLO 12
    XRI BLACK
    PLO 13              ; R13.0 = enemy color

    ; --- Check pawn attacks ---
    GLO 12
    LBNZ IIC_PAWN_BLACK_KING

IIC_PAWN_WHITE_KING:
    GLO 11
    ADI DIR_SE
    PLO 14
    ANI $88
    LBNZ IIC_PAWN_SW

    LDI HIGH(BOARD)
    PHI 7
    GLO 14
    PLO 7
    LDN 7
    SMI B_PAWN
    LBZ IIC_IN_CHECK

IIC_PAWN_SW:
    GLO 11
    ADI DIR_SW
    PLO 14
    ANI $88
    LBNZ IIC_CHECK_KNIGHTS

    LDI HIGH(BOARD)
    PHI 7
    GLO 14
    PLO 7
    LDN 7
    SMI B_PAWN
    LBZ IIC_IN_CHECK
    LBR IIC_CHECK_KNIGHTS

IIC_PAWN_BLACK_KING:
    GLO 11
    ADI DIR_NE
    PLO 14
    ANI $88
    LBNZ IIC_PAWN_NW

    LDI HIGH(BOARD)
    PHI 7
    GLO 14
    PLO 7
    LDN 7
    SMI W_PAWN
    LBZ IIC_IN_CHECK

IIC_PAWN_NW:
    GLO 11
    ADI DIR_NW
    PLO 14
    ANI $88
    LBNZ IIC_CHECK_KNIGHTS

    LDI HIGH(BOARD)
    PHI 7
    GLO 14
    PLO 7
    LDN 7
    SMI W_PAWN
    LBZ IIC_IN_CHECK

IIC_CHECK_KNIGHTS:
    LDI HIGH(KNIGHT_OFFSETS)
    PHI 8
    LDI LOW(KNIGHT_OFFSETS)
    PLO 8

    LDI 8
    PLO 14

    LDI 2
    STR 2
    GLO 13
    ADD
    PHI 14              ; R14.1 = enemy knight

IIC_KN_LOOP:
    LDN 8
    STR 2
    GLO 11
    ADD
    PLO 7

    ANI $88
    LBNZ IIC_KN_NEXT

    LDI HIGH(BOARD)
    PHI 7
    LDN 7
    STR 2
    GHI 14
    SM
    LBZ IIC_IN_CHECK

IIC_KN_NEXT:
    INC 8
    DEC 14
    GLO 14
    LBNZ IIC_KN_LOOP

    ; --- Check diagonal attacks ---
    LDI HIGH(BISHOP_DIRS)
    PHI 8
    LDI LOW(BISHOP_DIRS)
    PLO 8

    LDI 4
    PLO 14

    LDI 3
    STR 2
    GLO 13
    ADD
    PHI 14              ; R14.1 = enemy bishop

IIC_DIAG_DIR:
    LDN 8
    PHI 13

    GLO 11
    PLO 7

IIC_DIAG_RAY:
    GLO 7
    STR 2
    GHI 13
    ADD
    PLO 7

    ANI $88
    LBNZ IIC_DIAG_NEXT

    LDI HIGH(BOARD)
    PHI 10
    GLO 7
    PLO 10
    LDN 10
    LBZ IIC_DIAG_RAY

    PLO 10
    STR 2
    GHI 14
    SM
    LBZ IIC_IN_CHECK

    GHI 14
    ADI 2
    STR 2
    GLO 10
    SM
    LBZ IIC_IN_CHECK

    LBR IIC_DIAG_NEXT

IIC_DIAG_NEXT:
    INC 8
    DEC 14
    GLO 14
    LBNZ IIC_DIAG_DIR

    ; --- Check orthogonal attacks ---
    LDI HIGH(ROOK_DIRS)
    PHI 8
    LDI LOW(ROOK_DIRS)
    PLO 8

    LDI 4
    PLO 14

    LDI 4
    STR 2
    GLO 13
    ADD
    PHI 14              ; R14.1 = enemy rook

IIC_ORTH_DIR:
    LDN 8
    PHI 13

    GLO 11
    PLO 7

IIC_ORTH_RAY:
    GLO 7
    STR 2
    GHI 13
    ADD
    PLO 7

    ANI $88
    LBNZ IIC_ORTH_NEXT

    LDI HIGH(BOARD)
    PHI 10
    GLO 7
    PLO 10
    LDN 10
    LBZ IIC_ORTH_RAY

    PLO 10
    STR 2
    GHI 14
    SM
    LBZ IIC_IN_CHECK

    GHI 14
    ADI 1
    STR 2
    GLO 10
    SM
    LBZ IIC_IN_CHECK

    LBR IIC_ORTH_NEXT

IIC_ORTH_NEXT:
    INC 8
    DEC 14
    GLO 14
    LBNZ IIC_ORTH_DIR

    ; --- Check king attacks ---
    LDI HIGH(KING_OFFSETS)
    PHI 8
    LDI LOW(KING_OFFSETS)
    PLO 8

    LDI 8
    PLO 14

    LDI 6
    STR 2
    GLO 13
    ADD
    PHI 14              ; R14.1 = enemy king

IIC_KI_LOOP:
    LDN 8
    STR 2
    GLO 11
    ADD
    PLO 7

    ANI $88
    LBNZ IIC_KI_NEXT

    LDI HIGH(BOARD)
    PHI 7
    LDN 7
    STR 2
    GHI 14
    SM
    LBZ IIC_IN_CHECK

IIC_KI_NEXT:
    INC 8
    DEC 14
    GLO 14
    LBNZ IIC_KI_LOOP

    LDI 0
    RETN

IIC_IN_CHECK:
    LDI 1
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
; SETUP_START_POS - Full starting position
; ==============================================================================
SETUP_START_POS:
    LDI HIGH(BOARD)
    PHI 10

    ; White back rank
    LDI $00
    PLO 10
    LDI W_ROOK
    STR 10
    INC 10
    LDI W_KNIGHT
    STR 10
    INC 10
    LDI W_BISHOP
    STR 10
    INC 10
    LDI W_QUEEN
    STR 10
    INC 10
    LDI W_KING
    STR 10
    INC 10
    LDI W_BISHOP
    STR 10
    INC 10
    LDI W_KNIGHT
    STR 10
    INC 10
    LDI W_ROOK
    STR 10

    ; White pawns
    LDI $10
    PLO 10
    LDI 8
    PLO 13
SSP_WP:
    LDI W_PAWN
    STR 10
    INC 10
    DEC 13
    GLO 13
    LBNZ SSP_WP

    ; Black pawns
    LDI $60
    PLO 10
    LDI 8
    PLO 13
SSP_BP:
    LDI B_PAWN
    STR 10
    INC 10
    DEC 13
    GLO 13
    LBNZ SSP_BP

    ; Black back rank
    LDI $70
    PLO 10
    LDI B_ROOK
    STR 10
    INC 10
    LDI B_KNIGHT
    STR 10
    INC 10
    LDI B_BISHOP
    STR 10
    INC 10
    LDI B_QUEEN
    STR 10
    INC 10
    LDI B_KING
    STR 10
    INC 10
    LDI B_BISHOP
    STR 10
    INC 10
    LDI B_KNIGHT
    STR 10
    INC 10
    LDI B_ROOK
    STR 10

    ; Game state
    LDI HIGH(GAME_STATE)
    PHI 10
    LDI LOW(GAME_STATE)
    PLO 10
    LDI WHITE
    STR 10
    INC 10
    LDI ALL_CASTLING
    STR 10
    INC 10
    LDI NO_EP
    STR 10

    RETN

; ==============================================================================
; Strings
; ==============================================================================
STR_BANNER:
    DB "Step13: Legal moves", 0DH, 0AH, 0

STR_TEST1:
    DB "Start pos: ", 0

STR_TEST2:
    DB "Ke1 vs Qe8: ", 0

STR_TEST3:
    DB "Pinned Re2: ", 0

STR_CRLF:
    DB 0DH, 0AH, 0

    END
