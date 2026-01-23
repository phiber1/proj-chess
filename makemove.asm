; ==============================================================================
; MAKE/UNMAKE MOVE MODULE
; ==============================================================================

; ------------------------------------------------------------------------------
; Undo information - defined in board-0x88.asm as EQUs in RAM ($6408-$640D)
; UNDO_CAPTURED, UNDO_FROM, UNDO_TO, UNDO_CASTLING, UNDO_EP, UNDO_HALFMOVE
; These MUST be in RAM (not ROM) for read/write access!
; ------------------------------------------------------------------------------

; ==============================================================================
; MAKE_MOVE - Apply move to the board
; Input: MOVE_FROM, MOVE_TO contain the move
; Output: Board updated, undo info saved, hash updated
;         D = 0 if success
; ==============================================================================
MAKE_MOVE:
    ; Save undo information
    LDI HIGH(UNDO_FROM)
    PHI 8
    LDI LOW(UNDO_FROM)
    PLO 8

    ; Save from square
    LDI HIGH(MOVE_FROM)
    PHI 9
    LDI LOW(MOVE_FROM)
    PLO 9
    LDN 9
    STR 8
    INC 8
    
    ; Save to square
    INC 9
    LDN 9               ; MOVE_TO
    STR 8
    INC 8
    
    ; Save castling rights from GAME_STATE + STATE_CASTLING
    LDI HIGH(GAME_STATE)
    PHI 9
    LDI LOW(GAME_STATE + STATE_CASTLING)
    PLO 9
    LDN 9
    STR 8
    INC 8

    ; Save en passant square from GAME_STATE + STATE_EP_SQUARE
    INC 9
    LDN 9
    STR 8
    INC 8

    ; Save halfmove clock from GAME_STATE + STATE_HALFMOVE
    INC 9
    LDN 9
    STR 8

    ; Get the piece being moved
    LDI HIGH(BOARD)
    PHI 8
    LDI LOW(BOARD)
    PLO 8
    LDI HIGH(MOVE_FROM)
    PHI 9
    LDI LOW(MOVE_FROM)
    PLO 9
    LDN 9               ; Get from square index
    SEX 2
    STR 2
    GLO 8
    ADD
    PLO 8
    GHI 8
    ADCI 0
    PHI 8
    LDN 8               ; D = piece at from square
    PLO 10              ; Save moving piece in R10.0

    ; Get captured piece at destination
    LDI HIGH(BOARD)
    PHI 8
    LDI LOW(BOARD)
    PLO 8
    LDI HIGH(MOVE_TO)
    PHI 9
    LDI LOW(MOVE_TO)
    PLO 9
    LDN 9               ; Get to square index
    STR 2
    GLO 8
    ADD
    PLO 8
    GHI 8
    ADCI 0
    PHI 8
    LDN 8               ; D = piece at to square (captured)
    
    ; Save captured piece
    PHI 10              ; Save in R10.1
    LDI HIGH(UNDO_CAPTURED)
    PHI 9
    LDI LOW(UNDO_CAPTURED)
    PLO 9
    GHI 10
    STR 9

    ; Place moving piece at destination
    GLO 10              ; Get moving piece
    STR 8               ; Store at to square (R8 still points there)

    ; =========================================
    ; KING POSITION UPDATE
    ; =========================================
    ; If moving piece is a king, update GAME_STATE king position
    ; R10.0 = moving piece
    GLO 10              ; Get moving piece
    ANI PIECE_MASK      ; Get piece type (0-6)
    XRI KING_TYPE       ; Is it a king?
    LBNZ MM_NOT_KING    ; Not a king, skip

    ; It's a king - update king position in GAME_STATE
    ; Check color of king (R10.0 has full piece)
    GLO 10
    ANI COLOR_MASK      ; Get color (0=white, 8=black)
    BNZ MM_BLACK_KING

MM_WHITE_KING:
    ; Update STATE_W_KING_SQ with MOVE_TO
    LDI HIGH(GAME_STATE)
    PHI 9
    LDI LOW(GAME_STATE + STATE_W_KING_SQ)
    PLO 9
    BR MM_STORE_KING

