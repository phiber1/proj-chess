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
; UPDATE_CASTLING_RIGHTS / UPDATE_EP_SQUARE / UPDATE_HALFMOVE_CLOCK /
; RESTORE_GAME_STATE removed 2026-05-19: dead code (zero call sites). The live
; castling/EP/halfmove updates are inlined in makemove.asm's MAKE_MOVE path;
; state restoration on unmake reads UNDO_* variables directly. Removal reclaims
; ~213 bytes to fit Item-B (Fix B keep-queen-when-winning bonus, evaluate.asm)
; while keeping the binary tail below \$6000 (BOARD). CLEAR_CASTLING_RIGHT
; lives in board-0x88.asm and is still used by makemove.asm directly.
; ------------------------------------------------------------------------------

; ==============================================================================
; End of Make/Unmake Move Helpers
; ==============================================================================
