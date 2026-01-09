; ==============================================================================
; TRANSPOSITION TABLE FUNCTIONS
; ==============================================================================
; Provides Zobrist hashing and transposition table lookup/store.
;
; Functions:
;   HASH_INIT   - Compute full hash from current board position
;   TT_CLEAR    - Clear all TT entries
;   TT_PROBE    - Look up position in TT
;   TT_STORE    - Store position result in TT
;
; Hash is updated incrementally by MAKE_MOVE/UNMAKE_MOVE (in makemove.asm)
; ==============================================================================

; ==============================================================================
; HASH_INIT - Compute Zobrist hash from current board position
; ==============================================================================
; Scans the board and XORs all piece-square keys, plus side/castling/EP.
; Result stored in HASH_HI/HASH_LO.
;
; Uses: R7 (hash accumulator), R8 (temp), R9 (square counter), R10 (pointer)
; ==============================================================================
HASH_INIT:
    ; Initialize hash to zero
    LDI 0
    PHI 7
    PLO 7               ; R7 = 0 (hash accumulator)

    ; Scan all 64 valid squares (0x88 format)
    LDI 0
    PLO 9               ; R9.0 = square index (0x88 format)

HASH_INIT_LOOP:
    ; Check if square is valid (not off-board)
    GLO 9
    ANI $88
    LBNZ HASH_INIT_NEXT_SQ  ; Off-board, skip

    ; Get piece at this square
    LDI HIGH(BOARD)
    PHI 10
    GLO 9
    PLO 10              ; R10 = BOARD + square
    LDN 10              ; D = piece at square
    LBZ HASH_INIT_NEXT_SQ   ; Empty square, skip

    ; Have a piece - compute Zobrist key offset
    ; piece_index = (piece & 7) - 1 for white, + 6 for black
    ; Piece encoding: 1-6 = white P/N/B/R/Q/K, 9-14 = black
    PLO 8               ; R8.0 = piece
    ANI $07             ; D = piece type (1-6)
    SMI 1               ; D = piece_type - 1 (0-5)
    PLO 13              ; R13.0 = piece index base

    GLO 8               ; Get piece again
    ANI $08             ; Check color bit
    LBZ HASH_INIT_WHITE
    ; Black piece - add 6 to index
    GLO 13
    ADI 6
    PLO 13
HASH_INIT_WHITE:

    ; Now compute square index (0-63 from 0x88)
    ; sq64 = (sq88 >> 4) * 8 + (sq88 & 7) = rank*8 + file
    GLO 9               ; 0x88 square
    ANI $07             ; D = file (0-7)
    PLO 8               ; R8.0 = file
    GLO 9
    ANI $70             ; D = rank * 16 (masked)
    SHR                 ; D = rank * 8
    STR 2               ; Save rank*8
    GLO 8               ; D = file
    ADD                 ; D = rank*8 + file = sq64
    PLO 8               ; R8.0 = sq64 (0-63)

    ; Compute Zobrist table offset:
    ; offset = piece_index * 128 + sq64 * 2
    ; R13.0 = piece_index (0-11)
    ; R8.0 = sq64 (0-63)

    ; First: piece_index * 128 = piece_index << 7
    ; Since piece_index is 0-11, result fits in 16 bits
    GLO 13              ; piece_index (0-11)
    SHL                 ; x2
    SHL                 ; x4
    SHL                 ; x8
    SHL                 ; x16
    SHL                 ; x32
    SHL                 ; x64
    PHI 8               ; R8.1 = (piece_index * 64) = high part of offset
    LDI 0
    LSNF                ; Skip if no carry from last SHL
    LDI 1               ; Carry into high byte
    ; Actually, piece_index * 128: need one more shift
    ; Let me reconsider: piece * 128 = piece << 7
    ; For piece=11: 11 << 7 = 1408 = $580
    ; High byte = piece >> 1, low byte = (piece & 1) << 7

    ; Restart: piece_index * 128
    GLO 13              ; piece_index (0-11)
    SHR                 ; D = piece_index >> 1
    PHI 8               ; R8.1 = high byte of piece*128
    GLO 13
    ANI $01             ; D = piece_index & 1
    LBZ HASH_INIT_EVEN_PIECE
    LDI $80
    LBR HASH_INIT_ADD_SQ
HASH_INIT_EVEN_PIECE:
    LDI 0
