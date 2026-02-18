; ==============================================================================
; Step 10: En passant capture
; Position after 1.e4 d5 2.e5 f5 - white can play exf6 e.p.
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

; Board definitions
BOARD       EQU $5000
GAME_STATE  EQU $5080
MOVE_LIST   EQU $5200

; Game state offsets
GS_SIDE     EQU 0
GS_CASTLE   EQU 1
GS_EP       EQU 2       ; En passant target square

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

ALL_CASTLING EQU $0F
NO_EP       EQU $FF

; Squares
SQ_E1       EQU $04
SQ_E8       EQU $74
SQ_E2       EQU $14
SQ_E4       EQU $34
SQ_E5       EQU $44
SQ_D7       EQU $63
SQ_D5       EQU $43
SQ_F7       EQU $65
SQ_F5       EQU $45
SQ_F6       EQU $55     ; En passant target

DIR_N       EQU $F0     ; -16
DIR_S       EQU $10     ; +16
DIR_E       EQU $01     ; +1
DIR_W       EQU $FF     ; -1
DIR_NE      EQU $F1     ; -15
DIR_NW      EQU $EF     ; -17
DIR_SE      EQU $11     ; +17
DIR_SW      EQU $0F     ; +15

; Pawn capture directions (white pawns)
CAP_LEFT    EQU $0F     ; +15: forward-left diagonal
CAP_RIGHT   EQU $11     ; +17: forward-right diagonal

; Knight offsets (8 L-shaped moves)
KNIGHT_OFFSETS:
    DB $DF, $E1, $EE, $F2, $0E, $12, $1F, $21

; King offsets (8 directions)
KING_OFFSETS:
    DB $EF, $F0, $F1, $FF, $01, $0F, $10, $11

; Sliding directions for bishop (4 diagonals)
BISHOP_DIRS:
    DB $EF, $F1, $0F, $11

; Sliding directions for rook (4 orthogonals)
ROOK_DIRS:
    DB $F0, $10, $FF, $01

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

    CALL INIT_BOARD

    ; Set up position after 1.e4 d5 2.e5 f5
    ; Clear e2, place pawn on e5
    LDI HIGH(BOARD)
    PHI 10
    LDI SQ_E2
    PLO 10
    LDI EMPTY
    STR 10

    LDI HIGH(BOARD)
    PHI 10
    LDI SQ_E5
    PLO 10
    LDI W_PAWN
    STR 10

    ; Clear d7, place pawn on d5
    LDI HIGH(BOARD)
    PHI 10
    LDI SQ_D7
    PLO 10
    LDI EMPTY
    STR 10

    LDI HIGH(BOARD)
    PHI 10
    LDI SQ_D5
    PLO 10
    LDI B_PAWN
    STR 10

    ; Clear f7, place pawn on f5 (just moved)
    LDI HIGH(BOARD)
    PHI 10
    LDI SQ_F7
    PLO 10
    LDI EMPTY
    STR 10

    LDI HIGH(BOARD)
    PHI 10
    LDI SQ_F5
    PLO 10
    LDI B_PAWN
    STR 10

    ; Set en passant square to f6
    LDI HIGH(GAME_STATE)
    PHI 10
    LDI LOW(GAME_STATE + GS_EP)
    PLO 10
    LDI SQ_F6
    STR 10

    LDI HIGH(STR_BOARD)
    PHI 8
    LDI LOW(STR_BOARD)
    PLO 8
    CALL SERIAL_PRINT_STRING

    CALL GEN_MOVES

    CALL SERIAL_PRINT_HEX

    LDI HIGH(STR_MOVES)
    PHI 8
    LDI LOW(STR_MOVES)
    PLO 8
    CALL SERIAL_PRINT_STRING

HALT:
    BR HALT

; GEN_MOVES - Generate all moves for white
; Output: D = move count
GEN_MOVES:
    LDI HIGH(BOARD)
    PHI 10
    LDI LOW(BOARD)
    PLO 10

    LDI HIGH(MOVE_LIST)
    PHI 9
    LDI LOW(MOVE_LIST)
    PLO 9

    LDI 0
    PLO 14              ; E.0 = square index
    PLO 15              ; F.0 = move count

SCAN_LOOP:
    GLO 14
    ANI $88
    LBNZ SCAN_SKIP

    LDN 10
    LBZ SCAN_SKIP

    PLO 13
    ANI COLOR_MASK
    LBNZ SCAN_SKIP

    GLO 13
    ANI PIECE_MASK

    SMI 1
    LBZ DO_PAWN
    SMI 1
    LBZ DO_KNIGHT
    SMI 1
    LBZ DO_BISHOP
    SMI 1
    LBZ DO_ROOK
    SMI 1
    LBZ DO_QUEEN
    SMI 1
    LBZ DO_KING
    LBR SCAN_SKIP

DO_PAWN:
    CALL GEN_PAWN_AT
    LBR SCAN_SKIP

