; ==============================================================================
; RCA 1802/1806 Chess Engine - Board Module (0x88 Representation)
; ==============================================================================
; 0x88 board uses 128 bytes where valid squares have (index & 0x88) == 0
; This simplifies boundary checking - invalid moves wrap to invalid squares
; ==============================================================================

; ------------------------------------------------------------------------------
; Piece Encoding (3-bit type + 1-bit color in bit 3)
; ------------------------------------------------------------------------------
; Bits 0-2: Piece type (0-6)
; Bit 3:    Color (0=white, 1=black)
; Bits 4-7: Unused
; ------------------------------------------------------------------------------
EMPTY       EQU $00

; White pieces (bit 3 = 0)
W_PAWN      EQU $01
W_KNIGHT    EQU $02
W_BISHOP    EQU $03
W_ROOK      EQU $04
W_QUEEN     EQU $05
W_KING      EQU $06

; Black pieces (bit 3 = 1)
B_PAWN      EQU $09     ; $01 + $08
B_KNIGHT    EQU $0A     ; $02 + $08
B_BISHOP    EQU $0B     ; $03 + $08
B_ROOK      EQU $0C     ; $04 + $08
B_QUEEN     EQU $0D     ; $05 + $08
B_KING      EQU $0E     ; $06 + $08

; Masks
COLOR_MASK  EQU $08     ; Bit 3 indicates color
PIECE_MASK  EQU $07     ; Bits 0-2 are piece type
WHITE       EQU $00     ; White side value
BLACK       EQU $08     ; Black side value

; Piece types (without color)
PAWN_TYPE   EQU 1
KNIGHT_TYPE EQU 2
BISHOP_TYPE EQU 3
ROOK_TYPE   EQU 4
QUEEN_TYPE  EQU 5
KING_TYPE   EQU 6

; ------------------------------------------------------------------------------
; Memory Layout - ALL engine data consolidated at $6000
; ------------------------------------------------------------------------------
; Total: ~1536 bytes ($6000-$65FF)
;
; Board and game data: $6000-$63FF
BOARD       EQU $6000   ; 128 bytes - 0x88 board array ($6000-$607F)
GAME_STATE  EQU $6080   ; Game state structure (16 bytes) ($6080-$608F)
MOVE_HIST   EQU $6090   ; Move history for undo (256 bytes) ($6090-$618F)
MOVE_LIST   EQU $6200   ; Ply-indexed move lists (512 bytes) ($6200-$63FF)
                        ; Each ply gets 128 bytes (64 moves max): ply×128 + $6200
QS_MOVE_LIST EQU $6F00  ; Quiescence moves (256 bytes) ($6F00-$6FFF) - separate from UCI_BUFFER

; ------------------------------------------------------------------------------
; Engine Variables: $6400-$64FF
; ------------------------------------------------------------------------------
; Move history pointer and temps
HISTORY_PTR EQU $6400   ; 2 bytes - current history pointer ($6400-$6401)
MOVE_FROM   EQU $6402   ; 1 byte - move from square (temp)
MOVE_TO     EQU $6403   ; 1 byte - move to square (temp)
; NOTE: $6404 unused - castling state is at GAME_STATE + STATE_CASTLING ($6081)

; Move encoding temps (avoiding R14 - BIOS uses it)
DECODED_FLAGS   EQU $6405   ; 1 byte - flags from DECODE_MOVE_16BIT
MOVE_FLAGS_TEMP EQU $6406   ; 1 byte - flags for ENCODE_MOVE_16BIT
GM_SCAN_IDX     EQU $6407   ; 1 byte - board scan index for movegen

; Undo information for make/unmake move (MUST be in RAM, not ROM!)
UNDO_CAPTURED   EQU $6408   ; 1 byte - captured piece (or EMPTY)
UNDO_FROM       EQU $6409   ; 1 byte - from square
UNDO_TO         EQU $640A   ; 1 byte - to square
UNDO_CASTLING   EQU $640B   ; 1 byte - previous castling rights
UNDO_EP         EQU $640C   ; 1 byte - previous en passant square
UNDO_HALFMOVE   EQU $640D   ; 1 byte - previous halfmove clock