HASH_INIT_ADD_SQ:
    ; D = low byte of piece*128 (0 or $80)
    ; Now add sq64 * 2
    PLO 13              ; R13.0 = temp low
    GLO 8               ; sq64
    SHL                 ; sq64 * 2
    STR 2
    GLO 13
    ADD                 ; D = low + sq*2
    PLO 13              ; R13.0 = offset low
    GHI 8               ; high byte of piece*128
    ADCI 0              ; add carry
    PHI 13              ; R13.1 = offset high

    ; Now add ZOBRIST_PIECE_SQ base address
    GLO 13
    ADI LOW(ZOBRIST_PIECE_SQ)
    PLO 10
    GHI 13
    ADCI HIGH(ZOBRIST_PIECE_SQ)
    PHI 10              ; R10 = address of Zobrist key

    ; XOR the 16-bit key into hash (R7)
    LDA 10              ; High byte of key
    STR 2
    GHI 7
    XOR
    PHI 7               ; hash_hi ^= key_hi
    LDN 10              ; Low byte of key
    STR 2
    GLO 7
    XOR
    PLO 7               ; hash_lo ^= key_lo

HASH_INIT_NEXT_SQ:
    ; Next square
    INC 9               ; R9.0++
    GLO 9
    XRI $80             ; Check if we've passed square $7F
    LBNZ HASH_INIT_LOOP

    ; Done with pieces. Now XOR side to move.
    LDI HIGH(GAME_STATE)
    PHI 10
    LDI LOW(GAME_STATE)
    PLO 10
    LDN 10              ; D = side to move (0=white, 8=black)
    LBZ HASH_SIDE_DONE
    ; Black to move - XOR side key
    LDI HIGH(ZOBRIST_SIDE)
    PHI 10
    LDI LOW(ZOBRIST_SIDE)
    PLO 10
    LDA 10
    STR 2
    GHI 7
    XOR
    PHI 7
    LDN 10
    STR 2
    GLO 7
    XOR
    PLO 7
HASH_SIDE_DONE:

    ; XOR castling rights
    ; Castling is at GAME_STATE + STATE_CASTLING ($6081)
    LDI HIGH(GAME_STATE)
    PHI 10
    LDI LOW(GAME_STATE + STATE_CASTLING)
    PLO 10
    LDN 10              ; D = castling rights
    PLO 9               ; R9.0 = castling bits

    ; Check each castling bit
    ; White kingside (bit 0)
    GLO 9
    ANI CASTLE_WK
    LBZ HASH_NO_WK
    CALL HASH_XOR_CASTLE_0
HASH_NO_WK:
    ; White queenside (bit 1)
    GLO 9
    ANI CASTLE_WQ
    LBZ HASH_NO_WQ
    CALL HASH_XOR_CASTLE_1
HASH_NO_WQ:
    ; Black kingside (bit 2)
    GLO 9
    ANI CASTLE_BK
    LBZ HASH_NO_BK
    CALL HASH_XOR_CASTLE_2
HASH_NO_BK:
    ; Black queenside (bit 3)
    GLO 9
    ANI CASTLE_BQ
    LBZ HASH_NO_BQ
    CALL HASH_XOR_CASTLE_3
HASH_NO_BQ:

    ; XOR en passant file if set
    LDI HIGH(GAME_STATE)
    PHI 10
    LDI LOW(GAME_STATE)
    PLO 10
    INC 10
    INC 10              ; Point to EP square
    LDN 10              ; D = EP square ($FF if none)
    XRI $FF
    LBZ HASH_NO_EP      ; No EP square
    ; Have EP - get file (bits 0-2 of 0x88 square)
    LDN 10
    ANI $07             ; D = file (0-7)
    SHL                 ; D = file * 2 (offset into ZOBRIST_EP)
    ADI LOW(ZOBRIST_EP)
    PLO 10
    LDI HIGH(ZOBRIST_EP)
    ADCI 0
    PHI 10              ; R10 = address of EP file key
    LDA 10
    STR 2
    GHI 7
    XOR
    PHI 7
    LDN 10
    STR 2
    GLO 7
    XOR
    PLO 7
HASH_NO_EP:

    ; Store final hash
    LDI HIGH(HASH_HI)
    PHI 10
    LDI LOW(HASH_HI)
    PLO 10
    GHI 7
    STR 10
    INC 10
    GLO 7
    STR 10

    RETN

; Helper functions to XOR castling keys (avoids code duplication)
HASH_XOR_CASTLE_0:
    LDI HIGH(ZOBRIST_CASTLE)
    PHI 10
    LDI LOW(ZOBRIST_CASTLE)
    PLO 10
    LBR HASH_XOR_CASTLE_DO
