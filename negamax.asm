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
; NOTE: Alpha/beta stored in memory at ALPHA_HI/LO, BETA_HI/LO (big-endian)
; NOTE: Search depth stored in memory at SEARCH_DEPTH (not in a register)
; ------------------------------------------------------------------------------

; Memory locations for search state - defined in board-0x88.asm:
;   BEST_MOVE, NODES_SEARCHED, SEARCH_DEPTH, QS_*, EVAL_SQ_INDEX, KILLER_MOVES
;   ALPHA_HI/LO, BETA_HI/LO, SCORE_HI/LO (big-endian: high byte at lower address)
; All engine variables consolidated at $6400+ region

; ------------------------------------------------------------------------------
; NEGAMAX - Main recursive search function
; ------------------------------------------------------------------------------
; Input:  SEARCH_DEPTH = depth remaining in memory (0 = leaf node, evaluate)
;         ALPHA_HI/LO = alpha (lower bound) in memory (big-endian)
;         BETA_HI/LO = beta (upper bound) in memory (big-endian)
;         C = color (0 for white, 8 for black - matches COLOR_MASK)
;         A = board state pointer
; Output: R9 = score from current position
;         BEST_MOVE = best move found (if at root)
; Uses:   All registers 7-F, stack
; NOTE:   R6 is SCRT linkage register - never used for data!
; ------------------------------------------------------------------------------
NEGAMAX:
    ; Ensure X=2 for stack operations
    SEX 2

    ; -----------------------------------------------
    ; PLY LIMIT CHECK: Prevent array overflow
    ; -----------------------------------------------
    ; If CURRENT_PLY >= MAX_PLY (8), return static eval
    RLDI 10, CURRENT_PLY
    LDN 10              ; D = current ply
    SMI 8               ; D = ply - MAX_PLY
    LBNF NEGAMAX_PLY_OK ; ply < 8, continue

    ; Ply limit reached - return static evaluation
    CALL EVALUATE
    ; R9 has score, negate if black
    GLO 12
    ANI $08
    LBZ NEGAMAX_PLY_RET
    GLO 9
    SDI 0
    PLO 9
    GHI 9
    SDBI 0
    PHI 9
NEGAMAX_PLY_RET:
    RETN

NEGAMAX_PLY_OK:
    ; Save context to ply-indexed state array (no stack manipulation!)
    CALL SAVE_PLY_STATE

    ; -- TT node flag: default ALPHA (upper bound) --
    RLDI 10, CURRENT_PLY
    LDN 10
    ADI LOW(NODE_TT_FLAGS)
    PLO 10
    LDI HIGH(NODE_TT_FLAGS)
    PHI 10
    LDI TT_FLAG_ALPHA
    STR 10

    ; Increment node counter (for statistics)
    CALL INC_NODE_COUNT

    ; -----------------------------------------------
    ; RTC TIME TRACKING: Always update elapsed time
    ; -----------------------------------------------
    ; Read RTC on every node so elapsed time is accurate.
    ; Only check abort flag and enforce budget during d3+.

    ; --- RTC elapsed time check ---
    ; Read current seconds from DS12887 (binary mode)
    LDI $80                     ; Seconds register
    STR 2
    OUT 2                       ; Select register, R2++
    DEC 2                       ; Restore R2
    INP 3                       ; D = current_secs, M(R2) = current_secs
    PLO 7                       ; R7.0 = current_secs (R7 saved by SAVE_PLY_STATE)

    ; Load prev_secs, save for delta computation
    RLDI 13, SEARCH_PREV_SECS
    LDN 13                      ; D = prev_secs
    PHI 7                       ; R7.1 = prev_secs

    ; Update prev = current
    GLO 7                       ; D = current_secs
    STR 13                      ; SEARCH_PREV_SECS = current_secs

    ; Compute delta = current - prev
    GHI 7                       ; D = prev_secs
    STR 2                       ; M(R2) = prev_secs
    GLO 7                       ; D = current_secs
    SM                          ; D = current - prev (SM = D - M(R(X)))
    LBDF RTC_DELTA_POS          ; DF=1: no borrow, delta >= 0
    ADI 60                      ; Wrapped past 59→0: add 60
RTC_DELTA_POS:
    ; D = delta seconds (typically 0 or 1)

    ; Add delta to elapsed counter
    STR 2                       ; M(R2) = delta
    RLDI 13, SEARCH_ELAPSED
    LDN 13                      ; D = elapsed so far
    ADD                         ; D = elapsed + delta
    LBNF RTC_NO_SAT             ; DF=0: no carry, fits in 8 bits
    LDI 255                     ; Saturate at 255
RTC_NO_SAT:
    STR 13                      ; SEARCH_ELAPSED = updated value

    ; -----------------------------------------------
    ; ABORT CHECK: Only enforce budget during d3+
    ; -----------------------------------------------
    ; Depth 1-2 always complete; only abort d3+ if over budget
    RLDI 13, CURRENT_MAX_DEPTH
    LDN 13                      ; D = current iteration depth
    SMI 3
    LBNF NEGAMAX_BUDGET_OK      ; depth < 3, skip abort check

    ; --- Abort flag check (propagate up recursion during d3) ---
    RLDI 13, SEARCH_ABORTED
    LDN 13
    LBNZ NEGAMAX_ABORT_RETURN   ; Already aborted, bail out

    ; Check: elapsed >= 120 seconds?
    RLDI 13, SEARCH_ELAPSED
    LDN 13                      ; Reload elapsed (clobbered above)
    SMI 120                     ; D = elapsed - 120
    LBNF NEGAMAX_BUDGET_OK      ; DF=0: elapsed < 120, continue

    ; Time exceeded — set abort flag
    RLDI 13, SEARCH_ABORTED
    LDI 1
    STR 13

NEGAMAX_ABORT_RETURN:
    ; Restore ply state and return dummy score
    CALL RESTORE_PLY_STATE
    LDI 0
    PHI 9
    PLO 9                       ; R9 = 0 (score irrelevant, will be discarded)
    RETN

NEGAMAX_BUDGET_OK:

    ; -----------------------------------------------
    ; FIFTY-MOVE RULE: Check for draw
    ; -----------------------------------------------
    ; If halfmove clock >= 100, position is a draw
    RLDI 13, GAME_STATE + STATE_HALFMOVE
    LDN 13               ; D = halfmove clock
    SMI 100             ; D = halfmove - 100
    LBNF NEGAMAX_NOT_FIFTY ; If < 100, continue normally (long branch - crosses page)

    ; Draw return — shared by fifty-move rule and repetition detection
RETURN_DRAW:
    LDI 0
    PHI 9
    PLO 9               ; R9 = 0 (draw score) - R6 is SCRT linkage!
    ; Save score to SCORE_HI/LO BEFORE restore (RESTORE clobbers R9!)
    RLDI 10, SCORE_HI
    GHI 9
    STR 10
    INC 10
    GLO 9
    STR 10              ; SCORE_HI/LO = 0 (draw)
    CALL RESTORE_PLY_STATE
    ; Reload R9 from SCORE_HI/LO AFTER restore
    RLDI 10, SCORE_HI
    LDA 10
    PHI 9
    LDN 10
    PLO 9               ; R9 = draw score (0)
    RETN

NEGAMAX_NOT_FIFTY:
    ; -----------------------------------------------
    ; REPETITION DETECTION: Check game position history
    ; -----------------------------------------------
    ; Skip at root (ply 0) — root position is the last HASH_HIST
    ; entry and would always match itself.
    RLDI 10, CURRENT_PLY
    LDN 10
    LBZ REP_NO_MATCH

    ; Load current hash into R8
    RLDI 10, HASH_HI
    LDA 10              ; D = HASH_HI
    PHI 8
    LDN 10              ; D = HASH_LO
    PLO 8               ; R8 = current position hash

    ; Load history count
    RLDI 13, HASH_HIST_COUNT
    LDN 13
    LBZ REP_NO_MATCH    ; Empty history
    PLO 11              ; R11.0 = loop counter

    RLDI 9, HASH_HIST   ; R9 → first entry

REP_CHECK_LOOP:
    ; Compare hi byte
    LDA 9               ; D = hist[i].hi, R9→lo byte
    STR 2               ; temp at M(R2)
    GHI 8               ; D = current.hi
    XOR                 ; compare
    LBNZ REP_SKIP_LO   ; Hi mismatch

    ; Hi matched — compare lo byte
    LDA 9               ; D = hist[i].lo, R9→next entry
    STR 2
    GLO 8               ; D = current.lo
    XOR
    LBZ RETURN_DRAW     ; MATCH! Return draw (shared code)
    LBR REP_DEC         ; Mismatch, R9 already past both bytes

REP_SKIP_LO:
    INC 9               ; Skip lo byte

REP_DEC:
    DEC 11
    GLO 11
    LBNZ REP_CHECK_LOOP

REP_NO_MATCH:
    ; -----------------------------------------------
    ; Transposition Table Probe
    ; -----------------------------------------------
    ; Hash is updated incrementally in MAKE/UNMAKE_MOVE,
    ; so TT works correctly at all nodes.
    ;
    ; Skip TT at root (ply 0): TT_STORE saves the root's BEST_MOVE
    ; globally, so non-root TT entries have stale/sentinel move data.
    ; Root must always search fully to guarantee a valid BEST_MOVE.
    RLDI 10, CURRENT_PLY
    LDN 10              ; D = current ply
    LBZ NEGAMAX_TT_MISS ; Root: always search fully

    ; Load current search depth for comparison
    RLDI 13, SEARCH_DEPTH + 1
    LDN 13              ; D = depth low byte (SEARCH_DEPTH+1 = low byte)
    CALL TT_PROBE       ; D = required depth, returns D = 1 if hit
    LBZ NEGAMAX_TT_MISS ; No hit, continue with search

    ; TT hit - check if it's usable (EXACT bound)
    RLDI 10, TT_FLAG
    LDN 10              ; D = TT flag
    XRI TT_FLAG_EXACT
    LBNZ NEGAMAX_TT_MISS    ; Not exact, can't use directly (for now)

    ; EXACT hit at non-root node - use the stored score
    ; (Root is excluded above, so no BEST_MOVE copy needed)

    ; Get the score and save to SCORE_HI/LO BEFORE restore
    ; (RESTORE_PLY_STATE clobbers R9!)
    RLDI 10, TT_SCORE_HI
    LDA 10              ; score_hi
    PHI 9
    LDN 10              ; score_lo
    PLO 9               ; R9 = stored score
    ; Save to SCORE_HI/LO so it survives RESTORE
    RLDI 10, SCORE_HI
    GHI 9
    STR 10
    INC 10
    GLO 9
    STR 10              ; SCORE_HI/LO = TT score
    CALL RESTORE_PLY_STATE
    ; Reload R9 from SCORE_HI/LO AFTER restore
    RLDI 10, SCORE_HI
    LDA 10
    PHI 9
    LDN 10
    PLO 9               ; R9 = TT score (preserved through restore)
    RETN                ; Return TT score

NEGAMAX_TT_MISS:
    ; -----------------------------------------------
    ; Check if we're at a leaf node (depth == 0)
    ; -----------------------------------------------
    ; Load depth from memory (SEARCH_DEPTH)
    RLDI 13, SEARCH_DEPTH
    LDA 13              ; D = depth high byte
    LBNZ NEGAMAX_CONTINUE
    LDN 13              ; D = depth low byte
    LBNZ NEGAMAX_CONTINUE
    ; Depth is 0, evaluate leaf node
    LBR NEGAMAX_LEAF