MM_BLACK_KING:
    ; Update STATE_B_KING_SQ with MOVE_TO
    LDI HIGH(GAME_STATE)
    PHI 9
    LDI LOW(GAME_STATE + STATE_B_KING_SQ)
    PLO 9

MM_STORE_KING:
    ; Get MOVE_TO and store as new king square
    LDI HIGH(MOVE_TO)
    PHI 8
    LDI LOW(MOVE_TO)
    PLO 8
    LDN 8               ; D = to square
    STR 9               ; Store as new king position

    ; =========================================
    ; CASTLING RIGHTS UPDATE (king moved)
    ; =========================================
    ; King has moved - clear both castling rights for this color
    ; R10.0 still has moving piece
    GLO 10              ; Get moving piece
    ANI COLOR_MASK      ; Get color (0=white, 8=black)
    BNZ MM_CLEAR_BLACK_CASTLE

MM_CLEAR_WHITE_CASTLE:
    LDI $03             ; CASTLE_WK ($01) + CASTLE_WQ ($02)
    BR MM_DO_CLEAR_CASTLE

MM_CLEAR_BLACK_CASTLE:
    LDI $0C             ; CASTLE_BK ($04) + CASTLE_BQ ($08)

MM_DO_CLEAR_CASTLE:
    CALL CLEAR_CASTLING_RIGHT

MM_NOT_KING:
    ; Clear the from square
    LDI HIGH(BOARD)
    PHI 8
    LDI LOW(BOARD)
    PLO 8
    LDI HIGH(MOVE_FROM)
    PHI 9
    LDI LOW(MOVE_FROM)
    PLO 9
    LDN 9               ; Get from square
    STR 2
    GLO 8
    ADD
    PLO 8
    GHI 8
    ADCI 0
    PHI 8
    LDI EMPTY
    STR 8               ; Clear from square

    ; Toggle side to move
    LDI HIGH(SIDE)
    PHI 8
    LDI LOW(SIDE)
    PLO 8
    LDN 8
    XRI BLACK           ; Toggle between 0 and 8
    STR 8

    ; Clear en passant square (simplified - proper handling later)
    ; R8 is at SIDE ($6080), increment to reach EP_SQUARE ($6082)
    INC 8               ; $6081 = STATE_CASTLING
    INC 8               ; $6082 = STATE_EP_SQUARE
    LDI NO_EP
    STR 8

    ; ===========================================
    ; FIFTY-MOVE RULE: Update halfmove clock
    ; ===========================================
    ; Reset to 0 if: capture or pawn move
    ; Otherwise: increment
    ; R10.0 = moving piece, R10.1 = captured piece

    INC 8               ; Point to HALFMOVE

    ; Check if capture occurred (R10.1 != EMPTY)
    GHI 10              ; Get captured piece
    BNZ MM_RESET_HALFMOVE

    ; Check if pawn moved (piece type == PAWN_TYPE)
    GLO 10              ; Get moving piece
    ANI PIECE_MASK      ; Get piece type
    XRI PAWN_TYPE       ; Is it a pawn?
    BZ MM_RESET_HALFMOVE

    ; No capture, not pawn move - increment halfmove clock
    LDN 8               ; Get current halfmove
    ADI 1               ; Increment
    STR 8               ; Store back
    BR MM_DONE

MM_RESET_HALFMOVE:
    ; Reset halfmove clock to 0
    LDI 0
    STR 8