HASH_XOR_CASTLE_1:
    LDI HIGH(ZOBRIST_CASTLE)
    PHI 10
    LDI LOW(ZOBRIST_CASTLE)
    PLO 10
    INC 10
    INC 10
    LBR HASH_XOR_CASTLE_DO
HASH_XOR_CASTLE_2:
    LDI HIGH(ZOBRIST_CASTLE)
    PHI 10
    LDI LOW(ZOBRIST_CASTLE)
    PLO 10
    INC 10
    INC 10
    INC 10
    INC 10
    LBR HASH_XOR_CASTLE_DO
HASH_XOR_CASTLE_3:
    LDI HIGH(ZOBRIST_CASTLE)
    PHI 10
    LDI LOW(ZOBRIST_CASTLE)
    PLO 10
    INC 10
    INC 10
    INC 10
    INC 10
    INC 10
    INC 10
HASH_XOR_CASTLE_DO:
    LDA 10
    STR 2
    GHI 7
    XOR
    PHI 7
    LDN 10
    STR 2
    GLO 7
    XOR
    PLO 7
    RETN

; ==============================================================================
; TT_CLEAR - Clear all transposition table entries
; ==============================================================================
; Sets all TT entries to flag=TT_FLAG_NONE (0)
; Should be called at start of new game or new position.
;
; Uses: R9 (counter), R10 (pointer)
; ==============================================================================
TT_CLEAR:
    LDI HIGH(TT_TABLE)
    PHI 10
    LDI LOW(TT_TABLE)
    PLO 10              ; R10 = TT_TABLE

    ; Clear 256 entries × 8 bytes = 2048 bytes
    ; Use R9 as 16-bit counter
    LDI HIGH(TT_ENTRIES * TT_ENTRY_SIZE)
    PHI 9
    LDI LOW(TT_ENTRIES * TT_ENTRY_SIZE)
    PLO 9               ; R9 = 2048

    LDI 0               ; Value to write
TT_CLEAR_LOOP:
    STR 10
    INC 10
    DEC 9
    GHI 9
    LBNZ TT_CLEAR_LOOP
    GLO 9
    LBNZ TT_CLEAR_LOOP

    RETN

; ==============================================================================
; TT_PROBE - Look up current position in transposition table
; ==============================================================================
; Checks if current position (HASH_HI/LO) exists in TT.
; If found and depth >= required, copies entry data to TT_* variables.
;
; Input:  D = required depth
; Output: D = 1 if usable hit, 0 if miss
;         If hit: TT_SCORE, TT_DEPTH, TT_FLAG, TT_MOVE populated
;
; Uses: R7 (hash), R8 (required depth), R10 (pointer)
; ==============================================================================
TT_PROBE:
    PLO 8               ; R8.0 = required depth

    ; Load current hash
    LDI HIGH(HASH_HI)
    PHI 10
    LDI LOW(HASH_HI)
    PLO 10
    LDA 10
    PHI 7
    LDN 10
    PLO 7               ; R7 = current hash

    ; Calculate TT entry address: TT_TABLE + (hash_lo * 8)
    ; Since TT_ENTRY_SIZE = 8, multiply by 8 (shift left 3)
    GLO 7               ; hash_lo
    ANI TT_INDEX_MASK   ; Mask to table size
    SHL                 ; x2
    SHL                 ; x4
    SHL                 ; x8
    PLO 10              ; Low byte of offset
    LDI 0
    ADCI 0              ; Handle carry from shifts
    ; Actually need to handle this more carefully
    ; hash_lo * 8: max $FF * 8 = $7F8
    ; Need 16-bit result

    ; Redo: hash_lo * 8
    GLO 7               ; hash_lo
    ANI TT_INDEX_MASK
    PLO 9               ; Save masked index
    SHL                 ; x2, carry into DF
    PLO 10
    LDI 0
    SHLC                ; Shift carry into D
    PHI 10              ; R10.1 = high byte so far
    GLO 10
    SHL                 ; x4
    PLO 10
    GHI 10
    SHLC
    PHI 10
    GLO 10
    SHL                 ; x8
    PLO 10
    GHI 10
    SHLC
    PHI 10              ; R10 = index * 8

    ; Add TT_TABLE base
    GLO 10
    ADI LOW(TT_TABLE)
    PLO 10
    GHI 10
    ADCI HIGH(TT_TABLE)
    PHI 10              ; R10 = TT entry address

    ; Check if entry matches (compare stored hash with current)
    LDA 10              ; Entry hash_hi
    STR 2
    GHI 7
    XOR
    LBNZ TT_PROBE_MISS
    LDA 10              ; Entry hash_lo
    STR 2
    GLO 7
    XOR
    LBNZ TT_PROBE_MISS

    ; Hash matches! Check depth
    ; R10 now points to score_hi (offset 2)
    INC 10
    INC 10              ; Skip score, point to depth (offset 4)
    LDN 10              ; Entry depth
    STR 2
    GLO 8               ; Required depth
    SD                  ; D = entry_depth - required_depth
    LBNF TT_PROBE_MISS  ; Borrow means entry_depth < required

    ; Usable hit! Copy entry data to TT_* variables
    ; Back up to start of entry
    DEC 10
    DEC 10
    DEC 10
    DEC 10              ; R10 at entry start

    ; Copy to TT result variables
    LDI HIGH(TT_SCORE_HI)
    PHI 9
    LDI LOW(TT_SCORE_HI)
    PLO 9

    INC 10
    INC 10              ; Skip hash verification bytes
    LDA 10              ; score_hi
    STR 9
    INC 9
    LDA 10              ; score_lo
    STR 9
    INC 9
    LDA 10              ; depth
    STR 9
    INC 9
    LDA 10              ; flag
    STR 9
    INC 9
    LDA 10              ; move_hi
    STR 9
    INC 9
    LDN 10              ; move_lo
    STR 9

    ; Set TT_HIT = 1
    LDI HIGH(TT_HIT)
    PHI 10
    LDI LOW(TT_HIT)
    PLO 10
    LDI 1
    STR 10

    LDI 1               ; Return hit
    RETN

