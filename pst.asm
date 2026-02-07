; ==============================================================================
; RCA 1802/1806 Chess Engine - Piece-Square Tables
; ==============================================================================
; Positional bonuses based on piece placement
; Values in centipawns (signed 8-bit: -128 to +127)
;
; Tables are from White's perspective (flip for Black)
; Total size: 6 tables x 64 squares = 384 bytes
; ==============================================================================

; ------------------------------------------------------------------------------
; PAWN PST - Encourage central pawns and advancement
; ------------------------------------------------------------------------------
; a8 b8 c8 d8 e8 f8 g8 h8  (promotion rank - high values)
; a7 b7 c7 d7 e7 f7 g7 h7  (7th rank - very good)
; ...
; a1 b1 c1 d1 e1 f1 g1 h1  (back rank - pawns shouldn't be here)
; ------------------------------------------------------------------------------
PST_PAWN:
    ; Rank 8 (index 0-7) - pawns promote, but never here in normal play
    DB  0,  0,  0,  0,  0,  0,  0,  0
    ; Rank 7 (index 8-15) - about to promote!
    DB 50, 50, 50, 50, 50, 50, 50, 50
    ; Rank 6 (index 16-23)
    DB 10, 10, 20, 30, 30, 20, 10, 10
    ; Rank 5 (index 24-31)
    DB  5,  5, 10, 25, 25, 10,  5,  5
    ; Rank 4 (index 32-39) - center control
    DB  0,  0,  0, 20, 20,  0,  0,  0
    ; Rank 3 (index 40-47)
    DB  5, -5,-10,  0,  0,-10, -5,  5
    ; Rank 2 (index 48-55) - starting position
    DB  5, 10, 10,-20,-20, 10, 10,  5
    ; Rank 1 (index 56-63) - pawns never here
    DB  0,  0,  0,  0,  0,  0,  0,  0

; ------------------------------------------------------------------------------
; KNIGHT PST - Knights love the center, hate the rim
; ------------------------------------------------------------------------------
PST_KNIGHT:
    ; Rank 8
    DB -50,-40,-30,-30,-30,-30,-40,-50
    ; Rank 7
    DB -40,-20,  0,  0,  0,  0,-20,-40
    ; Rank 6
    DB -30,  0, 10, 15, 15, 10,  0,-30
    ; Rank 5
    DB -30,  5, 15, 20, 20, 15,  5,-30
    ; Rank 4
    DB -30,  0, 15, 20, 20, 15,  0,-30
    ; Rank 3
    DB -30,  5, 10, 15, 15, 10,  5,-30
    ; Rank 2
    DB -40,-20,  0,  5,  5,  0,-20,-40
    ; Rank 1
    DB -50,-40,-30,-30,-30,-30,-40,-50

; ------------------------------------------------------------------------------
; BISHOP PST - Avoid corners, prefer long diagonals
; ------------------------------------------------------------------------------
PST_BISHOP:
    ; Rank 8
    DB -20,-10,-10,-10,-10,-10,-10,-20
    ; Rank 7
    DB -10,  0,  0,  0,  0,  0,  0,-10
    ; Rank 6
    DB -10,  0,  5, 10, 10,  5,  0,-10
    ; Rank 5
    DB -10,  5,  5, 10, 10,  5,  5,-10
    ; Rank 4
    DB -10,  0, 10, 10, 10, 10,  0,-10
    ; Rank 3
    DB -10, 10, 10, 10, 10, 10, 10,-10
    ; Rank 2
    DB -10,  5,  0,  0,  0,  0,  5,-10
    ; Rank 1
    DB -20,-10,-10,-10,-10,-10,-10,-20

; ------------------------------------------------------------------------------
; ROOK PST - 7th rank is golden, open files later
; ------------------------------------------------------------------------------
PST_ROOK:
    ; Rank 8
    DB  0,  0,  0,  0,  0,  0,  0,  0
    ; Rank 7 - "pig" on 7th rank
    DB  5, 10, 10, 10, 10, 10, 10,  5
    ; Rank 6
    DB -5,  0,  0,  0,  0,  0,  0, -5
    ; Rank 5
    DB -5,  0,  0,  0,  0,  0,  0, -5
    ; Rank 4
    DB -5,  0,  0,  0,  0,  0,  0, -5
    ; Rank 3
    DB -5,  0,  0,  0,  0,  0,  0, -5
    ; Rank 2
    DB -5,  0,  0,  0,  0,  0,  0, -5
    ; Rank 1 - penalize undeveloped corner rooks, prefer central
    DB -15,  0,  0,  5,  5,  0,  0,-15

; ------------------------------------------------------------------------------
; QUEEN PST - Slight preference for center, avoid early development
; ------------------------------------------------------------------------------
PST_QUEEN:
    ; Rank 8 - heavy penalty for deep queen raids
    DB -30,-20,-20,-10,-10,-20,-20,-30
    ; Rank 7 - penalize edge squares in enemy territory
    DB -20,-10,  0,  0,  0,  0,-10,-20
    ; Rank 6
    DB -10,  0,  5,  5,  5,  5,  0,-10
    ; Rank 5
    DB  -5,  0,  5,  5,  5,  5,  0, -5
    ; Rank 4
    DB   0,  0,  5,  5,  5,  5,  0, -5
    ; Rank 3
    DB -10,  5,  5,  5,  5,  5,  0,-10
    ; Rank 2
    DB -10,  0,  5,  0,  0,  0,  0,-10
    ; Rank 1 - starting position OK
    DB -20,-10,-10, -5, -5,-10,-10,-20

; ------------------------------------------------------------------------------
; KING PST (Middlegame) - Castle! Stay safe on the side
; ------------------------------------------------------------------------------
PST_KING:
    ; Rank 8 (black's back rank - castled positions good)
    DB -30,-40,-40,-50,-50,-40,-40,-30
    ; Rank 7
    DB -30,-40,-40,-50,-50,-40,-40,-30
    ; Rank 6
    DB -30,-40,-40,-50,-50,-40,-40,-30
    ; Rank 5
    DB -30,-40,-40,-50,-50,-40,-40,-30
    ; Rank 4
    DB -20,-30,-30,-40,-40,-30,-30,-20
    ; Rank 3
    DB -10,-20,-20,-20,-20,-20,-20,-10
    ; Rank 2
    DB  20, 20,  0,  0,  0,  0, 20, 20
    ; Rank 1 - castled king is safest (b1/g1 = strong castling bonus)
    DB  20, 40, 10,  0,  0, 10, 40, 20

; ==============================================================================
; PST Table Address Lookup
; ==============================================================================
; Index by piece type (1-6) to get table address
PST_TABLE_LO:
    DB 0                    ; 0 = empty (unused)
    DB LOW(PST_PAWN)        ; 1 = pawn
    DB LOW(PST_KNIGHT)      ; 2 = knight
    DB LOW(PST_BISHOP)      ; 3 = bishop
    DB LOW(PST_ROOK)        ; 4 = rook
    DB LOW(PST_QUEEN)       ; 5 = queen
    DB LOW(PST_KING)        ; 6 = king

PST_TABLE_HI:
    DB 0
    DB HIGH(PST_PAWN)
    DB HIGH(PST_KNIGHT)
    DB HIGH(PST_BISHOP)
    DB HIGH(PST_ROOK)
    DB HIGH(PST_QUEEN)
    DB HIGH(PST_KING)

; ==============================================================================
; EVAL_PST - Add piece-square table bonuses to score
; ==============================================================================
; Input:  6 = current score (material)
; Output: 6 = score + PST bonuses
; Uses:   A, D, E, F
;
; Algorithm:
;   For each piece on board:
;     1. Get piece type and color
;     2. Convert 0x88 square to 0-63 index
;     3. For black pieces, flip the rank (mirror vertically)
;     4. Look up PST value
;     5. Add (white) or subtract (black) from score
; ==============================================================================
EVAL_PST:
    ; Ensure X=2 for all stack operations
    SEX 2

    ; Save score (R9 is score accumulator, NOT R6 which is SCRT linkage!)
    GLO 9
    STXD
    GHI 9
    STXD

    ; Save R15 (used by caller for move count in quiescence search)
    GLO 15
    STXD
    GHI 15
    STXD

    ; Initialize PST accumulator
    LDI 0
    PHI 7
    PLO 7               ; 7 = 0

    ; Point to board
    LDI HIGH(BOARD)
    PHI 10
    LDI LOW(BOARD)
    PLO 10

    ; Loop counter in memory (R14 is off-limits - BIOS uses it!)
    LDI HIGH(EVAL_TEMP1)
    PHI 8
    LDI LOW(EVAL_TEMP1)
    PLO 8
    LDI 0
    STR 8               ; EVAL_TEMP1 = 0 (square index)

EVAL_PST_LOOP:
    ; Check if valid square (load from memory)
    LDI HIGH(EVAL_TEMP1)
    PHI 8
    LDI LOW(EVAL_TEMP1)
    PLO 8
    LDN 8               ; D = square index
    ANI $88
    LBNZ EVAL_PST_NEXT_SQ

    ; Load piece
    LDN 10
    LBZ EVAL_PST_NEXT_SQ ; Empty square

    ; Save piece
    PLO 15               ; F.0 = piece

    ; Get piece type
    ANI PIECE_MASK
    PLO 13               ; D.0 = piece type (1-6)

    ; Get PST table address for this piece type
    LDI HIGH(PST_TABLE_LO)
    PHI 11
    LDI LOW(PST_TABLE_LO)
    PLO 11
    GLO 13               ; Piece type
    STR 2
    GLO 11
    ADD
    PLO 11
    LDN 11               ; D = low byte of PST address
    PHI 13               ; Save in D.1 temporarily

    LDI HIGH(PST_TABLE_HI)
    PHI 11
    LDI LOW(PST_TABLE_HI)
    PLO 11
    GLO 13               ; Piece type (still in D.0? No, need to reload)
    GLO 15               ; Get piece back
    ANI PIECE_MASK
    STR 2
    GLO 11
    ADD
    PLO 11
    LDN 11               ; High byte of PST address
    PHI 11
    GHI 13               ; Low byte (saved earlier)
    PLO 11               ; B = PST table base for this piece

    ; Convert 0x88 square to 0-63 index
    ; Index = (rank * 8) + file
    ; For 0x88: rank = sq >> 4, file = sq & 7
    ; Load square from memory (R14 is off-limits!)
    LDI HIGH(EVAL_TEMP1)
    PHI 8
    LDI LOW(EVAL_TEMP1)
    PLO 8
    LDN 8               ; D = square (0x88 format)
    STXD                ; Save square on stack for reuse
    ANI $07             ; File (0-7)
    PLO 13               ; D.0 = file

    IRX
    LDX                 ; D = square again
    ANI $70             ; Rank * 16
    SHR                 ; Rank * 8
    STR 2
    GLO 13
    ADD                 ; Index = rank*8 + file
    PLO 13               ; D.0 = 0-63 index

    ; For black pieces, flip the index (mirror board)
    ; New index = 63 - index = (7-rank)*8 + (7-file)
    ; Simpler: XOR with $38 flips rank (keeps file same within rank)
    GLO 15               ; Get piece
    ANI COLOR_MASK
    BZ EVAL_PST_WHITE

    ; Black piece - flip rank
    GLO 13
    XRI $38             ; Flip rank bits
    PLO 13

EVAL_PST_WHITE:
    ; Look up PST value
    GLO 13               ; Index
    STR 2
    GLO 11
    ADD
    PLO 11
    GHI 11
    ADCI 0
    PHI 11
    LDN 11               ; D = PST value (signed 8-bit)

    ; Extend sign to 16-bit
    PLO 13               ; D.0 = PST value
    ANI $80             ; Check sign bit
    LBZ EVAL_PST_POSITIVE
    LDI $FF
    PHI 13               ; D = sign-extended negative
    LBR EVAL_PST_ADD

EVAL_PST_POSITIVE:
    LDI 0
    PHI 13               ; D = sign-extended positive

EVAL_PST_ADD:
    ; Add or subtract based on color
    GLO 15               ; Get piece
    ANI COLOR_MASK
    LBZ EVAL_PST_ADD_WHITE

    ; Black - subtract from accumulator (7 = 7 - D)
    ; Actually: negate D, then add
    GLO 13
    SDI 0               ; D.0 = -D.0
    PLO 13
    GHI 13
    SDBI 0              ; D.1 = -D.1 - borrow
    PHI 13

EVAL_PST_ADD_WHITE:
    ; Add D to accumulator (7)
    GLO 13
    STR 2
    GLO 7
    ADD
    PLO 7

    GHI 13
    STR 2
    GHI 7
    ADC
    PHI 7

EVAL_PST_NEXT_SQ:
    INC 10               ; Next board position
    ; Increment square index in memory (R14 is off-limits!)
    LDI HIGH(EVAL_TEMP1)
    PHI 8
    LDI LOW(EVAL_TEMP1)
    PLO 8
    LDN 8               ; D = square index
    ADI 1               ; Increment
    STR 8               ; Store back
    XRI $80             ; Done when index = 128
    LBNZ EVAL_PST_LOOP

    ; Add PST accumulator to score
    ; Restore R15 first (LIFO - it was pushed last)
    IRX
    LDXA
    PHI 15
    LDX
    PLO 15

    ; Now restore material score (R9)
    IRX
    LDXA
    PHI 9
    LDX
    PLO 9

    ; R9 = R9 + R7
    GLO 7
    STR 2
    GLO 9
    ADD
    PLO 9

    GHI 7
    STR 2
    GHI 9
    ADC
    PHI 9

    RETN

; ==============================================================================
; End of Piece-Square Tables
; ==============================================================================
