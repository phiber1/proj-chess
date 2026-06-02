; ==============================================================================
; BOARD MODULE - Chess board representation and display
; ==============================================================================

; ------------------------------------------------------------------------------
; Piece encoding constants
; ------------------------------------------------------------------------------
EMPTY       EQU 00H
PAWN        EQU 01H
KNIGHT      EQU 02H
BISHOP      EQU 03H
ROOK        EQU 04H
QUEEN       EQU 05H
KING        EQU 06H

BLACK       EQU 80H         ; OR with piece type for black pieces
COLOR_MASK  EQU 80H
PIECE_MASK  EQU 0FH

; Black pieces
BPAWN       EQU 81H
BKNIGHT     EQU 82H
BBISHOP     EQU 83H
BROOK       EQU 84H
BQUEEN      EQU 85H
BKING       EQU 86H

; Castling flags
WK_CASTLE   EQU 01H         ; White kingside
WQ_CASTLE   EQU 02H         ; White queenside
BK_CASTLE   EQU 04H         ; Black kingside
BQ_CASTLE   EQU 08H         ; Black queenside

; Special values
NO_EP       EQU 0FFH        ; No en passant square

; ==============================================================================
; BOARD_INIT - Initialize board to starting position
; ==============================================================================
BOARD_INIT:
    ; Set up black back rank (indices 0-7)
    LDI HIGH(BOARD)
    PHI 8
    LDI LOW(BOARD)
    PLO 8

    LDI BROOK
    STR 8
    INC 8
    LDI BKNIGHT
    STR 8
    INC 8
    LDI BBISHOP
    STR 8
    INC 8
    LDI BQUEEN
    STR 8
    INC 8
    LDI BKING
    STR 8
    INC 8
    LDI BBISHOP
    STR 8
    INC 8
    LDI BKNIGHT
    STR 8
    INC 8
    LDI BROOK
    STR 8
    INC 8

    ; Black pawns (indices 8-15)
    LDI 8
    PLO 9
BI_BPAWNS:
    LDI BPAWN
    STR 8
    INC 8
    DEC 9
    GLO 9
    BNZ BI_BPAWNS

    ; Empty squares (indices 16-47)
    LDI 32
    PLO 9
BI_EMPTY:
    LDI EMPTY
    STR 8
    INC 8
    DEC 9
    GLO 9
    BNZ BI_EMPTY

    ; White pawns (indices 48-55)
    LDI 8
    PLO 9
BI_WPAWNS:
    LDI PAWN
    STR 8
    INC 8
    DEC 9
    GLO 9
    BNZ BI_WPAWNS

    ; White back rank (indices 56-63)
    LDI ROOK
    STR 8
    INC 8
    LDI KNIGHT
    STR 8
    INC 8
    LDI BISHOP
    STR 8
    INC 8
    LDI QUEEN
    STR 8
    INC 8
    LDI KING
    STR 8
    INC 8
    LDI BISHOP
    STR 8
    INC 8
    LDI KNIGHT
    STR 8
    INC 8
    LDI ROOK
    STR 8

    ; Initialize game state
    LDI HIGH(SIDE)
    PHI 8
    LDI LOW(SIDE)
    PLO 8

    LDI 00H             ; White to move
    STR 8
    INC 8

    LDI WK_CASTLE+WQ_CASTLE+BK_CASTLE+BQ_CASTLE  ; All castling available
    STR 8
    INC 8

    LDI NO_EP           ; No en passant
    STR 8
    INC 8

    LDI 00H             ; Halfmove clock = 0
    STR 8
    INC 8

    ; King squares: White=60 (e1), Black=4 (e8)
    LDI 60              ; White king on e1
    STR 8
    INC 8
    LDI 4               ; Black king on e8
    STR 8

    SEP 5               ; Return

; ==============================================================================
; BOARD_PRINT - Print the board to serial
; Uses R8, R9, R12 (R10 reserved for PIECE_TO_CHAR)
; ==============================================================================
BOARD_PRINT:
    ; Print newline first
    LDI 0DH
    SEP 4
    DW SERIAL_WRITE_CHAR
    LDI 0AH
    SEP 4
    DW SERIAL_WRITE_CHAR

    ; R9.0 = square index (0-63)
    ; R9.1 = rank counter (8 down to 1)
    LDI 0
    PLO 9
    LDI 8
    PHI 9