TT_PROBE_MISS:
    ; Set TT_HIT = 0
    LDI HIGH(TT_HIT)
    PHI 10
    LDI LOW(TT_HIT)
    PLO 10
    LDI 0
    STR 10

    LDI 0               ; Return miss
    RETN

; ==============================================================================
; TT_STORE - Store position result in transposition table
; ==============================================================================
; Stores current position with score, depth, flag, and best move.
; Always replaces existing entry (replace-always scheme).
;
; Input:  Stack contains (push order): score_hi, score_lo, depth, flag
;         BEST_MOVE contains best move
; Actually, let's use memory variables for simplicity:
;         SCORE_HI/LO = score to store
;         D = depth
;         R8.0 = flag
;
; Uses: R7 (hash), R9 (temp), R10 (pointer)
; ==============================================================================
TT_STORE:
    ; Save depth and flag
    STXD                ; Push depth
    GLO 8
    STXD                ; Push flag

    ; Load current hash
    LDI HIGH(HASH_HI)
    PHI 10
    LDI LOW(HASH_HI)
    PLO 10
    LDA 10
    PHI 7
    LDN 10
    PLO 7               ; R7 = current hash

    ; Calculate TT entry address: TT_TABLE + (hash_lo * 8)
    GLO 7
    ANI TT_INDEX_MASK
    SHL                 ; x2
    PLO 10
    LDI 0
    SHLC
    PHI 10
    GLO 10
    SHL                 ; x4
    PLO 10
    GHI 10
    SHLC
    PHI 10
    GLO 10
    SHL                 ; x8
    PLO 10
    GHI 10
    SHLC
    PHI 10              ; R10 = index * 8

    ; Add TT_TABLE base
    GLO 10
    ADI LOW(TT_TABLE)
    PLO 10
    GHI 10
    ADCI HIGH(TT_TABLE)
    PHI 10              ; R10 = TT entry address

    ; Write entry
    GHI 7               ; hash_hi
    STR 10
    INC 10
    GLO 7               ; hash_lo
    STR 10
    INC 10

    ; Score from SCORE_HI/LO
    LDI HIGH(SCORE_HI)
    PHI 9
    LDI LOW(SCORE_HI)
    PLO 9
    LDA 9               ; score_hi
    STR 10
    INC 10
    LDN 9               ; score_lo
    STR 10
    INC 10

    ; Depth and flag from stack
    IRX
    LDXA                ; flag
    PLO 8               ; Save temporarily
    LDX                 ; depth
    STR 10
    INC 10
    GLO 8               ; flag
    STR 10
    INC 10

    ; Best move from BEST_MOVE
    LDI HIGH(BEST_MOVE)
    PHI 9
    LDI LOW(BEST_MOVE)
    PLO 9
    LDA 9               ; move_hi
    STR 10
    INC 10
    LDN 9               ; move_lo
    STR 10

    RETN

