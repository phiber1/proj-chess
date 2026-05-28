; ==============================================================================
; RCA 1802/1806 Chess Engine - Position Evaluation
; ==============================================================================
; Evaluate board position and return score
; Positive score favors white, negative favors black
; ==============================================================================

; ------------------------------------------------------------------------------
; Piece Values (in centipawns)
; ------------------------------------------------------------------------------
PAWN_VALUE      EQU 100
KNIGHT_VALUE    EQU 320
BISHOP_VALUE    EQU 330
ROOK_VALUE      EQU 500
QUEEN_VALUE     EQU 900
KING_VALUE      EQU 20000   ; Effectively infinite (not used in material count)

; Check bonus: credit the attacker when side-to-move is in check.
; Applied at EVAL exit — rewards moves that deliver check, encourages
; attacking play (especially with queen) in endgame mate-chasing.
CHECK_BONUS     EQU 40

; Queen-king proximity bonus (Chebyshev distance lookup).
; Indexed by distance 0-7. Distance 0 unreachable (queen can't be on king's
; square). Encourages queen to attack enemy king in endgame, addressing the
; "queen sits idle" pattern that emerged after the queen-cap removed
; multi-promotion incentive.
QUEEN_PROX_BONUS:
    DB 0    ; distance 0 (not reachable)
    DB 60   ; distance 1 (adjacent — strongest attack)
    DB 50   ; distance 2
    DB 40   ; distance 3
    DB 30   ; distance 4
    DB 20   ; distance 5
    DB 10   ; distance 6
    DB 0    ; distance 7 (far — no bonus)

; Piece value table (indexed by piece type 0-6)
PIECE_VALUES:
    DW 0            ; Empty (type 0)
    DW 100          ; Pawn (type 1)
    DW 320          ; Knight (type 2)
    DW 330          ; Bishop (type 3)
    DW 500          ; Rook (type 4)
    DW 900          ; Queen (type 5)
    DW 0            ; King (type 6) - don't count in material

; ------------------------------------------------------------------------------
; EVALUATE - Main evaluation function
; ------------------------------------------------------------------------------
; Input:  A = board pointer (BOARD)
; Output: R9 = evaluation score (16-bit signed)
;         Positive = white advantage
;         Negative = black advantage
; NOTE:   Returns in R9, NOT R6! R6 is SCRT linkage register - off limits!
; Uses:   All registers except R6
;
; Components (in order of implementation):
;   1. Material count (DONE)
;   2. Piece-square tables (TODO)
;   3. Pawn structure (TODO)
;   4. King safety (TODO)
;   5. Mobility (TODO)
; ------------------------------------------------------------------------------

; ------------------------------------------------------------------------------
; CHECK_INSUFFICIENT_MATERIAL - Detect the canonical dead-draw material configs
; ------------------------------------------------------------------------------
; Returns D = 1 if the position is one of:
;   K vs K, K+N vs K, K+B vs K, K+B vs K+B (bishops on same square colour)
; else D = 0.  These are the four cases where neither side can force mate
; (item C — added 2026-05-18).  Returning 0 from EVALUATE for these stops the
; engine meandering in drawn endgames until the 50-move rule.
;
; Scans BOARD once, early-aborting to "not draw" the moment a pawn, rook, or
; queen is seen, or when the minor count exceeds 2.  In any position with
; pawns/rooks/queens (every opening/middlegame) the very first occupied square
; aborts the scan, so cost is ~1 iteration in normal play; only true bare-king
; endgames pay the full 128-square walk.
;
; Provably safe for non-drawn positions: the short-circuit only fires when
; material is EXACTLY one of the four configs above. Any pawn/rook/queen or a
; 3rd minor falls through untouched — cannot alter winning/losing eval.
;
; Uses: R7 (sq index), R8 (piece + type/sqcolor scratch), R10 (board ptr),
;       R11 (.0=minor total, .1=white bishop count),
;       R13 (.0=black bishop count, .1=bishop sq-colour bits)
; Does NOT touch R6 (SCRT) or R9 (caller score, not yet set at call site).
; ------------------------------------------------------------------------------
CHECK_INSUFFICIENT_MATERIAL:
    LDI 0
    PLO 11              ; R11.0 = minor total (bishops + knights)
    PHI 11              ; R11.1 = white bishop count
    PLO 13              ; R13.0 = black bishop count
    PHI 13              ; R13.1 = bishop sq-colour bits (b0=W, b1=B)

    LDI 0
    PLO 7               ; R7.0 = square index 0

CIM_LOOP:
    GLO 7
    ANI $88
    LBNZ CIM_NEXT       ; off-board 0x88 square, skip

    ; R10 = BOARD + sq
    GLO 7
    ADI LOW(BOARD)
    PLO 10
    LDI HIGH(BOARD)
    ADCI 0
    PHI 10
    LDN 10              ; D = piece
    LBZ CIM_NEXT        ; empty square

    PLO 8               ; R8.0 = full piece byte (kept all loop)
    ANI PIECE_MASK      ; D = piece type 1-6
    PHI 8               ; R8.1 = piece type

    XRI KING_TYPE       ; king? (always present, never counted)
    LBZ CIM_NEXT

    GHI 8               ; type
    XRI PAWN_TYPE
    LBZ CIM_NOT_DRAW    ; any pawn → not insufficient
    GHI 8
    XRI ROOK_TYPE
    LBZ CIM_NOT_DRAW    ; any rook → not insufficient
    GHI 8
    XRI QUEEN_TYPE
    LBZ CIM_NOT_DRAW    ; any queen → not insufficient

    ; piece is a minor (knight=2 or bishop=3)
    GLO 11
    ADI 1
    PLO 11              ; minor total++
    SMI 3
    LBDF CIM_NOT_DRAW   ; >=3 minors → not one of the four cases

    GHI 8               ; type
    XRI BISHOP_TYPE
    LBNZ CIM_NEXT       ; knight — counted in total, nothing more

    ; --- bishop: compute its square colour = ((sq>>4)+(sq&7)) & 1 ---
    GLO 7
    ANI $07             ; file
    STR 2               ; M(R2) = file
    GLO 7
    SHR
    SHR
    SHR
    SHR                 ; D = sq>>4 = rank (valid sq → high nibble 0-7)
    ADD                 ; D = rank + file
    ANI $01             ; D = square colour 0/1
    PHI 8               ; R8.1 = square colour

    GLO 8               ; full piece byte
    ANI COLOR_MASK      ; 0 = white bishop, 8 = black bishop
    LBNZ CIM_BLACK_B

    ; white bishop
    GHI 11
    ADI 1
    PHI 11              ; white bishop count++
    GHI 8               ; square colour
    LBZ CIM_NEXT        ; colour 0 → leave bit0 clear
    GHI 13
    ORI $01
    PHI 13              ; bit0 = white bishop on colour-1 square
    LBR CIM_NEXT

CIM_BLACK_B:
    GLO 13
    ADI 1
    PLO 13              ; black bishop count++
    GHI 8               ; square colour
    LBZ CIM_NEXT
    GHI 13
    ORI $02
    PHI 13              ; bit1 = black bishop on colour-1 square

CIM_NEXT:
    GLO 7
    ADI 1
    PLO 7
    XRI $80             ; scanned squares 0..127?
    LBNZ CIM_LOOP

    ; --- decision ---
    GLO 11              ; minor total
    LBZ CIM_DRAW        ; 0 minors → K vs K
    SMI 1
    LBZ CIM_DRAW        ; 1 minor  → K+N vs K or K+B vs K (either side)

    ; minor total == 2 (>=3 already rejected mid-scan).
    ; Draw only if exactly one bishop per side AND same square colour.
    GHI 11              ; white bishop count
    SMI 1
    LBNZ CIM_NOT_DRAW   ; != 1
    GLO 13              ; black bishop count
    SMI 1
    LBNZ CIM_NOT_DRAW   ; != 1
    GHI 13
    ANI $03             ; b0=white sqcolour, b1=black sqcolour
    LBZ CIM_DRAW        ; 00 → both colour-0 → same → draw
    XRI $03
    LBZ CIM_DRAW        ; 11 → both colour-1 → same → draw
    LBR CIM_NOT_DRAW    ; 01/10 → opposite colours (not in item-C list)

CIM_DRAW:
    LDI 1
    RETN

CIM_NOT_DRAW:
    LDI 0
    RETN

; ------------------------------------------------------------------------------
EVALUATE:
    ; Ensure X=2 for all stack/memory operations
    SEX 2

    ; Insufficient-material dead-draw short-circuit (item C, 2026-05-18).
    ; Safe by construction: only fires for K-K / K+N-K / K+B-K / K+B-K+B
    ; same-colour; any other material falls through to the full eval.
    CALL CHECK_INSUFFICIENT_MATERIAL
    LBZ EVAL_NOT_DEAD_DRAW
    LDI 0
    PHI 9
    PLO 9              ; R9 = 0 (draw)
    RETN
EVAL_NOT_DEAD_DRAW:

    ; Initialize score to 0
    ; NOTE: Use R9 for score, NOT R6! R6 is SCRT linkage register!
    LDI 0
    PHI 9
    PLO 9              ; R9 = 0 (score accumulator)

    ; Scan board and count material
    RLDI 10, BOARD

    ; Initialize square counter in memory (avoid R14!)
    RLDI 13, EVAL_SQ_INDEX
    LDI 0
    STR 13              ; EVAL_SQ_INDEX = 0

    ; Initialize piece counter in memory (D is still 0)
    RLDI 11, EG_PIECE_COUNT
    STR 11              ; EG_PIECE_COUNT = 0

    ; Initialize advanced pawn counters (D is still 0)
    RLDI 11, ADV_PAWN_W
    STR 11              ; ADV_PAWN_W = 0
    INC 11
    STR 11              ; ADV_PAWN_B = 0

    ; Initialize pawn file counts: 16 bytes at $6710-$671F (D is still 0)
    RLDI 11, W_PAWN_FILE_CT
    LDI 16              ; 16 bytes to clear
    PLO 8               ; R8.0 = loop counter