NEGAMAX_CONTINUE:
    ; ===============================================
    ; NULL MOVE PRUNING CHECK
    ; ===============================================
    ; If position is so strong that passing still beats beta, prune.
    ; Conditions: depth >= 3, not in check, NULL_MOVE_OK, ply > 0

    ; Condition 1: depth >= 3?
    RLDI 10, SEARCH_DEPTH + 1
    LDN 10              ; D = depth low byte
    SMI 3               ; D = depth - 3
    LBNF NMP_SKIP       ; depth < 3, skip null move

    ; Condition 2: ply > 0? (don't do at root)
    RLDI 10, CURRENT_PLY
    LDN 10              ; D = current ply
    LBZ NMP_SKIP        ; ply == 0, skip null move

    ; Condition 3: NULL_MOVE_OK?
    RLDI 10, NULL_MOVE_OK
    LDN 10
    LBZ NMP_SKIP        ; null move not allowed (already did one)

    ; Condition 4: NOT in check? (already verified above for non-CE path)
    CALL IS_IN_CHECK
    ; D = 1 if in check, 0 if safe
    LBNZ NMP_SKIP       ; in check, can't pass

    ; --- All conditions met, try null move ---

    ; Disable null move for child (prevent consecutive)
    RLDI 10, NULL_MOVE_OK
    LDI 0
    STR 10              ; NULL_MOVE_OK = 0

    ; Save depth to stack
    RLDI 13, SEARCH_DEPTH
    LDA 13              ; depth_hi
    STXD
    LDN 13              ; depth_lo
    STXD

    ; Save alpha/beta to stack
    RLDI 13, ALPHA_HI
    LDA 13              ; alpha_hi
    STXD
    LDN 13              ; alpha_lo
    STXD
    RLDI 13, BETA_HI
    LDA 13              ; beta_hi
    STXD
    LDN 13              ; beta_lo
    STXD

    ; Make null move (toggle side, update hash, clear EP)
    CALL NULL_MAKE_MOVE

    ; Set child depth = depth - 3 (R=2 reduction + normal -1)
    ; Peek depth from stack (at R2+5, R2+6)
    GLO 2
    ADI 6
    PLO 10
    GHI 2
    ADCI 0
    PHI 10              ; R10 = &depth_hi on stack
    LDN 10              ; depth_hi
    PHI 7               ; R7.1 = depth_hi
    DEC 10
    LDN 10              ; depth_lo
    SMI 3               ; depth_lo - 3
    PLO 7
    GHI 7
    SMBI 0              ; depth_hi - borrow
    PHI 7               ; R7 = depth - 3

    ; Store child depth to memory
    RLDI 10, SEARCH_DEPTH
    GHI 7
    STR 10
    INC 10
    GLO 7
    STR 10              ; SEARCH_DEPTH = depth - 3

    ; Set child alpha = -beta (zero window)
    ; Peek beta from stack (at R2+1, R2+2)
    GLO 2
    ADI 2
    PLO 10
    GHI 2
    ADCI 0
    PHI 10              ; R10 = &beta_hi on stack
    LDN 10              ; beta_hi
    PHI 7
    DEC 10
    LDN 10              ; beta_lo
    PLO 7               ; R7 = beta

    ; Negate beta for child alpha
    GLO 7
    SDI 0               ; -beta_lo
    PLO 8
    GHI 7
    SDBI 0              ; -beta_hi
    PHI 8               ; R8 = -beta = child alpha

    ; Store as new alpha
    RLDI 10, ALPHA_HI
    GHI 8
    STR 10
    INC 10
    GLO 8
    STR 10              ; ALPHA = -beta

    ; Set child beta = -beta + 1 (zero window)
    GLO 8
    ADI 1
    PLO 8
    GHI 8
    ADCI 0
    PHI 8               ; R8 = -beta + 1

    RLDI 10, BETA_HI
    GHI 8
    STR 10
    INC 10
    GLO 8
    STR 10              ; BETA = -beta + 1

    ; Toggle color for child
    GLO 12
    XRI $08
    PLO 12

    ; Increment ply
    RLDI 10, CURRENT_PLY
    LDN 10
    ADI 1
    STR 10              ; CURRENT_PLY++

    ; Recursive call
    CALL NEGAMAX
    ; R9 = score

    ; Decrement ply
    RLDI 10, CURRENT_PLY
    LDN 10
    SMI 1
    STR 10              ; CURRENT_PLY--

    ; Toggle color back
    GLO 12
    XRI $08
    PLO 12

    ; Negate score: score = -score
    GLO 9
    SDI 0
    PLO 9
    GHI 9
    SDBI 0
    PHI 9               ; R9 = -score

    ; Unmake null move (toggle side back, restore EP, update hash)
    CALL NULL_UNMAKE_MOVE

    ; Re-enable null move for this level
    RLDI 10, NULL_MOVE_OK
    LDI 1
    STR 10              ; NULL_MOVE_OK = 1

    ; Pop beta from stack into R7
    IRX
    LDXA                ; beta_lo
    PLO 7
    LDX                 ; beta_hi (R2 now at beta_hi slot)
    PHI 7               ; R7 = original beta

    ; Pop alpha from stack into R8
    IRX
    LDXA                ; alpha_lo
    PLO 8
    LDX                 ; alpha_hi
    PHI 8               ; R8 = original alpha

    ; Pop depth from stack and restore to memory
    IRX
    LDXA                ; depth_lo
    PLO 13
    LDX                 ; depth_hi
    PHI 13              ; R13 = original depth

    RLDI 10, SEARCH_DEPTH
    GHI 13
    STR 10
    INC 10
    GLO 13
    STR 10              ; SEARCH_DEPTH restored
    ; R7 = original beta, R8 = original alpha (for NMP_NO_CUTOFF path)

    ; Compare: score (R9) >= beta (R7)? If so, prune!
    ; Signed 16-bit comparison

    RLDI 10, COMPARE_TEMP
    SEX 10

    ; Check if signs differ
    GHI 9               ; score_hi
    STR 10
    GHI 7               ; beta_hi
    XOR
    ANI $80             ; Check sign bit difference
    SEX 2
    LBNZ NMP_CHECK_SIGN

    ; Same sign: score >= beta if (score - beta) has no borrow
    SEX 10
    GLO 7               ; beta_lo
    STR 10
    GLO 9               ; score_lo
    SM                  ; score_lo - beta_lo
    GHI 7               ; beta_hi
    STR 10
    GHI 9               ; score_hi
    SMB                 ; score_hi - beta_hi - borrow
    SEX 2
    LBNF NMP_NO_CUTOFF  ; Borrow set = score < beta
    LBR NMP_CUTOFF      ; No borrow = score >= beta

NMP_CHECK_SIGN:
    ; Different signs: positive >= negative always
    ; If score positive (hi bit 0) and beta negative (hi bit 1): score >= beta
    GHI 9               ; score_hi
    ANI $80
    LBNZ NMP_NO_CUTOFF  ; score negative, beta positive: score < beta
    ; score positive, beta negative: score >= beta
    ; Fall through to cutoff

NMP_CUTOFF:
    ; Null move cutoff! Return beta
    ; Save beta to SCORE memory (same pattern as NEGAMAX_RETURN)
    RLDI 10, SCORE_HI
    GHI 7               ; beta_hi
    STR 10
    INC 10
    GLO 7               ; beta_lo
    STR 10              ; SCORE = beta

    CALL RESTORE_PLY_STATE

    ; Load return value from SCORE memory into R9 (after restore)
    RLDI 10, SCORE_HI
    LDA 10              ; SCORE_HI
    PHI 9
    LDN 10              ; SCORE_LO
    PLO 9               ; R9 = beta

    RETN

NMP_NO_CUTOFF:
    ; Null move didn't cause cutoff - restore alpha/beta to memory
    ; R8 = original alpha, R7 = original beta
    RLDI 10, ALPHA_HI
    GHI 8
    STR 10
    INC 10
    GLO 8
    STR 10              ; ALPHA = original alpha

    RLDI 10, BETA_HI
    GHI 7
    STR 10
    INC 10
    GLO 7
    STR 10              ; BETA = original beta
    ; Fall through to normal move generation

NMP_SKIP:
    ; -----------------------------------------------
    ; REVERSE FUTILITY PRUNING (RFP)
    ; -----------------------------------------------
    ; At depth 1-2, if static_eval - margin >= beta, prune entire node.
    ; The position is so good that the opponent can't recover.
    ;
    ; Conditions: depth <= 2, ply > 0, not in check

    ; Condition 1: depth <= 2?
    RLDI 10, SEARCH_DEPTH + 1
    LDN 10              ; D = depth low byte
    SMI 3               ; D = depth - 3
    LBDF RFP_SKIP       ; depth >= 3, skip RFP

    ; Condition 2: ply > 0? (don't prune at root)
    RLDI 10, CURRENT_PLY
    LDN 10              ; D = current ply
    LBZ RFP_SKIP        ; ply == 0, skip

    ; Condition 3: not in check?
    CALL IS_IN_CHECK
    ; D = 1 if in check, 0 if safe
    LBNZ RFP_SKIP       ; in check, can't prune

    ; --- All conditions met ---
    ; Get static eval
    CALL EVALUATE
    ; R9 = score from white's perspective

    ; Negate if black to move (R12: 0=white, 8=black)
    GLO 12
    ANI $08
    LBZ RFP_NO_NEG
    GLO 9
    SDI 0
    PLO 9
    GHI 9
    SDBI 0
    PHI 9
RFP_NO_NEG:
    ; R9 = eval from side-to-move perspective (negamax convention)

    ; Save eval in SCORE_HI/LO (for return value if we prune)
    RLDI 10, SCORE_HI
    GHI 9
    STR 10
    INC 10
    GLO 9
    STR 10              ; SCORE_HI/LO = eval

    ; Select margin based on depth
    ; Load depth again
    RLDI 10, SEARCH_DEPTH + 1
    LDN 10              ; D = depth (1 or 2)
    SMI 2
    LBNF RFP_DEPTH1     ; depth < 2, so depth == 1

    ; Depth 2: subtract 300cp margin
    GLO 9
    SMI RFP_MARGIN_D2_LO
    PLO 9
    GHI 9
    SMBI RFP_MARGIN_D2_HI
    PHI 9
    LBR RFP_COMPARE

RFP_DEPTH1:
    ; Depth 1: subtract 150cp margin
    GLO 9
    SMI RFP_MARGIN_D1_LO
    PLO 9
    GHI 9
    SMBI RFP_MARGIN_D1_HI
    PHI 9

RFP_COMPARE:
    ; R9 = eval - margin
    ; Compare: (eval - margin) >= beta (R7)?
    ; Signed 16-bit comparison using same pattern as NMP

    RLDI 10, COMPARE_TEMP
    SEX 10

    ; Check if signs differ
    GHI 9               ; (eval-margin)_hi
    STR 10
    GHI 7               ; beta_hi
    XOR
    ANI $80             ; Check sign bit difference
    SEX 2
    LBNZ RFP_CHECK_SIGN

    ; Same sign: (eval-margin) >= beta if no borrow
    SEX 10
    GLO 7               ; beta_lo
    STR 10
    GLO 9               ; (eval-margin)_lo
    SM                  ; (eval-margin)_lo - beta_lo
    GHI 7               ; beta_hi
    STR 10
    GHI 9               ; (eval-margin)_hi
    SMB                 ; (eval-margin)_hi - beta_hi - borrow
    SEX 2
    LBNF RFP_SKIP       ; Borrow = eval-margin < beta, don't prune
    LBR RFP_PRUNE       ; No borrow = eval-margin >= beta, prune!

RFP_CHECK_SIGN:
    ; Different signs: positive >= negative always
    GHI 9               ; (eval-margin)_hi
    ANI $80
    LBNZ RFP_SKIP       ; eval-margin negative, beta positive: don't prune
    ; eval-margin positive, beta negative: prune
    ; Fall through to RFP_PRUNE

RFP_PRUNE:
    ; Return eval (saved in SCORE_HI/LO)
    CALL RESTORE_PLY_STATE
    ; Reload R9 from SCORE_HI/LO after restore
    RLDI 10, SCORE_HI
    LDA 10
    PHI 9
    LDN 10
    PLO 9               ; R9 = eval score
    RETN

RFP_SKIP:
    ; -----------------------------------------------
    ; Generate moves for current position
    ; -----------------------------------------------
    ; Use ply-indexed move list to avoid overwrites during recursion!
    ; Each ply gets 128 bytes (64 moves): PLY 0 at $6200, PLY 1 at $6280, etc.
    ; ply × 128 overflows 8 bits for ply >= 2, so use 16-bit math:
    ;   offset_hi = ply >> 1, offset_lo = (ply & 1) << 7

    RLDI 10, CURRENT_PLY
    LDN 10              ; D = current ply (0-3)

    ; Calculate high byte: HIGH(MOVE_LIST) + (ply >> 1)
    SHR                 ; D = ply >> 1 (0 or 1)
    ADI HIGH(MOVE_LIST) ; D = $62 + (ply >> 1)
    PHI 9               ; R9.1 = high byte

    ; Calculate low byte: (ply & 1) << 7 = $00 or $80
    LDN 10              ; D = ply (reload)
    ANI $01             ; D = ply & 1
    LBZ NEGAMAX_PLY_EVEN
    LDI $80             ; Odd ply: low byte = $80
    LBR NEGAMAX_PLY_DONE
NEGAMAX_PLY_EVEN:
    LDI $00             ; Even ply: low byte = $00
NEGAMAX_PLY_DONE:
    PLO 9               ; R9 = ply-indexed move list

    CALL GENERATE_MOVES
    ; Returns: D = move count
    ; NOTE: R9 now points PAST the end of the move list!

    ; Save move count to stack
    STXD

    ; Reset R9 to START of ply-indexed move list (128 bytes per ply)
    RLDI 10, CURRENT_PLY
    LDN 10              ; D = current ply

    ; Calculate high byte: HIGH(MOVE_LIST) + (ply >> 1)
    SHR                 ; D = ply >> 1
    ADI HIGH(MOVE_LIST)
    PHI 9

    ; Calculate low byte: (ply & 1) << 7
    LDN 10              ; D = ply (reload)
    ANI $01
    LBZ NEGAMAX_RESET_EVEN
    LDI $80
    LBR NEGAMAX_RESET_DONE
NEGAMAX_RESET_EVEN:
    LDI $00
NEGAMAX_RESET_DONE:
    PLO 9               ; R9 = ply-indexed move list start

    ; -----------------------------------------------
    ; Apply killer move ordering (search killers first)
    ; Only at ply 0-2 to avoid overhead deep in tree
    ; -----------------------------------------------
    RLDI 10, CURRENT_PLY
    LDN 10              ; D = current ply
    SMI 3               ; Check if ply >= 3
    LBDF NEGAMAX_SKIP_KILLER  ; Skip if ply >= 3

    INC 2               ; Point to move count on stack
    LDN 2               ; D = move count (peek, don't pop)
    DEC 2               ; Restore stack pointer
    CALL ORDER_KILLER_MOVES

NEGAMAX_SKIP_KILLER:
    ; -----------------------------------------------
    ; Order captures first (MVV-LVA preparation)
    ; Only at ply 0-2 to avoid overhead deep in tree
    ; -----------------------------------------------
    RLDI 10, CURRENT_PLY
    LDN 10              ; D = current ply
    SMI 3               ; Check if ply >= 3
    LBDF NEGAMAX_SKIP_CAPTURE_ORDER  ; Skip if ply >= 3

    INC 2               ; Point to move count on stack
    LDN 2               ; D = move count (peek, don't pop)
    DEC 2               ; Restore stack pointer
    CALL ORDER_CAPTURES_FIRST

NEGAMAX_SKIP_CAPTURE_ORDER:

    ; -----------------------------------------------
    ; Initialize best score to -INFINITY in memory
    ; -----------------------------------------------
    ; Using memory avoids register clobbering bugs!
    RLDI 10, BEST_SCORE_HI
    LDI $80
    STR 10              ; BEST_SCORE_HI = $80
    INC 10
    LDI $01
    STR 10              ; BEST_SCORE_LO = $01 (best = $8001 = -32767, safe to negate)

    ; -----------------------------------------------
    ; Futility Pruning Setup (depth 1 only)
    ; -----------------------------------------------
    ; Clear futility flag first
    RLDI 10, FUTILITY_OK
    LDI 0
    STR 10              ; FUTILITY_OK = 0 (disabled by default)

    ; Check if depth == 1 (frontier node)
    RLDI 13, SEARCH_DEPTH
    LDA 13              ; D = depth high byte
    LBNZ NEGAMAX_SKIP_FUTILITY  ; depth > 255, skip
    LDN 13              ; D = depth low byte
    XRI 1               ; Check if depth == 1
    LBNZ NEGAMAX_SKIP_FUTILITY  ; Not depth 1, skip

    ; Check guard: don't enable futility if side is in check
    ; (escape moves must not be pruned — mirrors RFP guard at line 563)
    CALL IS_IN_CHECK    ; R12 = our color; D = 1 if in check
    LBNZ NEGAMAX_SKIP_FUTILITY  ; in check, skip futility

    ; Depth == 1: Cache static eval for futility pruning
    CALL EVALUATE       ; Returns score in R9
    ; Store in STATIC_EVAL (big-endian)
    RLDI 10, STATIC_EVAL_HI
    GHI 9
    STR 10              ; STATIC_EVAL_HI
    INC 10
    GLO 9
    STR 10              ; STATIC_EVAL_LO

    ; Enable futility pruning for this node
    RLDI 10, FUTILITY_OK
    LDI 1
    STR 10              ; FUTILITY_OK = 1

    ; FIX: EVALUATE clobbered R9 (move list pointer) with eval score.
    ; Re-initialize R9 to move list start for this ply.
    RLDI 10, CURRENT_PLY
    LDN 10              ; D = current ply
    SHR                 ; D = ply >> 1
    ADI HIGH(MOVE_LIST)
    PHI 9               ; R9.1 = HIGH(MOVE_LIST) + (ply >> 1)
    LDN 10              ; D = ply (reload)
    ANI $01
    LBZ NEGAMAX_FUTILITY_R9_EVEN
    LDI $80
    LBR NEGAMAX_FUTILITY_R9_DONE
NEGAMAX_FUTILITY_R9_EVEN:
    LDI $00
NEGAMAX_FUTILITY_R9_DONE:
    PLO 9               ; R9 = ply-indexed move list start

NEGAMAX_SKIP_FUTILITY:

    ; Initialize LMR move counter to 0
    RLDI 10, LMR_MOVE_INDEX
    LDI 0
    STR 10              ; LMR_MOVE_INDEX = 0

    ; Check if there are any legal moves
    INC 2               ; Point R2 at move count
    LDN 2               ; Peek at move count
    DEC 2               ; Restore stack pointer
    LBNZ NEGAMAX_HAS_MOVES  ; Long branch (may cross page boundary)
    ; No legal moves - checkmate or stalemate
    LBR NEGAMAX_NO_MOVES

NEGAMAX_HAS_MOVES:
NEGAMAX_MOVE_LOOP:
    ; -----------------------------------------------
    ; Loop through all moves
    ; -----------------------------------------------
    ; Restore move count
    INC 2              ; Point R2 at move count
    LDN 2              ; Peek at move count (don't pop)
    DEC 2              ; Restore stack pointer
    LBZ NEGAMAX_RETURN  ; No moves left

    ; Get next move from list (big-endian: high byte first)
    LDA 9              ; Load high byte of move
    PHI 8
    LDA 9              ; Load low byte of move
    PLO 8              ; R8 = current move (16-bit encoded)

    ; Save R9 (move pointer) to ply-indexed memory (not stack!)
    ; This avoids stack alignment bugs across the large move loop
    RLDI 10, CURRENT_PLY
    LDN 10              ; D = ply
    SHL                 ; D = ply * 2
    ADI LOW(LOOP_MOVE_PTR)
    PLO 10
    LDI HIGH(LOOP_MOVE_PTR)
    PHI 10              ; R10 = LOOP_MOVE_PTR + ply*2
    GHI 9
    STR 10              ; Save R9.hi
    INC 10
    GLO 9
    STR 10              ; Save R9.lo

    ; Decode move: R8 → R13 (from/to)
    CALL DECODE_MOVE_16BIT
    ; R13.1 = from square, R13.0 = to square

    ; Store to MOVE_FROM/MOVE_TO for MAKE_MOVE
    RLDI 10, MOVE_FROM
    GHI 13              ; from
    STR 10
    INC 10
    GLO 13              ; to
    STR 10

    ; -----------------------------------------------
    ; Set LMR_IS_CAPTURE flag based on target square
    ; -----------------------------------------------
    ; R13.0 still has 'to' square from DECODE_MOVE_16BIT
    LDI HIGH(BOARD)
    PHI 10
    GLO 13              ; D = to square
    PLO 10              ; R10 = BOARD + to_square
    LDN 10              ; D = piece at target (0 if empty)
    PLO 7               ; Save piece in R7.0 (temp)
    RLDI 10, LMR_IS_CAPTURE
    GLO 7               ; Restore piece
    LBZ LMR_NOT_CAPTURE
    LDI 1               ; Non-empty = capture
    BR LMR_CAPTURE_DONE
LMR_NOT_CAPTURE:
    LDI 0               ; Empty = not capture
LMR_CAPTURE_DONE:
    STR 10              ; Store flag

    ; -----------------------------------------------
    ; Futility Pruning Check (depth 1 quiet moves)
    ; -----------------------------------------------
    ; Only apply at frontier nodes (remaining depth == 1).
    ; SEARCH_DEPTH is the remaining depth at this node (decremented
    ; by parent before recursion), so check SEARCH_DEPTH == 1 directly.
    ; This matches the futility setup code which also checks depth == 1.

    ; Check: is remaining depth == 1? (SEARCH_DEPTH low byte)
    RLDI 10, SEARCH_DEPTH + 1
    LDN 10              ; D = SEARCH_DEPTH low byte (remaining depth)
    XRI 1               ; Check if depth == 1
    LBNZ NEGAMAX_NOT_FUTILE  ; Not frontier node, skip futility

    ; Check if move is a capture (target square non-empty)
    RLDI 10, MOVE_TO
    LDN 10              ; D = to square
    PLO 10              ; R10.0 = to square
    LDI HIGH(BOARD)
    PHI 10              ; R10 = BOARD + to_square
    LDN 10              ; D = piece at target
    LBNZ NEGAMAX_NOT_FUTILE  ; Non-empty = capture, don't prune

    ; Not a capture - check if static_eval + margin < alpha
    ; Load STATIC_EVAL into R11
    RLDI 10, STATIC_EVAL_HI
    LDA 10              ; STATIC_EVAL_HI
    PHI 11
    LDN 10              ; STATIC_EVAL_LO
    PLO 11              ; R11 = static eval

    ; Add FUTILITY_MARGIN (150 = $0096)
    GLO 11
    ADI FUTILITY_MARGIN_D1_LO  ; Add low byte
    PLO 11
    GHI 11
    ADCI FUTILITY_MARGIN_D1_HI ; Add high byte with carry
    PHI 11              ; R11 = static_eval + margin

    ; Futility: prune if static_eval is very negative (losing badly)
    ; Simple check: if static_eval < -MARGIN, prune quiet moves
    ; This avoids the alpha comparison complexity in negamax
    ; Check if R11 (static_eval + margin) high byte has sign bit set
    ; If static_eval + margin < 0, we're down by more than margin, prune
    GHI 11              ; (eval+margin) high byte
    ANI $80             ; Check sign bit
    LBZ NEGAMAX_NOT_FUTILE  ; Sign bit clear = positive, don't prune

    ; Futile! Skip this move
    ; Restore R9 from ply-indexed memory
    RLDI 10, CURRENT_PLY
    LDN 10              ; D = ply
    SHL                 ; D = ply * 2
    ADI LOW(LOOP_MOVE_PTR)
    PLO 10
    LDI HIGH(LOOP_MOVE_PTR)
    PHI 10              ; R10 = LOOP_MOVE_PTR + ply*2
    LDA 10
    PHI 9               ; R9.hi
    LDN 10
    PLO 9               ; R9 = move list pointer restored

    ; Jump to decrement move count and continue loop
    LBR NEGAMAX_NEXT_MOVE

NEGAMAX_NOT_FUTILE:

    ; Set UNDO_PROMOTION based on move flags
    ; Must be done before MAKE_MOVE so promotions work correctly
    RLDI 10, UNDO_PROMOTION
    RLDI 13, DECODED_FLAGS
    LDN 13              ; D = flags
    XRI MOVE_PROMOTION  ; == $03?
    LBNZ NM_NOT_PROMO
    LDI QUEEN_TYPE      ; Promote to queen ($05)
    LBR NM_SET_PROMO
NM_NOT_PROMO:
    LDI 0               ; Not a promotion
NM_SET_PROMO:
    STR 10              ; UNDO_PROMOTION = QUEEN_TYPE or 0

    ; Make the move on the board
    CALL MAKE_MOVE

    ; -----------------------------------------------
    ; LEGALITY CHECK: Does this move leave our king in check?
    ; MAKE_MOVE does NOT toggle R12 - only SIDE in memory.
    ; R12 still contains our color (the side that just moved).
    ; -----------------------------------------------
    CALL IS_IN_CHECK
    ; D = 1 if our king is in check (illegal move), 0 if safe

    ; If in check, this move is illegal - unmake and skip
    LBZ NEGAMAX_MOVE_LEGAL  ; D=0 means not in check, move is legal

    ; ILLEGAL MOVE: Our king is in check after this move
    ; Unmake the move and continue to next move
    CALL UNMAKE_MOVE

    ; R12 stays as our color (UNMAKE_MOVE doesn't toggle R12)

    ; Restore R9 from ply-indexed memory and skip to next move
    RLDI 10, CURRENT_PLY
    LDN 10              ; D = ply
    SHL                 ; D = ply * 2
    ADI LOW(LOOP_MOVE_PTR)
    PLO 10
    LDI HIGH(LOOP_MOVE_PTR)
    PHI 10              ; R10 = LOOP_MOVE_PTR + ply*2
    LDA 10
    PHI 9               ; R9.hi
    LDN 10
    PLO 9               ; R9 = move list pointer restored

    LBR NEGAMAX_NEXT_MOVE   ; Skip this illegal move

NEGAMAX_MOVE_LEGAL:
    ; --- Check extension: does this move give check? ---
    GLO 12
    XRI 8
    PLO 12              ; R12 = opponent's color
    CALL IS_IN_CHECK    ; Check opponent's king
    ; D = 1 if giving check (RLDI does NOT clobber D)
    RLDI 10, CHECK_EXT_FLAG
    STR 10              ; Save result (0 or 1)
    GLO 12
    XRI 8
    PLO 12              ; R12 = our color restored

    ; -----------------------------------------------
    ; LMR Check: Should we reduce this move's search?
    ; -----------------------------------------------
    ; Clear LMR_REDUCED flag first
    RLDI 10, LMR_REDUCED
    LDI 0
    STR 10              ; LMR_REDUCED = 0 (default)

    ; Condition 1: LMR_MOVE_INDEX >= 4?
    RLDI 10, LMR_MOVE_INDEX
    LDN 10              ; D = moves searched so far
    SMI 4               ; D = index - 4
    LBNF LMR_SKIP       ; < 4, skip LMR

    ; Condition 2: SEARCH_DEPTH >= 3?
    RLDI 10, SEARCH_DEPTH + 1
    LDN 10              ; D = depth low byte
    SMI 3               ; D = depth - 3
    LBNF LMR_SKIP       ; < 3, skip LMR

    ; Condition 3: Not a capture?
    RLDI 10, LMR_IS_CAPTURE
    LDN 10              ; D = capture flag
    LBNZ LMR_SKIP       ; Is capture, skip LMR

    ; All conditions met - set LMR_REDUCED = 1
    RLDI 10, LMR_REDUCED
    LDI 1
    STR 10              ; LMR_REDUCED = 1

LMR_SKIP:

    ; -----------------------------------------------
    ; Save depth to stack and decrement for recursive call
    ; (PUSH ORDER: R9/R8, depth, alpha/beta, UNDO_* - pop in reverse!)
    ; -----------------------------------------------
    ; First, save current depth to stack for later restore
    RLDI 13, SEARCH_DEPTH
    LDA 13              ; D = depth high
    STXD
    LDN 13              ; D = depth low
    STXD                ; Stack now has: ... [depth_hi] [depth_lo]

    ; Now decrement depth in memory
    RLDI 13, SEARCH_DEPTH + 1
    LDN 13              ; D = depth low
    SMI 1
    STR 13              ; Store decremented low byte
    DEC 13              ; Point to high byte
    LDN 13              ; D = depth high
    SMBI 0              ; Subtract borrow
    STR 13              ; Store decremented high byte

    ; -----------------------------------------------
    ; LMR: Extra depth decrement if flag is set
    ; -----------------------------------------------
    RLDI 10, LMR_REDUCED
    LDN 10              ; D = LMR_REDUCED flag
    LBZ LMR_NO_EXTRA_DEC ; Not reduced, skip extra decrement

    ; LMR applies - decrement depth by 1 MORE (depth now = original - 2)
    RLDI 13, SEARCH_DEPTH + 1
    LDN 13              ; D = depth low
    SMI 1
    STR 13              ; depth_lo--
    DEC 13              ; Point to high byte
    LDN 13              ; D = depth high
    SMBI 0              ; Subtract borrow
    STR 13              ; depth_hi-- (with borrow)

LMR_NO_EXTRA_DEC:
    ; -----------------------------------------------
    ; Check extension: if move gives check AND depth is
    ; at the horizon (depth <= 0 after decrement), undo
    ; the decrement so checking move stays in main search
    ; where checkmate can be detected (QS can't detect it)
    ; -----------------------------------------------
    RLDI 10, CHECK_EXT_FLAG
    LDN 10              ; D = check flag
    LBZ CE_DONE         ; Not giving check, skip

    ; Only extend at horizon: depth <= 0 after decrement
    RLDI 13, SEARCH_DEPTH
    LDA 13              ; D = depth_hi
    LBNZ CE_DONE        ; depth_hi != 0, not at horizon
    LDN 13              ; D = depth_lo
    LBNZ CE_DONE        ; depth_lo != 0, not at horizon

    ; Depth is 0 — about to drop to QS. Undo decrement (+1)
    LDI 1
    STR 13              ; depth_lo = 1
    ; depth_hi stays 0 (already confirmed)

CE_DONE:
    ; -----------------------------------------------
    ; Negate and swap alpha/beta (memory-based - R6 is SCRT linkage!)
    ; -----------------------------------------------
    ; For negamax: score = -negamax(depth-1, -beta, -alpha, -color)

    ; Save current alpha and beta from memory to stack
    ; Load alpha from memory (big-endian: HI at lower address)
    RLDI 13, ALPHA_HI
    LDA 13              ; D = alpha_hi
    STXD
    LDN 13              ; D = alpha_lo
    STXD
    ; Load beta from memory (big-endian: HI at lower address)
    RLDI 13, BETA_HI
    LDA 13              ; D = beta_hi
    STXD
    LDN 13              ; D = beta_lo
    STXD
    ; Stack now has: [beta_lo][beta_hi][alpha_lo][alpha_hi][depth]...

    ; -----------------------------------------------
    ; Save UNDO_* to stack (7 bytes) for recursive safety
    ; Child calls will overwrite UNDO_*, so we must save it
    ; Push LAST so it gets popped FIRST (LIFO order!)
    ; -----------------------------------------------
    RLDI 10, UNDO_CAPTURED
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
    ; UNDO_PROMOTION is at $6404 (not contiguous)
    RLDI 10, UNDO_PROMOTION
    LDN 10              ; UNDO_PROMOTION
    STXD

    ; -----------------------------------------------
    ; Save BEST_SCORE to stack (2 bytes) for recursive safety
    ; Child calls will reinitialize BEST_SCORE to -infinity!
    ; -----------------------------------------------
    RLDI 10, BEST_SCORE_HI
    LDA 10              ; BEST_SCORE_HI
    STXD
    LDN 10              ; BEST_SCORE_LO
    STXD
    ; Stack now has: [BEST_SCORE][UNDO_*][beta][alpha][depth][R9]...

    ; Compute new_alpha = -beta, new_beta = -alpha
    ; Load beta from memory, negate, store as new alpha
    ; Big-endian: HI at lower address, must negate low byte first for borrow
    RLDI 13, BETA_LO
    LDN 13              ; D = beta_lo (at higher address)
    SDI 0               ; D = -beta_lo
    PLO 7               ; R7.0 = -beta_lo
    DEC 13              ; Point back to BETA_HI
    LDN 13              ; D = beta_hi
    SDBI 0              ; D = -beta_hi (with borrow)
    PHI 7               ; R7.1 = -beta_hi, R7 = -beta

    ; Load alpha from memory, negate
    RLDI 13, ALPHA_LO
    LDN 13              ; D = alpha_lo (at higher address)
    SDI 0               ; D = -alpha_lo
    PLO 8               ; R8.0 = -alpha_lo
    DEC 13              ; Point back to ALPHA_HI
    LDN 13              ; D = alpha_hi
    SDBI 0              ; D = -alpha_hi (with borrow)
    PHI 8               ; R8.1 = -alpha_hi, R8 = -alpha

    ; Now swap: new_alpha = -beta (in R7), new_beta = -alpha (in R8)
    ; Store to memory (big-endian: high byte at lower address)
    RLDI 13, ALPHA_HI
    GHI 7
    STR 13              ; ALPHA_HI = -beta high
    INC 13
    GLO 7
    STR 13              ; ALPHA_LO = -beta low

    RLDI 13, BETA_HI
    GHI 8
    STR 13              ; BETA_HI = -alpha high
    INC 13
    GLO 8
    STR 13              ; BETA_LO = -alpha low

    ; Toggle color (C): 0=white, 8=black (matches COLOR_MASK)
    GLO 12
    XRI $08             ; Toggle between 0 and 8
    PLO 12

    ; Increment ply counter before recursion
    RLDI 10, CURRENT_PLY
    LDN 10
    ADI 1
    STR 10              ; CURRENT_PLY++

    ; -----------------------------------------------
    ; Push LMR state to stack (overwritten by recursive call)
    ; -----------------------------------------------
    ; Push LMR_MOVE_INDEX first (popped last)
    RLDI 10, LMR_MOVE_INDEX
    LDN 10              ; D = LMR_MOVE_INDEX
    STXD                ; Push to stack
    ; Push LMR_REDUCED second (popped first)
    RLDI 10, LMR_REDUCED
    LDN 10              ; D = LMR_REDUCED flag
    STXD                ; Push to stack

    ; -----------------------------------------------
    ; Recursive call to NEGAMAX
    ; -----------------------------------------------
    CALL NEGAMAX
    ; Returns score in R9 (R6 is SCRT linkage - off limits!)

    ; -----------------------------------------------
    ; Pop LMR state (reverse order)
    ; -----------------------------------------------
    ; Pop LMR_REDUCED and save to LMR_OUTER
    IRX
    LDX                 ; D = saved LMR_REDUCED (R2 stays at this slot)
    PLO 7               ; Save in R7.0 (temp)
    RLDI 10, LMR_OUTER
    GLO 7               ; Restore LMR_REDUCED value
    STR 10              ; LMR_OUTER = saved LMR_REDUCED
    ; Pop LMR_MOVE_INDEX and restore to memory
    IRX
    LDX                 ; D = saved LMR_MOVE_INDEX
    PLO 7               ; Temp in R7.0
    RLDI 10, LMR_MOVE_INDEX
    GLO 7
    STR 10              ; LMR_MOVE_INDEX restored

    ; Decrement ply counter after recursion
    RLDI 10, CURRENT_PLY
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
    ; Big-endian: high byte at lower address (SCORE_HI)
    RLDI 10, SCORE_HI
    GHI 9               ; High byte first
    STR 10
    INC 10
    GLO 9               ; Low byte second
    STR 10              ; SCORE_HI/LO = negated score

    ; -----------------------------------------------
    ; LMR Re-search Check: Did reduced search beat alpha?
    ; -----------------------------------------------
    ; Read LMR_OUTER from memory (LMR_REDUCED was cleared by recursive call)
    RLDI 10, LMR_OUTER
    LDN 10              ; D = LMR_OUTER flag
    LBZ LMR_NO_RESEARCH ; Not reduced, skip re-search check

    ; Peek alpha from stack (alpha_hi at R2+13, alpha_lo at R2+12)
    GLO 2
    ADI 13              ; Calculate offset to alpha_hi
    PLO 10
    GHI 2
    ADCI 0
    PHI 10              ; R10 = address of alpha_hi on stack
    LDN 10              ; D = alpha_hi
    PHI 7               ; R7.1 = alpha_hi
    DEC 10              ; Point to alpha_lo (R2+11)
    LDN 10              ; D = alpha_lo
    PLO 7               ; R7 = parent's alpha (big-endian)

    ; Load score from SCORE_HI/LO
    RLDI 10, SCORE_HI
    LDA 10              ; D = score_hi
    PHI 13
    LDN 10              ; D = score_lo
    PLO 13              ; R13 = score

    ; Signed comparison: score (R13) > alpha (R7)?
    ; Use COMPARE_TEMP for scratch
    RLDI 10, COMPARE_TEMP
    SEX 10              ; X = R10 for comparisons

    ; Check if signs differ
    GHI 13              ; score_hi
    STR 10
    GHI 7               ; alpha_hi
    XOR
    ANI $80             ; Check sign bits differ
    SEX 2               ; Restore X = R2
    LBNZ LMR_RESEARCH_DIFF_SIGN

    ; Same sign: score > alpha if score - alpha > 0 (positive, no borrow)
    SEX 10
    GLO 7               ; alpha_lo
    STR 10
    GLO 13              ; score_lo
    SM                  ; D = score_lo - alpha_lo
    PHI 8               ; Save low result in R8.1
    GHI 7               ; alpha_hi
    STR 10
    GHI 13              ; score_hi
    SMB                 ; D = score_hi - alpha_hi - borrow
    SEX 2               ; Restore X = R2
    LBNF LMR_NO_RESEARCH ; Borrow = score <= alpha, no re-search
    LBNZ LMR_DO_RESEARCH ; High bytes differ and positive
    GHI 8               ; Check saved low result
    LBZ LMR_NO_RESEARCH  ; Equal (both zero), no re-search
    LBR LMR_DO_RESEARCH

LMR_RESEARCH_DIFF_SIGN:
    ; Different signs: positive > negative
    GHI 13              ; score_hi
    ANI $80
    LBNZ LMR_NO_RESEARCH ; score negative, alpha positive: score < alpha

LMR_DO_RESEARCH:
    ; Re-search needed! Score beat alpha on reduced search.

    ; Clear LMR_REDUCED so we don't re-search again
    RLDI 10, LMR_REDUCED
    LDI 0
    STR 10

    ; Increment SEARCH_DEPTH by 1 (undo the extra LMR reduction)
    ; Current depth = original - 2, we want original - 1
    RLDI 13, SEARCH_DEPTH + 1
    LDN 13              ; D = depth_lo
    ADI 1
    STR 13              ; depth_lo++
    DEC 13              ; Point to high byte
    LDN 13              ; D = depth_hi
    ADCI 0              ; Add carry
    STR 13              ; depth_hi++ (with carry)

    ; Re-setup alpha/beta for child (same swap as original)
    ; Peek parent's beta from stack (beta_hi at R2+11, beta_lo at R2+10)
    GLO 2
    ADI 11
    PLO 10
    GHI 2
    ADCI 0
    PHI 10              ; R10 = address of beta_hi on stack
    LDN 10              ; D = beta_hi
    PHI 8
    DEC 10              ; Point to beta_lo
    LDN 10              ; D = beta_lo
    PLO 8               ; R8 = parent's beta

    ; new_alpha = -beta (negate R8)
    GLO 8
    SDI 0
    PLO 7               ; R7.0 = -beta_lo
    GHI 8
    SDBI 0
    PHI 7               ; R7 = -beta = new_alpha

    ; Peek parent's alpha again (R2+13, R2+12)
    GLO 2
    ADI 13
    PLO 10
    GHI 2
    ADCI 0
    PHI 10
    LDN 10              ; D = alpha_hi
    PHI 8
    DEC 10
    LDN 10              ; D = alpha_lo
    PLO 8               ; R8 = parent's alpha

    ; new_beta = -alpha (negate R8)
    GLO 8
    SDI 0
    PLO 8               ; R8.0 = -alpha_lo
    GHI 8
    SDBI 0
    PHI 8               ; R8 = -alpha = new_beta

    ; Store new alpha/beta to memory
    RLDI 10, ALPHA_HI
    GHI 7               ; new_alpha_hi
    STR 10
    INC 10
    GLO 7               ; new_alpha_lo
    STR 10              ; ALPHA = -beta

    RLDI 10, BETA_HI
    GHI 8               ; new_beta_hi
    STR 10
    INC 10
    GLO 8               ; new_beta_lo
    STR 10              ; BETA = -alpha

    ; Increment ply for recursive call
    RLDI 10, CURRENT_PLY
    LDN 10
    ADI 1
    STR 10              ; CURRENT_PLY++

    ; Call NEGAMAX again (full depth this time)
    CALL NEGAMAX

    ; Decrement ply
    RLDI 10, CURRENT_PLY
    LDN 10
    SMI 1
    STR 10              ; CURRENT_PLY--

    ; Negate returned score
    GLO 9
    SDI 0
    PLO 9
    GHI 9
    SDBI 0
    PHI 9               ; R9 = -score

    ; Save to SCORE_HI/LO
    RLDI 10, SCORE_HI
    GHI 9               ; High byte
    STR 10
    INC 10
    GLO 9               ; Low byte
    STR 10              ; SCORE_HI/LO = re-search score

LMR_NO_RESEARCH:

    ; -----------------------------------------------
    ; Restore BEST_SCORE from stack FIRST (it was pushed last - LIFO!)
    ; This was corrupted by child's NEGAMAX initialization!
    ; -----------------------------------------------
    RLDI 10, BEST_SCORE_LO
    IRX
    LDXA                ; BEST_SCORE_LO
    STR 10
    DEC 10
    LDX                 ; BEST_SCORE_HI (R2 stays at this slot)
    STR 10

    ; -----------------------------------------------
    ; Restore UNDO_* from stack (7 bytes) before UNMAKE_MOVE
    ; -----------------------------------------------
    ; UNDO_PROMOTION first (it was pushed last - LIFO)
    RLDI 10, UNDO_PROMOTION
    IRX
    LDX                 ; UNDO_PROMOTION
    STR 10
    ; Now restore the contiguous block ($6408-$640D)
    RLDI 10, UNDO_HALFMOVE
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
    ; Stack order (low to high): beta_lo, beta_hi, alpha_lo, alpha_hi, depth_lo, depth_hi, R9

    ; Pop beta from stack to BETA memory (big-endian)
    IRX                 ; Point to beta_lo
    LDXA                ; D = beta_lo
    PLO 7               ; R7.0 = beta_lo
    LDXA                ; D = beta_hi
    PHI 7               ; R7.1 = beta_hi, R7 = beta
    RLDI 13, BETA_HI
    GHI 7
    STR 13              ; BETA_HI (high byte at lower addr)
    INC 13
    GLO 7
    STR 13              ; BETA_LO (low byte at higher addr)

    ; Pop alpha from stack to ALPHA memory (NO extra IRX - R2 already at alpha_lo)
    LDXA                ; D = alpha_lo
    PLO 7               ; R7.0 = alpha_lo
    LDXA                ; D = alpha_hi
    PHI 7               ; R7.1 = alpha_hi, R7 = alpha
    RLDI 13, ALPHA_HI
    GHI 7
    STR 13              ; ALPHA_HI (high byte at lower addr)
    INC 13
    GLO 7
    STR 13              ; ALPHA_LO (low byte at higher addr)

    ; Pop depth from stack to SEARCH_DEPTH memory
    ; Stack has: depth_lo, depth_hi (depth_lo at lower addr)
    ; R9 no longer on stack - depth_hi is directly below move_count
    LDXA                ; D = depth_lo, R2 advances to depth_hi
    PLO 7               ; Temp
    LDX                 ; D = depth_hi, R2 stays (one below move_count)
    PHI 7               ; R7 = depth (temp: hi.lo)
    RLDI 13, SEARCH_DEPTH
    GHI 7
    STR 13              ; SEARCH_DEPTH high
    INC 13
    GLO 7
    STR 13              ; SEARCH_DEPTH+1 low

    ; Toggle color back to parent's color (0/8)
    GLO 12
    XRI $08
    PLO 12              ; C = color restored

    ; Restore R9 (move list pointer) from ply-indexed memory
    RLDI 10, CURRENT_PLY
    LDN 10              ; D = ply
    SHL                 ; D = ply * 2
    ADI LOW(LOOP_MOVE_PTR)
    PLO 10
    LDI HIGH(LOOP_MOVE_PTR)
    PHI 10              ; R10 = LOOP_MOVE_PTR + ply*2
    LDA 10
    PHI 9               ; R9.hi
    LDN 10
    PLO 9               ; R9 = move list pointer restored

    ; Load score from SCORE memory into R13 (R9 is move list pointer!)
    ; Big-endian: high byte at lower address (SCORE_HI)
    RLDI 10, SCORE_HI
    LDA 10              ; SCORE_HI -> high byte
    PHI 13
    LDN 10              ; SCORE_LO -> low byte
    PLO 13              ; R13 = negated score from memory

    ; -----------------------------------------------
    ; Beta Cutoff Check: if (score >= beta) return beta
    ; -----------------------------------------------
    ; Compare score (R13) with beta (from BETA memory)
    ; Score is already saved to SCORE_HI/LO, can reload if needed

    ; Load beta from memory into R7 (use R10 as pointer, preserve R13=score)
    ; Big-endian: high byte at lower address (BETA_HI)
    RLDI 10, BETA_HI
    LDA 10              ; D = beta_hi
    PHI 7
    LDN 10              ; D = beta_lo
    PLO 7               ; R7 = beta (loaded from memory)

    ; SIGNED comparison: score (R13) vs beta (R7)
    ; Use COMPARE_TEMP for scratch (NEVER use STR 2 for scratch!)
    RLDI 10, COMPARE_TEMP
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
    ; Compute score - beta: SM does D - M(X), SD does M(X) - D
    SEX 10
    GLO 7
    STR 10              ; M(R10) = beta_lo
    GLO 13              ; D = score_lo
    SM                  ; D = D - M(X) = score_lo - beta_lo
    GHI 7
    STR 10              ; M(R10) = beta_hi
    GHI 13              ; D = score_hi
    SMB                 ; D = D - M(X) - borrow = score_hi - beta_hi - borrow
    SEX 2               ; X = R2 (restore)

    ; Check sign bit (negative means score < beta, no cutoff)
    ANI $80
    LBNZ NEGAMAX_NO_BETA_CUTOFF  ; score < beta, no cutoff
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
    ; Store beta to BEST_SCORE memory for return

    ; Store beta (R7) to BEST_SCORE memory
    RLDI 10, BEST_SCORE_HI
    GHI 7               ; Beta high byte
    STR 10
    INC 10
    GLO 7               ; Beta low byte
    STR 10

    ; At root (ply 0), save the cutoff move as BEST_MOVE.
    ; Beta cutoff means this move is "too good" - but at root there's
    ; no parent to reject it, so it IS the best move. Without this,
    ; BEST_MOVE stays at $FF/$FF sentinel → h@h@ output.
    RLDI 10, CURRENT_PLY
    LDN 10              ; D = current ply
    LBNZ NEGAMAX_BETA_NOT_ROOT

    ; At root: save UNDO_FROM/UNDO_TO to BEST_MOVE
    RLDI 10, UNDO_FROM
    LDA 10              ; UNDO_FROM
    PHI 8               ; Temp in R8.1
    LDN 10              ; UNDO_TO
    PLO 8               ; R8 = from/to

    RLDI 10, BEST_MOVE
    GHI 8
    STR 10              ; BEST_MOVE[0] = from
    INC 10
    GLO 8
    STR 10              ; BEST_MOVE[1] = to

NEGAMAX_BETA_NOT_ROOT:
    ; Decrement move count before returning
    INC 2
    LDN 2
    SMI 1
    STR 2
    DEC 2

    ; Store killer move (for move ordering optimization)
    CALL STORE_KILLER_MOVE

    ; -- TT node flag: BETA (lower bound) --
    RLDI 10, CURRENT_PLY
    LDN 10
    ADI LOW(NODE_TT_FLAGS)
    PLO 10
    LDI HIGH(NODE_TT_FLAGS)
    PHI 10
    LDI TT_FLAG_BETA
    STR 10

    LBR NEGAMAX_RETURN

NEGAMAX_NO_BETA_CUTOFF:
    ; Score is already in R13 from earlier load (before beta check)
    ; R9 = move list pointer (preserved)

    ; Load best score from memory into R8 for comparison
    RLDI 10, BEST_SCORE_HI
    LDA 10              ; BEST_SCORE_HI
    PHI 8
    LDN 10              ; BEST_SCORE_LO
    PLO 8               ; R8 = best score from memory

    ; -----------------------------------------------
    ; Update best score: if (score > maxScore) maxScore = score
    ; -----------------------------------------------
    ; SIGNED comparison of score (R13) vs best (R8)
    ; Use COMPARE_TEMP for scratch (NEVER use STR 2 for scratch!)
    RLDI 10, COMPARE_TEMP
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
    ; Score is better, update best score in memory (R13 -> BEST_SCORE)
    RLDI 10, BEST_SCORE_HI
    GHI 13              ; Score high byte
    STR 10
    INC 10
    GLO 13              ; Score low byte
    STR 10              ; BEST_SCORE = score

    ; -----------------------------------------------
    ; If at root (PLY == 0), save this move to BEST_MOVE
    ; -----------------------------------------------
    RLDI 10, CURRENT_PLY
    LDN 10              ; Get current ply
    LBNZ NEGAMAX_UPDATE_ALPHA  ; Not at root, skip BEST_MOVE but still update alpha

    ; At root - save move to BEST_MOVE from UNDO_FROM/UNDO_TO
    RLDI 10, UNDO_FROM
    LDA 10              ; UNDO_FROM
    PHI 7               ; Temp
    LDN 10              ; UNDO_TO
    PLO 7               ; R7 = from/to

    RLDI 10, BEST_MOVE
    GHI 7
    STR 10              ; BEST_MOVE[0] = from
    INC 10
    GLO 7
    STR 10              ; BEST_MOVE[1] = to

    ; Fall through to alpha update

NEGAMAX_UPDATE_ALPHA:
    ; -----------------------------------------------
    ; Update alpha: if (score > alpha) alpha = score
    ; -----------------------------------------------
    ; R13 = score (preserved from NEGAMAX_SCORE_BETTER entry)
    ; Load alpha from memory into R8
    RLDI 10, ALPHA_HI
    LDA 10
    PHI 8               ; R8.1 = alpha_hi
    LDN 10
    PLO 8               ; R8 = alpha

    ; Signed compare: score (R13) > alpha (R8)?
    RLDI 10, COMPARE_TEMP
    SEX 10

    ; Check if signs differ
    GHI 13              ; score_hi
    STR 10
    GHI 8               ; alpha_hi
    XOR
    ANI $80
    SEX 2
    LBNZ NEGAMAX_ALPHA_DIFF_SIGN

    ; Same sign: score > alpha if (score - alpha) > 0
    SEX 10
    GHI 8               ; alpha_hi
    STR 10
    GHI 13              ; score_hi
    SD                  ; D = score_hi - alpha_hi
    SEX 2
    LBNZ NEGAMAX_ALPHA_HI_DIFF
    ; High bytes equal, compare low
    SEX 10
    GLO 8               ; alpha_lo
    STR 10
    GLO 13              ; score_lo
    SD                  ; D = score_lo - alpha_lo
    SEX 2
    LBZ NEGAMAX_NEXT_MOVE           ; Equal, don't update
    LBNF NEGAMAX_ALPHA_DO_UPDATE    ; DF=0: score > alpha
    LBR NEGAMAX_NEXT_MOVE           ; DF=1: score < alpha

NEGAMAX_ALPHA_HI_DIFF:
    LBNF NEGAMAX_ALPHA_DO_UPDATE    ; DF=0: score > alpha
    LBR NEGAMAX_NEXT_MOVE           ; DF=1: score < alpha

NEGAMAX_ALPHA_DIFF_SIGN:
    ; Different signs: positive > negative
    GHI 13              ; score_hi
    ANI $80
    LBNZ NEGAMAX_NEXT_MOVE          ; Score negative, alpha positive - skip
    ; Score positive, alpha negative - update (fall through)

NEGAMAX_ALPHA_DO_UPDATE:
    ; alpha = score
    RLDI 10, ALPHA_HI
    GHI 13
    STR 10
    INC 10
    GLO 13
    STR 10              ; ALPHA = score

    ; -- TT node flag: EXACT (PV node) --
    RLDI 10, CURRENT_PLY
    LDN 10
    ADI LOW(NODE_TT_FLAGS)
    PLO 10
    LDI HIGH(NODE_TT_FLAGS)
    PHI 10
    LDI TT_FLAG_EXACT
    STR 10

NEGAMAX_NEXT_MOVE:
    ; -----------------------------------------------
    ; Increment LMR move counter (move was processed)
    ; -----------------------------------------------
    RLDI 10, LMR_MOVE_INDEX
    LDN 10
    ADI 1
    STR 10              ; LMR_MOVE_INDEX++

    ; -----------------------------------------------
    ; Decrement move counter and continue loop
    ; -----------------------------------------------
    IRX                ; Point to move_count
    LDX                ; Pop move count (R2 at now-empty slot)
    SMI 1              ; Decrement
    LBZ NEGAMAX_LOOP_DONE ; If count == 0, exit loop (long branch)
    STXD               ; Push decremented count
    LBR NEGAMAX_MOVE_LOOP

NEGAMAX_LOOP_DONE:
    ; Count reached 0 - R2 is AT move_count, need to put it BELOW
    DEC 2              ; Now R2 is below move_count, matching Path A

    ; Check if any legal move updated BEST_SCORE.
    ; If BEST_SCORE is still $8001 (initial sentinel), no legal move
    ; was found - all pseudo-legal moves left king in check.
    ; This is checkmate or stalemate; handle via NEGAMAX_NO_MOVES.
    ; (Stack state matches: R2 below move_count, same as line 734 path)
    RLDI 10, BEST_SCORE_HI
    LDA 10              ; D = BEST_SCORE_HI
    XRI $80
    LBNZ NEGAMAX_RETURN ; BEST_SCORE_HI != $80 → a legal move was scored
    LDN 10              ; D = BEST_SCORE_LO
    XRI $01
    LBNZ NEGAMAX_RETURN ; BEST_SCORE_LO != $01 → a legal move was scored

    ; BEST_SCORE == $8001: no legal move improved the sentinel.
    ; All pseudo-legal moves were illegal → checkmate or stalemate.
    LBR NEGAMAX_NO_MOVES

NEGAMAX_RETURN:
    ; -----------------------------------------------
    ; Return best score (from BEST_SCORE memory) via R9
    ; -----------------------------------------------
    ; Skip move count (1 byte) - IRX moves R2 to AT move_count, then
    ; CALL RESTORE will overwrite it with SCRT linkage. This effectively
    ; "pops" move_count without needing to read it.
    IRX

    ; Copy BEST_SCORE to SCORE memory BEFORE restore (RESTORE clobbers R9!)
    ; Best score is in BEST_SCORE_HI/LO, copy to SCORE_HI/LO for return
    RLDI 10, BEST_SCORE_HI
    LDA 10              ; BEST_SCORE_HI
    PHI 8               ; Temp in R8.1
    LDN 10              ; BEST_SCORE_LO
    PLO 8               ; Temp in R8.0

    RLDI 10, SCORE_HI
    GHI 8               ; Best score high byte
    STR 10
    INC 10
    GLO 8               ; Best score low byte
    STR 10

    ; -----------------------------------------------
    ; Store result in Transposition Table
    ; -----------------------------------------------
    ; Hash is updated incrementally in MAKE/UNMAKE_MOVE,
    ; so TT works correctly at all nodes.

    ; TT_STORE expects: D = depth, R8.0 = flag, SCORE_HI/LO and BEST_MOVE set
    ; -- Load TT node flag for current ply --
    RLDI 10, CURRENT_PLY
    LDN 10
    ADI LOW(NODE_TT_FLAGS)
    PLO 10
    LDI HIGH(NODE_TT_FLAGS)
    PHI 10
    LDN 10              ; D = flag
    PLO 8               ; R8.0 = flag
    RLDI 10, SEARCH_DEPTH + 1
    LDN 10              ; D = depth (low byte = actual depth)
    CALL TT_STORE

    ; Restore caller's context (clobbers R7, R8, R9, R11, R12)
    CALL RESTORE_PLY_STATE

    ; Load return value back into R9 AFTER restore
    ; Big-endian: load high byte from lower address first
    RLDI 10, SCORE_HI
    LDA 10              ; SCORE_HI -> high byte
    PHI 9
    LDN 10              ; SCORE_LO -> low byte
    PLO 9

    RETN

NEGAMAX_LEAF:
    ; -----------------------------------------------
    ; Leaf node - do quiescence search
    ; -----------------------------------------------
    CALL QUIESCENCE_SEARCH
    ; Returns score in R9 (already from side-to-move's perspective)

    ; Save return value to SCORE memory BEFORE restore (RESTORE clobbers R9!)
    ; Big-endian: store high byte at lower address (SCORE_HI), low at SCORE_LO
    RLDI 10, SCORE_HI
    GHI 9               ; Score high byte first
    STR 10
    INC 10
    GLO 9               ; Score low byte second
    STR 10

    ; Restore caller's context (clobbers R7, R8, R9, R11, R12)
    CALL RESTORE_PLY_STATE

    ; Load return value back into R9 AFTER restore
    ; Big-endian: load high byte from lower address first
    RLDI 10, SCORE_HI
    LDA 10              ; SCORE_HI -> high byte
    PHI 9
    LDN 10              ; SCORE_LO -> low byte
    PLO 9

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
    ; NOTE: Use $8001 (-32767) not $8000 (-32768) to avoid overflow when negating!
    ; -(-32768) = -32768 due to two's complement overflow, breaking score propagation!
    LDI $80
    PHI 9
    LDI $01
    PLO 9              ; R9 = -32767 (R6 is SCRT linkage - off limits!)

    ; Add depth to make closer mates better
    ; Load depth low byte from memory
    RLDI 13, SEARCH_DEPTH + 1
    LDN 13              ; D = depth low byte
    ; Use COMPARE_TEMP for ADD scratch (NEVER use STR 2!)
    RLDI 10, COMPARE_TEMP
    SEX 10
    STR 10
    GLO 9
    ADD
    SEX 2
    PLO 9
    ; High byte stays same (adding small depth won't overflow)

    ; Store checkmate score to BEST_SCORE memory for return
    RLDI 10, BEST_SCORE_HI
    GHI 9               ; Score high byte
    STR 10
    INC 10
    GLO 9               ; Score low byte
    STR 10

    ; -- TT node flag: EXACT (checkmate) --
    RLDI 10, CURRENT_PLY
    LDN 10
    ADI LOW(NODE_TT_FLAGS)
    PLO 10
    LDI HIGH(NODE_TT_FLAGS)
    PHI 10
    LDI TT_FLAG_EXACT
    STR 10

    LBR NEGAMAX_RETURN

NEGAMAX_STALEMATE:
    ; Stalemate - return 0 (draw)
    ; Store 0 to BEST_SCORE memory for return
    RLDI 10, BEST_SCORE_HI
    LDI 0
    STR 10              ; BEST_SCORE_HI = 0
    INC 10
    STR 10              ; BEST_SCORE_LO = 0

    ; -- TT node flag: EXACT (stalemate) --
    RLDI 10, CURRENT_PLY
    LDN 10
    ADI LOW(NODE_TT_FLAGS)
    PLO 10
    LDI HIGH(NODE_TT_FLAGS)
    PHI 10
    LDI TT_FLAG_EXACT
    STR 10

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
    ; Ensure X=2 for stack operations
    SEX 2

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
    ; Big-endian: high byte at lower address (QS_BEST_HI)
    RLDI 10, QS_BEST_HI
    GHI 9               ; High byte first
    STR 10
    INC 10
    GLO 9               ; Low byte second
    STR 10              ; QS_BEST = stand-pat

    ; -----------------------------------------------
    ; Stand-pat beta cutoff: if stand-pat >= beta, return
    ; (Position is already good enough, no need to search captures)
    ; -----------------------------------------------
    ; Load beta from memory (big-endian: HI at lower address)
    RLDI 10, BETA_HI
    LDA 10              ; beta high
    PHI 7
    LDN 10              ; beta low
    PLO 7               ; R7 = beta

    ; Compare: stand-pat (R9) >= beta (R7)?
    ; Signed comparison using COMPARE_TEMP
    RLDI 10, COMPARE_TEMP
    SEX 10
    GHI 9               ; stand-pat high
    STR 10
    GHI 7               ; beta high
    XOR
    ANI $80             ; Check if different signs
    SEX 2
    LBNZ QS_BETA_DIFF_SIGN

    ; Same sign - compare magnitudes
    ; stand-pat >= beta means stand-pat - beta >= 0, i.e., no borrow
    SEX 10
    GLO 7               ; beta low
    STR 10
    GLO 9               ; stand-pat low
    SM                  ; D = stand-pat_lo - beta_lo
    GHI 7               ; beta high
    STR 10
    GHI 9               ; stand-pat high
    SMB                 ; D = stand-pat_hi - beta_hi - borrow
    SEX 2
    LBDF QS_RETURN      ; No borrow = stand-pat >= beta, cutoff!
    LBR QS_NO_BETA_CUTOFF

QS_BETA_DIFF_SIGN:
    ; Different signs: positive >= negative always
    ; stand-pat positive (bit 7 = 0) means stand-pat >= beta
    GHI 9
    ANI $80
    LBZ QS_RETURN       ; stand-pat positive, beta negative -> cutoff

QS_NO_BETA_CUTOFF:
    ; -----------------------------------------------
    ; Alpha update: if stand-pat > alpha, alpha = stand-pat
    ; (Tightens window, makes beta cutoffs more likely)
    ; -----------------------------------------------
    ; Load alpha (R9 still has stand-pat)
    RLDI 10, ALPHA_HI
    LDA 10              ; alpha high
    PHI 7
    LDN 10              ; alpha low
    PLO 7               ; R7 = alpha

    ; Compare: stand-pat (R9) > alpha (R7)?
    RLDI 10, COMPARE_TEMP
    SEX 10
    GHI 9
    STR 10
    GHI 7
    XOR
    ANI $80
    SEX 2
    LBNZ QS_ALPHA_DIFF_SIGN

    ; Same sign - R9 > R7 means R9 - R7 > 0 (positive, no borrow, not zero)
    SEX 10
    GLO 7
    STR 10
    GLO 9
    SM                  ; D = stand-pat_lo - alpha_lo
    PHI 8               ; Save low result
    GHI 7
    STR 10
    GHI 9
    SMB                 ; D = stand-pat_hi - alpha_hi - borrow
    SEX 2
    LBNF QS_NO_ALPHA_UPDATE  ; Borrow = stand-pat <= alpha
    LBNZ QS_UPDATE_ALPHA     ; High diff non-zero and positive
    GHI 8                    ; Check low diff
    LBZ QS_NO_ALPHA_UPDATE   ; Both zero = equal, don't update
    LBR QS_UPDATE_ALPHA

QS_ALPHA_DIFF_SIGN:
    ; Different signs: positive > negative
    GHI 9
    ANI $80
    LBNZ QS_NO_ALPHA_UPDATE  ; stand-pat negative, alpha positive
    ; stand-pat positive, alpha negative -> update

QS_UPDATE_ALPHA:
    ; alpha = stand-pat
    RLDI 10, ALPHA_HI
    GHI 9
    STR 10
    INC 10
    GLO 9
    STR 10

QS_NO_ALPHA_UPDATE:
    ; -----------------------------------------------
    ; Delta pruning: if stand-pat + QUEEN_VALUE < alpha, return alpha
    ; (Even capturing a queen can't raise alpha - futile to search)
    ; -----------------------------------------------
    ; Load alpha from memory (big-endian: HI at lower address)
    RLDI 10, ALPHA_HI
    LDA 10              ; alpha high
    PHI 7
    LDN 10              ; alpha low
    PLO 7               ; R7 = alpha

    ; Calculate stand-pat + QUEEN_VALUE (900 = $0384)
    ; R9 = stand-pat, add 900
    GLO 9
    ADI LOW(900)        ; Add low byte of 900 ($84)
    PLO 8
    GHI 9
    ADCI HIGH(900)      ; Add high byte of 900 ($03) + carry
    PHI 8               ; R8 = stand-pat + 900

    ; Compare: (stand-pat + 900) < alpha?
    ; If R8 < R7, then delta prune
    RLDI 10, COMPARE_TEMP
    SEX 10
    GHI 8               ; (stand-pat + 900) high
    STR 10
    GHI 7               ; alpha high
    XOR
    ANI $80             ; Check if different signs
    SEX 2
    LBNZ QS_DELTA_DIFF_SIGN

    ; Same sign - compare: R8 < R7 means R8 - R7 has borrow
    SEX 10
    GLO 7               ; alpha low
    STR 10
    GLO 8               ; (stand-pat + 900) low
    SM                  ; D = (sp+900)_lo - alpha_lo
    GHI 7               ; alpha high
    STR 10
    GHI 8               ; (stand-pat + 900) high
    SMB                 ; D = (sp+900)_hi - alpha_hi - borrow
    SEX 2
    LBNF QS_DELTA_PRUNE ; Borrow = (stand-pat + 900) < alpha, prune!
    LBR QS_NO_DELTA_PRUNE

QS_DELTA_DIFF_SIGN:
    ; Different signs: negative < positive always
    ; (stand-pat + 900) negative means it's < alpha (if alpha positive)
    GHI 8
    ANI $80
    LBZ QS_NO_DELTA_PRUNE ; (stand-pat + 900) positive -> no prune

QS_DELTA_PRUNE:
    ; Return alpha (in R7) - we're too far behind
    GHI 7
    PHI 9
    GLO 7
    PLO 9               ; R9 = alpha
    RETN

QS_NO_DELTA_PRUNE:
    ; Generate all moves (use QS_MOVE_LIST to avoid clobbering parent's move list!)
    RLDI 9, QS_MOVE_LIST
    CALL GENERATE_MOVES
    ; D = move count

    ; Save move count to temp (must clear R15.1 to avoid DEC underflow!)
    PLO 15              ; R15.0 = move count (temp)
    LDI 0
    PHI 15              ; R15.1 = 0 (prevents underflow when DEC 15)

    ; Save move list start pointer (big-endian: high byte first)
    RLDI 10, QS_MOVE_PTR_HI
    LDI HIGH(QS_MOVE_LIST)
    STR 10
    INC 10
    LDI LOW(QS_MOVE_LIST)
    STR 10

    ; Initialize capture limit counter
    LDI 8                   ; QS_CAPTURE_LIMIT = 8 captures max
    PHI 11                  ; R11.1 = captures remaining

QS_LOOP:
    ; Check if any moves left
    GLO 15
    LBZ QS_RETURN

    ; Load move list pointer (big-endian: high byte first)
    RLDI 10, QS_MOVE_PTR_HI
    LDA 10              ; High byte
    PHI 9
    LDN 10              ; Low byte
    PLO 9               ; R9 = move pointer

    ; Load encoded move (big-endian: high byte first)
    LDA 9
    PHI 8
    LDA 9
    PLO 8               ; R8 = encoded move

    ; Save updated pointer (big-endian: high byte first)
    RLDI 10, QS_MOVE_PTR_HI
    GHI 9
    STR 10
    INC 10
    GLO 9
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
    RLDI 10, COMPARE_TEMP
    SEX 10
    STR 10              ; Store target color to COMPARE_TEMP
    GLO 12              ; D = our color (0 or 8, per COLOR_MASK)
    ANI COLOR_MASK      ; D = our color masked (0 or 8)
    XOR                 ; D = our_color XOR target_color
    SEX 2
    LBZ QS_LOOP         ; Same color (result 0) = own piece, skip

    ; -------------------------------------------------
    ; Per-capture delta pruning:
    ; If stand_pat + victim_value < alpha, skip capture
    ; (Even capturing this piece won't raise score above alpha)
    ; -------------------------------------------------
    ; Reload victim piece and extract type
    LDI HIGH(BOARD)
    PHI 10
    GLO 13              ; to square (preserved in R13.0)
    PLO 10
    LDN 10              ; piece at target
    ANI $07             ; D = piece type (1-6)

    ; Look up value: PIECE_VALUES + type*2
    SHL                 ; D = type * 2
    ADI LOW(PIECE_VALUES)
    PLO 10
    LDI HIGH(PIECE_VALUES)
    ADCI 0
    PHI 10              ; R10 = &PIECE_VALUES[type]

    LDA 10              ; victim value high
    PHI 8
    LDN 10              ; victim value low
    PLO 8               ; R8 = victim_value

    ; Load stand_pat from QS_BEST
    RLDI 10, QS_BEST_HI
    LDA 10
    PHI 7
    LDN 10
    PLO 7               ; R7 = stand_pat

    ; R7 = stand_pat + victim_value
    GLO 8
    STR 2               ; Use stack top as temp
    GLO 7
    ADD
    PLO 7
    GHI 8
    STR 2
    GHI 7
    ADC
    PHI 7               ; R7 = stand_pat + victim_value

    ; Load alpha
    RLDI 10, ALPHA_HI
    LDA 10
    PHI 8
    LDN 10
    PLO 8               ; R8 = alpha

    ; Compare: (stand_pat + victim) < alpha?
    ; If R7 < R8, skip this capture
    RLDI 10, COMPARE_TEMP
    SEX 10
    GHI 7               ; (stand_pat + victim) high
    STR 10
    GHI 8               ; alpha high
    XOR
    ANI $80             ; Check if different signs
    SEX 2
    LBNZ QS_DELTA_DIFF_SIGN2

    ; Same sign: R7 < R8 means R7 - R8 has borrow
    SEX 10
    GLO 8               ; alpha low
    STR 10
    GLO 7               ; (stand_pat + victim) low
    SM                  ; D = (sp+v)_lo - alpha_lo
    GHI 8               ; alpha high
    STR 10
    GHI 7               ; (stand_pat + victim) high
    SMB                 ; D = (sp+v)_hi - alpha_hi - borrow
    SEX 2
    LBNF QS_LOOP        ; Borrow = (stand_pat + victim) < alpha, skip!
    LBR QS_DELTA_NO_PRUNE

QS_DELTA_DIFF_SIGN2:
    ; Different signs: negative < positive always
    ; (stand_pat + victim) negative means it's < alpha (if alpha positive)
    GHI 7
    ANI $80
    LBNZ QS_LOOP        ; (stand_pat + victim) negative -> skip capture

QS_DELTA_NO_PRUNE:
    ; -------------------------------------------------
    ; End per-capture delta pruning
    ; -------------------------------------------------

    ; It's a capture! Process it.
    ; Save move count to stack (BOTH bytes! IS_IN_CHECK clobbers R15.1)
    GHI 15
    STXD
    GLO 15
    STXD

    ; Store from/to for MAKE_MOVE
    RLDI 10, MOVE_FROM
    GHI 13              ; from
    STR 10
    INC 10
    GLO 13              ; to
    STR 10

    ; Set UNDO_PROMOTION based on move flags (capture-promotions)
    RLDI 10, UNDO_PROMOTION
    RLDI 13, DECODED_FLAGS
    LDN 13              ; D = flags
    XRI MOVE_PROMOTION  ; == $03?
    LBNZ QS_NOT_PROMO
    LDI QUEEN_TYPE      ; Promote to queen ($05)
    LBR QS_SET_PROMO
QS_NOT_PROMO:
    LDI 0               ; Not a promotion
QS_SET_PROMO:
    STR 10              ; UNDO_PROMOTION = QUEEN_TYPE or 0

    ; Make move
    CALL MAKE_MOVE

    ; -----------------------------------------------
    ; LEGALITY CHECK: Does this capture leave our king in check?
    ; MAKE_MOVE does NOT toggle R12 - only SIDE in memory.
    ; R12 still contains our color (the side that just moved).
    ; -----------------------------------------------
    CALL IS_IN_CHECK
    ; D = 1 if our king is in check (illegal), 0 if safe

    LBZ QS_CAPTURE_LEGAL  ; D=0 means not in check, capture is legal

    ; ILLEGAL CAPTURE: Unmake and skip to next capture
    CALL UNMAKE_MOVE

    ; R12 stays as our color (UNMAKE_MOVE doesn't toggle R12)

    ; Restore move count from stack and continue loop (both bytes)
    IRX
    LDXA
    PLO 15              ; R15.0 = move count low
    LDX
    PHI 15              ; R15.1 = move count high (0)
    LBR QS_LOOP         ; Skip this illegal capture, try next

QS_CAPTURE_LEGAL:
    ; Check capture limit - decrement and bail if exhausted
    GHI 11                  ; D = captures remaining
    LBZ QS_CAPTURE_LIMIT_HIT ; Already at 0, don't process more
    SMI 1
    PHI 11                  ; R11.1 = captures remaining - 1

    ; Evaluate position after capture
    CALL EVALUATE
    ; Score in R9 (from white's perspective)

    ; Negate if black to move (R12: 0=white, 8=black)
    GLO 12
    ANI $08             ; Check if black (COLOR_MASK)
    LBZ QS_NO_NEG       ; Long branch - crosses page boundary
    ; Negate R9 (R6 is SCRT linkage - off limits!)
    GLO 9
    SDI 0
    PLO 9
    GHI 9
    SDBI 0
    PHI 9
QS_NO_NEG:
    ; Save score (R9) before UNMAKE_MOVE clobbers it
    GHI 9
    STXD
    GLO 9
    STXD

    ; Unmake move
    CALL UNMAKE_MOVE

    ; Restore score (R9)
    IRX
    LDXA
    PLO 9
    LDX
    PHI 9

    ; Restore move count (both bytes)
    IRX
    LDXA
    PLO 15              ; R15.0 = move count low
    LDX
    PHI 15              ; R15.1 = move count high (0)

    ; Compare: if score (R9) > best (QS_BEST), update best
    ; Load QS_BEST into R7 for comparison (big-endian: HI first)
    RLDI 10, QS_BEST_HI
    LDA 10              ; High byte
    PHI 7
    LDN 10              ; Low byte
    PLO 7               ; R7 = QS_BEST

    ; Signed comparison: R9 > R7?
    ; Use COMPARE_TEMP for scratch (NEVER use STR 2!)
    RLDI 10, COMPARE_TEMP
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
    ; Update best = score (big-endian: HI first)
    RLDI 10, QS_BEST_HI
    GHI 9               ; High byte first
    STR 10
    INC 10
    GLO 9               ; Low byte second
    STR 10

    ; -----------------------------------------------
    ; Beta cutoff check: if best >= beta, return beta
    ; -----------------------------------------------
    ; Load beta (big-endian: HI first)
    RLDI 10, BETA_HI
    LDA 10              ; beta high
    PHI 7
    LDN 10              ; beta low
    PLO 7               ; R7 = beta

    ; Compare: best (R9) >= beta (R7)?
    RLDI 10, COMPARE_TEMP
    SEX 10
    GHI 9               ; best high
    STR 10
    GHI 7               ; beta high
    XOR
    ANI $80
    SEX 2
    LBNZ QS_BETA_CUT_DIFF

    ; Same sign: best >= beta means best - beta >= 0 (no borrow)
    SEX 10
    GLO 7               ; beta low
    STR 10
    GLO 9               ; best low
    SM
    GHI 7               ; beta high
    STR 10
    GHI 9               ; best high
    SMB
    SEX 2
    LBDF QS_BETA_CUTOFF ; No borrow = best >= beta, cutoff!
    LBR QS_LOOP

QS_BETA_CUT_DIFF:
    ; Different signs: positive >= negative
    GHI 9               ; best high
    ANI $80
    LBZ QS_BETA_CUTOFF  ; best positive, beta negative -> cutoff
    LBR QS_LOOP

QS_BETA_CUTOFF:
    ; Return beta (fail-high)
    GHI 7
    PHI 9
    GLO 7
    PLO 9               ; R9 = beta
    RETN

QS_CAPTURE_LIMIT_HIT:
    ; Hit capture limit - unmake the move and return best so far
    CALL UNMAKE_MOVE
    ; Restore move count from stack (was pushed at capture processing start)
    IRX
    LDXA
    PLO 15              ; R15.0 = move count low
    LDX
    PHI 15              ; R15.1 = move count high (0)
    ; Fall through to QS_RETURN

QS_RETURN:
    ; Return best score in R9 (big-endian: HI first)
    RLDI 10, QS_BEST_HI
    LDA 10              ; High byte
    PHI 9
    LDN 10              ; Low byte
    PLO 9
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
; Input:  R11 = move that caused beta cutoff
;         CURRENT_PLY = current ply (in memory)
; Output: Killer move stored in table
; Uses:   R10, R13, D
; ------------------------------------------------------------------------------
STORE_KILLER_MOVE:
    ; Calculate killer table offset from CURRENT_PLY
    ; (Use ply, not depth, so killers work across different search depths)
    RLDI 13, CURRENT_PLY
    LDN 13              ; D = current ply
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

    ; Reset pointer to killer1 position (R10 is at killer2_high, need killer1_low)
    DEC 10              ; killer2_low
    DEC 10              ; killer1_high
    DEC 10              ; killer1_low

    ; Store new killer1 (R11 = move that caused cutoff)
    GLO 11
    STR 10
    INC 10
    GHI 11
    STR 10

    RETN

; ------------------------------------------------------------------------------
; ORDER_KILLER_MOVES - Promote killer moves to front of move list
; ------------------------------------------------------------------------------
; Input:  R9 = start of move list
;         D = move count
;         CURRENT_PLY = current ply (for killer table index)
; Output: Move list reordered with killers at front
; Uses:   R7, R8, R10, R11, R13
; Note:   Call this right after GENERATE_MOVES, before move loop
; ------------------------------------------------------------------------------
ORDER_KILLER_MOVES:
    ; Save move count
    PLO 7               ; R7.0 = move count
    LBZ OKM_DONE        ; No moves, nothing to order

    ; Calculate killer table offset from CURRENT_PLY
    RLDI 10, CURRENT_PLY
    LDN 10              ; D = ply
    ANI $0F             ; Limit to 16 plies
    SHL
    SHL                 ; × 4 (2 moves × 2 bytes each)
    PLO 13              ; R13.0 = offset

    ; Point to killer table entry
    LDI HIGH(KILLER_MOVES)
    PHI 10
    GLO 13
    ADI LOW(KILLER_MOVES)
    PLO 10              ; R10 = &killer1 for this ply

    ; Load killer1 (16-bit) into R11
    LDA 10              ; killer1 low
    PLO 11
    LDA 10              ; killer1 high
    PHI 11              ; R11 = killer1

    ; Load killer2 (16-bit) into R13
    LDA 10              ; killer2 low
    PLO 13
    LDN 10              ; killer2 high
    PHI 13              ; R13 = killer2

    ; Check if killers are zero (uninitialized)
    GLO 11
    OR
    GHI 11
    LBZ OKM_TRY_KILLER2 ; killer1 is zero, skip

    ; === Search for killer1 in move list ===
    ; R8 = scan pointer, start from R9
    GHI 9
    PHI 8
    GLO 9
    PLO 8               ; R8 = move list start

    GLO 7               ; D = move count
    PHI 7               ; R7.1 = loop counter

OKM_SCAN_K1:
    GHI 7
    LBZ OKM_TRY_KILLER2 ; No more moves to scan

    ; Compare move at R8 with killer1 (R11)
    LDA 8               ; move low byte
    STR 2
    GLO 11
    XOR
    LBNZ OKM_K1_NEXT    ; Low bytes don't match

    LDN 8               ; move high byte
    STR 2
    GHI 11
    XOR
    LBZ OKM_K1_FOUND    ; Match! Swap to front

OKM_K1_NEXT:
    INC 8               ; Skip high byte (already loaded)
    GHI 7
    SMI 1
    PHI 7               ; Decrement counter
    LBR OKM_SCAN_K1

OKM_K1_FOUND:
    ; Killer1 found at R8-1 (we did LDA). Swap with first move.
    DEC 8               ; R8 points to killer1_low in list

    ; Only swap if not already at front
    GHI 8
    STR 2
    GHI 9
    XOR
    LBNZ OKM_K1_SWAP
    GLO 8
    STR 2
    GLO 9
    XOR
    LBZ OKM_TRY_KILLER2 ; Already at front, no swap needed

OKM_K1_SWAP:
    ; Swap 2-byte entry at R8 with entry at R9
    ; Save move at R9 to stack
    LDA 9
    STXD
    LDN 9
    STXD

    ; Copy killer from R8 to R9-2 (reset R9 first)
    DEC 9
    DEC 9
    LDA 8               ; killer low
    STR 9
    INC 9
    LDN 8               ; killer high
    STR 9
    INC 9               ; R9 back to +2

    ; Copy saved move from stack to R8
    DEC 8               ; Back to low byte position
    IRX
    LDXA                ; Saved high byte
    INC 8
    STR 8               ; Store at R8+1
    DEC 8
    LDX                 ; Saved low byte
    STR 8               ; Store at R8

    ; Reset R9 to list start
    DEC 9
    DEC 9

OKM_TRY_KILLER2:
    ; Check if killer2 is zero
    GLO 13
    OR
    GHI 13
    LBZ OKM_DONE        ; killer2 is zero, skip

    ; Check if we have at least 2 moves
    GLO 7               ; Original move count
    SMI 2
    LBNF OKM_DONE       ; Less than 2 moves

    ; === Search for killer2 in move list (skip first entry) ===
    GHI 9
    PHI 8
    GLO 9
    ADI 2               ; Skip first entry
    PLO 8
    GHI 9
    ADCI 0
    PHI 8               ; R8 = second entry

    GLO 7               ; move count
    SMI 1               ; Skip first
    PHI 7               ; R7.1 = counter

OKM_SCAN_K2:
    GHI 7
    LBZ OKM_DONE        ; No more moves

    ; Compare move at R8 with killer2 (R13)
    LDA 8               ; move low byte
    STR 2
    GLO 13
    XOR
    LBNZ OKM_K2_NEXT    ; Low bytes don't match

    LDN 8               ; move high byte
    STR 2
    GHI 13
    XOR
    LBZ OKM_K2_FOUND    ; Match!

OKM_K2_NEXT:
    INC 8
    GHI 7
    SMI 1
    PHI 7
    LBR OKM_SCAN_K2

OKM_K2_FOUND:
    ; Killer2 found at R8-1. Swap with second move (R9+2).
    DEC 8               ; R8 points to killer2_low

    ; Calculate second entry position
    GHI 9
    PHI 10
    GLO 9
    ADI 2
    PLO 10
    GHI 9
    ADCI 0
    PHI 10              ; R10 = second entry

    ; Only swap if not already there
    GHI 8
    STR 2
    GHI 10
    XOR
    LBNZ OKM_K2_SWAP
    GLO 8
    STR 2
    GLO 10
    XOR
    LBZ OKM_DONE        ; Already in position

OKM_K2_SWAP:
    ; Swap 2-byte entry at R8 with entry at R10
    LDA 10              ; second entry low
    STXD
    LDN 10              ; second entry high
    STXD

    ; Copy killer to second position
    DEC 10
    LDA 8               ; killer low
    STR 10
    INC 10
    LDN 8               ; killer high
    STR 10

    ; Copy saved to R8
    DEC 8
    IRX
    LDXA                ; high byte
    INC 8
    STR 8
    DEC 8
    LDX                 ; low byte
    STR 8

OKM_DONE:
    RETN

; ------------------------------------------------------------------------------
; ORDER_CAPTURES_FIRST - Move captures to front of move list (MVV-LVA prep)
; ------------------------------------------------------------------------------
; Input:  R9 = start of move list
;         D = move count
; Output: Move list reordered with captures at front
; Uses:   R7, R8, R10, R11, R13
; Note:   Call after GENERATE_MOVES, before move loop
; TODO:   Add MVV-LVA scoring: victim_type * 8 - attacker_type (not yet implemented)
; ------------------------------------------------------------------------------
ORDER_CAPTURES_FIRST:
    ; Save move count
    PLO 7               ; R7.0 = move count
    LBZ OCF_DONE        ; No moves

    ; R8 = front pointer (where to put next capture)
    GHI 9
    PHI 8
    GLO 9
    PLO 8               ; R8 = front = list start

    ; R10 = scan pointer
    GHI 9
    PHI 10
    GLO 9
    PLO 10              ; R10 = scan = list start

    ; R7.1 = remaining count to scan
    GLO 7
    PHI 7

OCF_SCAN_LOOP:
    GHI 7
    LBZ OCF_DONE        ; No more moves to scan

    ; Decode move at R10 to get target square
    ; Move format: [flags:2][to:7][from:7]
    ; Low byte bits 0-6 = from, High byte bits 0-5 << 1 | low byte bit 7 = to
    LDA 10              ; Low byte
    PLO 11              ; Save low byte
    LDN 10              ; High byte
    PHI 11              ; R11 = encoded move (hi.lo)

    ; Extract 'to' square: (high & $3F) << 1 | (low >> 7)
    ANI $3F
    SHL
    PLO 13              ; R13.0 = to bits 1-6
    GLO 11              ; Low byte
    ANI $80             ; Bit 7
    LBZ OCF_TO_BIT0_CLR
    GLO 13
    ORI $01
    PLO 13
OCF_TO_BIT0_CLR:
    ; R13.0 = to square, R11 = encoded move

    ; Check if target square has a piece (any piece = potential capture)
    ; Calculate BOARD + to_square
    ; BOARD is at $6000, so high byte is $60, low byte is to_square
    LDI HIGH(BOARD)
    PHI 13
    ; R13 now = $60xx where xx = to_square (already in R13.0)

    ; Load piece at target square
    LDN 13              ; D = piece at target
    DEC 10              ; Reset R10 to low byte position

    ; If piece is 0 (empty), not a capture
    LBZ OCF_NEXT_MOVE   ; Empty square, skip

    ; Non-empty = capture (we don't check color here for simplicity)
    ; Fall through to OCF_IS_CAPTURE

OCF_IS_CAPTURE:
    ; Move is a capture - swap to front if not already there
    ; R10 points to current move, R8 points to front
    GHI 10
    STR 2
    GHI 8
    XOR
    LBNZ OCF_DO_SWAP
    GLO 10
    STR 2
    GLO 8
    XOR
    LBZ OCF_ADVANCE_FRONT  ; Already at front

OCF_DO_SWAP:
    ; Swap 2-byte entries at R8 and R10
    ; Save R8 entry to stack
    LDA 8
    STXD
    LDN 8
    STXD
    DEC 8               ; Reset R8

    ; Copy R10 to R8
    LDA 10
    STR 8
    INC 8
    LDN 10
    STR 8
    DEC 8
    DEC 10              ; Reset both

    ; Copy stack to R10
    IRX
    LDXA                ; High byte
    INC 10
    STR 10
    DEC 10
    LDX                 ; Low byte
    STR 10

OCF_ADVANCE_FRONT:
    ; Advance front pointer
    INC 8
    INC 8

OCF_NEXT_MOVE:
    ; Advance scan pointer
    INC 10
    INC 10
    ; Decrement counter
    GHI 7
    SMI 1
    PHI 7
    LBR OCF_SCAN_LOOP

OCF_DONE:
    RETN

; ------------------------------------------------------------------------------
; INC_NODE_COUNT - Increment 32-bit node counter (FULL VERSION)
; ------------------------------------------------------------------------------
; Input:  None
; Output: NODES_SEARCHED incremented
; Uses:   A, D
; ------------------------------------------------------------------------------
INC_NODE_COUNT:
    RLDI 10, NODES_SEARCHED

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
; SEARCH_POSITION - Iterative Deepening Entry Point
; ==============================================================================
; Input:  SEARCH_DEPTH = target depth (stored in memory by UCI handler)
; Output: R9 = best score (R6 is SCRT linkage - off limits!)
;         BEST_MOVE = best move found
; Searches depth 1, 2, ..., TARGET_DEPTH. If depth N exceeds node budget,
; aborts and returns depth N-1's bestmove.
; ==============================================================================
SEARCH_POSITION:
    SEX 2

    ; --- Save TARGET_DEPTH from SEARCH_DEPTH (set by UCI handler) ---
    RLDI 10, SEARCH_DEPTH + 1
    LDN 10                      ; D = target depth (low byte)
    STXD                        ; Save depth on stack (LDI clobbers D!)
    RLDI 10, TARGET_DEPTH
    IRX
    LDX                         ; D = target depth (restored from stack)
    STR 10                      ; TARGET_DEPTH = original depth

    ; --- Clear SEARCH_ABORTED flag ---
    RLDI 10, SEARCH_ABORTED
    LDI 0
    STR 10

    ; --- Clear ITER_BEST (no bestmove yet) ---
    RLDI 10, ITER_BEST_FROM
    LDI $FF
    STR 10
    INC 10
    STR 10                      ; ITER_BEST_TO = $FF

    ; --- Set starting depth = 1 ---
    RLDI 10, CURRENT_MAX_DEPTH
    LDI 1
    STR 10

    ; --- Initialize RTC elapsed timer ---
    ; Read current seconds from DS12887 RTC (binary mode)
    ; Protocol: OUT port 2 = register select, INP port 3 = read data
    LDI $80                     ; $80 = seconds register
    STR 2                       ; Store at M(R2) for OUT
    OUT 2                       ; Send to port 2 (selects seconds), R2++
    DEC 2                       ; Restore stack pointer
    INP 3                       ; D = seconds (binary 0-59), also M(R2)
    STXD                        ; Save seconds on stack (LDI clobbers D!)
    RLDI 10, SEARCH_PREV_SECS
    IRX
    LDX                         ; D = seconds (restored)
    STR 10                      ; SEARCH_PREV_SECS = current seconds

    ; Clear elapsed counter
    RLDI 10, SEARCH_ELAPSED
    LDI 0
    STR 10                      ; SEARCH_ELAPSED = 0

    ; --- Clear node counter (once for entire search) ---
    RLDI 11, NODES_SEARCHED
    LDI 0
    STR 11
    INC 11
    STR 11
    INC 11
    STR 11
    INC 11
    STR 11

    ; --- Initialize Zobrist hash (once — TT benefits from earlier depths) ---
    CALL HASH_INIT

; ======================================================================
; ITERATIVE DEEPENING LOOP
; ======================================================================
ITER_LOOP:
    ; --- Set SEARCH_DEPTH = CURRENT_MAX_DEPTH for this iteration ---
    RLDI 10, SEARCH_DEPTH
    LDI 0
    STR 10                      ; SEARCH_DEPTH high = 0
    INC 10
    ; Load CURRENT_MAX_DEPTH
    RLDI 13, CURRENT_MAX_DEPTH
    LDN 13                      ; D = current depth
    STR 10                      ; SEARCH_DEPTH low = current depth

    ; --- Reset SEARCH_ABORTED for this iteration ---
    RLDI 10, SEARCH_ABORTED
    LDI 0
    STR 10

    ; --- Standard search init ---
    ; Alpha = -32767
    RLDI 10, ALPHA_HI
    LDI $80
    STR 10                      ; ALPHA_HI = $80
    INC 10
    LDI $01
    STR 10                      ; ALPHA_LO = $01

    ; Beta = +32767
    RLDI 10, BETA_HI
    LDI $7F
    STR 10                      ; BETA_HI = $7F
    INC 10
    LDI $FF
    STR 10                      ; BETA_LO = $FF

    ; CURRENT_PLY = 0
    RLDI 10, CURRENT_PLY
    LDI 0
    STR 10

    ; NULL_MOVE_OK = 1
    RLDI 10, NULL_MOVE_OK
    LDI 1
    STR 10

    ; Get side to move
    CALL GET_SIDE_TO_MOVE
    PLO 12                      ; C.0 = color

    ; Board pointer
    RLDI 10, BOARD

    ; Clear best move for this iteration
    RLDI 11, BEST_MOVE
    LDI $FF
    STR 11
    INC 11
    STR 11

    ; --- Run search for this depth ---
    CALL NEGAMAX

    ; --- Check if search was aborted ---
    RLDI 10, SEARCH_ABORTED
    LDN 10
    LBNZ ITER_ABORTED           ; Aborted: use previous depth's bestmove

    ; --- Depth completed: save bestmove ---
    ; Set up BOTH pointers first, then copy (LDI clobbers D!)
    RLDI 10, BEST_MOVE
    RLDI 11, ITER_BEST_FROM
    ; Now copy: R10→BEST_MOVE, R11→ITER_BEST
    LDA 10                      ; D = from square
    STR 11                      ; ITER_BEST_FROM = from
    INC 11
    LDN 10                      ; D = to square (BEST_MOVE+1)
    STR 11                      ; ITER_BEST_TO = to

    ; --- Save score from this depth ---
    RLDI 10, ITER_SCORE_HI
    GHI 9
    STR 10                      ; ITER_SCORE_HI = R9.hi
    INC 10
    GLO 9
    STR 10                      ; ITER_SCORE_LO = R9.lo

    ; --- Send UCI "info" for this depth ---
    CALL SEND_UCI_INFO

    ; --- Check if we've reached TARGET_DEPTH ---
    RLDI 10, CURRENT_MAX_DEPTH
    LDN 10                      ; D = current depth
    STR 2                       ; Push to stack for comparison
    RLDI 10, TARGET_DEPTH
    LDN 10                      ; D = target depth
    SM                          ; D = target - current (M(R2) = current)
    LBZ ITER_DONE               ; current == target, finished

    ; --- Increment depth and loop ---
    RLDI 10, CURRENT_MAX_DEPTH
    LDN 10
    ADI 1
    STR 10                      ; CURRENT_MAX_DEPTH++
    LBR ITER_LOOP

ITER_ABORTED:
    ; Search at this depth was aborted — fall back to ITER_BEST
    ; Set up BOTH pointers first, then copy (LDI clobbers D!)
    RLDI 10, ITER_BEST_FROM
    RLDI 11, BEST_MOVE
    ; Now copy: R10→ITER_BEST, R11→BEST_MOVE
    LDA 10                      ; D = ITER_BEST_FROM
    STR 11                      ; BEST_MOVE[0] = from
    INC 11
    LDN 10                      ; D = ITER_BEST_TO
    STR 11                      ; BEST_MOVE[1] = to

ITER_DONE:
    RETN

; ==============================================================================
; SEND_UCI_INFO - Send "info depth N nodes NNNNN" after each iteration
; ==============================================================================
; Sends: "info depth N nodes NNNNN\r\n"
;   N = CURRENT_MAX_DEPTH (ASCII digit)
;   NNNNN = NODES_SEARCHED as decimal via F_UINTOUT (lower 16 bits)
; ==============================================================================
SEND_UCI_INFO:
    ; Send "info depth "
    RLDI 15, STR_INFO_DEPTH
    SEP 4
    DW F_MSG

    ; Send depth digit (1-9)
    RLDI 10, CURRENT_MAX_DEPTH
    LDN 10                      ; D = depth (1-9)
    ADI '0'                     ; Convert to ASCII
    CALL SERIAL_WRITE_CHAR

    ; Send " nodes "
    RLDI 15, STR_NODES
    SEP 4
    DW F_MSG

    ; Load NODES_SEARCHED (16-bit) into R13: high byte first, then low
    RLDI 10, NODES_SEARCHED + 1
    LDN 10                      ; D = high byte of node count
    PHI 13                      ; R13.1 = high byte
    RLDI 10, NODES_SEARCHED
    LDN 10                      ; D = low byte of node count
    PLO 13                      ; R13.0 = low byte

    ; Point R15 at ASCII scratch buffer
    RLDI 15, UINT_BUFFER

    ; Convert R13 to ASCII decimal at R15
    SEP 4
    DW F_UINTOUT

    ; Null-terminate (R15 points past last digit)
    LDI 0
    STR 15

    ; Print the decimal string
    RLDI 15, UINT_BUFFER
    SEP 4
    DW F_MSG

    ; Send CR+LF
    LDI 13
    CALL SERIAL_WRITE_CHAR
    LDI 10
    CALL SERIAL_WRITE_CHAR

    RETN

; ==============================================================================
; End of Negamax Core
; ==============================================================================