; Search state (aligned to $6410)
; BEST_SCORE in memory - avoids register shuffling bugs!
BEST_SCORE_HI   EQU $640E   ; 1 byte - best score high byte (big-endian)
BEST_SCORE_LO   EQU $640F   ; 1 byte - best score low byte
BEST_MOVE       EQU $6410   ; 2 bytes - best move found ($6410-$6411)
NODES_SEARCHED  EQU $6412   ; 4 bytes - node counter ($6412-$6415)
SEARCH_DEPTH    EQU $6416   ; 2 bytes - current search depth ($6416-$6417)

; Quiescence search state (big-endian: HI at lower address)
QS_BEST_HI      EQU $6418   ; 1 byte - stand-pat/best score high
QS_BEST_LO      EQU $6419   ; 1 byte - stand-pat/best score low
QS_MOVE_PTR_HI  EQU $641A   ; 1 byte - move list pointer high
QS_MOVE_PTR_LO  EQU $641B   ; 1 byte - move list pointer low
QS_TEMP         EQU $641C   ; 1 byte - temp storage

; Evaluation state
EVAL_SQ_INDEX   EQU $641D   ; 1 byte - square counter for evaluate

; Move generation state
GEN_LOOP_CTR    EQU $641E   ; 1 byte - loop counter for knight/king gen
GEN_FROM_SQ     EQU $641F   ; 1 byte - from square for knight/king gen

; Killer moves table (aligned to $6420)
KILLER_MOVES    EQU $6420   ; 32 bytes - 2 per ply × 16 ply ($6420-$643F)

; Evaluation temps (after killer moves)
EVAL_TEMP1      EQU $6440   ; 1 byte - PST loop counter / endgame temp
EVAL_TEMP2      EQU $6441   ; 1 byte - piece type temp for evaluation

; Search alpha/beta/score (memory-based to avoid R6/R7 corruption by SCRT)
; Big-endian layout: high byte at lower address, low byte at higher address
ALPHA_HI        EQU $6442   ; 1 byte - alpha high byte
ALPHA_LO        EQU $6443   ; 1 byte - alpha low byte
BETA_HI         EQU $6444   ; 1 byte - beta high byte
BETA_LO         EQU $6445   ; 1 byte - beta low byte
SCORE_HI        EQU $6446   ; 1 byte - score return high byte
SCORE_LO        EQU $6447   ; 1 byte - score return low byte
CURRENT_PLY     EQU $6448   ; 1 byte - current search ply (0=root)
COMPARE_TEMP    EQU $6449   ; 1 byte - scratch for comparisons (NEVER use STR 2!)
MOVECOUNT_TEMP  EQU $644A   ; 1 byte - saved move count for loop decrement
MOVE_TEMP_HI    EQU $644B   ; 1 byte - saved encoded move high byte (SCRT clobbers R8!)
MOVE_TEMP_LO    EQU $644C   ; 1 byte - saved encoded move low byte

; Opening book support
GAME_PLY        EQU $644D   ; 1 byte - game ply (moves since start position)
BOOK_MOVE_FROM  EQU $644E   ; 1 byte - book response from square
BOOK_MOVE_TO    EQU $644F   ; 1 byte - book response to square

; ------------------------------------------------------------------------------
; Ply-Indexed State Array: $6450-$649F (80 bytes = 8 plies × 10 bytes)
; ------------------------------------------------------------------------------
; Each ply frame stores registers that must be preserved across recursion:
;   Offset 0: R7.hi    Offset 1: R7.lo   (alpha/beta temp)
;   Offset 2: R8.hi    Offset 3: R8.lo   (best score)
;   Offset 4: R9.hi    Offset 5: R9.lo   (move list pointer)
;   Offset 6: R11.hi   Offset 7: R11.lo  (current move)
;   Offset 8: R12.hi   Offset 9: R12.lo  (side to move)
;
; Address for ply N = PLY_STATE_BASE + (N × 10)
; This replaces stack-based SAVE/RESTORE_SEARCH_CONTEXT - no SCRT interference!
; ------------------------------------------------------------------------------
PLY_STATE_BASE  EQU $6450   ; Base address of ply state array
PLY_FRAME_SIZE  EQU 10      ; Bytes per ply frame
MAX_PLY         EQU 8       ; Maximum search depth supported