EVAL_CLR_PAWN_CT:
    LDI 0
    STR 11
    INC 11
    DEC 8
    GLO 8
    LBNZ EVAL_CLR_PAWN_CT

    ; Initialize bishop counts + rook file trackers + queen counts
    LDI 0
    RLDI 11, EVAL_W_BISHOPS
    STR 11              ; EVAL_W_BISHOPS = 0
    INC 11
    STR 11              ; EVAL_B_BISHOPS = 0
    RLDI 11, W_QUEEN_CNT
    STR 11              ; W_QUEEN_CNT = 0
    INC 11
    STR 11              ; B_QUEEN_CNT = 0
    ; Rook files = $FF (no rook); queen squares also default to $FF (no queen)
    LDI $FF
    RLDI 11, EVAL_W_ROOK_F1
    STR 11              ; EVAL_W_ROOK_F1 = $FF
    INC 11
    STR 11              ; EVAL_W_ROOK_F2 = $FF
    INC 11
    STR 11              ; EVAL_B_ROOK_F1 = $FF
    INC 11
    STR 11              ; EVAL_B_ROOK_F2 = $FF
    RLDI 11, W_QUEEN_SQ
    STR 11              ; W_QUEEN_SQ = $FF
    INC 11
    STR 11              ; B_QUEEN_SQ = $FF

EVAL_SCAN:
    ; Check if square is valid (R13 points to EVAL_SQ_INDEX)
    LDN 13
    ANI $88
    LBNZ EVAL_NEXT_SQUARE

    ; Load piece at square
    LDN 10
    LBZ EVAL_NEXT_SQUARE ; Empty square

    ; Get piece type and color
    ; NOTE: R13 must stay pointing to EVAL_SQ_INDEX - use R8 for piece temp!
    PLO 8               ; R8.0 = piece (temp storage)

    ; Check color
    ANI COLOR_MASK
    PLO 15              ; F.0 = color (0=white, 8=black)

    ; Get piece type
    GLO 8               ; Get piece back from R8.0
    ANI PIECE_MASK
    PLO 8               ; R8.0 = piece type (1-6)

    ; Skip king (type 6)
    XRI 6
    LBZ EVAL_NEXT_SQUARE

    ; Count non-king piece (memory variable — R12 is side-to-move, off limits)
    RLDI 11, EG_PIECE_COUNT
    LDN 11
    ADI 1
    STR 11

    ; Check if pawn for advanced pawn bonus (graduated)
    GLO 8               ; piece type (1-5)
    XRI 1
    LBNZ EVAL_NOT_ADV_PAWN  ; not a pawn (+3 instr for non-pawns)
    ; Pawn — extract rank from 0x88 square
    LDN 13              ; D = 0x88 square (from EVAL_SQ_INDEX)
    ANI $70             ; D = rank << 4 ($00-$70)
    STR 2               ; save rank<<4 on stack
    GLO 15              ; D = color (0=white, 8=black)
    LBNZ EVAL_BP_ADV
    ; === White pawn: rank 7=$60 (+150), rank 6=$50 (+100), rank 5=$40 (+50), rank 4=$30 (+25) ===
    LDN 2
    XRI $60
    LBZ EVAL_WP_R7
    LDN 2
    XRI $50
    LBZ EVAL_WP_R6
    LDN 2
    XRI $40
    LBZ EVAL_WP_R5
    LDN 2
    XRI $30
    LBNZ EVAL_NOT_ADV_PAWN
    LDI 25              ; rank 4 (unchanged)
    LBR EVAL_WP_ADD
EVAL_WP_R5:
    LDI 60              ; rank 5  (Fix B 2026-05-27: 50→60)
    LBR EVAL_WP_ADD
EVAL_WP_R7:
    LDI 200             ; rank 7  (Fix B 2026-05-27: 90→200, one-from-promotion)
    LBR EVAL_WP_ADD
EVAL_WP_R6:
    LDI 120             ; rank 6  (Fix B 2026-05-27: 70→120, two-from-promotion)
EVAL_WP_ADD:
    STR 2
    RLDI 11, ADV_PAWN_W
    LDN 11
    ADD
    LBNF EVAL_WP_NOSAT  ; DF=0: no carry, no overflow
    LDI 255             ; Overflow: saturate at 255
EVAL_WP_NOSAT:
    STR 11              ; ADV_PAWN_W = min(sum, 255)
    LBR EVAL_NOT_ADV_PAWN
EVAL_BP_ADV:
    ; === Black pawn: rank 2=$10 (+150), rank 3=$20 (+100), rank 4=$30 (+50), rank 5=$40 (+25) ===
    LDN 2
    XRI $10
    LBZ EVAL_BP_R2
    LDN 2
    XRI $20
    LBZ EVAL_BP_R3
    LDN 2
    XRI $30
    LBZ EVAL_BP_R4
    LDN 2
    XRI $40
    LBNZ EVAL_NOT_ADV_PAWN
    LDI 25              ; rank 5 (unchanged, mirror of W r4)
    LBR EVAL_BP_ADD
EVAL_BP_R4:
    LDI 60              ; rank 4  (Fix B 2026-05-27: 50→60, mirror of W r5)
    LBR EVAL_BP_ADD
EVAL_BP_R2:
    LDI 200             ; rank 2  (Fix B 2026-05-27: 90→200, mirror of W r7)
    LBR EVAL_BP_ADD
EVAL_BP_R3:
    LDI 120             ; rank 3  (Fix B 2026-05-27: 70→120, mirror of W r6)
EVAL_BP_ADD:
    STR 2
    RLDI 11, ADV_PAWN_B
    LDN 11
    ADD
    LBNF EVAL_BP_NOSAT  ; DF=0: no carry, no overflow
    LDI 255             ; Overflow: saturate at 255
EVAL_BP_NOSAT:
    STR 11              ; ADV_PAWN_B = min(sum, 255)
EVAL_NOT_ADV_PAWN:

    ; ==================================================================
    ; Track pawn files, bishop count, rook files for structure eval
    ; R8.0 = piece type (1-6), R15.0 = color, R13 -> EVAL_SQ_INDEX
    ; ==================================================================

    ; --- PAWN: increment per-file count ---
    GLO 8               ; piece type
    XRI 1               ; pawn?
    LBNZ EVAL_NOT_PAWN_TRACK
    LDN 13              ; D = 0x88 square
    ANI $07             ; D = file (0-7)
    STR 2               ; save file on stack
    GLO 15              ; color
    LBNZ EVAL_BP_COUNT
    ; White pawn: W_PAWN_FILE_CT[file]++
    LDN 2               ; D = file
    ADI LOW(W_PAWN_FILE_CT)
    PLO 11
    LDI HIGH(W_PAWN_FILE_CT)
    ADCI 0
    PHI 11              ; R11 = &W_PAWN_FILE_CT[file]
    LDN 11
    ADI 1
    STR 11
    LBR EVAL_NOT_PAWN_TRACK
EVAL_BP_COUNT:
    ; Black pawn: B_PAWN_FILE_CT[file]++
    LDN 2               ; D = file
    ADI LOW(B_PAWN_FILE_CT)
    PLO 11
    LDI HIGH(B_PAWN_FILE_CT)
    ADCI 0
    PHI 11              ; R11 = &B_PAWN_FILE_CT[file]
    LDN 11
    ADI 1
    STR 11
EVAL_NOT_PAWN_TRACK:

    ; --- BISHOP: count per color ---
    GLO 8               ; piece type
    XRI 3               ; bishop?
    LBNZ EVAL_NOT_BISHOP_TRACK
    GLO 15              ; color
    LBNZ EVAL_BB_TRACK
    RLDI 11, EVAL_W_BISHOPS
    LDN 11
    ADI 1
    STR 11
    LBR EVAL_NOT_BISHOP_TRACK
EVAL_BB_TRACK:
    RLDI 11, EVAL_B_BISHOPS
    LDN 11
    ADI 1
    STR 11
EVAL_NOT_BISHOP_TRACK:

    ; --- ROOK: save file number (up to 2 per side) ---
    GLO 8               ; piece type
    XRI 4               ; rook?
    LBNZ EVAL_NOT_ROOK_TRACK
    LDN 13              ; 0x88 square
    ANI $07             ; D = file (0-7)
    PHI 8               ; save file in R8.1
    GLO 15              ; color
    LBNZ EVAL_BROOK_TRACK
    ; White rook: store in F1 or F2
    RLDI 11, EVAL_W_ROOK_F1
    LDN 11
    XRI $FF             ; is F1 empty?
    LBNZ EVAL_WR_F2
    GHI 8               ; D = file
    STR 11              ; F1 = file
    LBR EVAL_NOT_ROOK_TRACK
EVAL_WR_F2:
    RLDI 11, EVAL_W_ROOK_F2
    GHI 8
    STR 11              ; F2 = file
    LBR EVAL_NOT_ROOK_TRACK
EVAL_BROOK_TRACK:
    ; Black rook: store in F1 or F2
    RLDI 11, EVAL_B_ROOK_F1
    LDN 11
    XRI $FF
    LBNZ EVAL_BR_F2
    GHI 8
    STR 11
    LBR EVAL_NOT_ROOK_TRACK
EVAL_BR_F2:
    RLDI 11, EVAL_B_ROOK_F2
    GHI 8
    STR 11
EVAL_NOT_ROOK_TRACK:

    ; --- QUEEN: count + remember square (for redundant-queen cap and proximity bonus) ---
    GLO 8               ; piece type
    XRI 5               ; queen?
    LBNZ EVAL_NOT_QUEEN_TRACK
    GLO 15              ; color
    LBNZ EVAL_BQ_TRACK
    ; White queen
    RLDI 11, W_QUEEN_CNT
    LDN 11
    ADI 1
    STR 11
    LDN 13              ; current 0x88 square from EVAL_SQ_INDEX
    RLDI 11, W_QUEEN_SQ
    STR 11
    LBR EVAL_NOT_QUEEN_TRACK