MM_DONE:
    ; =========================================
    ; HASH UPDATE: XOR piece-square changes
    ; =========================================
    ; HASH_XOR_PIECE_SQ: R8.0 = piece, R8.1 = square
    ; Clobbers: R7, R9, R10, R13. Preserves: R8
    ; After each call, reload from memory (safe, no register deps)

    ; --- Step 1: XOR out [moving piece, from] ---
    ; Get moving piece from BOARD[UNDO_TO]
    LDI HIGH(UNDO_TO)
    PHI 10
    LDI LOW(UNDO_TO)
    PLO 10
    LDN 10              ; D = to_square
    ADI LOW(BOARD)
    PLO 10
    LDI HIGH(BOARD)
    ADCI 0
    PHI 10              ; R10 = &BOARD[to_square]
    LDN 10              ; D = moving piece
    PLO 8               ; R8.0 = moving piece
    ; Get from square
    LDI HIGH(UNDO_FROM)
    PHI 10
    LDI LOW(UNDO_FROM)
    PLO 10
    LDN 10              ; D = from_square
    PHI 8               ; R8.1 = from_square
    CALL HASH_XOR_PIECE_SQ

    ; --- Step 2: XOR out [captured, to] ---
    ; Get captured piece from UNDO_CAPTURED
    LDI HIGH(UNDO_CAPTURED)
    PHI 10
    LDI LOW(UNDO_CAPTURED)
    PLO 10
    LDN 10              ; D = captured piece
    PLO 8               ; R8.0 = captured piece
    ; Get to square
    LDI HIGH(UNDO_TO)
    PHI 10
    LDI LOW(UNDO_TO)
    PLO 10
    LDN 10              ; D = to_square
    PHI 8               ; R8.1 = to_square
    CALL HASH_XOR_PIECE_SQ  ; skips if captured == EMPTY

    ; --- Step 3: XOR in [moving piece, to] ---
    ; Get to square first (need for R8.1 and BOARD index)
    LDI HIGH(UNDO_TO)
    PHI 10
    LDI LOW(UNDO_TO)
    PLO 10
    LDN 10              ; D = to_square
    PHI 8               ; R8.1 = to_square
    ; Compute BOARD[to_square]
    ADI LOW(BOARD)
    PLO 10
    LDI HIGH(BOARD)
    ADCI 0
    PHI 10              ; R10 = &BOARD[to_square]
    LDN 10              ; D = moving piece
    PLO 8               ; R8.0 = moving piece
    CALL HASH_XOR_PIECE_SQ

    ; --- Step 4: XOR side ---
    CALL HASH_XOR_SIDE

    LDI 0               ; Return success
    SEP 5

; ==============================================================================
; UNMAKE_MOVE - Reverse the last move
; Input: Undo info from previous MAKE_MOVE
; Output: Board restored to previous state
; ==============================================================================
UNMAKE_MOVE:
    ; Get moving piece from to square
    LDI HIGH(BOARD)
    PHI 8
    LDI LOW(BOARD)
    PLO 8
    LDI HIGH(UNDO_TO)
    PHI 9
    LDI LOW(UNDO_TO)
    PLO 9
    LDN 9               ; Get to square
    SEX 2
    STR 2
    GLO 8
    ADD
    PLO 8
    GHI 8
    ADCI 0
    PHI 8
    LDN 8               ; D = piece at to square
    PLO 10              ; Save in R10.0

    ; Restore captured piece at to square
    LDI HIGH(UNDO_CAPTURED)
    PHI 9
    LDI LOW(UNDO_CAPTURED)
    PLO 9
    LDN 9               ; Get captured piece
    STR 8               ; Put back at to square

    ; Put moving piece back at from square
    LDI HIGH(BOARD)
    PHI 8
    LDI LOW(BOARD)
    PLO 8
    LDI HIGH(UNDO_FROM)
    PHI 9
    LDI LOW(UNDO_FROM)
    PLO 9
    LDN 9               ; Get from square
    STR 2
    GLO 8
    ADD
    PLO 8
    GHI 8
    ADCI 0
    PHI 8
    GLO 10              ; Get moving piece
    STR 8               ; Put back at from square

    ; =========================================
    ; KING POSITION RESTORE
    ; =========================================
    ; If moving piece is a king, restore GAME_STATE king position to from square
    ; R10.0 = moving piece
    GLO 10              ; Get moving piece
    ANI PIECE_MASK      ; Get piece type (0-6)
    XRI KING_TYPE       ; Is it a king?
    LBNZ UM_NOT_KING    ; Not a king, skip

    ; It's a king - restore king position in GAME_STATE
    ; Check color of king (R10.0 has full piece)
    GLO 10
    ANI COLOR_MASK      ; Get color (0=white, 8=black)
    BNZ UM_BLACK_KING

