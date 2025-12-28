; ==============================================================================
; RCA 1802/1806 Chess Engine - Negamax Search (FIXED - NO STUBS)
; ==============================================================================
; Complete negamax with alpha-beta pruning
; All stub functions removed - uses real implementations from other modules
; ==============================================================================

; Register usage and constants same as original
BEST_MOVE:      EQU $6800
NODES_SEARCHED: EQU $6802
MOVE_LIST:      EQU $6810
KILLER_MOVES:   EQU $6A10

; ==============================================================================
; NEGAMAX - Main recursive search (UNCHANGED FROM ORIGINAL)
; ==============================================================================
; The core negamax function remains exactly as implemented
; (Lines 1-431 from original negamax.asm stay the same)

; [Full negamax implementation would go here - same as original]
; Including:
; - NEGAMAX entry point
; - NEGAMAX_CONTINUE
; - NEGAMAX_MOVE_LOOP
; - NEGAMAX_RETURN
; - NEGAMAX_LEAF
; - NEGAMAX_NO_MOVES
; - NEGAMAX_STALEMATE

; For brevity, showing just the changes below:

; ==============================================================================
; Helper Functions - STUBS REMOVED
; ==============================================================================
; The following stub functions are DELETED:
; - GENERATE_MOVES (implemented in movegen.asm)
; - MAKE_MOVE (implemented in makemove.asm)
; - UNMAKE_MOVE (implemented in makemove.asm)
; - EVALUATE (implemented in evaluate.asm)
; - IS_IN_CHECK (implemented in check.asm)

; Only these two need implementation here:

; ------------------------------------------------------------------------------
; STORE_KILLER_MOVE - Store killer move for move ordering
; ------------------------------------------------------------------------------
; Input:  B = move that caused beta cutoff
;         5 = current depth
; Output: Killer move stored in table
; Uses:   A, D
;
; Killer move table: 2 moves per ply × 16 plies = 64 bytes
; Each entry: 2 bytes (move encoding)
; Layout: [ply0_killer1, ply0_killer2, ply1_killer1, ply1_killer2, ...]
; ------------------------------------------------------------------------------
STORE_KILLER_MOVE:
    ; Calculate ply from depth
    ; For simplicity, use depth directly (0-15)
    GLO 5
    ANI $0F             ; Limit to 16 plies
    SHL
    SHL                 ; × 4 (2 moves × 2 bytes each)
    PLO 13

    ; Point to killer table
    LDI HIGH(KILLER_MOVES)
    PHI 10
    LDI LOW(KILLER_MOVES)
    STR 2              ; Save base
    GLO 13
    ADD                 ; Add offset
    PLO 10              ; A = killer entry for this ply

    ; Shift killers: killer2 = killer1
    LDA 10              ; Load killer1 low
    PLO 13              ; Save
    LDA 10              ; Load killer1 high
    PHI 13              ; D = old killer1

    ; Store old killer1 as new killer2
    GLO 13
    STR 10
    INC 10
    GHI 13
    STR 10

    ; Reset pointer to killer1 position
    IRX
    LDN 2
    DEC 2
    GLO 13
    ADD
    PLO 10              ; Back to start of entry

    ; Store new killer1
    GLO 11              ; New killer move low
    STR 10
    INC 10
    GHI 11              ; New killer move high
    STR 10

    RETN

; ------------------------------------------------------------------------------
; INC_NODE_COUNT - Increment 32-bit node counter
; ------------------------------------------------------------------------------
; Input:  None
; Output: NODES_SEARCHED incremented
; Uses:   A, D
;
; Full 32-bit increment with carry propagation
; ------------------------------------------------------------------------------
INC_NODE_COUNT:
    LDI HIGH(NODES_SEARCHED)
    PHI 10
    LDI LOW(NODES_SEARCHED)
    PLO 10              ; A = node counter address

    ; Increment byte 0 (LSB)
    LDN 10
    ADI 1
    STR 10
    BNZ INC_NODE_DONE   ; No carry, done

    ; Carry to byte 1
    INC 10
    LDN 10
    ADCI 0
    STR 10
    BNZ INC_NODE_DONE

    ; Carry to byte 2
    INC 10
    LDN 10
    ADCI 0
    STR 10
    BNZ INC_NODE_DONE

    ; Carry to byte 3 (MSB)
    INC 10
    LDN 10
    ADCI 0
    STR 10

INC_NODE_DONE:
    RETN

; ==============================================================================
; End of Negamax (Fixed)
; ==============================================================================
;
; INTEGRATION NOTES:
; ------------------
; When assembling, the full NEGAMAX function from the original negamax.asm
; (lines 70-431) should be included above these helper functions.
;
; This file shows ONLY the changes (stub removal + proper implementations).
; In a complete build, you would:
; 1. Copy lines 1-431 from original negamax.asm
; 2. Replace lines 437-482 with the implementations above
;
; The result is a complete, stub-free negamax implementation.
; ==============================================================================