EVAL_BQ_TRACK:
    ; Black queen
    RLDI 11, B_QUEEN_CNT
    LDN 11
    ADI 1
    STR 11
    LDN 13              ; current 0x88 square from EVAL_SQ_INDEX
    RLDI 11, B_QUEEN_SQ
    STR 11
EVAL_NOT_QUEEN_TRACK:

    ; Get piece value from table
    ; R8.0 = piece type (1-6), need to look up in PIECE_VALUES table
    GLO 8               ; Piece type from R8.0
    SHL                 ; Multiply by 2 (16-bit table entries)
    STR 2               ; Save offset to stack
    LDI LOW(PIECE_VALUES)
    ADD                 ; D = LOW(PIECE_VALUES) + offset
    PLO 11              ; R11.0 = low byte of address
    LDI HIGH(PIECE_VALUES)
    ADCI 0              ; Add carry if low byte overflowed
    PHI 11              ; R11 = PIECE_VALUES + (type * 2)

    ; Load 16-bit value
    LDA 11
    PHI 7              ; 7.1 = value high
    LDN 11
    PLO 7              ; 7.0 = value low
                        ; 7 = piece value

    ; Add or subtract based on color
    GLO 15              ; Color
    BZ EVAL_ADD_WHITE

EVAL_ADD_BLACK:
    ; Black piece - subtract from score (negate 7)
    CALL NEG16_R7
    ; Fall through to add

EVAL_ADD_WHITE:
    ; White piece or negated black - add to score
    ; R9 = R9 + R7 (using R9 for score, not R6 which is SCRT linkage!)
    GLO 9
    STR 2
    GLO 7
    ADD
    PLO 9
    GHI 9
    STR 2
    GHI 7
    ADC
    PHI 9
    ; 6 updated with new score

EVAL_NEXT_SQUARE:
    INC 10              ; Next square
    ; Increment square counter in memory (R13 still points to EVAL_SQ_INDEX)
    LDN 13
    ADI 1
    STR 13
    SMI 128
    LBNF EVAL_SCAN      ; Continue if < 128 (DF=0 means borrow, i.e., D was < 128)

EVAL_DONE:
    ; R9 contains material score

    ; ==================================================================
    ; Redundant-queen cap: extra queens beyond the first (per side) score
    ; as 0 cp. Prevents the engine from preferring more pawn promotions
    ; over delivering mate when it already has a queen — the eval bug
    ; that caused yesterday's 3-queen shuffle endgame.
    ; Implementation: subtract (W_QUEEN_CNT - 1) * 900 from white side,
    ; add (B_QUEEN_CNT - 1) * 900 for black side.
    ; ==================================================================

    ; --- White side ---
    RLDI 8, W_QUEEN_CNT
    LDN 8
    LBZ QC_W_DONE       ; 0 queens: nothing to cap
    SMI 1
    LBZ QC_W_DONE       ; 1 queen: no extras

    PLO 7               ; R7.0 = number of extras (>= 1)
    LDI 0
    PHI 7               ; clean R7.1 for predictable DEC

QC_W_LOOP:
    LDI $84             ; low byte of 900 ($0384)
    STR 2
    GLO 9
    SM
    PLO 9
    LDI $03             ; high byte of 900
    STR 2
    GHI 9
    SMB
    PHI 9
    DEC 7
    GLO 7
    LBNZ QC_W_LOOP
QC_W_DONE:

    ; --- Black side (extras flip sign: ADD 900 each) ---
    RLDI 8, B_QUEEN_CNT
    LDN 8
    LBZ QC_B_DONE
    SMI 1
    LBZ QC_B_DONE

    PLO 7
    LDI 0
    PHI 7

QC_B_LOOP:
    LDI $84
    STR 2
    GLO 9
    ADD
    PLO 9
    LDI $03
    STR 2
    GHI 9
    ADC
    PHI 9
    DEC 7
    GLO 7
    LBNZ QC_B_LOOP
QC_B_DONE:

    ; ==================================================================
    ; Queen-king proximity bonus
    ; For each side that has a queen, bonus = lookup[chebyshev_distance]
    ; from queen to enemy king. Encourages attacking play in endgame
    ; (paired with queen-cap which removed the redundant-promotion bias).
    ; ==================================================================

    ; --- White queen → black king proximity ---
    RLDI 8, W_QUEEN_SQ
    LDN 8
    XRI $FF
    LBZ QP_W_DONE       ; W_QUEEN_SQ == $FF (no queen), skip

    ; D was XOR'd; reload queen square
    RLDI 8, W_QUEEN_SQ
    LDN 8
    PHI 7               ; R7.1 = W queen 0x88 square

    RLDI 8, GAME_STATE + STATE_B_KING_SQ
    LDN 8
    PHI 8               ; R8.1 = B king 0x88 square (use R8.1 to free R8.0)

    ; |q_rank - k_rank|
    GHI 7
    ANI $70
    SHR
    SHR
    SHR
    SHR                 ; D = q_rank
    PLO 13              ; R13.0 = q_rank
    GHI 8
    ANI $70
    SHR
    SHR
    SHR
    SHR                 ; D = k_rank
    STR 2
    GLO 13
    SD                  ; D = k_rank - q_rank
    LBDF QP_W_RANK_OK
    SDI 0               ; negate to get magnitude
QP_W_RANK_OK:
    PHI 13              ; R13.1 = |rank diff|

    ; |q_file - k_file|
    GHI 7
    ANI $07             ; D = q_file
    PLO 13              ; R13.0 = q_file
    GHI 8
    ANI $07             ; D = k_file
    STR 2
    GLO 13
    SD                  ; D = k_file - q_file
    LBDF QP_W_FILE_OK
    SDI 0
QP_W_FILE_OK:
    PLO 13              ; R13.0 = |file diff|

    ; max(R13.1, R13.0)
    GHI 13
    STR 2
    GLO 13
    SD                  ; D = R13.1 - R13.0 (rank - file)
    LBDF QP_W_USE_RANK
    GLO 13              ; file > rank → max = file
    LBR QP_W_HAVE_DIST
QP_W_USE_RANK:
    GHI 13              ; rank >= file → max = rank
QP_W_HAVE_DIST:
    ; D = chebyshev distance (1-7 typically, 0 impossible)
    ADI LOW(QUEEN_PROX_BONUS)
    PLO 11
    LDI 0
    ADCI HIGH(QUEEN_PROX_BONUS)
    PHI 11
    LDN 11              ; D = bonus
    STR 2
    GLO 9
    ADD
    PLO 9
    GHI 9
    ADCI 0
    PHI 9
QP_W_DONE:

    ; --- Black queen → white king proximity (subtract bonus from R9) ---
    RLDI 8, B_QUEEN_SQ
    LDN 8
    XRI $FF
    LBZ QP_B_DONE

    RLDI 8, B_QUEEN_SQ
    LDN 8
    PHI 7

    RLDI 8, GAME_STATE + STATE_W_KING_SQ
    LDN 8
    PHI 8

    ; |q_rank - k_rank|
    GHI 7
    ANI $70
    SHR
    SHR
    SHR
    SHR
    PLO 13
    GHI 8
    ANI $70
    SHR
    SHR
    SHR
    SHR
    STR 2
    GLO 13
    SD
    LBDF QP_B_RANK_OK
    SDI 0
QP_B_RANK_OK:
    PHI 13

    ; |q_file - k_file|
    GHI 7
    ANI $07
    PLO 13
    GHI 8
    ANI $07
    STR 2
    GLO 13
    SD
    LBDF QP_B_FILE_OK
    SDI 0
QP_B_FILE_OK:
    PLO 13

    ; max
    GHI 13
    STR 2
    GLO 13
    SD
    LBDF QP_B_USE_RANK
    GLO 13
    LBR QP_B_HAVE_DIST
QP_B_USE_RANK:
    GHI 13
QP_B_HAVE_DIST:
    ADI LOW(QUEEN_PROX_BONUS)
    PLO 11
    LDI 0
    ADCI HIGH(QUEEN_PROX_BONUS)
    PHI 11
    LDN 11              ; D = bonus
    STR 2
    GLO 9
    SM                  ; subtract bonus from white-relative score
    PLO 9
    GHI 9
    SMBI 0
    PHI 9
QP_B_DONE:

    ; Add piece-square table bonuses
    CALL EVAL_PST

    ; ==================================================================
    ; Castling Rights Bonus (Phase 2 fix 2026-05-22: 20 → 50)
    ; +50cp per side that still has castling rights remaining.
    ;
    ; Bumped from +20 to +50 because +20 was too weak to deter
    ; premature king moves. King PST: e1=-20, f1=+10 (=+30 PST gain
    ; for Kf1). With castling rights at +20, losing rights for Kf1
    ; was net +10 cp gain — engine moved king to f1 instead of
    ; castling. With +50, losing rights costs -50, so Kf1 is now
    ; -20 net (worse than staying or developing a piece).
    ;
    ; Validated empirically against 2026-05-22 PM match's move-15
    ; e1f1 mistake (engine in check, chose Kf1 over Bc1-d2 block).
    ; ==================================================================
    RLDI 11, GAME_STATE + STATE_CASTLING
    LDN 11              ; D = castling rights byte
    STR 2               ; save for reuse
    ANI $03             ; white bits (WK|WQ)
    LBZ EVAL_NO_W_CASTLE
    GLO 9
    ADI 50
    PLO 9
    GHI 9
    ADCI 0
    PHI 9               ; R9 += 50 (white has castling rights)
EVAL_NO_W_CASTLE:
    LDN 2               ; reload castling byte
    ANI $0C             ; black bits (BK|BQ)
    LBZ EVAL_NO_B_CASTLE
    GLO 9
    SMI 50
    PLO 9
    GHI 9
    SMBI 0
    PHI 9               ; R9 -= 50 (black has castling rights)