UM_WHITE_KING:
    ; Update STATE_W_KING_SQ with UNDO_FROM
    LDI HIGH(GAME_STATE)
    PHI 9
    LDI LOW(GAME_STATE + STATE_W_KING_SQ)
    PLO 9
    BR UM_STORE_KING

UM_BLACK_KING:
    ; Update STATE_B_KING_SQ with UNDO_FROM
    LDI HIGH(GAME_STATE)
    PHI 9
    LDI LOW(GAME_STATE + STATE_B_KING_SQ)
    PLO 9

UM_STORE_KING:
    ; Get UNDO_FROM and store as restored king square
    LDI HIGH(UNDO_FROM)
    PHI 8
    LDI LOW(UNDO_FROM)
    PLO 8
    LDN 8               ; D = from square
    STR 9               ; Restore king position

UM_NOT_KING:
    ; Restore castling rights to GAME_STATE + STATE_CASTLING
    LDI HIGH(UNDO_CASTLING)
    PHI 9
    LDI LOW(UNDO_CASTLING)
    PLO 9
    LDN 9
    PHI 10              ; Save in R10.1

    LDI HIGH(GAME_STATE)
    PHI 8
    LDI LOW(GAME_STATE + STATE_CASTLING)
    PLO 8
    GHI 10
    STR 8

    ; Restore en passant square to GAME_STATE + STATE_EP_SQUARE
    LDI HIGH(UNDO_EP)
    PHI 9
    LDI LOW(UNDO_EP)
    PLO 9
    LDN 9
    INC 8               ; Point to EP_SQUARE ($6082)
    STR 8

    ; Restore halfmove clock to GAME_STATE + STATE_HALFMOVE
    LDI HIGH(UNDO_HALFMOVE)
    PHI 9
    LDI LOW(UNDO_HALFMOVE)
    PLO 9
    LDN 9
    INC 8               ; Point to HALFMOVE ($6083)
    STR 8

    ; Toggle side to move back
    LDI HIGH(SIDE)
    PHI 8
    LDI LOW(SIDE)
    PLO 8
    LDN 8
    XRI BLACK           ; Toggle between 0 and 8
    STR 8

    ; =========================================
    ; HASH UPDATE: XOR piece-square changes (reverse of MAKE_MOVE)
    ; =========================================
    ; HASH_XOR_PIECE_SQ: R8.0 = piece, R8.1 = square
    ; Clobbers: R7, R9, R10, R13. Preserves: R8
    ; Board is now restored: piece at UNDO_FROM, captured at UNDO_TO

    ; --- Step 1: XOR out [moving piece, to] ---
    ; Moving piece is now at BOARD[UNDO_FROM]
    LDI HIGH(UNDO_FROM)
    PHI 10
    LDI LOW(UNDO_FROM)
    PLO 10
    LDN 10              ; D = from_square
    ADI LOW(BOARD)
    PLO 10
    LDI HIGH(BOARD)
    ADCI 0
    PHI 10              ; R10 = &BOARD[from_square]
    LDN 10              ; D = moving piece
    PLO 8               ; R8.0 = moving piece
    ; Get to square
    LDI HIGH(UNDO_TO)
    PHI 10
    LDI LOW(UNDO_TO)
    PLO 10
    LDN 10              ; D = to_square
    PHI 8               ; R8.1 = to_square
    CALL HASH_XOR_PIECE_SQ

    ; --- Step 2: XOR in [captured, to] ---
    ; Captured piece is in UNDO_CAPTURED
    LDI HIGH(UNDO_CAPTURED)
    PHI 10
    LDI LOW(UNDO_CAPTURED)
    PLO 10
    LDN 10              ; D = captured piece
    PLO 8               ; R8.0 = captured piece
    ; Get to square
    LDI HIGH(UNDO_TO)
    PHI 10
    LDI LOW(UNDO_TO)
    PLO 10
    LDN 10              ; D = to_square
    PHI 8               ; R8.1 = to_square
    CALL HASH_XOR_PIECE_SQ  ; skips if captured == EMPTY

    ; --- Step 3: XOR in [moving piece, from] ---
    ; Moving piece is at BOARD[UNDO_FROM]
    LDI HIGH(UNDO_FROM)
    PHI 10
    LDI LOW(UNDO_FROM)
    PLO 10
    LDN 10              ; D = from_square
    PHI 8               ; R8.1 = from_square
    ; Compute BOARD[from_square]
    ADI LOW(BOARD)
    PLO 10
    LDI HIGH(BOARD)
    ADCI 0
    PHI 10              ; R10 = &BOARD[from_square]
    LDN 10              ; D = moving piece
    PLO 8               ; R8.0 = moving piece
    CALL HASH_XOR_PIECE_SQ

    ; --- Step 4: XOR side ---
    CALL HASH_XOR_SIDE

    SEP 5