; ------------------------------------------------------------------------------
; Futility Pruning: $64A0-$64A3
; ------------------------------------------------------------------------------
; At depth 1, skip quiet moves where static_eval + margin < alpha
STATIC_EVAL_HI  EQU $64A0   ; 1 byte - cached static eval high byte
STATIC_EVAL_LO  EQU $64A1   ; 1 byte - cached static eval low byte
FUTILITY_OK     EQU $64A2   ; 1 byte - 1 if futility pruning enabled this node

; Futility margin: 150 centipawns (1.5 pawns) = $0096
FUTILITY_MARGIN_HI  EQU $00
FUTILITY_MARGIN_LO  EQU $96

; ------------------------------------------------------------------------------
; Late Move Reductions: $64A3-$64A6
; ------------------------------------------------------------------------------
; At depth >= 3, reduce search depth for later quiet moves
LMR_MOVE_INDEX    EQU $64A3   ; 1 byte - moves searched so far at this node
LMR_REDUCED       EQU $64A4   ; 1 byte - flag: 1=current move searched at reduced depth
LMR_IS_CAPTURE    EQU $64A5   ; 1 byte - flag: 1=current move is a capture
LMR_OUTER         EQU $64A6   ; 1 byte - saved LMR_REDUCED (survives recursive calls)

; ------------------------------------------------------------------------------
; Null Move Pruning: $64A7-$64A8
; ------------------------------------------------------------------------------
NULL_MOVE_OK      EQU $64A7   ; 1 byte - flag: 1=can try null move, 0=cannot (prevents double-null)
NULL_SAVED_EP     EQU $64A8   ; 1 byte - saved EP square before null move

; ------------------------------------------------------------------------------
; Check Detection: $64A9
; ------------------------------------------------------------------------------
ENEMY_COLOR_TEMP  EQU $64A9   ; 1 byte - enemy color for IS_SQUARE_ATTACKED

; ------------------------------------------------------------------------------
; UCI state: $6500-$6600
; ------------------------------------------------------------------------------
UCI_BUFFER      EQU $6500   ; 256 bytes - input buffer ($6500-$65FF)
UCI_STATE       EQU $6600   ; 1 byte - UCI state

; ------------------------------------------------------------------------------
; Transposition Table: $6700-$6EFF (256 entries × 8 bytes = 2KB)
; ------------------------------------------------------------------------------
; Current position hash (updated incrementally by MAKE_MOVE/UNMAKE_MOVE)
HASH_HI         EQU $6601   ; 1 byte - hash high byte
HASH_LO         EQU $6602   ; 1 byte - hash low byte

; TT lookup result (set by TT_PROBE)
TT_HIT          EQU $6603   ; 1 byte - 0=miss, 1=hit
TT_SCORE_HI     EQU $6604   ; 1 byte - stored score high
TT_SCORE_LO     EQU $6605   ; 1 byte - stored score low
TT_DEPTH        EQU $6606   ; 1 byte - stored depth
TT_FLAG         EQU $6607   ; 1 byte - stored flag (EXACT/ALPHA/BETA)
TT_MOVE_HI      EQU $6608   ; 1 byte - stored best move high
TT_MOVE_LO      EQU $6609   ; 1 byte - stored best move low

; TT table base address and sizing
TT_TABLE        EQU $6700   ; 256 entries × 8 bytes = 2KB ($6700-$6EFF)
TT_ENTRIES      EQU 256     ; Number of entries (power of 2 for masking)
TT_ENTRY_SIZE   EQU 8       ; Bytes per entry
TT_INDEX_MASK   EQU $FF     ; Mask for 256 entries (hash_lo & $FF)

; TT entry structure (8 bytes per entry):
;   Offset 0: hash_verify_hi  - Upper hash bits for collision detection
;   Offset 1: hash_verify_lo  - (we store full hash, index with low bits)
;   Offset 2: score_hi        - Stored score high byte
;   Offset 3: score_lo        - Stored score low byte
;   Offset 4: depth           - Search depth when stored
;   Offset 5: flag            - Bound type (EXACT/ALPHA/BETA)
;   Offset 6: best_move_hi    - Best move high byte
;   Offset 7: best_move_lo    - Best move low byte
TT_OFF_HASH_HI  EQU 0
TT_OFF_HASH_LO  EQU 1
TT_OFF_SCORE_HI EQU 2
TT_OFF_SCORE_LO EQU 3
TT_OFF_DEPTH    EQU 4
TT_OFF_FLAG     EQU 5
TT_OFF_MOVE_HI  EQU 6
TT_OFF_MOVE_LO  EQU 7

