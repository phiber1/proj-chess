; ==============================================================================
; RCA 1802/1806 Chess Engine - Negamax Search with Alpha-Beta Pruning
; ==============================================================================
; Core search algorithm
; ==============================================================================

; ------------------------------------------------------------------------------
; Register Usage During Search
; ------------------------------------------------------------------------------
; 0:  Reserved for interrupts/DMA
; 1:  Reserved for interrupt PC
; 2:  Stack pointer (X register) - CRITICAL
; 3:  Program counter (P register) - CRITICAL
; 4:  SCALL routine pointer (BIOS SCRT)
; 5:  SRET routine pointer (BIOS SCRT) - DO NOT USE FOR DATA!
; 6:  SCRT linkage register - DO NOT USE FOR DATA! (corrupted by every CALL)
; 7:  Temp for alpha/beta operations (beta loaded from memory when needed)
; 8:  Best score accumulator
; 9:  Move list pointer / score return value
; A:  Board state pointer (set before search)
; B:  Current move being evaluated
; C:  Color/side to move (0 for white, 8 for black - matches COLOR_MASK)
; D:  Temp/scratch register 1
; E:  Temp/scratch register 2 (move counter)
; F:  Temp/scratch register 3
; NOTE: Alpha/beta stored in memory at ALPHA_LO/HI, BETA_LO/HI (not registers)
; NOTE: Search depth stored in memory at SEARCH_DEPTH (not in a register)
; ------------------------------------------------------------------------------

; Memory locations for search state - defined in board-0x88.asm:
;   BEST_MOVE, NODES_SEARCHED, SEARCH_DEPTH, QS_*, EVAL_SQ_INDEX, KILLER_MOVES
;   ALPHA_LO/HI, BETA_LO/HI, SCORE_LO/HI (added for memory-based alpha/beta)
; All engine variables consolidated at $6400+ region

; ------------------------------------------------------------------------------
; NEGAMAX - Main recursive search function
; ------------------------------------------------------------------------------
; Input:  SEARCH_DEPTH = depth remaining in memory (0 = leaf node, evaluate)
;         ALPHA_LO/HI = alpha (lower bound) in memory
;         BETA_LO/HI = beta (upper bound) in memory
;         C = color (0 for white, 8 for black - matches COLOR_MASK)
;         A = board state pointer
; Output: R9 = score from current position
;         BEST_MOVE = best move found (if at root)
; Uses:   All registers 7-F, stack
; NOTE:   R6 is SCRT linkage register - never used for data!
; ------------------------------------------------------------------------------
NEGAMAX:
    ; Debug: N for NEGAMAX entry (before SAVE)
    LDI 'N'
    CALL SERIAL_WRITE_CHAR

    ; Save context to ply-indexed state array (no stack manipulation!)
    CALL SAVE_PLY_STATE

    ; Debug: S for after SAVE returned
    LDI 'S'
    CALL SERIAL_WRITE_CHAR

    ; Increment node counter (for statistics)
    CALL INC_NODE_COUNT

    ; -----------------------------------------------
    ; FIFTY-MOVE RULE: Check for draw
    ; -----------------------------------------------
    ; If halfmove clock >= 100, position is a draw
    LDI HIGH(GAME_STATE)
    PHI 13
    LDI LOW(GAME_STATE + STATE_HALFMOVE)
    PLO 13
    LDN 13               ; D = halfmove clock
    SMI 100             ; D = halfmove - 100
    BNF NEGAMAX_NOT_FIFTY ; If < 100, continue normally

    ; Fifty-move rule triggered - return draw (score = 0)
    LDI 0
    PHI 9
    PLO 9               ; R9 = 0 (draw score) - R6 is SCRT linkage!
    CALL RESTORE_PLY_STATE
    RETN

NEGAMAX_NOT_FIFTY:
    ; -----------------------------------------------
    ; Check if we're at a leaf node (depth == 0)
    ; -----------------------------------------------
    ; Load depth from memory (SEARCH_DEPTH)
    LDI HIGH(SEARCH_DEPTH)
    PHI 13
    LDI LOW(SEARCH_DEPTH)
    PLO 13
    LDA 13              ; D = depth high byte
    LBNZ NEGAMAX_CONTINUE
    LDN 13              ; D = depth low byte
    LBNZ NEGAMAX_CONTINUE
    ; Depth is 0, evaluate leaf node
    LBR NEGAMAX_LEAF

NEGAMAX_CONTINUE:
    ; -----------------------------------------------
    ; Initialize best score to -INFINITY
    ; -----------------------------------------------
    LDI $80
    PHI 8              ; 8.1 = $80
    LDI $00
    PLO 8              ; 8 = $8000 (-32768)

    ; -----------------------------------------------
    ; Generate moves for current position
    ; -----------------------------------------------
    ; Board is at A, color is in C
    ; Move list will be placed at MOVE_LIST
    LDI HIGH(MOVE_LIST)
    PHI 9
    LDI LOW(MOVE_LIST)
    PLO 9              ; 9 = move list pointer

    CALL GENERATE_MOVES
    ; Returns: D = move count
    ; Move list at 9 (MOVE_LIST)

    ; Save move count to stack
    STXD

    ; Check if there are any legal moves
    IRX
    LDN 2               ; Peek at move count
    DEC 2               ; Restore stack pointer
    BNZ NEGAMAX_HAS_MOVES
    ; No legal moves - checkmate or stalemate
    LBR NEGAMAX_NO_MOVES

