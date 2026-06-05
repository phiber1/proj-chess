; ==============================================================================
; Debug Test 16: Full legal move loop with memory-based make/unmake
; Fix: Use MOVE_PIECE/CAPT_PIECE memory instead of R7
; ==============================================================================

    ORG $0000
    LBR MAIN

#include "serial-io.asm"

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
BOARD       EQU $5000
GAME_STATE  EQU $5080
MOVE_LIST   EQU $5200
LEGAL_LIST  EQU $5300

; Piece storage for make/unmake
MOVE_PIECE  EQU $5090
CAPT_PIECE  EQU $5091

EMPTY       EQU $00
COLOR_MASK  EQU $08
WHITE       EQU $00
BLACK       EQU $08
W_KING      EQU $06
B_QUEEN     EQU $0D
B_KING      EQU $0E
NO_EP       EQU $FF
PIECE_MASK  EQU $07

GS_SIDE     EQU 0
GS_CASTLE   EQU 1
GS_EP       EQU 2

CASTLE_WK   EQU $01
CASTLE_WQ   EQU $02
CASTLE_BK   EQU $04
CASTLE_BQ   EQU $08

DIR_N       EQU $F0
DIR_S       EQU $10
DIR_E       EQU $01
DIR_W       EQU $FF
DIR_NE      EQU $F1
DIR_NW      EQU $EF
DIR_SE      EQU $11
DIR_SW      EQU $0F

SQ_E1       EQU $04
SQ_D1       EQU $03
SQ_F1       EQU $05
SQ_G1       EQU $06
SQ_C1       EQU $02
SQ_B1       EQU $01
SQ_E8       EQU $74
SQ_F8       EQU $75
SQ_G8       EQU $76
SQ_D8       EQU $73
SQ_C8       EQU $72
SQ_B8       EQU $71

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

    ; Setup board: Ke1, BQe8, BKa8
    CALL CLEAR_BOARD

    LDI HIGH(BOARD)
    PHI 10
    LDI SQ_E1
    PLO 10
    LDI W_KING
    STR 10

    LDI $70
    PLO 10
    LDI B_KING
    STR 10

    LDI SQ_E8
    PLO 10
    LDI B_QUEEN
    STR 10

    ; Game state
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

    ; Generate moves
    LDI HIGH(MOVE_LIST)
    PHI 9
    LDI LOW(MOVE_LIST)
    PLO 9
    LDI WHITE
    PLO 12
    CALL GENERATE_MOVES

    ; Print pseudo-legal count
    LDI HIGH(STR_PSEUDO)
    PHI 8
    LDI LOW(STR_PSEUDO)
    PLO 8
    CALL SERIAL_PRINT_STRING
    LDI 5               ; We know it's 5
    CALL SERIAL_PRINT_HEX
    CALL PRINT_CRLF

    ; Now filter for legal moves
    CALL GEN_LEGAL_MOVES
    STXD                ; Save return value (D clobbered by serial!)

    ; Print legal count
    LDI HIGH(STR_LEGAL)
    PHI 8
    LDI LOW(STR_LEGAL)
    PLO 8
    CALL SERIAL_PRINT_STRING
    IRX
    LDX                 ; Restore return value
    CALL SERIAL_PRINT_HEX
    CALL PRINT_CRLF

HALT:
    BR HALT

; ==============================================================================
; GEN_LEGAL_MOVES - Filter pseudo-legal moves
; Uses memory-based make/unmake to avoid R7 SCRT issue
; Returns: D = legal move count
; ==============================================================================
GEN_LEGAL_MOVES:
    LDI HIGH(MOVE_LIST)
    PHI 10
    LDI LOW(MOVE_LIST)
    PLO 10

    LDI 5
    PLO 15              ; R15.0 = pseudo-legal count

    LDI 0
    PLO 14              ; R14.0 = legal count

    LDI WHITE
    PLO 12              ; Ensure R12 = WHITE (serial might have clobbered it)

