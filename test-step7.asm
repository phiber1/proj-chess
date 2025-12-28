; ==============================================================================
; Step 7: Full move generation (expect 20 total from starting position)
; Adds: Bishop, Rook, Queen (sliding pieces) + King
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
SQ_E1       EQU $04
SQ_E8       EQU $74

DIR_N       EQU $F0     ; -16
DIR_S       EQU $10     ; +16
DIR_E       EQU $01     ; +1
DIR_W       EQU $FF     ; -1
DIR_NE      EQU $F1     ; -15
DIR_NW      EQU $EF     ; -17
DIR_SE      EQU $11     ; +17
DIR_SW      EQU $0F     ; +15

; Knight offsets (8 L-shaped moves)
KNIGHT_OFFSETS:
    DB $DF      ; -33: up 2, left 1
    DB $E1      ; -31: up 2, right 1
    DB $EE      ; -18: up 1, left 2
    DB $F2      ; -14: up 1, right 2
    DB $0E      ; +14: down 1, left 2
    DB $12      ; +18: down 1, right 2
    DB $1F      ; +31: down 2, left 1
    DB $21      ; +33: down 2, right 1

; King offsets (8 directions)
KING_OFFSETS:
    DB $EF      ; NW (-17)
    DB $F0      ; N  (-16)
    DB $F1      ; NE (-15)
    DB $FF      ; W  (-1)
    DB $01      ; E  (+1)
    DB $0F      ; SW (+15)
    DB $10      ; S  (+16)
    DB $11      ; SE (+17)

; Sliding directions for bishop (4 diagonals)
BISHOP_DIRS:
    DB $EF      ; NW
    DB $F1      ; NE
    DB $0F      ; SW
    DB $11      ; SE

; Sliding directions for rook (4 orthogonals)
ROOK_DIRS:
    DB $F0      ; N
    DB $10      ; S
    DB $FF      ; W
    DB $01      ; E

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

    LDI HIGH(STR_BOARD)
    PHI 8
    LDI LOW(STR_BOARD)
    PLO 8
    CALL SERIAL_PRINT_STRING

    CALL GEN_MOVES
    ; D = move count

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
    LBZ SCAN_SKIP       ; Empty

    ; Check piece type
    PLO 13              ; Save piece in D.0
    ANI COLOR_MASK
    LBNZ SCAN_SKIP      ; Black piece

    ; White piece - dispatch by type
    GLO 13
    ANI PIECE_MASK

    SMI 1               ; Pawn?
    LBZ DO_PAWN
    SMI 1               ; Knight?
    LBZ DO_KNIGHT
    SMI 1               ; Bishop?
    LBZ DO_BISHOP
    SMI 1               ; Rook?
    LBZ DO_ROOK
    SMI 1               ; Queen?
    LBZ DO_QUEEN
    SMI 1               ; King?
    LBZ DO_KING
    LBR SCAN_SKIP       ; Unknown piece

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
GEN_PAWN_AT:
    ; Single push
    GLO 14
    ADI DIR_S
    PLO 11

    ANI $88
    LBNZ GPA_DONE

    LDI HIGH(BOARD)
    PHI 13
    GLO 11
    PLO 13
    LDN 13
    LBNZ GPA_DONE       ; Blocked

    ; Add single push
    INC 15
    GLO 14
    STR 9
    INC 9
    GLO 11
    STR 9
    INC 9

    ; Double push if on rank 2
    GLO 14
    ANI $F0
    XRI $10
    LBNZ GPA_DONE

    GLO 11
    ADI DIR_S
    PLO 11

    LDI HIGH(BOARD)
    PHI 13
    GLO 11
    PLO 13
    LDN 13
    LBNZ GPA_DONE

    ; Add double push
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
    PHI 11              ; B.1 = from square

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
    LBZ GKA_NEXT        ; White piece

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

; GEN_BISHOP_AT - Generate bishop moves (4 diagonal rays)
GEN_BISHOP_AT:
    GLO 14
    PHI 11              ; B.1 = from square

    LDI HIGH(BISHOP_DIRS)
    PHI 12
    LDI LOW(BISHOP_DIRS)
    PLO 12

    LDI 4
    PLO 13              ; 4 directions

GBA_DIR_LOOP:
    LDN 12
    PHI 8               ; R8.1 = direction offset

    GHI 11              ; Start from piece square
    PLO 11

GBA_RAY:
    GLO 11
    STR 2
    GHI 8               ; Get direction
    ADD
    PLO 11              ; B.0 = next square

    ANI $88
    LBNZ GBA_NEXT_DIR   ; Off board

    LDI HIGH(BOARD)
    PHI 7
    GLO 11
    PLO 7
    LDN 7
    LBZ GBA_ADD_MOVE    ; Empty - add and continue

    ; Occupied - check color
    ANI COLOR_MASK
    LBZ GBA_NEXT_DIR    ; White piece - blocked, stop ray

    ; Black piece - can capture, then stop
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
    LBR GBA_RAY         ; Continue ray

GBA_NEXT_DIR:
    INC 12
    DEC 13
    GLO 13
    LBNZ GBA_DIR_LOOP

    RETN

; GEN_ROOK_AT - Generate rook moves (4 orthogonal rays)
GEN_ROOK_AT:
    GLO 14
    PHI 11              ; B.1 = from square

    LDI HIGH(ROOK_DIRS)
    PHI 12
    LDI LOW(ROOK_DIRS)
    PLO 12

    LDI 4
    PLO 13              ; 4 directions

GRA_DIR_LOOP:
    LDN 12
    PHI 8               ; R8.1 = direction offset

    GHI 11              ; Start from piece square
    PLO 11

GRA_RAY:
    GLO 11
    STR 2
    GHI 8               ; Get direction
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
    LBZ GRA_NEXT_DIR    ; White piece

    ; Black piece - capture
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

; GEN_QUEEN_AT - Generate queen moves (8 rays = bishop + rook)
GEN_QUEEN_AT:
    CALL GEN_BISHOP_AT
    CALL GEN_ROOK_AT
    RETN

; GEN_KING_AT - Generate king moves (8 adjacent squares)
GEN_KING_AT:
    GLO 14
    PHI 11              ; B.1 = from square

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
    LBZ GKIA_NEXT       ; White piece

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
    BNZ IB_WP

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
    DB "Step7: Full movegen", 0DH, 0AH, 0

STR_BOARD:
    DB "Board initialized", 0DH, 0AH, 0

STR_MOVES:
    DB " moves", 0DH, 0AH, 0

    END