DO_KNIGHT:
    CALL GEN_KNIGHT_AT
    LBR SCAN_SKIP

DO_BISHOP:
    CALL GEN_BISHOP_AT
    LBR SCAN_SKIP

DO_ROOK:
    CALL GEN_ROOK_AT
    LBR SCAN_SKIP

DO_QUEEN:
    CALL GEN_QUEEN_AT
    LBR SCAN_SKIP

DO_KING:
    CALL GEN_KING_AT
    LBR SCAN_SKIP

SCAN_SKIP:
    INC 10
    INC 14
    GLO 14
    ANI $80
    LBZ SCAN_LOOP

    GLO 15
    RETN

; GEN_PAWN_AT - Generate moves for pawn at E.0
; Includes: single push, double push, captures, en passant
GEN_PAWN_AT:
    ; === Single push ===
    GLO 14
    ADI DIR_S
    PLO 11

    ANI $88
    LBNZ GPA_CAPTURES

    LDI HIGH(BOARD)
    PHI 13
    GLO 11
    PLO 13
    LDN 13
    LBNZ GPA_CAPTURES

    INC 15
    GLO 14
    STR 9
    INC 9
    GLO 11
    STR 9
    INC 9

    ; === Double push if on rank 2 ===
    GLO 14
    ANI $F0
    XRI $10
    LBNZ GPA_CAPTURES

    GLO 11
    ADI DIR_S
    PLO 11

    LDI HIGH(BOARD)
    PHI 13
    GLO 11
    PLO 13
    LDN 13
    LBNZ GPA_CAPTURES

    INC 15
    GLO 14
    STR 9
    INC 9
    GLO 11
    STR 9
    INC 9

GPA_CAPTURES:
    ; === Capture left ===
    GLO 14
    ADI CAP_LEFT
    PLO 11

    ANI $88
    LBNZ GPA_CAP_RIGHT

    ; Check for en passant
    LDI HIGH(GAME_STATE)
    PHI 13
    LDI LOW(GAME_STATE + GS_EP)
    PLO 13
    LDN 13              ; Get EP square
    STR 2               ; Store on stack
    GLO 11              ; Get target square
    SM                  ; Compare: target - EP
    LBZ GPA_ADD_CAP_L   ; If equal, it's en passant!

    ; Normal capture - check if enemy piece
    LDI HIGH(BOARD)
    PHI 13
    GLO 11
    PLO 13
    LDN 13
    LBZ GPA_CAP_RIGHT   ; Empty

    ANI COLOR_MASK
    LBZ GPA_CAP_RIGHT   ; White piece

GPA_ADD_CAP_L:
    INC 15
    GLO 14
    STR 9
    INC 9
    GLO 11
    STR 9
    INC 9

GPA_CAP_RIGHT:
    ; === Capture right ===
    GLO 14
    ADI CAP_RIGHT
    PLO 11

    ANI $88
    LBNZ GPA_DONE

    ; Check for en passant
    LDI HIGH(GAME_STATE)
    PHI 13
    LDI LOW(GAME_STATE + GS_EP)
    PLO 13
    LDN 13              ; Get EP square
    STR 2
    GLO 11
    SM
    LBZ GPA_ADD_CAP_R   ; En passant!

    ; Normal capture
    LDI HIGH(BOARD)
    PHI 13
    GLO 11
    PLO 13
    LDN 13
    LBZ GPA_DONE

    ANI COLOR_MASK
    LBZ GPA_DONE

GPA_ADD_CAP_R:
    INC 15
    GLO 14
    STR 9
    INC 9
    GLO 11
    STR 9
    INC 9

GPA_DONE:
    RETN

; GEN_KNIGHT_AT - Generate moves for knight at E.0
GEN_KNIGHT_AT:
    GLO 14
    PHI 11

    LDI HIGH(KNIGHT_OFFSETS)
    PHI 12
    LDI LOW(KNIGHT_OFFSETS)
    PLO 12

    LDI 8
    PLO 13

GKA_LOOP:
    LDN 12
    STR 2
    GHI 11
    ADD
    PLO 11

    ANI $88
    LBNZ GKA_NEXT

    LDI HIGH(BOARD)
    PHI 8
    GLO 11
    PLO 8
    LDN 8
    LBZ GKA_ADD

    ANI COLOR_MASK
    LBZ GKA_NEXT

GKA_ADD:
    INC 15
    GHI 11
    STR 9
    INC 9
    GLO 11
    STR 9
    INC 9

GKA_NEXT:
    INC 12
    DEC 13
    GLO 13
    LBNZ GKA_LOOP

    RETN

; GEN_BISHOP_AT
GEN_BISHOP_AT:
    GLO 14
    PHI 11

    LDI HIGH(BISHOP_DIRS)
    PHI 12
    LDI LOW(BISHOP_DIRS)
    PLO 12

    LDI 4
    PLO 13

