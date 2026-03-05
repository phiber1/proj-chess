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
    RLDI 8, UNDO_FROM

    ; Save from square
    RLDI 9, MOVE_FROM
    LDN 9
    STR 8
    INC 8
    
    ; Save to square
    INC 9
    LDN 9               ; MOVE_TO
    STR 8
    INC 8
    
    ; Save castling rights from GAME_STATE + STATE_CASTLING
    RLDI 9, GAME_STATE + STATE_CASTLING
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
    RLDI 9, MOVE_FROM
    LDN 9               ; D = from square index
    PLO 8
    LDI HIGH(BOARD)
    PHI 8               ; R8 = &BOARD[from]
    LDN 8               ; D = piece at from square
    PLO 10              ; Save moving piece in R10.0

    ; Get captured piece at destination
    RLDI 9, MOVE_TO
    LDN 9               ; D = to square index
    PLO 8
    LDI HIGH(BOARD)
    PHI 8               ; R8 = &BOARD[to]
    LDN 8               ; D = piece at to square (captured)
    
    ; Save captured piece
    PHI 10              ; Save in R10.1
    RLDI 9, UNDO_CAPTURED
    GHI 10
    STR 9

    ; Save capture square (default = to, changed by EP)
    RLDI 9, UNDO_CAP_SQ
    RLDI 13, UNDO_TO
    LDN 13
    STR 9               ; UNDO_CAP_SQ = MOVE_TO (default)

    ; Place moving piece at destination
    GLO 10              ; Get moving piece
    STR 8               ; Store at to square (R8 still points there)

    ; =========================================
    ; EN PASSANT CAPTURE
    ; =========================================
    ; Detect: pawn moves to saved EP square, BOARD[to] was empty
    ; R10.1 = captured piece at BOARD[to], R10.0 = moving piece
    GHI 10              ; captured piece
    LBNZ MM_NOT_EP_CAP  ; Normal capture (piece at to) -> skip

    GLO 10              ; moving piece
    ANI PIECE_MASK
    XRI PAWN_TYPE
    LBNZ MM_NOT_EP_CAP  ; Not a pawn -> skip

    ; Pawn moved to empty square. Check if to == saved EP square.
    RLDI 9, UNDO_EP     ; EP square from BEFORE this move
    LDN 9               ; D = saved EP square
    XRI NO_EP
    LBZ MM_NOT_EP_CAP   ; No EP was active ($FF) -> skip
    RLDI 9, UNDO_EP
    LDN 9               ; D = EP square
    STR 2
    RLDI 9, UNDO_TO
    LDN 9               ; D = to square
    XOR
    LBNZ MM_NOT_EP_CAP  ; to != EP -> not en passant

    ; EP CAPTURE! Captured pawn at (from_rank | to_file)
    RLDI 9, UNDO_FROM
    LDN 9
    ANI $70             ; from rank
    PLO 13
    RLDI 9, UNDO_TO
    LDN 9
    ANI $07             ; to file
    STR 2
    GLO 13
    OR                  ; D = captured square
    PLO 8
    LDI HIGH(BOARD)
    PHI 8               ; R8 = &BOARD[cap_sq]

    ; Read and save the captured pawn
    LDN 8               ; D = enemy pawn
    PHI 10              ; R10.1 = captured pawn (update from EMPTY)
    RLDI 9, UNDO_CAPTURED
    GHI 10
    STR 9               ; UNDO_CAPTURED = enemy pawn

    ; Save EP capture square
    GLO 8               ; D = cap_sq (low byte of R8)
    STXD                ; push to stack
    RLDI 9, UNDO_CAP_SQ
    IRX
    LDX                 ; D = cap_sq
    STR 9               ; UNDO_CAP_SQ = captured square

    ; Remove captured pawn from board
    LDI EMPTY
    STR 8               ; BOARD[cap_sq] = EMPTY