EVAL_NO_B_CASTLE:

    ; ==================================================================
    ; State-conditional walked-king penalty (Phase 2 audit 2026-05-22)
    ; ------------------------------------------------------------------
    ; If a side hasn't castled (CASTLED_FLAGS bit clear) AND their king
    ; has moved away from its starting square, they walked the king out
    ; of the castling opportunity — apply a -50 cp penalty. This is the
    ; state-conditional companion to the static king PST: PST values for
    ; "side" squares (f1, h1, etc.) are correct for castled-then-walked,
    ; wrong for walked-without-castling. The flag distinguishes them.
    ;
    ; CASTLED_FLAGS bits: 0 = white castled, 4 = black castled.
    ; e1 = $04 (0x88), e8 = $74.
    ; ==================================================================
    RLDI 10, CASTLED_FLAGS
    LDN 10
    STR 2                       ; save flags on stack scratch

    ; --- White check ---
    RLDI 10, GAME_STATE + STATE_W_KING_SQ
    LDN 10                      ; D = white king sq
    XRI $04                     ; e1 = $04
    LBZ EVAL_CFL_W_DONE         ; king still on e1, no penalty
    LDN 2                       ; reload CASTLED_FLAGS
    ANI $01                     ; white castled bit
    LBNZ EVAL_CFL_W_DONE        ; white castled, no penalty
    ; Walked king without castling: R9 -= 50
    GLO 9
    SMI 50
    PLO 9
    GHI 9
    SMBI 0
    PHI 9
EVAL_CFL_W_DONE:

    ; --- Black check ---
    RLDI 10, GAME_STATE + STATE_B_KING_SQ
    LDN 10                      ; D = black king sq
    XRI $74                     ; e8 = $74
    LBZ EVAL_CFL_B_DONE         ; king still on e8, no penalty
    LDN 2                       ; reload CASTLED_FLAGS
    ANI $10                     ; black castled bit
    LBNZ EVAL_CFL_B_DONE        ; black castled, no penalty
    ; Walked king without castling (black perspective: R9 += 50)
    GLO 9
    ADI 50
    PLO 9
    GHI 9
    ADCI 0
    PHI 9
EVAL_CFL_B_DONE:

    ; ==================================================================
    ; State-conditional pawn shield eval (Phase 2 audit 2026-05-22)
    ; ------------------------------------------------------------------
    ; If a side has castled, check pawn shield at the 3 squares directly
    ; in front of the king (rank 2 for white, rank 7 for black). Penalize
    ; -60 cp per missing shield pawn. Captures the "open file near king"
    ; danger pattern observed in earlier disaster matches.
    ;
    ; Gating:
    ;   - Only fires when CASTLED_FLAGS bit is set for that side
    ;   - Only fires when king is on its back rank (rank 1 / rank 8)
    ;   - The $88 mask catches file-boundary overflow (file=-1 or 8)
    ;
    ; Cost note: ~80 instructions per color per leaf. Combined with the
    ; walked-king penalty and N2/N3 hanging-piece check, the per-leaf
    ; eval overhead is noticeable in opening positions (high branching
    ; factor), causing some d=3-d=4 IDS completions where d=5 was
    ; expected. The 2026-05-22 winning match showed the engine adapted
    ; (building a manual king fortress when castling wasn't reached at
    ; low depth), so the architecture is functional despite the cost.
    ; Future work: move shield logic to $7B00 overflow page, or cache.
    ; ==================================================================

    ; --- White shield ---
    RLDI 10, CASTLED_FLAGS
    LDN 10
    ANI $01
    LBZ EVAL_PS_BLACK       ; white not castled, skip

    RLDI 10, GAME_STATE + STATE_W_KING_SQ
    LDN 10                  ; D = king square (0x88)
    PLO 8                   ; save in R8.0
    ANI $70                 ; mask rank bits
    LBNZ EVAL_PS_BLACK      ; king not on rank 1, skip
    GLO 8                   ; reload king sq
    ANI $07                 ; D = king file (0-7)
    PLO 7                   ; R7.0 = king file

    ; Shield square: king_file - 1, rank 2
    GLO 7
    SMI 1                   ; file - 1 (will overflow to $FF if file=0)
    ORI $10                 ; combine with rank 2
    PLO 10
    ANI $88                 ; off-board check
    LBNZ EVAL_PS_W_CENTER
    LDI HIGH(BOARD)
    PHI 10
    LDN 10
    XRI W_PAWN
    LBZ EVAL_PS_W_CENTER    ; own pawn here, no penalty
    GLO 9
    SMI 60
    PLO 9
    GHI 9
    SMBI 0
    PHI 9

EVAL_PS_W_CENTER:
    ; Shield square: king_file, rank 2
    GLO 7
    ORI $10                 ; rank 2 + king file
    PLO 10
    LDI HIGH(BOARD)
    PHI 10
    LDN 10
    XRI W_PAWN
    LBZ EVAL_PS_W_RIGHT
    GLO 9
    SMI 60
    PLO 9
    GHI 9
    SMBI 0
    PHI 9

EVAL_PS_W_RIGHT:
    ; Shield square: king_file + 1, rank 2
    GLO 7
    ADI 1
    ORI $10
    PLO 10
    ANI $88                 ; off-board check
    LBNZ EVAL_PS_BLACK
    LDI HIGH(BOARD)
    PHI 10
    LDN 10
    XRI W_PAWN
    LBZ EVAL_PS_BLACK
    GLO 9
    SMI 60
    PLO 9
    GHI 9
    SMBI 0
    PHI 9

EVAL_PS_BLACK:
    ; --- Black shield (mirror) ---
    RLDI 10, CASTLED_FLAGS
    LDN 10
    ANI $10                 ; black castled bit
    LBZ EVAL_PS_DONE

    RLDI 10, GAME_STATE + STATE_B_KING_SQ
    LDN 10
    PLO 8
    ANI $70
    XRI $70                 ; rank 8 == $70
    LBNZ EVAL_PS_DONE       ; king not on rank 8, skip
    GLO 8
    ANI $07
    PLO 7

    ; Shield: king_file - 1, rank 7
    GLO 7
    SMI 1
    ORI $60                 ; rank 7
    PLO 10
    ANI $88
    LBNZ EVAL_PS_B_CENTER
    LDI HIGH(BOARD)
    PHI 10
    LDN 10
    XRI B_PAWN
    LBZ EVAL_PS_B_CENTER
    GLO 9
    ADI 60
    PLO 9
    GHI 9
    ADCI 0
    PHI 9

EVAL_PS_B_CENTER:
    ; Shield: king_file, rank 7
    GLO 7
    ORI $60
    PLO 10
    LDI HIGH(BOARD)
    PHI 10
    LDN 10
    XRI B_PAWN
    LBZ EVAL_PS_B_RIGHT
    GLO 9
    ADI 60
    PLO 9
    GHI 9
    ADCI 0
    PHI 9

EVAL_PS_B_RIGHT:
    ; Shield: king_file + 1, rank 7
    GLO 7
    ADI 1
    ORI $60
    PLO 10
    ANI $88
    LBNZ EVAL_PS_DONE
    LDI HIGH(BOARD)
    PHI 10
    LDN 10
    XRI B_PAWN
    LBZ EVAL_PS_DONE
    GLO 9
    ADI 60
    PLO 9
    GHI 9
    ADCI 0
    PHI 9

EVAL_PS_DONE:

    ; ==================================================================
    ; Doubled Pawn Penalty: -15cp per extra pawn on same file
    ; Iterate 8 files; if count >= 2, penalty += (count - 1) * 15
    ; ==================================================================

    ; --- White doubled pawns ---
    RLDI 11, W_PAWN_FILE_CT     ; $6710
    LDI 8
    PLO 13                      ; R13.0 = file counter (temp, will restore later)
    LDI 0
    PHI 7                       ; R7.1 = white doubled penalty accumulator
EVAL_WDP_LOOP:
    LDA 11                      ; D = pawn count for this file, R11++
    SMI 2                       ; D = count - 2 (DF=1 if count >= 2)
    LBNF EVAL_WDP_NEXT          ; count < 2, no doubled
    ; count >= 2: penalty = (count - 1) * 15
    ; D = count - 2, so D + 1 = count - 1
    ADI 1                       ; D = count - 1
    ; Multiply by 15: x*16 - x = (x<<4) - x
    ; But with 8-bit arithmetic, max extra pawns = 7, 7*15 = 105 fits in byte
    PLO 7                       ; save (count-1) in R7.0
    SHL
    SHL
    SHL
    SHL                         ; D = (count-1) * 16
    STR 2                       ; M(R2) = (count-1) * 16
    GLO 7                       ; D = (count-1)
    SD                          ; D = M(R2) - D = (count-1)*16 - (count-1) = (count-1)*15
    STR 2                       ; save penalty on stack
    GHI 7                       ; accumulated penalty
    ADD                         ; D = accumulated + this file's penalty
    PHI 7                       ; update accumulator
EVAL_WDP_NEXT:
    DEC 13
    GLO 13
    LBNZ EVAL_WDP_LOOP
    ; R7.1 = total white doubled penalty (always positive)
    ; Subtract from score (penalty for white)
    GHI 7
    LBZ EVAL_WDP_DONE           ; skip if 0
    STR 2
    GLO 9
    SM                          ; R9.0 - penalty
    PLO 9
    GHI 9
    SMBI 0
    PHI 9                       ; R9 -= white doubled penalty
EVAL_WDP_DONE:

    ; --- Black doubled pawns ---
    RLDI 11, B_PAWN_FILE_CT     ; $6718
    LDI 8
    PLO 13
    LDI 0
    PHI 7
EVAL_BDP_LOOP:
    LDA 11
    SMI 2
    LBNF EVAL_BDP_NEXT
    ADI 1                       ; D = count - 1
    PLO 7
    SHL
    SHL
    SHL
    SHL                         ; (count-1) * 16
    STR 2
    GLO 7
    SD                          ; (count-1) * 15
    STR 2
    GHI 7
    ADD
    PHI 7
EVAL_BDP_NEXT:
    DEC 13
    GLO 13
    LBNZ EVAL_BDP_LOOP
    ; Add black penalty to score (good for white)
    GHI 7
    LBZ EVAL_BDP_DONE
    STR 2
    GLO 9
    ADD
    PLO 9
    GHI 9
    ADCI 0
    PHI 9                       ; R9 += black doubled penalty
