; ==============================================================================
; Step 6: Pawn + Knight moves (expect 20 total: 16 pawn + 4 knight)
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

DIR_S       EQU $10

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

; GEN_MOVES - Generate pawn + knight moves for white
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
    BNZ SCAN_SKIP

    LDN 10
    BZ SCAN_SKIP        ; Empty

    ; Check piece type
    PLO 13              ; Save piece in D.0
    ANI COLOR_MASK
    BNZ SCAN_SKIP       ; Black piece

    ; White piece - check type
    GLO 13
    ANI PIECE_MASK

    SMI 1               ; Pawn?
    BZ DO_PAWN
    SMI 1               ; Knight?
    BZ DO_KNIGHT
    BR SCAN_SKIP        ; Other piece, skip for now

DO_PAWN:
    CALL GEN_PAWN_AT
    BR SCAN_SKIP

DO_KNIGHT:
    CALL GEN_KNIGHT_AT
    BR SCAN_SKIP

SCAN_SKIP:
    INC 10
    INC 14
    GLO 14
    ANI $80
    BZ SCAN_LOOP

    GLO 15
    RETN

; GEN_PAWN_AT - Generate moves for pawn at E.0
; Uses R15 for count, R9 for move list
GEN_PAWN_AT:
    ; Single push
    GLO 14
    ADI DIR_S
    PLO 11

    ANI $88
    BNZ GPA_DONE

    LDI HIGH(BOARD)
    PHI 13
    GLO 11
    PLO 13
    LDN 13
    BNZ GPA_DONE        ; Blocked

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
    BNZ GPA_DONE

    GLO 11
    ADI DIR_S
    PLO 11

    LDI HIGH(BOARD)
    PHI 13
    GLO 11
    PLO 13
    LDN 13
    BNZ GPA_DONE

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
; Uses R15 for count, R9 for move list
GEN_KNIGHT_AT:
    ; Save from square
    GLO 14
    PHI 11              ; B.1 = from square

    LDI HIGH(KNIGHT_OFFSETS)
    PHI 12
    LDI LOW(KNIGHT_OFFSETS)
    PLO 12              ; C = offset table pointer

    LDI 8
    PLO 13              ; D.0 = offset counter

GKA_LOOP:
    ; Get offset
    LDN 12
    STR 2               ; Store offset on stack

    ; Calculate target
    GHI 11              ; From square
    ADD                 ; Add offset
    PLO 11              ; B.0 = target

    ; Check if valid square
    ANI $88
    BNZ GKA_NEXT

    ; Check if target empty or enemy
    LDI HIGH(BOARD)
    PHI 8               ; Use R8 temporarily
    GLO 11
    PLO 8
    LDN 8
    BZ GKA_ADD          ; Empty - can move

    ; Check if enemy
    ANI COLOR_MASK
    BZ GKA_NEXT         ; White piece - blocked

GKA_ADD:
    ; Add move
    INC 15
    GHI 11              ; From
    STR 9
    INC 9
    GLO 11              ; To
    STR 9
    INC 9

GKA_NEXT:
    INC 12              ; Next offset
    DEC 13
    GLO 13
    LBNZ GKA_LOOP       ; Long branch - crosses page boundary

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
    DB "Step6: Pawn+Knight", 0DH, 0AH, 0

STR_BOARD:
    DB "Board initialized", 0DH, 0AH, 0

STR_MOVES:
    DB " moves", 0DH, 0AH, 0

    END