; ==============================================================================
; NULL_MAKE_MOVE - Make a null move (pass - just toggle side)
; ==============================================================================
; Used by null move pruning. No actual piece moves.
; Input: None
; Output: Side toggled, hash updated, EP cleared
; Saves: EP square to NULL_SAVED_EP for unmake
; ==============================================================================
NULL_MAKE_MOVE:
    ; Save EP square to NULL_SAVED_EP
    LDI HIGH(GAME_STATE + STATE_EP_SQUARE)
    PHI 10
    LDI LOW(GAME_STATE + STATE_EP_SQUARE)
    PLO 10
    LDN 10              ; D = current EP square
    PLO 7               ; Save in R7.0
    LDI HIGH(NULL_SAVED_EP)
    PHI 10
    LDI LOW(NULL_SAVED_EP)
    PLO 10
    GLO 7
    STR 10              ; NULL_SAVED_EP = old EP

    ; Clear EP square (no EP after null move)
    LDI HIGH(GAME_STATE + STATE_EP_SQUARE)
    PHI 10
    LDI LOW(GAME_STATE + STATE_EP_SQUARE)
    PLO 10
    LDI $FF             ; Invalid EP
    STR 10

    ; Toggle side to move
    LDI HIGH(GAME_STATE + STATE_SIDE_TO_MOVE)
    PHI 10
    LDI LOW(GAME_STATE + STATE_SIDE_TO_MOVE)
    PLO 10
    LDN 10
    XRI $08             ; Toggle 0 <-> 8
    STR 10

    ; Update hash for side change
    CALL HASH_XOR_SIDE

    RETN

; ==============================================================================
; NULL_UNMAKE_MOVE - Undo a null move
; ==============================================================================
; Restores state from before null move
; Input: None
; Output: Side toggled back, hash restored, EP restored
; ==============================================================================
NULL_UNMAKE_MOVE:
    ; Toggle side back
    LDI HIGH(GAME_STATE + STATE_SIDE_TO_MOVE)
    PHI 10
    LDI LOW(GAME_STATE + STATE_SIDE_TO_MOVE)
    PLO 10
    LDN 10
    XRI $08             ; Toggle 8 <-> 0
    STR 10

    ; Restore EP square from NULL_SAVED_EP
    LDI HIGH(NULL_SAVED_EP)
    PHI 10
    LDI LOW(NULL_SAVED_EP)
    PLO 10
    LDN 10              ; D = saved EP
    PLO 7               ; Save in R7.0
    LDI HIGH(GAME_STATE + STATE_EP_SQUARE)
    PHI 10
    LDI LOW(GAME_STATE + STATE_EP_SQUARE)
    PLO 10
    GLO 7
    STR 10              ; Restore EP

    ; Update hash for side change (XOR again = restore)
    CALL HASH_XOR_SIDE

    RETN

; ==============================================================================
; END OF MAKE/UNMAKE MODULE
; ==============================================================================