; TT flag values
TT_FLAG_NONE    EQU 0       ; Empty/invalid entry
TT_FLAG_EXACT   EQU 1       ; Exact score (PV node)
TT_FLAG_ALPHA   EQU 2       ; Upper bound (fail-low)
TT_FLAG_BETA    EQU 3       ; Lower bound (fail-high)

; History entry size
HIST_ENTRY_SIZE EQU 8   ; 8 bytes per history entry

; Game state offsets
STATE_SIDE_TO_MOVE  EQU 0   ; 1 byte: 0=white, 8=black
SIDE    EQU GAME_STATE      ; Alias for side-to-move (offset 0)
STATE_CASTLING      EQU 1   ; 1 byte: castling rights bits
STATE_EP_SQUARE     EQU 2   ; 1 byte: en passant target (0x88), $FF=none
STATE_HALFMOVE      EQU 3   ; 1 byte: halfmove clock (50-move rule)
STATE_FULLMOVE_LO   EQU 4   ; 1 byte: fullmove number low byte
STATE_FULLMOVE_HI   EQU 5   ; 1 byte: fullmove number high byte
STATE_W_KING_SQ     EQU 6   ; 1 byte: white king square (0x88)
STATE_B_KING_SQ     EQU 7   ; 1 byte: black king square (0x88)

; Castling rights bit flags
CASTLE_WK   EQU $01     ; White kingside (e1-g1)
CASTLE_WQ   EQU $02     ; White queenside (e1-c1)
CASTLE_BK   EQU $04     ; Black kingside (e8-g8)
CASTLE_BQ   EQU $08     ; Black queenside (e8-c8)
ALL_CASTLING EQU $0F    ; All castling rights

; Move encoding flags
MOVE_NORMAL     EQU $00
MOVE_CASTLE     EQU $01
MOVE_EP         EQU $02
MOVE_PROMOTION  EQU $03

; ------------------------------------------------------------------------------
; Direction Offsets (0x88 board)
; ------------------------------------------------------------------------------
; In 0x88, each rank is 16 bytes apart (8 valid + 8 invalid)
; Direction = rank_delta * 16 + file_delta
; ------------------------------------------------------------------------------
DIR_N   EQU $F0     ; -16 (up one rank)
DIR_S   EQU $10     ; +16 (down one rank)
DIR_E   EQU $01     ; +1 (right one file)
DIR_W   EQU $FF     ; -1 (left one file)
DIR_NE  EQU $F1     ; -15 (up-right)
DIR_NW  EQU $EF     ; -17 (up-left)
DIR_SE  EQU $11     ; +17 (down-right)
DIR_SW  EQU $0F     ; +15 (down-left)

; ------------------------------------------------------------------------------
; Knight Move Offsets (8 L-shaped moves)
; ------------------------------------------------------------------------------
KNIGHT_OFFSETS:
    DB $DF      ; -33: up 2, left 1
    DB $E1      ; -31: up 2, right 1
    DB $EE      ; -18: up 1, left 2
    DB $F2      ; -14: up 1, right 2
    DB $0E      ; +14: down 1, left 2
    DB $12      ; +18: down 1, right 2
    DB $1F      ; +31: down 2, left 1
    DB $21      ; +33: down 2, right 1

; ------------------------------------------------------------------------------
; King Move Offsets (8 adjacent squares)
; ------------------------------------------------------------------------------
KING_OFFSETS:
    DB DIR_N    ; $F0: up
    DB DIR_NE   ; $F1: up-right
    DB DIR_E    ; $01: right
    DB DIR_SE   ; $11: down-right
    DB DIR_S    ; $10: down
    DB DIR_SW   ; $0F: down-left
    DB DIR_W    ; $FF: left
    DB DIR_NW   ; $EF: up-left