; ==============================================================================
; HASH_XOR_PIECE_SQ - XOR piece-square key into current hash
; ==============================================================================
; Used for incremental hash updates in MAKE_MOVE/UNMAKE_MOVE.
;
; Input:  R8.0 = piece (1-6 white, 9-14 black, or EMPTY=0 for no-op)
;         R8.1 = square (0x88 format)
; Output: HASH_HI/LO updated
; Uses:   R7, R9, R10, R13
; ==============================================================================
HASH_XOR_PIECE_SQ:
    ; Skip if piece is EMPTY
    GLO 8
    LBZ HXPS_DONE

    ; Load current hash into R7
    LDI HIGH(HASH_HI)
    PHI 10
    LDI LOW(HASH_HI)
    PLO 10
    LDA 10
    PHI 7
    LDN 10
    PLO 7               ; R7 = current hash

    ; Compute piece index (0-11)
    ; piece_index = (piece & 7) - 1 for white, + 6 for black
    GLO 8               ; piece
    ANI $07             ; piece type (1-6)
    SMI 1               ; piece_type - 1 (0-5)
    PLO 13              ; R13.0 = base index

    GLO 8               ; piece again
    ANI $08             ; color bit
    LBZ HXPS_WHITE
    ; Black - add 6
    GLO 13
    ADI 6
    PLO 13
HXPS_WHITE:

    ; Compute square index (0-63 from 0x88)
    ; sq64 = (sq88 >> 4) * 8 + (sq88 & 7)
    GHI 8               ; 0x88 square
    ANI $07             ; file
    PLO 9               ; R9.0 = file
    GHI 8
    ANI $70             ; rank * 16
    SHR                 ; rank * 8
    PLO 7               ; R7.0 = rank*8 (temp, don't use STR 2 - corrupts stack!)
    GLO 9               ; file
    STR 2               ; OK to use stack briefly here
    GLO 7               ; rank*8
    ADD                 ; rank*8 + file = sq64
    PLO 9               ; R9.0 = sq64

    ; Compute Zobrist offset: piece_index * 128 + sq64 * 2
    ; piece * 128: high = piece >> 1, low = (piece & 1) << 7
    GLO 13              ; piece_index
    SHR                 ; piece >> 1
    PHI 13              ; R13.1 = high byte of piece*128
    GLO 13
    SHL                 ; Restore, then check bit 0
    SHR                 ; Back to original
    ANI $01
    LBZ HXPS_EVEN
    LDI $80
    LBR HXPS_ADD_SQ
HXPS_EVEN:
    LDI 0
HXPS_ADD_SQ:
    ; D = low byte of piece*128 (0 or $80)
    PLO 10              ; R10.0 = temp low
    GLO 9               ; sq64
    SHL                 ; sq64 * 2
    STR 2
    GLO 10
    ADD                 ; low + sq*2
    PLO 10
    GHI 13              ; high of piece*128
    ADCI 0
    PHI 10              ; R10 = offset

    ; Add ZOBRIST_PIECE_SQ base
    GLO 10
    ADI LOW(ZOBRIST_PIECE_SQ)
    PLO 10
    GHI 10
    ADCI HIGH(ZOBRIST_PIECE_SQ)
    PHI 10              ; R10 = key address

    ; XOR key into hash
    LDA 10              ; key_hi
    STR 2
    GHI 7
    XOR
    PHI 7
    LDN 10              ; key_lo
    STR 2
    GLO 7
    XOR
    PLO 7

    ; Store updated hash
    LDI HIGH(HASH_HI)
    PHI 10
    LDI LOW(HASH_HI)
    PLO 10
    GHI 7
    STR 10
    INC 10
    GLO 7
    STR 10

HXPS_DONE:
    RETN

; ==============================================================================
; HASH_XOR_SIDE - Toggle side-to-move in hash
; ==============================================================================
; Called after every move to flip the side-to-move bit in the hash.
;
; Uses: R7, R10
; ==============================================================================
HASH_XOR_SIDE:
    ; Load current hash
    LDI HIGH(HASH_HI)
    PHI 10
    LDI LOW(HASH_HI)
    PLO 10
    LDA 10
    PHI 7
    LDN 10
    PLO 7               ; R7 = current hash

    ; XOR with side key
    LDI HIGH(ZOBRIST_SIDE)
    PHI 10
    LDI LOW(ZOBRIST_SIDE)
    PLO 10
    LDA 10              ; key_hi
    STR 2
    GHI 7
    XOR
    PHI 7
    LDN 10              ; key_lo
    STR 2
    GLO 7
    XOR
    PLO 7

    ; Store updated hash
    LDI HIGH(HASH_HI)
    PHI 10
    LDI LOW(HASH_HI)
    PLO 10
    GHI 7
    STR 10
    INC 10
    GLO 7
    STR 10

    RETN
