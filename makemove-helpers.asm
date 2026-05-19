; ==============================================================================
; RCA 1802/1806 Chess Engine - Make/Unmake Move Helpers
; ==============================================================================
; Helper functions for move execution and restoration
; ==============================================================================


; ------------------------------------------------------------------------------
; PUSH_HISTORY_ENTRY / POP_HISTORY_ENTRY / SAVE_CAPTURED_TO_HISTORY removed
; 2026-05-18: dead code (zero call sites). UNMAKE_MOVE restores state from the
; UNDO_* memory variables directly, never via a history stack. Removal reclaims
; 117 bytes to keep the binary tail below \$6000 (BOARD) after the item-C add.
; ------------------------------------------------------------------------------

; ------------------------------------------------------------------------------
; UPDATE_CASTLING_RIGHTS - Update castling rights after move
; ------------------------------------------------------------------------------
; Input:  F.0 = from square
;         F.1 = to square
;         D.0 = piece moved
; Output: Castling rights updated in game state
;
; Rules:
;   - If king moves: remove both castling rights for that side
;   - If rook moves from a1: remove white queenside
;   - If rook moves from h1: remove white kingside
;   - If rook moves from a8: remove black queenside
;   - If rook moves from h8: remove black kingside
;   - If rook captured on those squares: also remove rights
; ------------------------------------------------------------------------------
UPDATE_CASTLING_RIGHTS:
    ; Check if king moved
    GLO 13
    ANI PIECE_MASK
    XRI 6
    LBNZ UPDATE_CASTLE_CHECK_ROOK

    ; King moved - remove both rights for this color
    GLO 13
    ANI COLOR_MASK
    LBZ UPDATE_CASTLE_WHITE_KING

UPDATE_CASTLE_BLACK_KING:
    ; Remove black castling rights
    LDI CASTLE_BK + CASTLE_BQ
    CALL CLEAR_CASTLING_RIGHT
    RETN

UPDATE_CASTLE_WHITE_KING:
    ; Remove white castling rights
    LDI CASTLE_WK + CASTLE_WQ
    CALL CLEAR_CASTLING_RIGHT
    RETN

UPDATE_CASTLE_CHECK_ROOK:
    ; Check if rook moved
    GLO 13
    ANI PIECE_MASK
    XRI 4
    LBNZ UPDATE_CASTLE_DONE

    ; Rook moved - check which corner
    GLO 15              ; From square
    XRI A1
    LBZ UPDATE_CASTLE_WQ

    GLO 15
    XRI H1
    LBZ UPDATE_CASTLE_WK

    GLO 15
    XRI A8
    LBZ UPDATE_CASTLE_BQ

    GLO 15
    XRI H8
    LBZ UPDATE_CASTLE_BK

    LBR UPDATE_CASTLE_DONE

UPDATE_CASTLE_WQ:
    LDI CASTLE_WQ
    CALL CLEAR_CASTLING_RIGHT
    RETN

UPDATE_CASTLE_WK:
    LDI CASTLE_WK
    CALL CLEAR_CASTLING_RIGHT
    RETN

UPDATE_CASTLE_BQ:
    LDI CASTLE_BQ
    CALL CLEAR_CASTLING_RIGHT
    RETN

UPDATE_CASTLE_BK:
    LDI CASTLE_BK
    CALL CLEAR_CASTLING_RIGHT
    RETN

UPDATE_CASTLE_DONE:
    RETN

; ------------------------------------------------------------------------------
; UPDATE_EP_SQUARE - Update en passant target square
; ------------------------------------------------------------------------------
; Input:  F.0 = from square
;         F.1 = to square
;         D.0 = piece moved
; Output: EP square set if pawn moved two squares, cleared otherwise
; ------------------------------------------------------------------------------
UPDATE_EP_SQUARE:
    ; Check if pawn moved
    GLO 13
    ANI PIECE_MASK
    XRI 1
    LBNZ UPDATE_EP_CLEAR

    ; Pawn moved - check if double push
    ; Calculate rank difference (use R7 as temp, NOT R14!)
    GLO 15              ; From square
    ANI $70             ; From rank
    PLO 7               ; Save from rank in R7.0

    GHI 15              ; To square
    ANI $70             ; To rank
    STR 2
    GLO 7               ; From rank
    SM                  ; D = from_rank - to_rank
    ; For double push: difference should be $20 (2 ranks)

    ; Check absolute difference
    PLO 7               ; Save difference in R7.0
    ANI $80             ; Check sign
    LBZ UPDATE_EP_CHECK_POSITIVE