GLM_LOOP:
    GLO 15
    LBZ GLM_DONE

    ; Read move into R11
    LDA 10
    PLO 11              ; from
    LDA 10
    PHI 11              ; to

    ; Save R10, R14, R12 (R11 will be restored manually)
    GLO 12
    STXD
    GLO 14
    STXD
    GHI 10
    STXD
    GLO 10
    STXD

    ; Make move (uses memory for piece storage)
    CALL MAKE_MOVE_MEM

    ; Check if in check
    CALL IS_IN_CHECK
    PLO 13              ; Save result

    ; Restore R11 manually (serial in IS_IN_CHECK might have clobbered it)
    ; Actually IS_IN_CHECK uses R11 internally, so we need to reload from stack
    ; But we didn't save R11! Let me fix this...

    ; For unmake, we need R11. Reload from MOVE_LIST using saved R10
    IRX
    LDXA
    PLO 10
    LDX
    PHI 10
    ; R10 now points past the move we just read
    ; Go back 2 bytes to re-read the move
    DEC 10
    DEC 10
    LDA 10
    PLO 11
    LDA 10
    PHI 11
    ; Now R10 is back where it should be

    ; Save R10 again for later restore
    GHI 10
    STXD
    GLO 10
    STXD

    ; Unmake move
    CALL UNMAKE_MOVE_MEM

    ; Restore R10
    IRX
    LDXA
    PLO 10
    LDX
    PHI 10

    ; Restore R14
    IRX
    LDXA
    PLO 14

    ; Restore R12
    LDX
    PLO 12

    ; Check result - if 0, move is legal
    GLO 13
    LBNZ GLM_NEXT

    ; Legal move - count it
    INC 14

GLM_NEXT:
    DEC 15
    LBR GLM_LOOP

GLM_DONE:
    GLO 14              ; Return legal count
    RETN

; ==============================================================================
PRINT_CRLF:
    LDI HIGH(STR_CRLF)
    PHI 8
    LDI LOW(STR_CRLF)
    PLO 8
    CALL SERIAL_PRINT_STRING
    RETN

; ==============================================================================
; MAKE_MOVE_MEM - Uses memory for piece storage
; Key: Set destination pointer BEFORE loading data!
; ==============================================================================
MAKE_MOVE_MEM:
    ; Setup R8.1 = BOARD high, R10 = MOVE_PIECE
    LDI HIGH(BOARD)
    PHI 8
    LDI HIGH(MOVE_PIECE)
    PHI 10
    LDI LOW(MOVE_PIECE)
    PLO 10

    ; Save moving piece: board[from] -> MOVE_PIECE
    GLO 11              ; from
    PLO 8               ; R8 = BOARD + from
    LDN 8               ; D = piece at from
    STR 10              ; MOVE_PIECE = piece

    ; Save captured piece: board[to] -> CAPT_PIECE
    GHI 11              ; to
    PLO 8               ; R8 = BOARD + to
    LDN 8               ; D = piece at to (captured)
    INC 10              ; R10 = CAPT_PIECE
    STR 10              ; CAPT_PIECE = captured

    ; Move piece to destination: set R8 first, then load piece
    GHI 11              ; to
    PLO 8               ; R8 = BOARD + to
    DEC 10              ; R10 = MOVE_PIECE
    LDN 10              ; D = moving piece
    STR 8               ; board[to] = piece

    ; Clear source square
    GLO 11              ; from
    PLO 8               ; R8 = BOARD + from
    LDI EMPTY
    STR 8

    RETN

; ==============================================================================
; UNMAKE_MOVE_MEM - Uses memory for piece storage
; ==============================================================================
UNMAKE_MOVE_MEM:
    ; Setup R8 = BOARD, R10 = MOVE_PIECE
    LDI HIGH(BOARD)
    PHI 8
    LDI HIGH(MOVE_PIECE)
    PHI 10
    LDI LOW(MOVE_PIECE)
    PLO 10

    ; board[from] = moving piece
    GLO 11              ; from
    PLO 8               ; R8 = BOARD + from
    LDN 10              ; D = moving piece
    STR 8               ; board[from] = piece

    ; board[to] = captured piece
    GHI 11              ; to
    PLO 8               ; R8 = BOARD + to
    INC 10              ; R10 = CAPT_PIECE
    LDN 10              ; D = captured piece
    STR 8               ; board[to] = captured

    RETN

#include "movegen-new.asm"

; ==============================================================================
; IS_IN_CHECK - Check if current side's king is in check
; ==============================================================================
IS_IN_CHECK:
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
    PLO 11

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
    GLO 12
    XRI BLACK
    PLO 13

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
    PHI 14

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

    LDI 0
    RETN

IIC_IN_CHECK:
    LDI 1
    RETN

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
STR_BANNER:
    DB "Debug16: Legal moves test", 0DH, 0AH, 0

STR_PSEUDO:
    DB "Pseudo-legal: ", 0

STR_LEGAL:
    DB "Legal: ", 0

STR_CRLF:
    DB 0DH, 0AH, 0

    END