GBA_DIR_LOOP:
    LDN 12
    PHI 8

    GHI 11
    PLO 11

GBA_RAY:
    GLO 11
    STR 2
    GHI 8
    ADD
    PLO 11

    ANI $88
    LBNZ GBA_NEXT_DIR

    LDI HIGH(BOARD)
    PHI 7
    GLO 11
    PLO 7
    LDN 7
    LBZ GBA_ADD_MOVE

    ANI COLOR_MASK
    LBZ GBA_NEXT_DIR

    INC 15
    GHI 11
    STR 9
    INC 9
    GLO 11
    STR 9
    INC 9
    LBR GBA_NEXT_DIR

GBA_ADD_MOVE:
    INC 15
    GHI 11
    STR 9
    INC 9
    GLO 11
    STR 9
    INC 9
    LBR GBA_RAY

GBA_NEXT_DIR:
    INC 12
    DEC 13
    GLO 13
    LBNZ GBA_DIR_LOOP

    RETN

; GEN_ROOK_AT
GEN_ROOK_AT:
    GLO 14
    PHI 11

    LDI HIGH(ROOK_DIRS)
    PHI 12
    LDI LOW(ROOK_DIRS)
    PLO 12

    LDI 4
    PLO 13

GRA_DIR_LOOP:
    LDN 12
    PHI 8

    GHI 11
    PLO 11

GRA_RAY:
    GLO 11
    STR 2
    GHI 8
    ADD
    PLO 11

    ANI $88
    LBNZ GRA_NEXT_DIR

    LDI HIGH(BOARD)
    PHI 7
    GLO 11
    PLO 7
    LDN 7
    LBZ GRA_ADD_MOVE

    ANI COLOR_MASK
    LBZ GRA_NEXT_DIR

    INC 15
    GHI 11
    STR 9
    INC 9
    GLO 11
    STR 9
    INC 9
    LBR GRA_NEXT_DIR

GRA_ADD_MOVE:
    INC 15
    GHI 11
    STR 9
    INC 9
    GLO 11
    STR 9
    INC 9
    LBR GRA_RAY

GRA_NEXT_DIR:
    INC 12
    DEC 13
    GLO 13
    LBNZ GRA_DIR_LOOP

    RETN

; GEN_QUEEN_AT
GEN_QUEEN_AT:
    CALL GEN_BISHOP_AT
    CALL GEN_ROOK_AT
    RETN

; GEN_KING_AT
GEN_KING_AT:
    GLO 14
    PHI 11

    LDI HIGH(KING_OFFSETS)
    PHI 12
    LDI LOW(KING_OFFSETS)
    PLO 12

    LDI 8
    PLO 13

GKIA_LOOP:
    LDN 12
    STR 2
    GHI 11
    ADD
    PLO 11

    ANI $88
    LBNZ GKIA_NEXT

    LDI HIGH(BOARD)
    PHI 8
    GLO 11
    PLO 8
    LDN 8
    LBZ GKIA_ADD

    ANI COLOR_MASK
    LBZ GKIA_NEXT

GKIA_ADD:
    INC 15
    GHI 11
    STR 9
    INC 9
    GLO 11
    STR 9
    INC 9

GKIA_NEXT:
    INC 12
    DEC 13
    GLO 13
    LBNZ GKIA_LOOP

    RETN

; INIT_BOARD
INIT_BOARD:
    LDI HIGH(BOARD)
    PHI 10
    LDI LOW(BOARD)
    PLO 10
    LDI 128
    PLO 13
IB_CLEAR:
    LDI EMPTY
    STR 10
    INC 10
    DEC 13
    GLO 13
    BNZ IB_CLEAR

    LDI HIGH(BOARD)
    PHI 10
    LDI LOW(BOARD)
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

    LDI HIGH(BOARD)
    PHI 10
    LDI LOW(BOARD + $10)
    PLO 10
    LDI 8
    PLO 13
IB_WP:
    LDI W_PAWN
    STR 10
    INC 10
    DEC 13
    GLO 13
    LBNZ IB_WP

    LDI HIGH(BOARD)
    PHI 10
    LDI LOW(BOARD + $60)
    PLO 10
    LDI 8
    PLO 13
IB_BP:
    LDI B_PAWN
    STR 10
    INC 10
    DEC 13
    GLO 13
    BNZ IB_BP

    LDI HIGH(BOARD)
    PHI 10
    LDI LOW(BOARD + $70)
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
    INC 10
    LDI 0
    STR 10
    INC 10
    LDI 1
    STR 10
    INC 10
    LDI 0
    STR 10
    INC 10
    LDI SQ_E1
    STR 10
    INC 10
    LDI SQ_E8
    STR 10

    RETN

STR_BANNER:
    DB "Step10: En passant", 0DH, 0AH, 0

STR_BOARD:
    DB "1.e4 d5 2.e5 f5", 0DH, 0AH, 0

STR_MOVES:
    DB " moves", 0DH, 0AH, 0

    END