EVAL_BDP_DONE:

    ; ==================================================================
    ; Bishop Pair Bonus: +30cp for having both bishops
    ; ==================================================================
    RLDI 11, EVAL_W_BISHOPS
    LDN 11
    SMI 2
    LBNF EVAL_NO_WBP            ; < 2 bishops
    GLO 9
    ADI 30
    PLO 9
    GHI 9
    ADCI 0
    PHI 9                       ; R9 += 30 (white bishop pair)
EVAL_NO_WBP:
    RLDI 11, EVAL_B_BISHOPS
    LDN 11
    SMI 2
    LBNF EVAL_NO_BBP
    GLO 9
    SMI 30
    PLO 9
    GHI 9
    SMBI 0
    PHI 9                       ; R9 -= 30 (black bishop pair)
EVAL_NO_BBP:

    ; ==================================================================
    ; Rook on Open/Semi-Open File
    ; +20cp open (no friendly pawns, no enemy pawns on file)
    ; +10cp semi-open (no friendly pawns, enemy pawns present)
    ; ==================================================================

    ; --- White rook 1 ---
    RLDI 11, EVAL_W_ROOK_F1
    LDN 11
    XRI $FF
    LBZ EVAL_WR_DONE            ; no white rook 1
    ; Check white pawn count on this file
    LDN 11                      ; D = file (reload, XRI changed D)
    ADI LOW(W_PAWN_FILE_CT)
    PLO 11
    LDI HIGH(W_PAWN_FILE_CT)
    ADCI 0
    PHI 11                      ; R11 = &W_PAWN_FILE_CT[file]
    LDN 11
    LBNZ EVAL_WR1_CLOSED        ; friendly pawns on file, no bonus
    ; No friendly pawns. Check enemy pawns for open vs semi-open.
    RLDI 11, EVAL_W_ROOK_F1
    LDN 11                      ; D = file
    ADI LOW(B_PAWN_FILE_CT)
    PLO 11
    LDI HIGH(B_PAWN_FILE_CT)
    ADCI 0
    PHI 11
    LDN 11                      ; D = black pawn count on this file
    LBNZ EVAL_WR1_SEMI
    ; Fully open file: +20
    GLO 9
    ADI 20
    PLO 9
    GHI 9
    ADCI 0
    PHI 9
    LBR EVAL_WR1_CLOSED
EVAL_WR1_SEMI:
    ; Semi-open: +10
    GLO 9
    ADI 10
    PLO 9
    GHI 9
    ADCI 0
    PHI 9
EVAL_WR1_CLOSED:

    ; --- White rook 2 ---
    RLDI 11, EVAL_W_ROOK_F2
    LDN 11
    XRI $FF
    LBZ EVAL_WR_DONE
    LDN 11
    ADI LOW(W_PAWN_FILE_CT)
    PLO 11
    LDI HIGH(W_PAWN_FILE_CT)
    ADCI 0
    PHI 11
    LDN 11
    LBNZ EVAL_WR_DONE           ; friendly pawns, no bonus
    RLDI 11, EVAL_W_ROOK_F2
    LDN 11
    ADI LOW(B_PAWN_FILE_CT)
    PLO 11
    LDI HIGH(B_PAWN_FILE_CT)
    ADCI 0
    PHI 11
    LDN 11
    LBNZ EVAL_WR2_SEMI
    GLO 9
    ADI 20
    PLO 9
    GHI 9
    ADCI 0
    PHI 9
    LBR EVAL_WR_DONE
EVAL_WR2_SEMI:
    GLO 9
    ADI 10
    PLO 9
    GHI 9
    ADCI 0
    PHI 9
EVAL_WR_DONE:

    ; --- Black rook 1 ---
    RLDI 11, EVAL_B_ROOK_F1
    LDN 11
    XRI $FF
    LBZ EVAL_BR_DONE
    LDN 11
    ADI LOW(B_PAWN_FILE_CT)
    PLO 11
    LDI HIGH(B_PAWN_FILE_CT)
    ADCI 0
    PHI 11
    LDN 11
    LBNZ EVAL_BR1_CLOSED        ; friendly pawns, no bonus
    RLDI 11, EVAL_B_ROOK_F1
    LDN 11
    ADI LOW(W_PAWN_FILE_CT)
    PLO 11
    LDI HIGH(W_PAWN_FILE_CT)
    ADCI 0
    PHI 11
    LDN 11
    LBNZ EVAL_BR1_SEMI
    ; Fully open: -20 (good for black)
    GLO 9
    SMI 20
    PLO 9
    GHI 9
    SMBI 0
    PHI 9
    LBR EVAL_BR1_CLOSED
EVAL_BR1_SEMI:
    GLO 9
    SMI 10
    PLO 9
    GHI 9
    SMBI 0
    PHI 9
EVAL_BR1_CLOSED:

    ; --- Black rook 2 ---
    RLDI 11, EVAL_B_ROOK_F2
    LDN 11
    XRI $FF
    LBZ EVAL_BR_DONE
    LDN 11
    ADI LOW(B_PAWN_FILE_CT)
    PLO 11
    LDI HIGH(B_PAWN_FILE_CT)
    ADCI 0
    PHI 11
    LDN 11
    LBNZ EVAL_BR_DONE
    RLDI 11, EVAL_B_ROOK_F2
    LDN 11
    ADI LOW(W_PAWN_FILE_CT)
    PLO 11
    LDI HIGH(W_PAWN_FILE_CT)
    ADCI 0
    PHI 11
    LDN 11
    LBNZ EVAL_BR2_SEMI
    GLO 9
    SMI 20
    PLO 9
    GHI 9
    SMBI 0
    PHI 9
    LBR EVAL_BR_DONE
EVAL_BR2_SEMI:
    GLO 9
    SMI 10
    PLO 9
    GHI 9
    SMBI 0
    PHI 9
