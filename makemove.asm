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
    ; ===========================================
    ; HASH UPDATE: Update Zobrist hash
    ; ===========================================
    ; Read piece info from UNDO_* memory (not stack - CALL clobbers stack!)
    ; HASH_XOR_PIECE_SQ expects: R8.0 = piece, R8.1 = square
    ; HASH_XOR_PIECE_SQ clobbers: R7, R9, R10, R13
    ; Use COMPARE_TEMP to save moving piece (registers get clobbered)

    ; 1. XOR out moving piece from origin square
    ; Read piece from BOARD[UNDO_TO] (where it moved to)
    LDI HIGH(UNDO_TO)
    PHI 9
    LDI LOW(UNDO_TO)
    PLO 9
    LDN 9               ; D = to square
    ADI LOW(BOARD)
    PLO 8
    LDI HIGH(BOARD)
    ADCI 0
    PHI 8               ; R8 = BOARD + to_square
    LDN 8               ; D = moving piece (now at destination)
    PLO 11              ; R11.0 = moving piece (temp save, D about to be clobbered)

    ; Save moving piece to COMPARE_TEMP (R13 gets clobbered by HASH_XOR_PIECE_SQ!)
    LDI HIGH(COMPARE_TEMP)
    PHI 9
    LDI LOW(COMPARE_TEMP)
    PLO 9
    GLO 11              ; D = moving piece
    STR 9               ; COMPARE_TEMP = moving piece

    ; Set up R8 for HASH_XOR_PIECE_SQ: R8.0 = piece, R8.1 = square
    PLO 8               ; R8.0 = moving piece
    LDI HIGH(UNDO_FROM)
    PHI 9
    LDI LOW(UNDO_FROM)
    PLO 9
    LDN 9               ; D = from square
    PHI 8               ; R8.1 = from square
    CALL HASH_XOR_PIECE_SQ

    ; 2. XOR out captured piece from destination (if any)
    LDI HIGH(UNDO_CAPTURED)
    PHI 9
    LDI LOW(UNDO_CAPTURED)
    PLO 9
    LDN 9               ; D = captured piece
    LBZ MM_HASH_NO_CAP  ; Skip if empty (no capture)
    PLO 8               ; R8.0 = captured piece
    LDI HIGH(UNDO_TO)
    PHI 9
    LDI LOW(UNDO_TO)
    PLO 9
    LDN 9               ; D = to square
    PHI 8               ; R8.1 = to square
    CALL HASH_XOR_PIECE_SQ
MM_HASH_NO_CAP:

    ; 3. XOR in moving piece at destination
    ; Reload moving piece from COMPARE_TEMP
    LDI HIGH(COMPARE_TEMP)
    PHI 9
    LDI LOW(COMPARE_TEMP)
    PLO 9
    LDN 9               ; D = moving piece
    PLO 8               ; R8.0 = moving piece
    LDI HIGH(UNDO_TO)
    PHI 9
    LDI LOW(UNDO_TO)
    PLO 9
    LDN 9               ; D = to square
    PHI 8               ; R8.1 = to square
    CALL HASH_XOR_PIECE_SQ

    ; 4. XOR side to move
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

    ; ===========================================
    ; HASH UPDATE: Update Zobrist hash (reverse)
    ; ===========================================
    ; Read piece info from memory (not stack - CALL clobbers stack!)
    ; HASH_XOR_PIECE_SQ clobbers: R7, R9, R10, R13
    ; Use COMPARE_TEMP to save moving piece
    ; Moving piece is now back at BOARD[UNDO_FROM]

    ; Get moving piece from BOARD[UNDO_FROM]
    LDI HIGH(UNDO_FROM)
    PHI 9
    LDI LOW(UNDO_FROM)
    PLO 9
    LDN 9               ; D = from square
    ADI LOW(BOARD)
    PLO 8
    LDI HIGH(BOARD)
    ADCI 0
    PHI 8               ; R8 = BOARD + from_square
    LDN 8               ; D = moving piece (now back at origin)
    PLO 11              ; R11.0 = moving piece (temp save, D about to be clobbered)

    ; Save moving piece to COMPARE_TEMP (R13 gets clobbered!)
    LDI HIGH(COMPARE_TEMP)
    PHI 9
    LDI LOW(COMPARE_TEMP)
    PLO 9
    GLO 11              ; D = moving piece
    STR 9               ; COMPARE_TEMP = moving piece

    ; 1. XOR out moving piece from destination (where it was before unmake)
    PLO 8               ; R8.0 = moving piece
    LDI HIGH(UNDO_TO)
    PHI 9
    LDI LOW(UNDO_TO)
    PLO 9
    LDN 9               ; D = to square
    PHI 8               ; R8.1 = to square
    CALL HASH_XOR_PIECE_SQ

    ; 2. XOR in captured piece at destination (if any)
    LDI HIGH(UNDO_CAPTURED)
    PHI 9
    LDI LOW(UNDO_CAPTURED)
    PLO 9
    LDN 9               ; D = captured piece
    LBZ UM_HASH_NO_CAP  ; Skip if empty
    PLO 8               ; R8.0 = captured piece
    LDI HIGH(UNDO_TO)
    PHI 9
    LDI LOW(UNDO_TO)
    PLO 9
    LDN 9               ; D = to square
    PHI 8               ; R8.1 = to square
    CALL HASH_XOR_PIECE_SQ
UM_HASH_NO_CAP:

    ; 3. XOR in moving piece at origin (where it is now)
    ; Reload moving piece from COMPARE_TEMP
    LDI HIGH(COMPARE_TEMP)
    PHI 9
    LDI LOW(COMPARE_TEMP)
    PLO 9
    LDN 9               ; D = moving piece
    PLO 8               ; R8.0 = moving piece
    LDI HIGH(UNDO_FROM)
    PHI 9
    LDI LOW(UNDO_FROM)
    PLO 9
    LDN 9               ; D = from square
    PHI 8               ; R8.1 = from square
    CALL HASH_XOR_PIECE_SQ

    ; 4. XOR side to move
    CALL HASH_XOR_SIDE

    SEP 5

; ==============================================================================
; END OF MAKE/UNMAKE MODULE
; ==============================================================================