MM_NOT_EP_CAP:

    ; =========================================
    ; PAWN PROMOTION
    ; =========================================
    ; Check UNDO_PROMOTION - if non-zero, replace pawn with promoted piece
    ; R8 still points to BOARD[to], R10.0 = moving piece
    RLDI 9, UNDO_PROMOTION
    LDN 9               ; D = promotion piece type (0 if none)
    LBZ MM_NOT_PROMOTION

    ; Promotion! Replace pawn with promoted piece
    ; Get color from moving piece (R10.0), combine with promotion type
    GLO 10              ; Moving piece (pawn)
    ANI COLOR_MASK      ; Get color (0=white, 8=black)
    STR 2               ; Save color on stack
    LDN 9               ; Get promotion piece type again
    ADD                 ; D = color + piece_type = promoted piece
    STR 8               ; Store promoted piece at BOARD[to]

MM_NOT_PROMOTION:

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
    RLDI 9, GAME_STATE + STATE_W_KING_SQ
    BR MM_STORE_KING

MM_BLACK_KING:
    ; Update STATE_B_KING_SQ with MOVE_TO
    RLDI 9, GAME_STATE + STATE_B_KING_SQ

MM_STORE_KING:
    ; Get MOVE_TO and store as new king square
    RLDI 8, MOVE_TO
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
    ; D = castling mask ($03 or $0C) — preserved through CALL via R7
    CALL CLEAR_CASTLING_RIGHT

    ; Reload R10 (clobbered by CLEAR_CASTLING_RIGHT)
    ; R10.0 = moving piece from BOARD[MOVE_TO]
    RLDI 9, MOVE_TO
    LDN 9               ; D = to square
    PLO 8
    LDI HIGH(BOARD)
    PHI 8               ; R8 = &BOARD[to]
    LDN 8               ; D = moving piece (king)
    PLO 10              ; R10.0 = moving piece
    ; R10.1 = captured piece from UNDO_CAPTURED
    RLDI 9, UNDO_CAPTURED
    LDN 9               ; D = captured piece
    PHI 10              ; R10.1 = captured piece

    ; =========================================
    ; CASTLING ROOK MOVEMENT
    ; =========================================
    ; Detect: to - from = $02 (kingside) or $FE (queenside)
    RLDI 9, COMPARE_TEMP
    RLDI 8, UNDO_FROM
    LDN 8               ; D = from square
    SEX 9
    STR 9               ; M(COMPARE_TEMP) = from
    RLDI 8, UNDO_TO
    LDN 8               ; D = to square
    SM                   ; D = to - from
    SEX 2

    XRI $02
    LBZ MM_CASTLE_KS     ; to - from = 2: kingside
    XRI $FC              ; XOR chain: checks if original was $FE
    LBZ MM_CASTLE_QS     ; to - from = $FE: queenside
    LBR MM_NOT_KING      ; Normal king move

