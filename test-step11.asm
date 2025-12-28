; ==============================================================================
; Step 11: Castling (both O-O and O-O-O)
; Position: Starting position with Nb1, Bc1, Qd1, Bf1, Ng1 removed
; Expected: 25 moves (0x19) = 16 pawn + 5 rook + 4 king (incl. 2 castling)
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
GS_EP       EQU 2

; Castling right bits
CASTLE_WK   EQU $01     ; White kingside
CASTLE_WQ   EQU $02     ; White queenside
CASTLE_BK   EQU $04     ; Black kingside
CASTLE_BQ   EQU $08     ; Black queenside

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
SQ_A1       EQU $00
SQ_B1       EQU $01
SQ_C1       EQU $02
SQ_D1       EQU $03
SQ_E1       EQU $04
SQ_F1       EQU $05
SQ_G1       EQU $06
SQ_H1       EQU $07
SQ_E8       EQU $74

DIR_S       EQU $10

; Pawn capture directions
CAP_LEFT    EQU $0F
CAP_RIGHT   EQU $11

; Knight offsets
KNIGHT_OFFSETS:
    DB $DF, $E1, $EE, $F2, $0E, $12, $1F, $21

; King offsets (8 directions)
KING_OFFSETS:
    DB $EF, $F0, $F1, $FF, $01, $0F, $10, $11

; Sliding directions
BISHOP_DIRS:
    DB $EF, $F1, $0F, $11

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

    ; Clear pieces between king and rooks for castling
    ; Queenside: clear Nb1, Bc1, Qd1
    LDI HIGH(BOARD)
    PHI 10

    LDI SQ_B1
    PLO 10
    LDI EMPTY
    STR 10              ; Clear b1

    LDI SQ_C1
    PLO 10
    LDI EMPTY
    STR 10              ; Clear c1

    LDI SQ_D1
    PLO 10
    LDI EMPTY
    STR 10              ; Clear d1

    ; Kingside: clear Bf1, Ng1
    LDI SQ_F1
    PLO 10
    LDI EMPTY
    STR 10              ; Clear f1

    LDI SQ_G1
    PLO 10
    LDI EMPTY
    STR 10              ; Clear g1

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
    PLO 14
    PLO 15

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

; GEN_PAWN_AT - Generate pawn moves (push, double, capture, EP)
GEN_PAWN_AT:
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
    GLO 14
    ADI CAP_LEFT
    PLO 11

    ANI $88
    LBNZ GPA_CAP_RIGHT

    LDI HIGH(GAME_STATE)
    PHI 13
    LDI LOW(GAME_STATE + GS_EP)
    PLO 13
    LDN 13
    STR 2
    GLO 11
    SM
    LBZ GPA_ADD_CAP_L

    LDI HIGH(BOARD)
    PHI 13
    GLO 11
    PLO 13
    LDN 13
    LBZ GPA_CAP_RIGHT

    ANI COLOR_MASK
    LBZ GPA_CAP_RIGHT

GPA_ADD_CAP_L:
    INC 15
    GLO 14
    STR 9
    INC 9
    GLO 11
    STR 9
    INC 9

GPA_CAP_RIGHT:
    GLO 14
    ADI CAP_RIGHT
    PLO 11

    ANI $88
    LBNZ GPA_DONE

    LDI HIGH(GAME_STATE)
    PHI 13
    LDI LOW(GAME_STATE + GS_EP)
    PLO 13
    LDN 13
    STR 2
    GLO 11
    SM
    LBZ GPA_ADD_CAP_R

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

; GEN_KNIGHT_AT
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

; GEN_KING_AT - Generate king moves including castling
GEN_KING_AT:
    GLO 14
    PHI 11              ; B.1 = from square (king position)

    ; === Normal king moves (8 directions) ===
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

    ; === Castling ===
    ; Only if king is on e1
    GHI 11              ; Get king square
    SMI SQ_E1
    LBNZ GKIA_DONE      ; Not on e1, no castling

    ; Get castling rights
    LDI HIGH(GAME_STATE)
    PHI 13
    LDI LOW(GAME_STATE + GS_CASTLE)
    PLO 13
    LDN 13
    PLO 12              ; C.0 = castling rights

    ; === Kingside O-O ===
    GLO 12
    ANI CASTLE_WK
    LBZ GKIA_QUEENSIDE  ; No kingside rights

    ; Check f1 empty
    LDI HIGH(BOARD)
    PHI 13
    LDI SQ_F1
    PLO 13
    LDN 13
    LBNZ GKIA_QUEENSIDE ; f1 not empty

    ; Check g1 empty
    LDI SQ_G1
    PLO 13
    LDN 13
    LBNZ GKIA_QUEENSIDE ; g1 not empty

    ; Add O-O (king e1->g1)
    INC 15
    LDI SQ_E1
    STR 9
    INC 9
    LDI SQ_G1
    STR 9
    INC 9

GKIA_QUEENSIDE:
    ; === Queenside O-O-O ===
    GLO 12
    ANI CASTLE_WQ
    LBZ GKIA_DONE       ; No queenside rights

    ; Check d1 empty
    LDI HIGH(BOARD)
    PHI 13
    LDI SQ_D1
    PLO 13
    LDN 13
    LBNZ GKIA_DONE      ; d1 not empty

    ; Check c1 empty
    LDI SQ_C1
    PLO 13
    LDN 13
    LBNZ GKIA_DONE      ; c1 not empty

    ; Check b1 empty
    LDI SQ_B1
    PLO 13
    LDN 13
    LBNZ GKIA_DONE      ; b1 not empty

    ; Add O-O-O (king e1->c1)
    INC 15
    LDI SQ_E1
    STR 9
    INC 9
    LDI SQ_C1
    STR 9
    INC 9

GKIA_DONE:
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
    LBNZ IB_CLEAR

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
    LBNZ IB_BP

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
    DB "Step11: Castling", 0DH, 0AH, 0

STR_BOARD:
    DB "Both sides clear", 0DH, 0AH, 0

STR_MOVES:
    DB " moves", 0DH, 0AH, 0

    END