BP_RANK_LOOP:
    ; Print rank number
    GHI 9
    ADI '0'             ; Convert to ASCII
    SEP 4
    DW SERIAL_WRITE_CHAR

    LDI ' '
    SEP 4
    DW SERIAL_WRITE_CHAR

    ; Print 8 squares for this rank
    LDI 8
    PLO 12              ; File counter in R12 (R10 used by PIECE_TO_CHAR)

BP_FILE_LOOP:
    ; Get piece at current square
    LDI HIGH(BOARD)
    PHI 8
    LDI LOW(BOARD)
    PLO 8
    SEX 2
    GLO 9               ; Square index
    STR 2
    GLO 8
    ADD
    PLO 8
    GHI 8
    ADCI 0
    PHI 8
    LDN 8               ; D = piece at square

    ; Convert piece to character
    SEP 4
    DW PIECE_TO_CHAR

    ; Print the character
    SEP 4
    DW SERIAL_WRITE_CHAR

    LDI ' '
    SEP 4
    DW SERIAL_WRITE_CHAR

    ; Next square
    INC 9
    DEC 12
    GLO 12
    LBNZ BP_FILE_LOOP   ; Long branch for assembler compatibility

    ; End of rank - print newline
    LDI 0DH
    SEP 4
    DW SERIAL_WRITE_CHAR
    LDI 0AH
    SEP 4
    DW SERIAL_WRITE_CHAR

    ; Next rank
    GHI 9
    SMI 1
    PHI 9
    LBNZ BP_RANK_LOOP   ; Long branch for assembler compatibility

    ; Print file labels
    LDI HIGH(STR_FILES)
    PHI 8
    LDI LOW(STR_FILES)
    PLO 8
    SEP 4
    DW SERIAL_PRINT_STRING

    SEP 5               ; Return

; ==============================================================================
; PIECE_TO_CHAR - Convert piece code to ASCII character
; Input: D = piece code
; Output: D = ASCII character
; Uses lookup table approach
; ==============================================================================
PIECE_TO_CHAR:
    LBZ PTC_EMPTY       ; Empty square - quick exit (use long branch)

    PLO 10              ; Save piece in R10.0
    ANI PIECE_MASK      ; Get piece type (1-6)

    ; Use piece type as index into character table
    SMI 1               ; Adjust to 0-based (PAWN=0, KNIGHT=1, etc)
    LBNF PTC_UNKNOWN    ; If negative, unknown piece (long branch)

    ; Bounds check - piece type must be 0-5
    SMI 6
    LBDF PTC_UNKNOWN    ; If >= 6, unknown piece
    ADI 6               ; Restore index

    ; Load character from table
    PHI 10              ; Save index in R10.1
    LDI HIGH(PTC_TABLE)
    PHI 8
    LDI LOW(PTC_TABLE)
    PLO 8
    SEX 2
    GHI 10              ; Get index
    STR 2
    GLO 8
    ADD
    PLO 8
    LDN 8               ; D = character from table
    BR PTC_CHECK_COLOR

PTC_UNKNOWN:
    LDI '?'
    SEP 5

PTC_EMPTY:
    LDI '.'
    SEP 5

PTC_CHECK_COLOR:
    ; D has uppercase letter, R10.0 has original piece
    PLO 8               ; Save letter in R8.0
    GLO 10              ; Get original piece
    ANI COLOR_MASK      ; Check color bit
    BZ PTC_WHITE        ; White piece - keep uppercase

    ; Black piece - convert to lowercase (add 20H)
    GLO 8
    ADI 20H
    SEP 5

PTC_WHITE:
    GLO 8
    SEP 5

; Character lookup table (index 0-5 = PAWN..KING)
PTC_TABLE:
    DB 'P', 'N', 'B', 'R', 'Q', 'K'

; ==============================================================================
; String constants
; ==============================================================================
STR_FILES:
    DB "  a b c d e f g h", 0DH, 0AH, 0

; ==============================================================================
; Game state data
; ==============================================================================
BOARD:
    DS 64               ; 64 squares
SIDE:
    DS 1                ; Side to move (00=White, 80=Black)
CASTLING:
    DS 1                ; Castling rights
EP_SQUARE:
    DS 1                ; En passant target square
HALFMOVE:
    DS 1                ; Halfmove clock
KING_SQ:
    DS 2                ; King squares [0]=White, [1]=Black

; ==============================================================================
; END OF BOARD MODULE
; ==============================================================================