MM_CASTLE_KS:
    ; Kingside: rook from to+1 (h-file) to to-1 (f-file)
    RLDI 9, UNDO_TO
    LDN 9               ; D = to square

    ; Read rook from BOARD[to+1]
    ADI 1                ; D = to + 1
    PLO 8
    LDI HIGH(BOARD)
    PHI 8               ; R8 = &BOARD[to+1]
    LDN 8               ; D = rook piece
    PHI 13              ; R13.1 = rook piece (temp)
    LDI EMPTY
    STR 8               ; Clear rook's old square (h1/h8)

    ; Place rook at BOARD[to-1]
    LDN 9               ; D = to square (reload from UNDO_TO)
    SMI 1                ; D = to - 1
    PLO 8
    LDI HIGH(BOARD)
    PHI 8               ; R8 = &BOARD[to-1]
    GHI 13              ; D = rook piece
    STR 8               ; Place rook at f1/f8

    ; Hash: XOR out [rook, to+1]
    GHI 13              ; D = rook piece
    PLO 8               ; R8.0 = rook piece
    LDN 9               ; D = to square
    ADI 1                ; D = to + 1 (rook's old square)
    PHI 8               ; R8.1 = old rook square
    CALL HASH_XOR_PIECE_SQ

    ; Hash: XOR in [rook, to-1] (R8.0 preserved by HASH_XOR)
    RLDI 9, UNDO_TO
    LDN 9               ; D = to square
    SMI 1                ; D = to - 1 (rook's new square)
    PHI 8               ; R8.1 = new rook square
    CALL HASH_XOR_PIECE_SQ

    LBR MM_CASTLE_DONE

MM_CASTLE_QS:
    ; Queenside: rook from to-2 (a-file) to to+1 (d-file)
    RLDI 9, UNDO_TO
    LDN 9               ; D = to square

    ; Read rook from BOARD[to-2]
    SMI 2                ; D = to - 2
    PLO 8
    LDI HIGH(BOARD)
    PHI 8               ; R8 = &BOARD[to-2]
    LDN 8               ; D = rook piece
    PHI 13              ; R13.1 = rook piece (temp)
    LDI EMPTY
    STR 8               ; Clear rook's old square (a1/a8)

    ; Place rook at BOARD[to+1]
    LDN 9               ; D = to square (reload from UNDO_TO)
    ADI 1                ; D = to + 1
    PLO 8
    LDI HIGH(BOARD)
    PHI 8               ; R8 = &BOARD[to+1]
    GHI 13              ; D = rook piece
    STR 8               ; Place rook at d1/d8

    ; Hash: XOR out [rook, to-2]
    GHI 13              ; D = rook piece
    PLO 8               ; R8.0 = rook piece
    LDN 9               ; D = to square
    SMI 2                ; D = to - 2 (rook's old square)
    PHI 8               ; R8.1 = old rook square
    CALL HASH_XOR_PIECE_SQ

    ; Hash: XOR in [rook, to+1] (R8.0 preserved by HASH_XOR)
    RLDI 9, UNDO_TO
    LDN 9               ; D = to square
    ADI 1                ; D = to + 1 (rook's new square)
    PHI 8               ; R8.1 = new rook square
    CALL HASH_XOR_PIECE_SQ

MM_CASTLE_DONE:
    ; Reload R10 (clobbered by HASH_XOR_PIECE_SQ)
    RLDI 9, UNDO_TO
    LDN 9               ; D = to square
    PLO 8
    LDI HIGH(BOARD)
    PHI 8               ; R8 = &BOARD[to]
    LDN 8               ; D = king piece
    PLO 10              ; R10.0 = moving piece
    RLDI 9, UNDO_CAPTURED
    LDN 9               ; D = captured piece
    PHI 10              ; R10.1 = captured piece
    ; Fall through to MM_NOT_KING

MM_NOT_KING:
    ; Clear the from square
    RLDI 9, MOVE_FROM
    LDN 9               ; D = from square
    PLO 8
    LDI HIGH(BOARD)
    PHI 8               ; R8 = &BOARD[from]
    LDI EMPTY
    STR 8               ; Clear from square

    ; Toggle side to move
    RLDI 8, SIDE
    LDN 8
    XRI BLACK           ; Toggle between 0 and 8
    STR 8

    ; =========================================
    ; EN PASSANT SQUARE UPDATE
    ; =========================================
    ; Set EP target if pawn double-push, else clear
    ; R8 is at SIDE ($6080), increment to reach EP_SQUARE ($6082)
    INC 8               ; $6081 = STATE_CASTLING
    INC 8               ; $6082 = STATE_EP_SQUARE

    ; Check if moving piece is a pawn
    GLO 10              ; D = moving piece
    ANI PIECE_MASK      ; piece type
    XRI PAWN_TYPE
    LBNZ MM_EP_CLEAR    ; Not a pawn -> clear EP

    ; Pawn moved. Check rank difference = $20 (double push)
    RLDI 9, UNDO_FROM
    LDN 9               ; D = from
    ANI $70             ; from rank
    PLO 13              ; R13.0 = from rank
    RLDI 9, UNDO_TO
    LDN 9               ; D = to
    ANI $70             ; to rank
    STR 2
    GLO 13              ; D = from rank
    SM                  ; D = from_rank - to_rank

    ; White double push: from_rank - to_rank = $E0 (-$20)
    ; Black double push: from_rank - to_rank = $20
    XRI $E0
    LBZ MM_EP_WHITE     ; White pawn double push
    XRI $C0             ; XOR chain: $20 XOR $E0 = $C0, XOR $C0 = 0
    LBZ MM_EP_BLACK     ; Black pawn double push
    LBR MM_EP_CLEAR     ; Not a double push

MM_EP_WHITE:
    ; EP square = to + DIR_N ($F0) = one rank above destination
    RLDI 9, UNDO_TO
    LDN 9
    ADI DIR_N           ; to - $10 (square pawn passed through)
    STR 8               ; STATE_EP_SQUARE = EP target
    LBR MM_EP_DONE

MM_EP_BLACK:
    ; EP square = to + DIR_S ($10) = one rank below destination
    RLDI 9, UNDO_TO
    LDN 9
    ADI DIR_S           ; to + $10 (square pawn passed through)
    STR 8               ; STATE_EP_SQUARE = EP target
    LBR MM_EP_DONE

MM_EP_CLEAR:
    LDI NO_EP
    STR 8

MM_EP_DONE:

    ; ===========================================
    ; FIFTY-MOVE RULE: Update halfmove clock
    ; ===========================================
    ; Reset to 0 if: capture or pawn move
    ; Otherwise: increment
    ; R10.0 = moving piece, R10.1 = captured piece

    INC 8               ; Point to HALFMOVE

    ; Check if capture occurred (R10.1 != EMPTY)
    GHI 10              ; Get captured piece
    LBNZ MM_RESET_HALFMOVE

    ; Check if pawn moved (piece type == PAWN_TYPE)
    GLO 10              ; Get moving piece
    ANI PIECE_MASK      ; Get piece type
    XRI PAWN_TYPE       ; Is it a pawn?
    LBZ MM_RESET_HALFMOVE

    ; No capture, not pawn move - increment halfmove clock
    LDN 8               ; Get current halfmove
    ADI 1               ; Increment
    STR 8               ; Store back
    LBR MM_ROOK_CHECK

MM_RESET_HALFMOVE:
    ; Reset halfmove clock to 0
    LDI 0
    STR 8

    ; =========================================
    ; CASTLING RIGHTS: ROOK HOME SQUARE CHECK
    ; =========================================
    ; If FROM or TO is a rook home square, clear that castling right.
    ; FROM: rook moves away from home (own castling revoked)
    ; TO: rook captured on home square (opponent castling revoked)
    ; R10 is no longer needed (halfmove done), safe to clobber.
MM_ROOK_CHECK:
    RLDI 9, UNDO_FROM
    LDA 9               ; D = from square, R9 advances to UNDO_TO
    CALL MM_ROOK_HOME_CHECK
    LDN 9               ; D = to square (R9 already at UNDO_TO)
    CALL MM_ROOK_HOME_CHECK

MM_ROOK_DONE:

MM_DONE:
    ; =========================================
    ; HASH UPDATE: XOR piece-square changes
    ; =========================================
    ; HASH_XOR_PIECE_SQ: R8.0 = piece, R8.1 = square
    ; Clobbers: R7, R9, R10, R13. Preserves: R8
    ; After each call, reload from memory (safe, no register deps)
    ;
    ; For promotion: BOARD[to] has promoted piece, but we need to
    ; XOR out [pawn, from]. Check UNDO_PROMOTION to get original piece.

    ; --- Step 1: XOR out [moving piece, from] ---
    ; Check if this was a promotion
    RLDI 10, UNDO_PROMOTION
    LDN 10              ; D = promotion type (0 if none)
    LBZ MM_HASH_NOT_PROMO

    ; Promotion: original piece was a pawn. Get color from BOARD[to].
    RLDI 10, UNDO_TO
    LDN 10              ; D = to_square
    ADI LOW(BOARD)
    PLO 10
    LDI HIGH(BOARD)
    ADCI 0
    PHI 10              ; R10 = &BOARD[to_square]
    LDN 10              ; D = promoted piece
    ANI COLOR_MASK      ; Get color (0=white, 8=black)
    ORI PAWN_TYPE       ; D = pawn of same color
    PLO 8               ; R8.0 = pawn
    LBR MM_HASH_GOT_PIECE

MM_HASH_NOT_PROMO:
    ; Normal move: get moving piece from BOARD[UNDO_TO]
    RLDI 10, UNDO_TO
    LDN 10              ; D = to_square
    ADI LOW(BOARD)
    PLO 10
    LDI HIGH(BOARD)
    ADCI 0
    PHI 10              ; R10 = &BOARD[to_square]
    LDN 10              ; D = moving piece
    PLO 8               ; R8.0 = moving piece

MM_HASH_GOT_PIECE:
    ; Get from square
    RLDI 10, UNDO_FROM
    LDN 10              ; D = from_square
    PHI 8               ; R8.1 = from_square
    CALL HASH_XOR_PIECE_SQ

    ; --- Step 2: XOR out [captured, captured_square] ---
    ; For normal captures: captured_square = to
    ; For EP captures: captured_square = (from_rank | to_file)
    RLDI 10, UNDO_CAPTURED
    LDN 10              ; D = captured piece
    PLO 8               ; R8.0 = captured piece
    RLDI 10, UNDO_CAP_SQ
    LDN 10              ; D = capture square
    PHI 8               ; R8.1 = capture square
    CALL HASH_XOR_PIECE_SQ  ; skips if captured == EMPTY

    ; --- Step 3: XOR in [moving piece, to] ---
    ; Get to square first (need for R8.1 and BOARD index)
    RLDI 10, UNDO_TO
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

; ------------------------------------------------------------------------------
; MM_ROOK_HOME_CHECK - Check if square is a rook home square
; ------------------------------------------------------------------------------
; If so, clear the corresponding castling right.
; Input: D = square to check
; Clobbers: R10, R13 (via CLEAR_CASTLING_RIGHT)
; Note: Called from MAKE_MOVE for both FROM and TO squares.
;       FROM handles rook moving away; TO handles rook being captured.
; ------------------------------------------------------------------------------
MM_ROOK_HOME_CHECK:
    LBZ MMRHC_A1         ; $00 = a1 → white queenside
    XRI $07
    LBZ MMRHC_H1         ; $07 = h1 → white kingside
    XRI $77
    LBZ MMRHC_A8         ; $70 = a8 → black queenside
    XRI $07
    LBZ MMRHC_H8         ; $77 = h8 → black kingside
    RETN                 ; No match, return

MMRHC_A1:
    LDI CASTLE_WQ        ; $02
    LBR MMRHC_CLEAR

MMRHC_H1:
    LDI CASTLE_WK        ; $01
    LBR MMRHC_CLEAR

MMRHC_A8:
    LDI CASTLE_BQ        ; $08
    LBR MMRHC_CLEAR

MMRHC_H8:
    LDI CASTLE_BK        ; $04

MMRHC_CLEAR:
    CALL CLEAR_CASTLING_RIGHT
    RETN

; ==============================================================================
; UNMAKE_MOVE - Reverse the last move
; Input: Undo info from previous MAKE_MOVE
; Output: Board restored to previous state
; ==============================================================================
UNMAKE_MOVE:
    ; Get moving piece from to square
    RLDI 9, UNDO_TO
    LDN 9               ; D = to square
    PLO 8
    LDI HIGH(BOARD)
    PHI 8               ; R8 = &BOARD[to]
    LDN 8               ; D = piece at to square
    PLO 10              ; Save in R10.0

    ; Restore captured piece at actual capture square
    ; (handles EP: cap_sq != to for en passant captures)
    RLDI 9, UNDO_CAP_SQ
    LDN 9               ; D = cap_sq
    PLO 8
    LDI HIGH(BOARD)
    PHI 8               ; R8 = &BOARD[cap_sq]
    RLDI 9, UNDO_CAPTURED
    LDN 9
    STR 8               ; BOARD[cap_sq] = captured piece

    ; For EP: clear BOARD[to] (cap_sq != to)
    RLDI 9, UNDO_CAP_SQ
    LDN 9               ; D = cap_sq
    STR 2
    RLDI 9, UNDO_TO
    LDN 9               ; D = to
    XOR
    LBZ UM_CAP_DONE     ; cap_sq == to -> nothing more to do

    ; EP case: clear BOARD[to]
    RLDI 9, UNDO_TO
    LDN 9
    PLO 8
    LDI HIGH(BOARD)
    PHI 8
    LDI EMPTY
    STR 8               ; BOARD[to] = EMPTY

UM_CAP_DONE:

    ; =========================================
    ; PAWN PROMOTION UNDO
    ; =========================================
    ; If UNDO_PROMOTION != 0, restore pawn instead of promoted piece
    ; R10.0 = piece from BOARD[to] (promoted piece if promotion)
    ; Guard: if piece is EMPTY, skip promotion undo (prevents phantom pawn
    ; from corrupted UNDO_PROMOTION)
    GLO 10              ; D = piece from BOARD[to]
    LBZ UM_NOT_PROMOTION ; EMPTY piece = nothing to un-promote
    RLDI 9, UNDO_PROMOTION
    LDN 9               ; D = promotion type (0 if none)
    LBZ UM_NOT_PROMOTION

    ; Promotion: restore pawn (get color from R10.0, the promoted piece)
    GLO 10              ; D = promoted piece
    ANI COLOR_MASK      ; Get color (0=white, 8=black)
    ORI PAWN_TYPE       ; D = pawn of same color
    PLO 10              ; R10.0 = pawn (overwrites promoted piece)

UM_NOT_PROMOTION:
    ; Put moving piece back at from square
    RLDI 9, UNDO_FROM
    LDN 9               ; D = from square
    PLO 8
    LDI HIGH(BOARD)
    PHI 8               ; R8 = &BOARD[from]
    GLO 10              ; D = moving piece (pawn if promotion)
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
    LBNZ UM_BLACK_KING

UM_WHITE_KING:
    ; Update STATE_W_KING_SQ with UNDO_FROM
    RLDI 9, GAME_STATE + STATE_W_KING_SQ
    LBR UM_STORE_KING

UM_BLACK_KING:
    ; Update STATE_B_KING_SQ with UNDO_FROM
    RLDI 9, GAME_STATE + STATE_B_KING_SQ

UM_STORE_KING:
    ; Get UNDO_FROM and store as restored king square
    RLDI 8, UNDO_FROM
    LDN 8               ; D = from square
    STR 9               ; Restore king position

    ; =========================================
    ; CASTLING ROOK UNDO
    ; =========================================
    ; Detect: to - from = $02 (kingside) or $FE (queenside)
    RLDI 9, COMPARE_TEMP
    RLDI 8, UNDO_FROM
    LDN 8               ; D = from square
    SEX 9
    STR 9               ; M(COMPARE_TEMP) = from
    RLDI 8, UNDO_TO
    LDN 8               ; D = to square
    SM                   ; D = to - from
    SEX 2

    XRI $02
    LBZ UM_CASTLE_KS     ; Kingside
    XRI $FC
    LBZ UM_CASTLE_QS     ; Queenside
    LBR UM_NOT_KING      ; Normal king move

UM_CASTLE_KS:
    ; Kingside undo: rook from to-1 (f-file) back to to+1 (h-file)
    RLDI 9, UNDO_TO
    LDN 9               ; D = to square

    ; Read rook from BOARD[to-1]
    SMI 1                ; D = to - 1
    PLO 8
    LDI HIGH(BOARD)
    PHI 8               ; R8 = &BOARD[to-1]
    LDN 8               ; D = rook piece
    PHI 13              ; R13.1 = rook piece (temp)
    LDI EMPTY
    STR 8               ; Clear f1/f8

    ; Place rook back at BOARD[to+1]
    LDN 9               ; D = to square
    ADI 1                ; D = to + 1
    PLO 8
    LDI HIGH(BOARD)
    PHI 8               ; R8 = &BOARD[to+1]
    GHI 13              ; D = rook piece
    STR 8               ; Restore rook to h1/h8

    ; Hash: XOR [rook, to-1] (same pairs as make - XOR cancels)
    GHI 13              ; D = rook piece
    PLO 8               ; R8.0 = rook piece
    LDN 9               ; D = to square
    SMI 1                ; D = to - 1
    PHI 8               ; R8.1 = f1/f8
    CALL HASH_XOR_PIECE_SQ

    ; Hash: XOR [rook, to+1] (R8.0 preserved)
    RLDI 9, UNDO_TO
    LDN 9               ; D = to square
    ADI 1                ; D = to + 1
    PHI 8               ; R8.1 = h1/h8
    CALL HASH_XOR_PIECE_SQ

    LBR UM_NOT_KING

UM_CASTLE_QS:
    ; Queenside undo: rook from to+1 (d-file) back to to-2 (a-file)
    RLDI 9, UNDO_TO
    LDN 9               ; D = to square

    ; Read rook from BOARD[to+1]
    ADI 1                ; D = to + 1
    PLO 8
    LDI HIGH(BOARD)
    PHI 8               ; R8 = &BOARD[to+1]
    LDN 8               ; D = rook piece
    PHI 13              ; R13.1 = rook piece (temp)
    LDI EMPTY
    STR 8               ; Clear d1/d8

    ; Place rook back at BOARD[to-2]
    LDN 9               ; D = to square
    SMI 2                ; D = to - 2
    PLO 8
    LDI HIGH(BOARD)
    PHI 8               ; R8 = &BOARD[to-2]
    GHI 13              ; D = rook piece
    STR 8               ; Restore rook to a1/a8

    ; Hash: XOR [rook, to+1]
    GHI 13              ; D = rook piece
    PLO 8               ; R8.0 = rook piece
    LDN 9               ; D = to square
    ADI 1                ; D = to + 1
    PHI 8               ; R8.1 = d1/d8
    CALL HASH_XOR_PIECE_SQ

    ; Hash: XOR [rook, to-2] (R8.0 preserved)
    RLDI 9, UNDO_TO
    LDN 9               ; D = to square
    SMI 2                ; D = to - 2
    PHI 8               ; R8.1 = a1/a8
    CALL HASH_XOR_PIECE_SQ

UM_NOT_KING:
    ; Restore castling rights to GAME_STATE + STATE_CASTLING
    RLDI 9, UNDO_CASTLING
    LDN 9
    PHI 10              ; Save in R10.1

    RLDI 8, GAME_STATE + STATE_CASTLING
    GHI 10
    STR 8

    ; Restore en passant square to GAME_STATE + STATE_EP_SQUARE
    RLDI 9, UNDO_EP
    LDN 9
    INC 8               ; Point to EP_SQUARE ($6082)
    STR 8

    ; Restore halfmove clock to GAME_STATE + STATE_HALFMOVE
    RLDI 9, UNDO_HALFMOVE
    LDN 9
    INC 8               ; Point to HALFMOVE ($6083)
    STR 8

    ; Toggle side to move back
    RLDI 8, SIDE
    LDN 8
    XRI BLACK           ; Toggle between 0 and 8
    STR 8

    ; =========================================
    ; HASH UPDATE: XOR piece-square changes (reverse of MAKE_MOVE)
    ; =========================================
    ; HASH_XOR_PIECE_SQ: R8.0 = piece, R8.1 = square
    ; Clobbers: R7, R9, R10, R13. Preserves: R8
    ; Board is now restored: piece at UNDO_FROM, captured at UNDO_TO
    ;
    ; For promotion: need to XOR out [promoted_piece, to], not [pawn, to]

    ; --- Step 1: XOR out [piece that WAS at to], to ---
    ; Check if this was a promotion
    RLDI 10, UNDO_PROMOTION
    LDN 10              ; D = promotion type (0 if none)
    LBZ UM_HASH_NOT_PROMO

    ; Promotion: XOR out [promoted_piece, to]
    ; Get color from BOARD[from] (the pawn), combine with promotion type
    RLDI 10, UNDO_FROM
    LDN 10              ; D = from_square
    ADI LOW(BOARD)
    PLO 10
    LDI HIGH(BOARD)
    ADCI 0
    PHI 10              ; R10 = &BOARD[from_square]
    LDN 10              ; D = pawn
    ANI COLOR_MASK      ; Get color
    PLO 8               ; R8.0 = color (temp)
    RLDI 10, UNDO_PROMOTION
    LDN 10              ; D = promotion piece type
    STR 2               ; Save on stack
    GLO 8               ; D = color
    ADD                 ; D = color + promotion_type = promoted piece
    PLO 8               ; R8.0 = promoted piece
    LBR UM_HASH_GOT_PIECE

UM_HASH_NOT_PROMO:
    ; Normal move: XOR out [moving piece, to]
    ; Moving piece is now at BOARD[UNDO_FROM]
    RLDI 10, UNDO_FROM
    LDN 10              ; D = from_square
    ADI LOW(BOARD)
    PLO 10
    LDI HIGH(BOARD)
    ADCI 0
    PHI 10              ; R10 = &BOARD[from_square]
    LDN 10              ; D = moving piece
    PLO 8               ; R8.0 = moving piece

UM_HASH_GOT_PIECE:
    ; Get to square
    RLDI 10, UNDO_TO
    LDN 10              ; D = to_square
    PHI 8               ; R8.1 = to_square
    CALL HASH_XOR_PIECE_SQ

    ; --- Step 2: XOR in [captured, captured_square] ---
    ; For normal captures: captured_square = to
    ; For EP captures: captured_square = (from_rank | to_file)
    RLDI 10, UNDO_CAPTURED
    LDN 10              ; D = captured piece
    PLO 8               ; R8.0 = captured piece
    RLDI 10, UNDO_CAP_SQ
    LDN 10              ; D = capture square
    PHI 8               ; R8.1 = capture square
    CALL HASH_XOR_PIECE_SQ  ; skips if captured == EMPTY

    ; --- Step 3: XOR in [moving piece, from] ---
    ; Moving piece is at BOARD[UNDO_FROM]
    RLDI 10, UNDO_FROM
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
    RLDI 10, GAME_STATE + STATE_EP_SQUARE
    LDN 10              ; D = current EP square
    PLO 7               ; Save in R7.0
    RLDI 10, NULL_SAVED_EP
    GLO 7
    STR 10              ; NULL_SAVED_EP = old EP

    ; Clear EP square (no EP after null move)
    RLDI 10, GAME_STATE + STATE_EP_SQUARE
    LDI $FF             ; Invalid EP
    STR 10

    ; Toggle side to move
    RLDI 10, GAME_STATE + STATE_SIDE_TO_MOVE
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
    RLDI 10, GAME_STATE + STATE_SIDE_TO_MOVE
    LDN 10
    XRI $08             ; Toggle 8 <-> 0
    STR 10

    ; Restore EP square from NULL_SAVED_EP
    RLDI 10, NULL_SAVED_EP
    LDN 10              ; D = saved EP
    PLO 7               ; Save in R7.0
    RLDI 10, GAME_STATE + STATE_EP_SQUARE
    GLO 7
    STR 10              ; Restore EP

    ; Update hash for side change (XOR again = restore)
    CALL HASH_XOR_SIDE

    RETN

; ==============================================================================
; END OF MAKE/UNMAKE MODULE
; ==============================================================================