; ------------------------------------------------------------------------------
; Square Constants (0x88 format)
; ------------------------------------------------------------------------------
; Rank 1 (white's back rank)
SQ_A1   EQU $00
SQ_B1   EQU $01
SQ_C1   EQU $02
SQ_D1   EQU $03
SQ_E1   EQU $04     ; White king starting square
SQ_F1   EQU $05
SQ_G1   EQU $06     ; White kingside castle target
SQ_H1   EQU $07

; Rank 2 (white pawns)
SQ_A2   EQU $10
SQ_E2   EQU $14
SQ_H2   EQU $17

; Rank 7 (black pawns)
SQ_A7   EQU $60
SQ_E7   EQU $64
SQ_H7   EQU $67

; Rank 8 (black's back rank)
SQ_A8   EQU $70
SQ_B8   EQU $71
SQ_C8   EQU $72
SQ_D8   EQU $73
SQ_E8   EQU $74     ; Black king starting square
SQ_F8   EQU $75
SQ_G8   EQU $76     ; Black kingside castle target
SQ_H8   EQU $77

; Special values
INVALID_SQ  EQU $FF
NO_EP       EQU $FF

; Short aliases for common squares (used by makemove)
A1  EQU SQ_A1
H1  EQU SQ_H1
A8  EQU SQ_A8
H8  EQU SQ_H8

; ==============================================================================
; INIT_BOARD - Initialize board to starting position
; ==============================================================================
; Sets up standard chess starting position with 0x88 layout
; Initializes game state
; Uses: A, D
; ==============================================================================
INIT_BOARD:
    ; Clear entire 128-byte board to empty
    LDI HIGH(BOARD)
    PHI 10
    LDI LOW(BOARD)
    PLO 10

    LDI 128
    PLO 13

INIT_CLEAR:
    LDI EMPTY           ; Must reload each iteration (GLO clobbers D)
    STR 10
    INC 10
    DEC 13
    GLO 13
    BNZ INIT_CLEAR

    ; Set up white back rank (rank 1 = offset $00)
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

    ; Set up white pawns (rank 2 = offset $10)
    LDI HIGH(BOARD)
    PHI 10
    LDI LOW(BOARD + $10)
    PLO 10

    LDI 8
    PLO 13
INIT_WP:
    LDI W_PAWN          ; Must reload - GLO clobbers D
    STR 10
    INC 10
    DEC 13
    GLO 13
    LBNZ INIT_WP        ; Long branch - target may cross page boundary

    ; Set up black pawns (rank 7 = offset $60)
    LDI HIGH(BOARD)
    PHI 10
    LDI LOW(BOARD + $60)
    PLO 10

    LDI 8
    PLO 13
INIT_BP:
    LDI B_PAWN          ; Must reload - GLO clobbers D
    STR 10
    INC 10
    DEC 13
    GLO 13
    BNZ INIT_BP

    ; Set up black back rank (rank 8 = offset $70)
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

    ; Initialize game state
    LDI HIGH(GAME_STATE)
    PHI 10
    LDI LOW(GAME_STATE)
    PLO 10

    LDI WHITE
    STR 10               ; Side to move = white
    INC 10

    LDI ALL_CASTLING
    STR 10               ; All castling rights
    INC 10

    LDI NO_EP
    STR 10               ; No en passant
    INC 10

    LDI 0
    STR 10               ; Halfmove clock = 0
    INC 10

    LDI 1
    STR 10               ; Fullmove = 1 (low byte)
    INC 10

    LDI 0
    STR 10               ; Fullmove high byte = 0
    INC 10

    LDI SQ_E1
    STR 10               ; White king on e1
    INC 10

    LDI SQ_E8
    STR 10               ; Black king on e8

    RETN

; ==============================================================================
; GET_SIDE_TO_MOVE - Get current side to move
; ==============================================================================
; Output: D = side (WHITE=0 or BLACK=8)
; Uses: A
; ==============================================================================
GET_SIDE_TO_MOVE:
    LDI HIGH(GAME_STATE)
    PHI 10
    LDI LOW(GAME_STATE + STATE_SIDE_TO_MOVE)
    PLO 10
    LDN 10
    RETN

; ==============================================================================
; SET_SIDE_TO_MOVE - Set side to move
; ==============================================================================
; Input: D = side (WHITE=0 or BLACK=8)
; Uses: A
; ==============================================================================
SET_SIDE_TO_MOVE:
    STXD                ; Save D
    LDI HIGH(GAME_STATE)
    PHI 10
    LDI LOW(GAME_STATE + STATE_SIDE_TO_MOVE)
    PLO 10
    IRX
    LDN 2
    STR 10
    RETN

; ==============================================================================
; FLIP_SIDE - Toggle side to move
; ==============================================================================
; Uses: A, D
; ==============================================================================
FLIP_SIDE:
    LDI HIGH(GAME_STATE)
    PHI 10
    LDI LOW(GAME_STATE + STATE_SIDE_TO_MOVE)
    PLO 10
    LDN 10
    XRI BLACK           ; Toggle between 0 and 8
    STR 10
    RETN

; ==============================================================================
; GET_CASTLING_RIGHTS - Get castling rights byte
; ==============================================================================
; Output: D = castling rights
; Uses: A
; ==============================================================================
GET_CASTLING_RIGHTS:
    LDI HIGH(GAME_STATE)
    PHI 13                  ; Use R13, not R10 (R10 is board scan pointer!)
    LDI LOW(GAME_STATE + STATE_CASTLING)
    PLO 13
    LDN 13
    RETN

; ==============================================================================
; CLEAR_CASTLING_RIGHT - Clear specific castling right(s)
; ==============================================================================
; Input: D = castling bit(s) to clear (CASTLE_WK, CASTLE_WQ, etc.)
; Uses: A (R10), D, R13.0
; ==============================================================================
CLEAR_CASTLING_RIGHT:
    XRI $FF             ; Invert to create mask
    PLO 13              ; Save mask in R13.0

    LDI HIGH(GAME_STATE)
    PHI 10
    LDI LOW(GAME_STATE + STATE_CASTLING)
    PLO 10

    SEX 10              ; Point X to castling rights
    GLO 13              ; Get mask
    AND                 ; D = mask AND current rights
    STR 10              ; Store back
    SEX 2               ; Restore X to stack
    RETN

; ==============================================================================
; GET_PIECE_AT - Get piece at square
; ==============================================================================
; Input: D = square (0x88 format)
; Output: D = piece code (0 if empty or invalid square)
; Uses: A
; ==============================================================================
GET_PIECE_AT:
    ; Save square in A.0
    PLO 10

    ; Check if valid square using original value
    ANI $88
    BNZ GET_PIECE_INVALID

    ; Valid square - build address and get piece
    LDI HIGH(BOARD)
    PHI 10
    ; A.0 already has square offset
    LDN 10               ; Load piece at BOARD + square
    RETN

GET_PIECE_INVALID:
    LDI 0               ; Return empty for invalid squares
    RETN

; ==============================================================================
; INIT_MOVE_HISTORY - Initialize history pointer to start of history buffer
; ==============================================================================
; Sets HISTORY_PTR to point to MOVE_HIST base address
; Uses: R10, D
; ==============================================================================
INIT_MOVE_HISTORY:
    ; Set HISTORY_PTR to point to start of MOVE_HIST buffer
    LDI HIGH(HISTORY_PTR)
    PHI 10
    LDI LOW(HISTORY_PTR)
    PLO 10
    LDI HIGH(MOVE_HIST)
    STR 10              ; HISTORY_PTR high byte = $60
    INC 10
    LDI LOW(MOVE_HIST)
    STR 10              ; HISTORY_PTR low byte = $90

    ; Clear GAME_PLY for opening book tracking
    LDI HIGH(GAME_PLY)
    PHI 10
    LDI LOW(GAME_PLY)
    PLO 10
    LDI 0
    STR 10              ; GAME_PLY = 0
    RETN

; ==============================================================================
; SERIAL_INIT - Initialize serial I/O (placeholder for build compatibility)
; ==============================================================================
; The actual serial init is in serial-io-9600.asm
; This is just a placeholder if that file is not included
; ==============================================================================
; SERIAL_INIT already defined in serial-io-9600.asm

; ==============================================================================
; End of Board Module (0x88)
; ==============================================================================