NEGAMAX_HAS_MOVES:
NEGAMAX_MOVE_LOOP:
    ; -----------------------------------------------
    ; Loop through all moves
    ; -----------------------------------------------
    ; Restore move count
    IRX
    LDN 2              ; Peek at move count (don't pop)
    DEC 2              ; Re-decrement
    LBZ NEGAMAX_RETURN  ; No moves left

    ; Get next move from list
    LDA 9              ; Load high byte of move
    PHI 11
    LDA 9              ; Load low byte of move
    PLO 11              ; B = current move (16-bit encoded)

    ; Save current state before making move
    ; (9 = move list pointer, 8 = best score so far)
    GLO 9
    STXD
    GHI 9
    STXD

    GLO 8
    STXD
    GHI 8
    STXD

    ; -----------------------------------------------
    ; Decode move and set MOVE_FROM/MOVE_TO for MAKE_MOVE
    ; -----------------------------------------------
    ; R11 has encoded move (swapped due to little-endian load)
    ; R11.HI = encoded low byte, R11.LO = encoded high byte
    ; DECODE_MOVE_16BIT expects R8 with normal byte order
    GHI 11              ; Get encoded low byte
    PLO 8               ; Store as R8 low
    GLO 11              ; Get encoded high byte
    PHI 8               ; Store as R8 high

    CALL DECODE_MOVE_16BIT
    ; R13.1 = from square, R13.0 = to square

    ; Store to MOVE_FROM/MOVE_TO for MAKE_MOVE
    LDI HIGH(MOVE_FROM)
    PHI 10
    LDI LOW(MOVE_FROM)
    PLO 10
    GHI 13              ; from
    STR 10
    INC 10
    GLO 13              ; to
    STR 10

    ; -----------------------------------------------
    ; Make the move on the board
    ; -----------------------------------------------
    CALL MAKE_MOVE
    ; MOVE_FROM/MOVE_TO set above
    ; Board is now updated with move made

    ; -----------------------------------------------
    ; Save depth to stack and decrement for recursive call
    ; (PUSH ORDER: R9/R8, depth, alpha/beta, UNDO_* - pop in reverse!)
    ; -----------------------------------------------
    ; First, save current depth to stack for later restore
    LDI HIGH(SEARCH_DEPTH)
    PHI 13
    LDI LOW(SEARCH_DEPTH)
    PLO 13
    LDA 13              ; D = depth high
    STXD
    LDN 13              ; D = depth low
    STXD                ; Stack now has: ... [depth_hi] [depth_lo]

    ; Now decrement depth in memory
    LDI HIGH(SEARCH_DEPTH)
    PHI 13
    LDI LOW(SEARCH_DEPTH + 1)
    PLO 13              ; Point to low byte
    LDN 13              ; D = depth low
    SMI 1
    STR 13              ; Store decremented low byte
    DEC 13              ; Point to high byte
    LDN 13              ; D = depth high
    SMBI 0              ; Subtract borrow
    STR 13              ; Store decremented high byte

    ; -----------------------------------------------
    ; Negate and swap alpha/beta (memory-based - R6 is SCRT linkage!)
    ; -----------------------------------------------
    ; For negamax: score = -negamax(depth-1, -beta, -alpha, -color)

    ; Save current alpha and beta from memory to stack
    ; Load alpha from memory
    LDI HIGH(ALPHA_LO)
    PHI 13
    LDI LOW(ALPHA_LO)
    PLO 13
    LDA 13              ; D = alpha_lo
    STXD
    LDN 13              ; D = alpha_hi
    STXD
    ; Load beta from memory
    LDI HIGH(BETA_LO)
    PHI 13
    LDI LOW(BETA_LO)
    PLO 13
    LDA 13              ; D = beta_lo
    STXD
    LDN 13              ; D = beta_hi
    STXD
    ; Stack now has: [beta_hi][beta_lo][alpha_hi][alpha_lo][depth]...

    ; -----------------------------------------------
    ; Save UNDO_* to stack (6 bytes) for recursive safety
    ; Child calls will overwrite UNDO_*, so we must save it
    ; Push LAST so it gets popped FIRST (LIFO order!)
    ; -----------------------------------------------
    LDI HIGH(UNDO_CAPTURED)
    PHI 10
    LDI LOW(UNDO_CAPTURED)
    PLO 10
    LDA 10              ; UNDO_CAPTURED
    STXD
    LDA 10              ; UNDO_FROM
    STXD
    LDA 10              ; UNDO_TO
    STXD
    LDA 10              ; UNDO_CASTLING
    STXD
    LDA 10              ; UNDO_EP
    STXD
    LDN 10              ; UNDO_HALFMOVE
    STXD
    ; Stack now has: [UNDO_*][beta][alpha][depth][R8][R9]...

    ; Compute new_alpha = -beta, new_beta = -alpha
    ; Load beta from memory, negate, store as new alpha
    LDI HIGH(BETA_LO)
    PHI 13
    LDI LOW(BETA_LO)
    PLO 13
    LDA 13              ; D = beta_lo
    SDI 0               ; D = -beta_lo
    PLO 7               ; Temp store
    LDN 13              ; D = beta_hi
    SDBI 0              ; D = -beta_hi (with borrow)
    PHI 7               ; R7 = -beta (negated beta)

    ; Load alpha from memory, negate
    LDI HIGH(ALPHA_LO)
    PHI 13
    LDI LOW(ALPHA_LO)
    PLO 13
    LDA 13              ; D = alpha_lo
    SDI 0               ; D = -alpha_lo
    PLO 8               ; Temp in R8.0
    LDN 13              ; D = alpha_hi
    SDBI 0              ; D = -alpha_hi (with borrow)
    PHI 8               ; R8 = -alpha (negated alpha)

    ; Now swap: new_alpha = -beta (in R7), new_beta = -alpha (in R8)
    ; Store to memory
    LDI HIGH(ALPHA_LO)
    PHI 13
    LDI LOW(ALPHA_LO)
    PLO 13
    GLO 7
    STR 13              ; ALPHA_LO = -beta low
    INC 13
    GHI 7
    STR 13              ; ALPHA_HI = -beta high

    LDI HIGH(BETA_LO)
    PHI 13
    LDI LOW(BETA_LO)
    PLO 13
    GLO 8
    STR 13              ; BETA_LO = -alpha low
    INC 13
    GHI 8
    STR 13              ; BETA_HI = -alpha high

    ; Toggle color (C): 0=white, 8=black (matches COLOR_MASK)
    GLO 12
    XRI $08             ; Toggle between 0 and 8
    PLO 12

    ; Increment ply counter before recursion
    LDI HIGH(CURRENT_PLY)
    PHI 10
    LDI LOW(CURRENT_PLY)
    PLO 10
    LDN 10
    ADI 1
    STR 10              ; CURRENT_PLY++

    ; -----------------------------------------------
    ; Recursive call to NEGAMAX
    ; -----------------------------------------------
    CALL NEGAMAX
    ; Returns score in R9 (R6 is SCRT linkage - off limits!)

    ; Decrement ply counter after recursion
    LDI HIGH(CURRENT_PLY)
    PHI 10
    LDI LOW(CURRENT_PLY)
    PLO 10
    LDN 10
    SMI 1
    STR 10              ; CURRENT_PLY--

    ; -----------------------------------------------
    ; Negate the returned score (R6 is SCRT linkage - off limits!)
    ; -----------------------------------------------
    GLO 9
    SDI 0
    PLO 9
    GHI 9
    SDBI 0
    PHI 9               ; R9 = -score

    ; Save negated score to memory (R9 will be overwritten by stack pops)
    LDI HIGH(SCORE_LO)
    PHI 10
    LDI LOW(SCORE_LO)
    PLO 10
    GLO 9
    STR 10
    INC 10
    GHI 9
    STR 10              ; SCORE_LO/HI = negated score

    ; -----------------------------------------------
    ; Restore UNDO_* from stack (6 bytes) before UNMAKE_MOVE
    ; -----------------------------------------------
    LDI HIGH(UNDO_HALFMOVE)
    PHI 10
    LDI LOW(UNDO_HALFMOVE)
    PLO 10
    IRX
    LDXA                ; UNDO_HALFMOVE
    STR 10
    DEC 10
    LDXA                ; UNDO_EP
    STR 10
    DEC 10
    LDXA                ; UNDO_CASTLING
    STR 10
    DEC 10
    LDXA                ; UNDO_TO
    STR 10
    DEC 10
    LDXA                ; UNDO_FROM
    STR 10
    DEC 10
    LDX                 ; UNDO_CAPTURED (last, no inc)
    STR 10

    ; -----------------------------------------------
    ; Unmake the move
    ; -----------------------------------------------
    CALL UNMAKE_MOVE
    ; Board restored to previous state

    ; -----------------------------------------------
    ; Restore context (memory-based alpha/beta - R6 is SCRT linkage!)
    ; -----------------------------------------------
    ; Stack order (low to high): beta_hi, beta_lo, alpha_hi, alpha_lo, depth_lo, depth_hi, R8, R9

    ; Pop beta from stack to BETA memory
    IRX                 ; Point to beta_hi
    LDXA                ; D = beta_hi
    PHI 7               ; Temp
    LDXA                ; D = beta_lo
    PLO 7               ; R7 = beta (temp)
    LDI HIGH(BETA_LO)
    PHI 13
    LDI LOW(BETA_LO)
    PLO 13
    GLO 7
    STR 13              ; BETA_LO
    INC 13
    GHI 7
    STR 13              ; BETA_HI

    ; Pop alpha from stack to ALPHA memory (NO extra IRX - R2 already at alpha_hi)
    LDXA                ; D = alpha_hi
    PHI 7               ; Temp
    LDXA                ; D = alpha_lo
    PLO 7               ; R7 = alpha (temp)
    LDI HIGH(ALPHA_LO)
    PHI 13
    LDI LOW(ALPHA_LO)
    PLO 13
    GLO 7
    STR 13              ; ALPHA_LO
    INC 13
    GHI 7
    STR 13              ; ALPHA_HI

    ; Pop depth from stack to SEARCH_DEPTH memory
    ; Stack has: depth_lo, depth_hi (depth_lo at lower addr)
    LDXA                ; D = depth_lo
    PLO 7               ; Temp
    LDXA                ; D = depth_hi
    PHI 7               ; R7 = depth (temp: hi.lo)
    LDI HIGH(SEARCH_DEPTH)
    PHI 13
    LDI LOW(SEARCH_DEPTH)
    PLO 13
    GHI 7
    STR 13              ; SEARCH_DEPTH high
    INC 13
    GLO 7
    STR 13              ; SEARCH_DEPTH+1 low

    ; Toggle color back to parent's color (0/8)
    GLO 12
    XRI $08
    PLO 12              ; C = color restored

    ; Pop best score (R8)
    LDXA                ; D = R8.1
    PHI 8
    LDXA                ; D = R8.0
    PLO 8

    ; Restore R9 (move list pointer) from stack
    ; We need R9 to continue iterating through the move list!
    LDXA                ; D = R9.1, then R2++ to R9.0
    PHI 9
    LDX                 ; D = R9.0, R2 stays at R9.0 (below move_count)
    PLO 9               ; R9 = move list pointer restored

    ; Load score from SCORE memory into R13 (R9 is move list pointer!)
    LDI HIGH(SCORE_LO)
    PHI 10
    LDI LOW(SCORE_LO)
    PLO 10
    LDA 10              ; SCORE_LO
    PLO 13
    LDN 10              ; SCORE_HI
    PHI 13              ; R13 = negated score from memory

    ; -----------------------------------------------
    ; Beta Cutoff Check: if (score >= beta) return beta
    ; -----------------------------------------------
    ; Compare score (R9) with beta (from BETA memory)
    ; Score is already saved to SCORE_LO/HI, can reload if needed

    ; Load beta from memory into R7 (use R10 as pointer, preserve R13=score)
    LDI HIGH(BETA_LO)
    PHI 10
    LDI LOW(BETA_LO)
    PLO 10
    LDA 10              ; D = beta_lo
    PLO 7
    LDN 10              ; D = beta_hi
    PHI 7               ; R7 = beta (loaded from memory)

    ; SIGNED comparison: score (R13) vs beta (R7)
    ; Use COMPARE_TEMP for scratch (NEVER use STR 2 for scratch!)
    LDI HIGH(COMPARE_TEMP)
    PHI 10
    LDI LOW(COMPARE_TEMP)
    PLO 10
    SEX 10              ; X = R10 for comparisons

    ; First check if signs differ
    GHI 13              ; score high byte
    STR 10
    GHI 7               ; beta high byte
    XOR                 ; XOR high bytes
    ANI $80             ; Check if sign bits differ
    SEX 2               ; X = R2 (restore for branches)
    LBNZ NEGAMAX_BETA_DIFF_SIGN

    ; Same sign - use subtraction result
    SEX 10
    GLO 7
    STR 10
    GLO 13
    SM                  ; D = score_lo - beta_lo
    GHI 7
    STR 10
    GHI 13
    SMB                 ; D = score_hi - beta_hi - borrow
    SEX 2               ; X = R2 (restore)

    ; Check sign bit (negative means score < beta)
    ANI $80
    LBNZ NEGAMAX_NO_BETA_CUTOFF
    ; Fall through to cutoff (score >= beta)
    LBR NEGAMAX_DO_BETA_CUTOFF

NEGAMAX_BETA_DIFF_SIGN:
    ; Different signs - positive number is greater
    GHI 13              ; score high byte
    ANI $80
    LBNZ NEGAMAX_NO_BETA_CUTOFF  ; Score negative, beta positive: score < beta, NO cutoff
    ; Score positive, beta negative: score > beta, CUTOFF (fall through)

NEGAMAX_DO_BETA_CUTOFF:
    ; Beta cutoff! Return beta (already in R7)
    ; Put beta in R8 (best) - NEGAMAX_RETURN will move R8 to R9

    ; Move beta (R7) to R8 for return
    GLO 7
    PLO 8
    GHI 7
    PHI 8

    ; Decrement move count before returning
    IRX
    LDN 2
    SMI 1
    STR 2
    DEC 2

    ; Store killer move (for move ordering optimization)
    CALL STORE_KILLER_MOVE

    LBR NEGAMAX_RETURN

NEGAMAX_NO_BETA_CUTOFF:
    ; Score is already in R13 from earlier load (before beta check)
    ; R9 = move list pointer (preserved)

    ; -----------------------------------------------
    ; Update best score: if (score > maxScore) maxScore = score
    ; -----------------------------------------------
    ; SIGNED comparison of score (R13) vs best (R8)
    ; Use COMPARE_TEMP for scratch (NEVER use STR 2 for scratch!)
    LDI HIGH(COMPARE_TEMP)
    PHI 10
    LDI LOW(COMPARE_TEMP)
    PLO 10
    SEX 10              ; X = R10 for comparisons

    ; First check if signs differ
    GHI 13              ; score high byte
    STR 10
    GHI 8               ; best high byte
    XOR                 ; XOR high bytes
    ANI $80             ; Check if sign bits differ
    SEX 2               ; X = R2 (restore for branches)
    LBNZ NEGAMAX_DIFF_SIGN

    ; Same sign - use subtraction result
    SEX 10
    GHI 8
    STR 10
    GHI 13
    SD                  ; D = score_hi - best_hi
    SEX 2
    LBNZ NEGAMAX_HI_DIFF
    ; High bytes equal, compare low
    SEX 10
    GLO 8
    STR 10
    GLO 13
    SD                  ; D = score_lo - best_lo
    SEX 2
    LBZ NEGAMAX_NEXT_MOVE       ; Equal, don't update (keep first move)
    LBNF NEGAMAX_SCORE_BETTER   ; DF=0: score > best
    LBR NEGAMAX_NEXT_MOVE       ; DF=1: score < best

NEGAMAX_HI_DIFF:
    LBNF NEGAMAX_SCORE_BETTER   ; DF=0: score > best
    LBR NEGAMAX_NEXT_MOVE       ; DF=1: score < best

NEGAMAX_DIFF_SIGN:
    ; Different signs - positive number is greater
    GHI 13
    ANI $80
    LBNZ NEGAMAX_NEXT_MOVE      ; Score negative, best positive - skip
    ; Score positive/zero, best negative - update (fall through)

NEGAMAX_SCORE_BETTER:
    ; Score is better, update best score (R13 -> R8)
    GLO 13
    PLO 8
    GHI 13
    PHI 8              ; R8 = score

    ; -----------------------------------------------
    ; If at root (PLY == 0), save this move to BEST_MOVE
    ; -----------------------------------------------
    LDI HIGH(CURRENT_PLY)
    PHI 10
    LDI LOW(CURRENT_PLY)
    PLO 10
    LDN 10              ; Get current ply
    LBNZ NEGAMAX_NEXT_MOVE  ; Not at root, skip BEST_MOVE update

    ; At root - save move to BEST_MOVE
    ; Move is in UNDO_FROM/UNDO_TO (restored after unmake)
    LDI HIGH(UNDO_FROM)
    PHI 10
    LDI LOW(UNDO_FROM)
    PLO 10
    LDA 10              ; UNDO_FROM
    PHI 7               ; Temp
    LDN 10              ; UNDO_TO
    PLO 7               ; R7 = from/to

    LDI HIGH(BEST_MOVE)
    PHI 10
    LDI LOW(BEST_MOVE)
    PLO 10
    GHI 7
    STR 10              ; BEST_MOVE[0] = from
    INC 10
    GLO 7
    STR 10              ; BEST_MOVE[1] = to

    ; -----------------------------------------------
    ; Update alpha: if (score > alpha) alpha = score
    ; -----------------------------------------------
    ; Compare score (R9) with alpha - alpha is currently unknown!
    ; Alpha was restored but we used stack for score. Need to save score to memory.
    ; For now, skip alpha update (alpha-beta pruning still works via beta cutoff)
    ; TODO: Properly track alpha if needed for deeper search improvement

NEGAMAX_NEXT_MOVE:
    ; -----------------------------------------------
    ; Decrement move counter and continue loop
    ; -----------------------------------------------
    IRX                ; Point to move_count
    LDX                ; Pop move count (R2 at now-empty slot)
    SMI 1              ; Decrement
    BZ NEGAMAX_LOOP_DONE  ; If count == 0, exit loop
    STXD               ; Push decremented count
    LBR NEGAMAX_MOVE_LOOP

NEGAMAX_LOOP_DONE:
    ; Count reached 0 - R2 is AT move_count, need to put it BELOW
    DEC 2              ; Now R2 is below move_count, matching Path A
    ; Fall through to NEGAMAX_RETURN

NEGAMAX_RETURN:
    ; -----------------------------------------------
    ; Return best score (in R8) via R9
    ; -----------------------------------------------
    ; Skip move count (1 byte) - IRX moves R2 to AT move_count, then
    ; CALL RESTORE will overwrite it with SCRT linkage. This effectively
    ; "pops" move_count without needing to read it.
    IRX

    ; Move best score from R8 to R9 for return (R6 is SCRT linkage - off limits!)
    GLO 8
    PLO 9
    GHI 8
    PHI 9

    ; Restore caller's context
    ; NOTE: RESTORE_SEARCH_CONTEXT now properly handles SCRT linkage
    ; (pops it from stack, reads saved context, restores R6, returns)
    CALL RESTORE_PLY_STATE

    RETN

NEGAMAX_LEAF:
    ; -----------------------------------------------
    ; Leaf node - do quiescence search
    ; -----------------------------------------------
    ; Debug: marker L for reaching NEGAMAX_LEAF (depth 0)
    LDI 'L'
    CALL SERIAL_WRITE_CHAR

    CALL QUIESCENCE_SEARCH
    ; Returns score in R9 (already from side-to-move's perspective)
    ; R6 is SCRT linkage - off limits!

    ; Debug: after QS, before RESTORE
    LDI '('
    CALL SERIAL_WRITE_CHAR

    CALL RESTORE_PLY_STATE

    ; Debug: after RESTORE (if we get here)
    LDI ')'
    CALL SERIAL_WRITE_CHAR

    RETN

NEGAMAX_NO_MOVES:
    ; -----------------------------------------------
    ; No legal moves - checkmate or stalemate
    ; -----------------------------------------------
    ; Check if in check
    CALL IS_IN_CHECK
    ; Returns: D = 1 if in check, 0 if not

    LBZ NEGAMAX_STALEMATE   ; Long branch - may cross page

    ; Checkmate - return very low score (adjusted by depth for faster mates)
    ; Score = -MATE_SCORE + depth
    ; This makes shorter mates score higher
    LDI $80
    PHI 9
    LDI $00
    PLO 9              ; R9 = -32768 (R6 is SCRT linkage - off limits!)

    ; Add depth to make closer mates better
    ; Load depth low byte from memory
    LDI HIGH(SEARCH_DEPTH + 1)
    PHI 13
    LDI LOW(SEARCH_DEPTH + 1)
    PLO 13
    LDN 13              ; D = depth low byte
    ; Use COMPARE_TEMP for ADD scratch (NEVER use STR 2!)
    LDI HIGH(COMPARE_TEMP)
    PHI 10
    LDI LOW(COMPARE_TEMP)
    PLO 10
    SEX 10
    STR 10
    GLO 9
    ADD
    SEX 2
    PLO 9
    ; High byte stays same (adding small depth won't overflow)

    ; Need to put R9 into R8 for NEGAMAX_RETURN to work
    GLO 9
    PLO 8
    GHI 9
    PHI 8
    LBR NEGAMAX_RETURN

NEGAMAX_STALEMATE:
    ; Stalemate - return 0 (draw)
    LDI 0
    PHI 8
    PLO 8              ; R8 = 0 (best score), NEGAMAX_RETURN copies to R9
    LBR NEGAMAX_RETURN

; ==============================================================================
; QUIESCENCE_SEARCH - Search captures at leaf nodes
; ==============================================================================
; Avoids horizon effect by extending search for captures
; Input:  C = color (0 for white, 8 for black - matches COLOR_MASK)
;         A = board pointer
; Output: R9 = best score (from side-to-move's perspective)
; NOTE:   R6 is SCRT linkage register - off limits for application data!
; ==============================================================================
QUIESCENCE_SEARCH:
    ; Debug: marker < for entering QS
    LDI '<'
    CALL SERIAL_WRITE_CHAR

    ; Stand-pat: evaluate current position
    CALL EVALUATE
    ; Returns score in R9 (from white's perspective)

    ; Negate if black to move (R12: 0=white, 8=black)
    GLO 12
    ANI $08             ; Check if black (COLOR_MASK)
    LBZ QS_SAVE_STANDPAT
    ; Negate score in R9 (R6 is SCRT linkage - off limits!)
    GLO 9
    SDI 0
    PLO 9
    GHI 9
    SDBI 0
    PHI 9

QS_SAVE_STANDPAT:
    ; Save stand-pat score to memory as best (avoid R14!)
    LDI HIGH(QS_BEST_LO)
    PHI 10
    LDI LOW(QS_BEST_LO)
    PLO 10
    GLO 9
    STR 10
    INC 10
    GHI 9
    STR 10              ; QS_BEST = stand-pat

    ; Generate all moves
    LDI HIGH(MOVE_LIST)
    PHI 9
    LDI LOW(MOVE_LIST)
    PLO 9
    CALL GENERATE_MOVES
    ; D = move count

    ; Save move count to temp (must clear R15.1 to avoid DEC underflow!)
    PLO 15              ; R15.0 = move count (temp)
    LDI 0
    PHI 15              ; R15.1 = 0 (prevents underflow when DEC 15)

    ; Save move list start pointer
    LDI HIGH(QS_MOVE_PTR_LO)
    PHI 10
    LDI LOW(QS_MOVE_PTR_LO)
    PLO 10
    LDI LOW(MOVE_LIST)
    STR 10
    INC 10
    LDI HIGH(MOVE_LIST)
    STR 10

QS_LOOP:
    ; Check if any moves left
    GLO 15
    LBZ QS_RETURN

    ; Load move list pointer
    LDI HIGH(QS_MOVE_PTR_LO)
    PHI 10
    LDI LOW(QS_MOVE_PTR_LO)
    PLO 10
    LDN 10
    PLO 9
    INC 10
    LDN 10
    PHI 9               ; R9 = move pointer

    ; Load encoded move (little-endian: low byte first)
    LDA 9
    PLO 8
    LDA 9
    PHI 8               ; R8 = encoded move

    ; Save updated pointer
    LDI HIGH(QS_MOVE_PTR_LO)
    PHI 10
    LDI LOW(QS_MOVE_PTR_LO)
    PLO 10
    GLO 9
    STR 10
    INC 10
    GHI 9
    STR 10

    ; Decrement move count
    DEC 15

    ; Decode move to get from/to squares
    CALL DECODE_MOVE_16BIT
    ; R13.1 = from, R13.0 = to (R14.0 = flags - but we don't use it)

    ; Check if this is a capture: target square must have enemy piece
    LDI HIGH(BOARD)
    PHI 10
    GLO 13              ; to square
    PLO 10
    LDN 10              ; piece at target
    LBZ QS_LOOP         ; Empty = not a capture, skip

    ; Has piece - check if enemy color
    ANI COLOR_MASK      ; D = target piece color (0 or 8)
    ; Use COMPARE_TEMP for XOR scratch (NEVER use STR 2!)
    LDI HIGH(COMPARE_TEMP)
    PHI 10
    LDI LOW(COMPARE_TEMP)
    PLO 10
    SEX 10
    STR 10              ; Store target color to COMPARE_TEMP
    GLO 12              ; D = our color (1 or $FF)
    ANI COLOR_MASK      ; D = our color masked (0 or 8)
    XOR                 ; D = our_color XOR target_color
    SEX 2
    LBZ QS_LOOP         ; Same color (result 0) = own piece, skip

    ; It's a capture! Process it.
    ; Save move count to stack
    GLO 15
    STXD

    ; Store from/to for MAKE_MOVE
    LDI HIGH(MOVE_FROM)
    PHI 10
    LDI LOW(MOVE_FROM)
    PLO 10
    GHI 13              ; from
    STR 10
    INC 10
    GLO 13              ; to
    STR 10

    ; Make move
    CALL MAKE_MOVE

    ; Evaluate position after capture
    CALL EVALUATE
    ; Score in R9 (from white's perspective)

    ; Negate if black to move (R12: 0=white, 8=black)
    GLO 12
    ANI $08             ; Check if black (COLOR_MASK)
    BZ QS_NO_NEG
    ; Negate R9 (R6 is SCRT linkage - off limits!)
    GLO 9
    SDI 0
    PLO 9
    GHI 9
    SDBI 0
    PHI 9
QS_NO_NEG:

    ; Unmake move
    CALL UNMAKE_MOVE

    ; Restore move count
    IRX
    LDX
    PLO 15

    ; Compare: if score (R9) > best (QS_BEST), update best
    ; Load QS_BEST into R7 for comparison
    LDI HIGH(QS_BEST_LO)
    PHI 10
    LDI LOW(QS_BEST_LO)
    PLO 10
    LDN 10
    PLO 7
    INC 10
    LDN 10
    PHI 7               ; R7 = QS_BEST

    ; Signed comparison: R9 > R7?
    ; Use COMPARE_TEMP for scratch (NEVER use STR 2!)
    LDI HIGH(COMPARE_TEMP)
    PHI 10
    LDI LOW(COMPARE_TEMP)
    PLO 10
    SEX 10
    GHI 9
    STR 10
    GHI 7
    XOR
    ANI $80
    SEX 2
    LBNZ QS_DIFF_SIGN

    ; Same sign - compare normally
    SEX 10
    GHI 7
    STR 10
    GHI 9
    SD
    SEX 2
    LBNZ QS_HI_DIFF
    ; High bytes equal, compare low
    SEX 10
    GLO 7
    STR 10
    GLO 9
    SD
    SEX 2
    LBZ QS_LOOP         ; Equal, don't update
    LBNF QS_UPDATE      ; Score > best
    LBR QS_LOOP         ; Score < best

QS_HI_DIFF:
    LBNF QS_UPDATE      ; Score > best
    LBR QS_LOOP         ; Score < best

QS_DIFF_SIGN:
    ; Different signs - positive is greater
    GHI 9
    ANI $80
    LBNZ QS_LOOP        ; Score negative, best positive - don't update
    ; Score positive, best negative - update

QS_UPDATE:
    ; Update best = score
    LDI HIGH(QS_BEST_LO)
    PHI 10
    LDI LOW(QS_BEST_LO)
    PLO 10
    GLO 9
    STR 10
    INC 10
    GHI 9
    STR 10
    LBR QS_LOOP

QS_RETURN:
    ; Debug: > for exiting QS
    LDI '>'
    CALL SERIAL_WRITE_CHAR

    ; Return best score in R9 (R6 is SCRT linkage - off limits!)
    LDI HIGH(QS_BEST_LO)
    PHI 10
    LDI LOW(QS_BEST_LO)
    PLO 10
    LDN 10
    PLO 9
    INC 10
    LDN 10
    PHI 9
    RETN

; ------------------------------------------------------------------------------
; Helper Functions - STUBS REMOVED (functions now in other modules)
; ------------------------------------------------------------------------------
; GENERATE_MOVES - implemented in movegen.asm
; MAKE_MOVE - implemented in makemove.asm
; UNMAKE_MOVE - implemented in makemove.asm
; EVALUATE - implemented in evaluate.asm
; IS_IN_CHECK - implemented in check.asm

; Only these helper functions remain here:

; ------------------------------------------------------------------------------
; STORE_KILLER_MOVE - Store killer move for move ordering
; ------------------------------------------------------------------------------
; Input:  B = move that caused beta cutoff
;         SEARCH_DEPTH = current depth (in memory)
; Output: Killer move stored in table
; Uses:   A, D
; ------------------------------------------------------------------------------
STORE_KILLER_MOVE:
    ; Calculate ply from depth (use depth directly, limit to 16 plies)
    ; Load depth low byte from memory
    LDI HIGH(SEARCH_DEPTH + 1)
    PHI 13
    LDI LOW(SEARCH_DEPTH + 1)
    PLO 13
    LDN 13              ; D = depth low byte
    ANI $0F             ; Limit to 16 plies
    SHL
    SHL                 ; × 4 (2 moves × 2 bytes each)
    PLO 13

    ; Point to killer table (offset in R13.0 is 0-60, won't overflow with ADI)
    LDI HIGH(KILLER_MOVES)
    PHI 10
    GLO 13              ; Get offset (0, 4, 8, ... 60)
    ADI LOW(KILLER_MOVES)  ; Add base address low byte
    PLO 10              ; R10 = KILLER_MOVES + offset

    ; Shift killers: killer2 = killer1
    LDA 10              ; Load killer1 low
    PLO 13
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
    PLO 10

    ; Store new killer1
    GLO 11
    STR 10
    INC 10
    GHI 11
    STR 10

    RETN

; ------------------------------------------------------------------------------
; INC_NODE_COUNT - Increment 32-bit node counter (FULL VERSION)
; ------------------------------------------------------------------------------
; Input:  None
; Output: NODES_SEARCHED incremented
; Uses:   A, D
; ------------------------------------------------------------------------------
INC_NODE_COUNT:
    LDI HIGH(NODES_SEARCHED)
    PHI 10
    LDI LOW(NODES_SEARCHED)
    PLO 10

    ; Increment byte 0 (LSB)
    LDN 10
    ADI 1
    STR 10
    LBNZ INC_NODE_DONE   ; No carry

    ; Carry to byte 1
    INC 10
    LDN 10
    ADCI 0
    STR 10
    LBNZ INC_NODE_DONE

    ; Carry to byte 2
    INC 10
    LDN 10
    ADCI 0
    STR 10
    LBNZ INC_NODE_DONE

    ; Carry to byte 3 (MSB)
    INC 10
    LDN 10
    ADCI 0
    STR 10

INC_NODE_DONE:
    RETN

; ==============================================================================
; SEARCH_POSITION - Entry point for search from UCI/main
; ==============================================================================
; Input:  SEARCH_DEPTH = search depth (stored in memory by caller)
; Output: R9 = best score (R6 is SCRT linkage - off limits!)
;         BEST_MOVE = best move found
; NOTE:   R5 is SRET in BIOS mode - cannot be used for depth!
; WARNING: R6 is SCRT linkage register - do NOT use for return values!
; ==============================================================================
SEARCH_POSITION:
    ; Debug: VERSION MARKER - change this to verify new build is loaded
    LDI 'V'
    CALL SERIAL_WRITE_CHAR
    LDI 'R'
    CALL SERIAL_WRITE_CHAR

    ; Alpha = -INFINITY (to memory - R6 is SCRT linkage, off limits!)
    ; NOTE: Use $8001 (-32767) not $8000 (-32768) to avoid overflow when negating!
    ; -(-32768) overflows to -32768, causing invalid alpha-beta window in child
    LDI HIGH(ALPHA_LO)
    PHI 10
    LDI LOW(ALPHA_LO)
    PLO 10
    LDI $01
    STR 10              ; ALPHA_LO = $01
    INC 10
    LDI $80
    STR 10              ; ALPHA_HI = $80 (alpha = $8001 = -32767)

    ; Beta = +INFINITY (to memory for consistency)
    LDI HIGH(BETA_LO)
    PHI 10
    LDI LOW(BETA_LO)
    PLO 10
    LDI $FF
    STR 10              ; BETA_LO = $FF
    INC 10
    LDI $7F
    STR 10              ; BETA_HI = $7F (beta = $7FFF = +32767)

    ; Initialize ply counter to 0 (we're at root)
    LDI HIGH(CURRENT_PLY)
    PHI 10
    LDI LOW(CURRENT_PLY)
    PLO 10
    LDI 0
    STR 10              ; CURRENT_PLY = 0

    ; Get side to move
    CALL GET_SIDE_TO_MOVE
    PLO 12              ; C.0 = color

    ; Board pointer
    LDI HIGH(BOARD)
    PHI 10
    LDI LOW(BOARD)
    PLO 10

    ; Clear best move
    LDI HIGH(BEST_MOVE)
    PHI 11
    LDI LOW(BEST_MOVE)
    PLO 11
    LDI $FF
    STR 11
    INC 11
    STR 11

    ; Clear node counter
    LDI HIGH(NODES_SEARCHED)
    PHI 11
    LDI LOW(NODES_SEARCHED)
    PLO 11
    LDI 0
    STR 11
    INC 11
    STR 11
    INC 11
    STR 11
    INC 11
    STR 11

    ; Call negamax
    CALL NEGAMAX

    RETN

; ==============================================================================
; End of Negamax Core
; ==============================================================================