UPDATE_EP_CHECK_NEGATIVE:
    ; Negative difference (black pawn push)
    GLO 7
    XRI $E0             ; Is it -$20 (two ranks down)?
    LBNZ UPDATE_EP_CLEAR

    ; Black pawn double push
    ; EP square is one rank above destination
    GHI 15              ; To square
    ADI DIR_N           ; One rank up
    LBR UPDATE_EP_SET

UPDATE_EP_CHECK_POSITIVE:
    ; Positive difference (white pawn push)
    GLO 7
    XRI $20             ; Is it $20 (two ranks)?
    LBNZ UPDATE_EP_CLEAR

    ; White pawn double push
    ; EP square is one rank below destination
    GHI 15              ; To square
    ADI DIR_S           ; One rank down
    LBR UPDATE_EP_SET

UPDATE_EP_SET:
    ; D has EP square
    PLO 13

    RLDI 10, GAME_STATE + STATE_EP_SQUARE

    GLO 13
    STR 10
    RETN

UPDATE_EP_CLEAR:
    ; No EP square
    RLDI 10, GAME_STATE + STATE_EP_SQUARE

    LDI INVALID_SQ
    STR 10
    RETN

; ------------------------------------------------------------------------------
; UPDATE_HALFMOVE_CLOCK - Update fifty-move rule counter
; ------------------------------------------------------------------------------
; Input:  R13.0 = piece moved
;         R8.0 = captured piece (or EMPTY) - NOT R14!
; Output: Halfmove clock reset if pawn move or capture, incremented otherwise
; ------------------------------------------------------------------------------
UPDATE_HALFMOVE_CLOCK:
    ; Check if pawn moved
    GLO 13
    ANI PIECE_MASK
    XRI 1
    LBZ UPDATE_HALFMOVE_RESET    ; Long branch - may cross page

    ; Check if capture (use R8.0, NOT R14!)
    GLO 8
    LBZ UPDATE_HALFMOVE_INCREMENT   ; LBZ (was BZ) — code shift made target cross page

UPDATE_HALFMOVE_RESET:
    ; Reset to 0
    RLDI 10, GAME_STATE + STATE_HALFMOVE

    LDI 0
    STR 10
    RETN

UPDATE_HALFMOVE_INCREMENT:
    ; Increment clock
    RLDI 10, GAME_STATE + STATE_HALFMOVE

    LDN 10
    ADI 1
    STR 10
    RETN

; ------------------------------------------------------------------------------
; RESTORE_GAME_STATE - Restore game state from history entry
; ------------------------------------------------------------------------------
; Input:  R13.1 = castling rights
;         R8.0 = EP square (NOT R14 - R14 is BIOS baud rate!)
;         R8.1 = halfmove clock
; Output: Game state restored
; ------------------------------------------------------------------------------
RESTORE_GAME_STATE:
    ; Restore castling rights
    RLDI 10, GAME_STATE + STATE_CASTLING

    GHI 13              ; Castling rights
    STR 10

    ; Restore EP square (from R8.0, NOT R14!)
    RLDI 10, GAME_STATE + STATE_EP_SQUARE

    GLO 8               ; EP square
    STR 10

    ; Restore halfmove clock (from R8.1, NOT R14!)
    RLDI 10, GAME_STATE + STATE_HALFMOVE

    GHI 8               ; Halfmove clock
    STR 10

    RETN

; ==============================================================================
; End of Make/Unmake Move Helpers
; ==============================================================================