EVAL_BR_DONE:

    ; ==================================================================
    ; N2: hanging-pawn penalty (2026-05-21)
    ; ------------------------------------------------------------------
    ; For each pawn, check if attacked by opposing B/Q (4 diagonals with
    ; blocker awareness) or opposing N (8 L-pattern squares). Defender
    ; check via own-pawn backward-diagonal adjacency. Per-attacker
    ; penalty: -25 cp (white pawn) / +25 cp (black pawn) per attacker.
    ; Routine lives in overflow page \$7B00 (see n2_hanging.asm).
    ; Catches the 2026-05-20 PM match's recurring blunder pattern:
    ; pushing pawns into known bishop attack ranges (move 38 g2-g4
    ; with Bf5 attacking g4, move 61 e5-e6 with bishop attacking e6).
    ; ==================================================================
    CALL N2_HANGING_PAWN

    ; ==================================================================
    ; Endgame phase eval (king centralization, advanced pawn, passed pawn,
    ; king-edge drive) — gated by EG_PIECE_COUNT threshold.
    ; Tightened 2026-04-30 from <21 to <12: previously fired after only 9
    ; captures (mid-middlegame), causing premature king-walking with d=5
    ; search exposing inappropriate king-centralization variations. <12
    ; requires 18 captures, true late-endgame territory where king activity
    ; and pawn promotion drives are actually correct strategy.
    ; ==================================================================

    ; Item-B gate (2026-05-19): snapshot pre-endgame score (material +
    ; PST + structure + king-safety) for the material-deficit gate at
    ; BKS_DONE. PERMANENT.
    RLDI 10, EVAL_PREEG
    GHI 9
    STR 10
    INC 10
    GLO 9
    STR 10

    ; ==================================================================
    ; Middlegame enemy-pawn-advance penalty (Fix 2026-05-27, revised)
    ; ------------------------------------------------------------------
    ; Initial Fix applied BOTH white and black ADV_PAWN at half-weight in
    ; middlegame. Caused over-pushing of own pawns (engine pushed pawns
    ; while own queen was attacked, 2026-05-27 match).
    ;
    ; Revised: asymmetric — apply ONLY the black ADV_PAWN penalty (from
    ; white's perspective) in middlegame. This signals enemy pawn marches
    ; without rewarding own pawn advances (which would compete with
    ; development in opening/middlegame).
    ;
    ; White's pawn-push reward STILL fires in endgame block at full
    ; weight (when EG_PIECE_COUNT < 12). Both sides get full ADV_PAWN
    ; treatment in endgame as before.
    ; ==================================================================
    RLDI 11, EG_PIECE_COUNT
    LDN 11
    SMI 12
    LBNF SKIP_MID_ADV   ; count < 12 (endgame) — let endgame block handle

    ; --- Black ADV_PAWN penalty only (enemy threat awareness) ---
    ; Half weight so black-pawn advance signals are present but moderate.
    RLDI 10, ADV_PAWN_B
    LDN 10
    SHR                 ; half
    STR 2
    GLO 9
    SM
    PLO 9
    GHI 9
    SMBI 0
    PHI 9

SKIP_MID_ADV:

    RLDI 11, EG_PIECE_COUNT
    LDN 11              ; D = piece count
    SMI 12              ; compare: count - 12
    LBDF BKS_DONE       ; DF=1 means count >= 12, not endgame, skip

    ; === White king centralization ===
    RLDI 10, GAME_STATE + STATE_W_KING_SQ
    LDN 10              ; D = white king 0x88 square
    ; Convert 0x88 to 0-63 index
    PLO 13              ; save square
    SHR
    SHR
    SHR
    SHR                 ; D = rank (0-7)
    SHL
    SHL
    SHL                 ; D = rank * 8
    STXD                ; push rank*8
    GLO 13
    ANI $07             ; D = file (0-7)
    IRX
    ADD                 ; D = rank*8 + file = index
    PLO 15              ; save white king index in R15.0
    ; Look up centralization value
    STR 2               ; save index on stack
    RLDI 11, KING_CENTER_TABLE
    GLO 11
    ADD                 ; D = LOW(table) + index
    PLO 11
    GHI 11
    ADCI 0
    PHI 11              ; R11 = &KING_CENTER_TABLE[index]
    LDN 11              ; D = table value (-30 to +30)
    SHL                 ; D = value * 2
    SHL                 ; D = value * 4 (-120 to +120)
    ; Sign-extend to 16 bits and add to R9
    PLO 7               ; R7.0 = bonus low byte
    ANI $80             ; check sign
    LBZ EG_W_POS
    LDI $FF
    LBR EG_W_HI
EG_W_POS:
    LDI 0
EG_W_HI:
    PHI 7               ; R7 = sign-extended 16-bit bonus
    ; R9 = R9 + R7 (add white king centralization)
    GLO 9
    STR 2
    GLO 7
    ADD
    PLO 9
    GHI 9
    STR 2
    GHI 7
    ADC
    PHI 9

    ; === Black king centralization ===
    RLDI 10, GAME_STATE + STATE_B_KING_SQ
    LDN 10              ; D = black king 0x88 square
    ; Convert 0x88 to 0-63 index
    PLO 13              ; save square
    SHR
    SHR
    SHR
    SHR                 ; D = rank
    SHL
    SHL
    SHL                 ; D = rank * 8
    STXD                ; push rank*8
    GLO 13
    ANI $07             ; D = file
    IRX
    ADD                 ; D = index
    PHI 15              ; save black king index in R15.1
    ; Look up centralization value
    STR 2
    RLDI 11, KING_CENTER_TABLE
    GLO 11
    ADD
    PLO 11
    GHI 11
    ADCI 0
    PHI 11              ; R11 = &KING_CENTER_TABLE[index]
    LDN 11              ; D = table value (-30 to +30)
    SHL                 ; D * 2
    SHL                 ; D * 4 (-120 to +120)
    ; Sign-extend to 16 bits into R7
    PLO 7
    ANI $80
    LBZ EG_B_POS
    LDI $FF
    LBR EG_B_HI
EG_B_POS:
    LDI 0
EG_B_HI:
    PHI 7               ; R7 = sign-extended 16-bit bonus
    ; R9 = R9 - R7 (subtract black king centralization)
    GLO 7
    STR 2
    GLO 9
    SM                  ; D = R9.0 - R7.0
    PLO 9
    GHI 7
    STR 2
    GHI 9
    SMB                 ; D = R9.1 - R7.1 - borrow
    PHI 9

    ; ==================================================================
    ; Advanced Pawn Bonus (endgame only)
    ; Graduated: +50/+100/+150 cp based on distance from promotion (saturated at 255)
    ; ==================================================================

    ; White advanced pawn bonus (accumulated)
    ; Asymmetric scaling: 1/4 in conversion phase only (we have queen,
    ; opp doesn't). Preserves full pawn aggression in opening (both have
    ; queens) and post-queen-exchange middlegame (neither has queen).
    RLDI 11, ADV_PAWN_W
    LDN 11              ; D = accumulated white bonus (0-255)
    LBZ EG_NO_W_ADV     ; none, skip
    STR 2               ; save bonus on stack
    RLDI 11, W_QUEEN_CNT
    LDN 11
    LBZ EG_W_ADV_GO     ; we don't have queen — full bonus, push toward promotion
    RLDI 11, B_QUEEN_CNT
    LDN 11
    LBNZ EG_W_ADV_GO    ; opp has queen too — full bonus, normal play
    LDN 2               ; conversion phase: scale to 1/4
    SHR
    SHR
    STR 2
EG_W_ADV_GO:
    GLO 9
    ADD                 ; R9.0 + bonus
    PLO 9
    GHI 9
    ADCI 0
    PHI 9               ; R9 += white pawn bonus
EG_NO_W_ADV:

    ; Black advanced pawn bonus (accumulated)
    ; No conversion-phase scaling on opponent pawns: we want full sensitivity
    ; to enemy promotion threats even when we've lost our queen.
    RLDI 11, ADV_PAWN_B
    LDN 11
    LBZ EG_NO_B_ADV     ; none, skip
    STR 2               ; save bonus on stack
    GLO 9
    SM                  ; D = R9.0 - bonus
    PLO 9
    GHI 9
    SMBI 0
    PHI 9               ; R9 -= black pawn bonus
EG_NO_B_ADV:

    ; ==================================================================
    ; Passed Pawn Bonus (endgame only, ranks 5-7)
    ; A pawn is "passed" if no enemy pawns on same or adjacent files.
    ; Uses W_PAWN_FILE_CT / B_PAWN_FILE_CT arrays (already populated).
    ; Only checks ranks 5-7 (white) / 4-2 (black) for bonus.
    ; Bonus: rank 2 = +25, rank 3 = +50, rank 4 = +90, rank 5 = +140, rank 6 = +200, rank 7 = +250
    ; ==================================================================

    ; --- White passed pawns ---
    LDI 0
    PLO 13              ; R13.0 = file counter (0-7)
    RLDI 11, W_PAWN_FILE_CT

PP_W_LOOP:
    LDN 11              ; D = W_PAWN_FILE_CT[file]
    LBZ PP_W_NEXT       ; no white pawn on this file

    ; White pawn exists — check if passed (no black pawns on file-1, file, file+1)
    ; Check B_PAWN_FILE_CT[file]
    GLO 13              ; D = file
    ADI LOW(B_PAWN_FILE_CT)
    PLO 10
    LDI HIGH(B_PAWN_FILE_CT)
    ADCI 0
    PHI 10              ; R10 = &B_PAWN_FILE_CT[file]
    LDN 10
    LBNZ PP_W_NEXT      ; black pawn on same file, not passed

    ; Check B_PAWN_FILE_CT[file-1] (skip if file == 0)
    GLO 13
    LBZ PP_W_LEFT_OK
    DEC 10              ; R10 = &B_PAWN_FILE_CT[file-1]
    LDN 10
    INC 10              ; restore R10
    LBNZ PP_W_NEXT      ; black pawn on left file
PP_W_LEFT_OK:

    ; Check B_PAWN_FILE_CT[file+1] (skip if file == 7)
    GLO 13
    XRI 7
    LBZ PP_W_RIGHT_OK
    INC 10              ; R10 = &B_PAWN_FILE_CT[file+1]
    LDN 10
    DEC 10              ; restore R10
    LBNZ PP_W_NEXT      ; black pawn on right file
PP_W_RIGHT_OK:

    ; Passed! Scan ranks 7-2 for the most advanced white pawn
    LDI HIGH(BOARD)
    PHI 10

    ; Rank 7: square = $60 + file
    GLO 13
    ORI $60
    PLO 10
    LDN 10
    XRI W_PAWN
    LBZ PP_W_R7

    ; Rank 6: square = $50 + file
    GLO 13
    ORI $50
    PLO 10
    LDN 10
    XRI W_PAWN
    LBZ PP_W_R6

    ; Rank 5: square = $40 + file
    GLO 13
    ORI $40
    PLO 10
    LDN 10
    XRI W_PAWN
    LBZ PP_W_R5

    ; Rank 4: square = $30 + file
    GLO 13
    ORI $30
    PLO 10
    LDN 10
    XRI W_PAWN
    LBZ PP_W_R4

    ; Rank 3: square = $20 + file
    GLO 13
    ORI $20
    PLO 10
    LDN 10
    XRI W_PAWN
    LBZ PP_W_R3

    ; Rank 2: square = $10 + file
    GLO 13
    ORI $10
    PLO 10
    LDN 10
    XRI W_PAWN
    LBNZ PP_W_NEXT      ; no white pawn found

    LDI 25              ; Rank 2 bonus
    LBR PP_W_ADD
PP_W_R3:
    LDI 50
    LBR PP_W_ADD
PP_W_R4:
    LDI 90
    LBR PP_W_ADD
PP_W_R5:
    LDI 140
    LBR PP_W_ADD
PP_W_R6:
    LDI 160             ; was 200, Fix A 2026-05-19
    LBR PP_W_ADD
PP_W_R7:
    LDI 180             ; was 250, Fix A 2026-05-19
PP_W_ADD:
    STR 2
    ; Asymmetric scaling (mirror of ADV_PAWN_W): scale 1/4 only in
    ; conversion phase (W has queen, B doesn't).
    RLDI 8, W_QUEEN_CNT
    LDN 8
    LBZ PP_W_ADD_GO     ; we don't have queen — full bonus
    RLDI 8, B_QUEEN_CNT
    LDN 8
    LBNZ PP_W_ADD_GO    ; both have queens — full bonus
    LDN 2               ; conversion phase: scale to 1/4
    SHR
    SHR
    STR 2
PP_W_ADD_GO:
    GLO 9
    ADD
    PLO 9
    GHI 9
    ADCI 0
    PHI 9               ; R9 += passed pawn bonus

PP_W_NEXT:
    INC 11              ; next W_PAWN_FILE_CT entry
    INC 13              ; file++
    GLO 13
    XRI 8
    LBNZ PP_W_LOOP

    ; --- Black passed pawns ---
    LDI 0
    PLO 13              ; R13.0 = file counter (0-7)
    RLDI 11, B_PAWN_FILE_CT

PP_B_LOOP:
    LDN 11              ; D = B_PAWN_FILE_CT[file]
    LBZ PP_B_NEXT       ; no black pawn on this file

    ; Black pawn exists — check if passed (no white pawns on file-1, file, file+1)
    ; Check W_PAWN_FILE_CT[file]
    GLO 13
    ADI LOW(W_PAWN_FILE_CT)
    PLO 10
    LDI HIGH(W_PAWN_FILE_CT)
    ADCI 0
    PHI 10              ; R10 = &W_PAWN_FILE_CT[file]
    LDN 10
    LBNZ PP_B_NEXT      ; white pawn on same file, not passed

    ; Check W_PAWN_FILE_CT[file-1] (skip if file == 0)
    GLO 13
    LBZ PP_B_LEFT_OK
    DEC 10
    LDN 10
    INC 10
    LBNZ PP_B_NEXT
PP_B_LEFT_OK:

    ; Check W_PAWN_FILE_CT[file+1] (skip if file == 7)
    GLO 13
    XRI 7
    LBZ PP_B_RIGHT_OK
    INC 10
    LDN 10
    DEC 10
    LBNZ PP_B_NEXT
PP_B_RIGHT_OK:

    ; Passed! Scan ranks 2-7 for the most advanced black pawn
    LDI HIGH(BOARD)
    PHI 10

    ; Rank 2: square = $10 + file
    GLO 13
    ORI $10
    PLO 10
    LDN 10
    XRI B_PAWN
    LBZ PP_B_R2

    ; Rank 3: square = $20 + file
    GLO 13
    ORI $20
    PLO 10
    LDN 10
    XRI B_PAWN
    LBZ PP_B_R3

    ; Rank 4: square = $30 + file
    GLO 13
    ORI $30
    PLO 10
    LDN 10
    XRI B_PAWN
    LBZ PP_B_R4

    ; Rank 5: square = $40 + file
    GLO 13
    ORI $40
    PLO 10
    LDN 10
    XRI B_PAWN
    LBZ PP_B_R5

    ; Rank 6: square = $50 + file
    GLO 13
    ORI $50
    PLO 10
    LDN 10
    XRI B_PAWN
    LBZ PP_B_R6

    ; Rank 7: square = $60 + file
    GLO 13
    ORI $60
    PLO 10
    LDN 10
    XRI B_PAWN
    LBNZ PP_B_NEXT      ; no black pawn found

    LDI 25              ; Rank 7 bonus (just started)
    LBR PP_B_SUB
PP_B_R6:
    LDI 50
    LBR PP_B_SUB
PP_B_R5:
    LDI 90
    LBR PP_B_SUB
PP_B_R4:
    LDI 140
    LBR PP_B_SUB
PP_B_R3:
    LDI 160             ; was 200, Fix A 2026-05-19
    LBR PP_B_SUB
PP_B_R2:
    LDI 180             ; was 250, Fix A 2026-05-19
PP_B_SUB:
    STR 2
    ; No conversion-phase scaling on opponent pawns: we want full sensitivity
    ; to enemy promotion threats even when we've lost our queen.
    GLO 9
    SM                  ; D = R9.0 - bonus
    PLO 9
    GHI 9
    SMBI 0
    PHI 9               ; R9 -= passed pawn bonus (black advantage)

PP_B_NEXT:
    INC 11              ; next B_PAWN_FILE_CT entry
    INC 13              ; file++
    GLO 13
    XRI 8
    LBNZ PP_B_LOOP

    ; ==================================================================
    ; Enemy King Edge Bonus (endgame only, when winning)
    ; Uses KING_EDGE_TABLE (already in binary, 64 bytes)
    ; Values: 60 at edges/corners, 0 at center — rewards driving to edge
    ; Scaled 2x via SHL for effective range 0-120cp
    ; ==================================================================

    ; Check if white is winning significantly (score > 200)
    GHI 9
    ANI $80             ; sign bit
    LBNZ EG_CHECK_BLACK ; negative, check if black winning
    GHI 9
    LBNZ EG_DRIVE_BLACK ; high byte > 0 → score > 255
    GLO 9
    SMI 200
    LBNF EG_EDGE_DONE   ; score < 200, skip

EG_DRIVE_BLACK:
    ; White winning — penalize black king for being in center
    ; R15.1 = black king index (saved during centralization)
    GHI 15              ; D = black king 0-63 index
    STR 2               ; save on stack
    RLDI 11, KING_EDGE_TABLE
    GLO 11
    ADD
    PLO 11
    GHI 11
    ADCI 0
    PHI 11              ; R11 = &KING_EDGE_TABLE[black_king]
    LDN 11              ; D = edge value (0-60)
    SHL                 ; D = value * 2 (0-120)
    STR 2               ; save bonus
    GLO 9
    ADD
    PLO 9
    GHI 9
    ADCI 0
    PHI 9               ; R9 += edge bonus (always positive, no sign extend)
    LBR EG_EDGE_DONE

EG_CHECK_BLACK:
    ; Check if black is winning (score < -200)
    ; Score is negative. Check if <= -201 (i.e., high byte < $FF or low byte <= $37)
    GHI 9
    XRI $FF
    LBNZ EG_DRIVE_WHITE ; high byte < $FF → score < -255
    GLO 9
    ADI 200             ; if score_lo + 200 overflows, score_lo > 55 → score > -201
    LBDF EG_EDGE_DONE   ; score > -201, not winning enough

EG_DRIVE_WHITE:
    ; Black winning — penalize white king for being in center
    ; R15.0 = white king index (saved during centralization)
    GLO 15              ; D = white king 0-63 index
    STR 2
    RLDI 11, KING_EDGE_TABLE
    GLO 11
    ADD
    PLO 11
    GHI 11
    ADCI 0
    PHI 11              ; R11 = &KING_EDGE_TABLE[white_king]
    LDN 11              ; D = edge value (0-60)
    SHL                 ; D = value * 2 (0-120)
    STR 2               ; save penalty
    GLO 9
    SM                  ; R9.0 - penalty (SM = D - M(R(X)))
    PLO 9
    GHI 9
    SMBI 0
    PHI 9               ; R9 -= edge penalty

EG_EDGE_DONE:

    ; ==================================================================
    ; Check bonus: if side-to-move is in check, credit the attacker.
    ; Score is white-relative, so white-in-check → R9 -= CHECK_BONUS;
    ; black-in-check → R9 += CHECK_BONUS.
    ; IS_IN_CHECK preserves R11/R12; we save R9 ourselves.
    ;
    ; Phase gate (Fix A 2026-05-27): skip check bonus in endgame.
    ; In endgame, checks are usually meaningless tempo wastes (king has many
    ; escape squares, no follow-up). The 2026-05-27 match showed engine
    ; making pointless rook check moves over pawn pushes because +40 cp
    ; check bonus outweighed the ~25-50 cp pawn-push reward.
    ; ==================================================================
    RLDI 10, EG_PIECE_COUNT
    LDN 10
    SMI 12
    LBNF CHECK_BONUS_DONE   ; count < 12 (endgame) — skip check bonus entirely

    GLO 9
    STXD
    GHI 9
    STXD

    CALL IS_IN_CHECK        ; uses R12 (side to move); D = 1 if in check
    PLO 8                   ; R8.0 = result

    IRX
    LDXA
    PHI 9
    LDX
    PLO 9                   ; R9 restored

    GLO 8
    LBZ CHECK_BONUS_DONE    ; not in check, skip

    GLO 12                  ; side to move: WHITE=0, BLACK=8
    LBZ CHECK_BONUS_SUB     ; white to move and white in check → penalty

    ; Black to move and black in check → bonus to white
    LDI CHECK_BONUS
    STR 2
    GLO 9
    ADD
    PLO 9
    GHI 9
    ADCI 0
    PHI 9
    LBR CHECK_BONUS_DONE

CHECK_BONUS_SUB:
    ; White to move and white in check → penalty to white
    LDI CHECK_BONUS
    STR 2
    GLO 9
    SM                      ; SM = D - M(R(X)) → R9.0 - CHECK_BONUS
    PLO 9
    GHI 9
    SMBI 0
    PHI 9

CHECK_BONUS_DONE:

    ; ==================================================================
    ; Fix B — keep-queen-when-winning (2026-05-19, relocated 2026-05-19 PM)
    ; ------------------------------------------------------------------
    ; Deter unforced Q-for-R sacs in winning positions while we still
    ; have a queen. Phase-gated by location: this code is inside the
    ; endgame block, so the LBDF BKS_DONE skip near line 1134 (piece
    ; count >= 12 = opening/middlegame) bypasses it. First deployment
    ; (commit 474579f) placed Fix B AFTER BKS_DONE, which let it fire
    ; during opening/middlegame search leaves and made the engine play
    ; passively (knights to the rim, queen retreats from active squares,
    ; king shuffling) whenever preeg crossed +300. Moving it inside the
    ; endgame block restores Win #17-style aggression while keeping the
    ; anti-Q-for-R sac intent active in the late game.
    ; Loads R7 = preeg locally; Item-B gate at BKS_DONE re-loads it for
    ; the opening path which skips this code.
    ; ==================================================================
    RLDI 10, EVAL_PREEG
    LDA 10
    PHI 7               ; R7.1 = preeg hi
    LDN 10
    PLO 7               ; R7.0 = preeg lo
    GLO 7
    SMI $2C             ; LOW(300)
    GHI 7
    SMBI $01            ; HIGH(300)
    ANI $80
    LBNZ FIX_B_NEG      ; sign set -> preeg < +300 -> try losing branch
    ; preeg >= +300: winning. If W_QUEEN_CNT > 0, R9 += 200.
    RLDI 8, W_QUEEN_CNT
    LDN 8
    LBZ FIX_B_DONE
    GLO 9
    ADI $C8             ; LOW(200)
    PLO 9
    GHI 9
    ADCI 0
    PHI 9
    LBR FIX_B_DONE
FIX_B_NEG:
    GLO 7
    ADI $2B             ; LOW(299)
    GHI 7
    ADCI $01            ; HIGH(299)
    ANI $80
    LBZ FIX_B_DONE      ; sign clear -> preeg > -300 -> neither lost
    ; preeg <= -300: losing. If B_QUEEN_CNT > 0, R9 -= 200.
    RLDI 8, B_QUEEN_CNT
    LDN 8
    LBZ FIX_B_DONE
    GLO 9
    SMI $C8             ; LOW(200)
    PLO 9
    GHI 9
    SMBI 0
    PHI 9
FIX_B_DONE:

    ; ==================================================================
    ; Hopeless-material amplifier (2026-05-19 PM-late; broadened 2026-05-27)
    ; ------------------------------------------------------------------
    ; Push eval past cutechess's -1500 cp / 10-move resign-adjudication
    ; threshold in terminal-loss positions so matches end via the GUI's
    ; adjudication instead of 50+ moves of shuffle.
    ;
    ; Trigger: EG_PIECE_COUNT <= 6 AND |preeg| >= 300
    ; Action:  losing side gets -2000; winning side gets +2000
    ;
    ; Broadening rationale (2026-05-27 killed match): the prior trigger
    ; (pc<=2 AND exactly one side has Q) was too narrow. Today's match
    ; reached 208 moves of queenless losing endgame that didn't qualify.
    ;
    ; Threshold rationale (2026-05-27 tighten from -500 to -300): hardware
    ; test on the killed-match position with -500 threshold showed amp
    ; firing at d=2 (score -2100) but engine dodging at d=3-5 via horizon-
    ; effect lines whose leaves had preeg between -300 and -500. -300
    ; matches Item-B's "materially lost" threshold; at pc<=6 a 3-pawn
    ; deficit is essentially never recoverable, denying the dodge route.
    ;
    ; New gate is symmetric and queen-agnostic. The two old branches
    ; (W_Q xor B_Q) collapse into preeg-sign branching because in K+Q vs K
    ; family positions preeg already encodes the material asymmetry
    ; (e.g., K+Q vs K has preeg ~+900, K vs K+Q has preeg ~-900). The
    ; broadened trigger ALSO catches K+R vs K, K+R+P vs K+B, etc.
    ;
    ; Cases caught (NEW vs OLD):
    ;   K+R vs K           pc=1, preeg~+500  NEW
    ;   K+B+B vs K         pc=2, preeg~+650  NEW
    ;   K+B vs K+R+P       pc=3, preeg~-600  NEW
    ;   K+Q vs K           pc=1, preeg~+900  OLD also caught
    ;   K+Q vs K+N         pc=2, preeg~+600  OLD also caught
    ;
    ; Cases NOT caught (intentional):
    ;   |preeg| < 300   - genuine middle endgame with comp possible
    ;   pc > 6          - still too many pieces; conversion uncertainty
    ;
    ; Inside endgame block: opening-path LBDF BKS_DONE near line 1134
    ; skips this code. After Fix B but before Item-B clamp; the +-2000
    ; survives the min/max clamp in both winning and losing branches
    ; because the clamp targets preeg (which is only material+PST+king-
    ; safety, well within +-1000), so the amplifier's magnitude dominates.
    ; ==================================================================
    RLDI 10, EG_PIECE_COUNT
    LDN 10
    SMI 7                       ; D = pc - 7, DF=1 if pc >= 7
    LBDF HM_AMP_DONE            ; pc > 6, skip

    ; pc <= 6 — load preeg and check |preeg| >= 300 ($012C)
    RLDI 10, EVAL_PREEG
    LDA 10
    PHI 7                       ; R7.1 = preeg hi
    LDN 10
    PLO 7                       ; R7.0 = preeg lo

    ; A = preeg + 299 ; preeg <= -300 iff A < 0 (sign bit set)
    ; (preeg=-300 -> A=-1 set; preeg=-299 -> A=0 clear) single check.
    GLO 7
    ADI $2B                     ; LOW(299)
    PLO 8
    GHI 7
    ADCI $01                    ; HIGH(299)
    ANI $80
    LBNZ HM_AMP_W_LOST          ; A negative -> white lost (preeg<=-300)

    ; B = preeg - 300 ; preeg >= +300 iff B >= 0 (sign clear)
    GLO 7
    SMI $2C                     ; LOW(300)
    PLO 8
    GHI 7
    SMBI $01                    ; HIGH(300)
    ANI $80
    LBNZ HM_AMP_DONE            ; B negative -> neither lost, skip

    ; Black is lost (preeg >= +300) -> winning amp: R9 += 2000 ($07D0)
    GLO 9
    ADI $D0                     ; LOW(2000)
    PLO 9
    GHI 9
    ADCI $07                    ; HIGH(2000)
    PHI 9
    LBR HM_AMP_DONE

HM_AMP_W_LOST:
    ; White is lost (preeg <= -300) -> losing amp: R9 -= 2000
    GLO 9
    SMI $D0                     ; LOW(2000)
    PLO 9
    GHI 9
    SMBI $07                    ; HIGH(2000)
    PHI 9

HM_AMP_DONE:

BKS_DONE:
    ; ==================================================================
    ; Item-B material-deficit gate (2026-05-19) + promotion-survival
    ; bonus (2026-05-28)
    ; ------------------------------------------------------------------
    ; EVAL_PREEG = core score (material+PST+structure+king-safety),
    ; captured before the endgame block. If a side is materially lost
    ; (|preeg| >= 300 against it) the endgame activity/pawn-push bonuses
    ; must not let the position read as drawish:
    ;   preeg <= -300 (white lost): R9 = min(R9, preeg)
    ;   preeg >= +300 (black lost): R9 = max(R9, preeg)
    ;   else (|preeg| < 300): unchanged — winning conversions keep full
    ;   endgame bonuses (16-win behaviour preserved).
    ; 300 = $012C.  delta = R9 - preeg via COMPARE_TEMP (eval scores are
    ; well within signed-16 range here; mate scores never reach the
    ; piece-count-gated endgame block).
    ;
    ; PROMOTION-SURVIVAL (2026-05-28): after the clamp on the losing
    ; side, restore HALF of the side's ADV_PAWN total. The full ADV_PAWN
    ; bonus was applied in the endgame block above but gets wiped out
    ; by the min/max clamp. Half-weight preserves the r4->r5->r6->r7
    ; gradient (so engine sees promotion as recoverable path) at a
    ; magnitude that doesn't undo Item-B's protective purpose.
    ; Triggered by 2026-05-28 match where engine had two r6 pawns
    ; (b6, d6), was at preeg -400, and would not push them because
    ; Item-B clamped pawn-push gain to zero.
    ;
    ; FOLLOW-UP (see MEMORY TODO): replace the hard step gate with a
    ; graduated ramp to remove the threshold cliff.
    ; ==================================================================
    RLDI 10, EVAL_PREEG
    LDA 10
    PHI 7               ; R7.1 = preeg hi
    LDN 10
    PLO 7               ; R7.0 = preeg lo

    ; A = preeg + 299 ; white-lost (preeg <= -300) iff A < 0 (sign set).
    ; (preeg=-300 -> A=-1 set; preeg=-299 -> A=0 clear) single check.
    GLO 7
    ADI $2B             ; LOW(299)
    PLO 8
    GHI 7
    ADCI $01            ; HIGH(299)
    ANI $80
    LBNZ GATE_WLOST     ; A negative -> white lost
    ; B = preeg - 300 ; black-lost (preeg >= +300) iff B >= 0 (sign clear)
    GLO 7
    SMI $2C
    GHI 7
    SMBI $01
    ANI $80
    LBNZ GATE_DONE      ; B negative -> preeg < +300 -> neither lost

    ; black lost: R9 = max(R9, preeg) -> if R9 < preeg, R9 = preeg
    CALL GATE_DELTA_SIGN    ; D bit7 = sign of (R9 - preeg)
    ANI $80
    LBZ GATE_BLOST_BONUS    ; R9 >= preeg already, skip clamp, do bonus
    ; clamp up to preeg
    GHI 7
    PHI 9
    GLO 7
    PLO 9
GATE_BLOST_BONUS:
    ; black is materially lost: subtract ADV_PAWN_B/2 from R9 (white pov)
    ; — half weight preserves r4->r7 gradient while keeping most of
    ; Item-B's protective intent against false-positive eval in losing
    ; positions. Magnitude tested 1/2 vs 3/4 vs full on 2026-05-28:
    ; bestmove choice in the test position is invariant to weight
    ; (engine sees that position as genuinely locked re: pushes),
    ; so the conservative half-weight is shipped.
    RLDI 10, ADV_PAWN_B
    LDN 10
    SHR                 ; D = ADV_PAWN_B / 2
    STR 2
    GLO 9
    SM                  ; R9.lo -= bonus
    PLO 9
    GHI 9
    SMBI 0              ; R9.hi -= borrow
    PHI 9
    LBR GATE_DONE

GATE_WLOST:
    ; white lost: R9 = min(R9, preeg) -> if R9 > preeg, R9 = preeg
    CALL GATE_DELTA_SIGN
    ANI $80
    LBNZ GATE_WLOST_BONUS   ; R9 < preeg already, skip clamp, do bonus
    ; clamp down to preeg
    GHI 7
    PHI 9
    GLO 7
    PLO 9
GATE_WLOST_BONUS:
    ; white is materially lost: add ADV_PAWN_W/2 to R9
    ; — half weight (see GATE_BLOST_BONUS above for rationale).
    RLDI 10, ADV_PAWN_W
    LDN 10
    SHR                 ; D = ADV_PAWN_W / 2
    STR 2
    GLO 9
    ADD                 ; R9.lo += bonus
    PLO 9
    GHI 9
    ADCI 0              ; R9.hi += carry
    PHI 9
GATE_DONE:
    RETN

; Helper: D.bit7 = sign of (R9 - preeg).  R7 = preeg.  Uses COMPARE_TEMP.
; Straight 16-bit subtract; eval scores bounded well within signed-16 in
; the endgame block so the sign is reliable.
GATE_DELTA_SIGN:
    RLDI 10, COMPARE_TEMP
    SEX 10
    GLO 7
    STR 10
    GLO 9
    SM                  ; D = R9.lo - preeg.lo
    GHI 7
    STR 10
    GHI 9
    SMB                 ; D = R9.hi - preeg.hi - borrow (sign of delta)
    SEX 2
    RETN

; ------------------------------------------------------------------------------
; 2026-05-21 — Reclaimed ~135 bytes of dead helpers (zero callers):
;   EVALUATE_MATERIAL (was just LBR EVALUATE, called only from removed EVAL_WITH_PST)
;   EVAL_WITH_PST + EVAL_PST_SCAN + EVAL_PST_NEXT (a TODO stub that called the
;     material eval then scanned the board but never actually applied any PST
;     value — the comment literally said "; TODO: Implement PST lookup and
;     addition". Real PST is computed by EVAL_PST in pst.asm, called from
;     line 804 above.)
;   SQUARE_0x88_TO_0x40 helper (never referenced; 0x88-to-0-63 conversion is
;     inlined where needed)
; ------------------------------------------------------------------------------

; ==============================================================================
; End of Evaluation
; ==============================================================================
