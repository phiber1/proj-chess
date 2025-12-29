; ==============================================================================
; RCA 1802/1806 Chess Engine - Stack Management Utilities
; ==============================================================================
; Register save/restore for recursion
; Stack grows downward from $7FFF
; 2 is the stack pointer (X register)
; ==============================================================================

; ------------------------------------------------------------------------------
; Stack Frame for Negamax Recursion
; ------------------------------------------------------------------------------
; Each recursive call saves:
;   6  (alpha)          - 2 bytes
;   7  (beta)           - 2 bytes
;   8  (best score)     - 2 bytes
;   9  (move list ptr)  - 2 bytes
;   B  (current move)   - 2 bytes
;   C  (color)          - 2 bytes
;   Return address       - 2 bytes
; NOTE: R5 is SRET in BIOS mode - DO NOT save/restore!
; NOTE: Depth is now in memory at SEARCH_DEPTH, not R5
; ------------------------------------------------------------------------------
; Total: 14 bytes per recursion level
; At 6 ply depth: 84 bytes maximum
; Stack allocation: 2KB ($7800-$7FFF) is more than sufficient
; ------------------------------------------------------------------------------

; ------------------------------------------------------------------------------
; INIT_STACK - Initialize stack pointer
; ------------------------------------------------------------------------------
; Call this once at program startup
; Sets 2 to $7FFF (top of 32KB RAM)
; ------------------------------------------------------------------------------
INIT_STACK:
    LDI $7F
    PHI 2              ; 2.1 = $7F
    LDI $FF
    PLO 2              ; 2.0 = $FF (2 = $7FFF)
    SEX 2              ; Set 2 as index register for stack ops
    RETN

; ------------------------------------------------------------------------------
; PUSH16 - Push 16-bit value onto stack
; ------------------------------------------------------------------------------
; Input:  6 = 16-bit value to push
; Output: Stack updated, 2 decremented by 2
; Uses:   None (6 preserved)
; ------------------------------------------------------------------------------
; PUSH16_R5 - REMOVED: R5 is SRET in BIOS mode, never touch it!
; PUSH16_R6 - REMOVED: R6 is SCRT linkage, corrupted by every CALL!

PUSH16_R7:
    GLO 7
    STXD
    GHI 7
    STXD
    RETN

PUSH16_R8:
    GLO 8
    STXD
    GHI 8
    STXD
    RETN

PUSH16_R9:
    GLO 9
    STXD
    GHI 9
    STXD
    RETN

PUSH16_RB:
    GLO 11
    STXD
    GHI 11
    STXD
    RETN

PUSH16_RC:
    GLO 12
    STXD
    GHI 12
    STXD
    RETN

; ------------------------------------------------------------------------------
; POP16 - Pop 16-bit value from stack
; ------------------------------------------------------------------------------
; Input:  Stack pointer at saved value
; Output: 6 = popped value, 2 incremented by 2
; Uses:   D
; ------------------------------------------------------------------------------
; POP16_R5 - REMOVED: R5 is SRET in BIOS mode, never touch it!
; POP16_R6 - REMOVED: R6 is SCRT linkage, corrupted by every CALL!

POP16_R7:
    IRX
    LDXA
    PHI 7
    LDX
    PLO 7
    RETN

POP16_R8:
    IRX
    LDXA
    PHI 8
    LDX
    PLO 8
    RETN

POP16_R9:
    IRX
    LDXA
    PHI 9
    LDX
    PLO 9
    RETN

POP16_RB:
    IRX
    LDXA
    PHI 11
    LDX
    PLO 11
    RETN

POP16_RC:
    IRX
    LDXA
    PHI 12
    LDX
    PLO 12
    RETN

; ------------------------------------------------------------------------------
; SAVE_SEARCH_CONTEXT / RESTORE_SEARCH_CONTEXT - REMOVED (Dec 28, 2025)
; ------------------------------------------------------------------------------
; The stack-based save/restore caused endless problems with SCRT interference:
;   - Bug #4: RESTORE popping SCRT linkage as context
;   - Bug #5: SAVE corrupting R6 on return
;   - Bug #6: Can't modify R3 while P=3 (required trampoline hack)
;
; Replaced with ply-indexed state arrays (SAVE_PLY_STATE / RESTORE_PLY_STATE).
; This approach uses fixed memory at PLY_STATE_BASE + (ply × 10), completely
; avoiding stack manipulation. System stack is now only used for SCRT linkage.
; ------------------------------------------------------------------------------

; ==============================================================================
; PLY-INDEXED STATE MANAGEMENT (Replaces stack-based SAVE/RESTORE)
; ==============================================================================
; These functions use a fixed memory array indexed by CURRENT_PLY.
; No stack manipulation = no SCRT interference!
; ==============================================================================

; ------------------------------------------------------------------------------
; SAVE_PLY_STATE - Save registers to ply-indexed state array
; ------------------------------------------------------------------------------
; Saves R7, R8, R9, R11, R12 to PLY_STATE_BASE + (CURRENT_PLY × 10)
; Uses: R10, R13 (clobbered)
; ------------------------------------------------------------------------------
SAVE_PLY_STATE:
    ; Get current ply and calculate frame address
    LDI HIGH(CURRENT_PLY)
    PHI 10
    LDI LOW(CURRENT_PLY)
    PLO 10
    LDN 10              ; D = current ply (0-7)

    ; Multiply ply by 10: ×10 = ×8 + ×2
    SHL                 ; D = ply × 2
    PLO 13              ; R13.0 = ply × 2 (save for later)
    SHL                 ; D = ply × 4
    SHL                 ; D = ply × 8
    STR 10              ; Store ply×8 to temp (M(R10) = CURRENT_PLY, OK to reuse)
    GLO 13              ; D = ply × 2
    ADD                 ; D = ply×8 + ply×2 = ply × 10

    ; Add to base address: R10 = PLY_STATE_BASE + offset
    ADI LOW(PLY_STATE_BASE)
    PLO 10
    LDI HIGH(PLY_STATE_BASE)
    ADCI 0              ; Add carry if any
    PHI 10              ; R10 = frame address

    ; Store registers (high byte first for big-endian consistency)
    GHI 7
    STR 10
    INC 10
    GLO 7
    STR 10
    INC 10

    GHI 8
    STR 10
    INC 10
    GLO 8
    STR 10
    INC 10

    GHI 9
    STR 10
    INC 10
    GLO 9
    STR 10
    INC 10

    GHI 11
    STR 10
    INC 10
    GLO 11
    STR 10
    INC 10

    GHI 12
    STR 10
    INC 10
    GLO 12
    STR 10

    RETN

; ------------------------------------------------------------------------------
; RESTORE_PLY_STATE - Restore registers from ply-indexed state array
; ------------------------------------------------------------------------------
; Restores R7, R8, R9, R11, R12 from PLY_STATE_BASE + (CURRENT_PLY × 10)
; Uses: R10, R13 (clobbered)
; ------------------------------------------------------------------------------
RESTORE_PLY_STATE:
    ; Get current ply and calculate frame address
    LDI HIGH(CURRENT_PLY)
    PHI 10
    LDI LOW(CURRENT_PLY)
    PLO 10
    LDN 10              ; D = current ply (0-7)

    ; Multiply ply by 10: ×10 = ×8 + ×2
    SHL                 ; D = ply × 2
    PLO 13              ; R13.0 = ply × 2 (save for later)
    SHL                 ; D = ply × 4
    SHL                 ; D = ply × 8
    STR 10              ; Store ply×8 to temp
    GLO 13              ; D = ply × 2
    ADD                 ; D = ply×8 + ply×2 = ply × 10

    ; Add to base address: R10 = PLY_STATE_BASE + offset
    ADI LOW(PLY_STATE_BASE)
    PLO 10
    LDI HIGH(PLY_STATE_BASE)
    ADCI 0              ; Add carry if any
    PHI 10              ; R10 = frame address

    ; Load registers (high byte first for big-endian consistency)
    LDA 10
    PHI 7
    LDA 10
    PLO 7

    LDA 10
    PHI 8
    LDA 10
    PLO 8

    LDA 10
    PHI 9
    LDA 10
    PLO 9

    LDA 10
    PHI 11
    LDA 10
    PLO 11

    LDA 10
    PHI 12
    LDN 10
    PLO 12

    RETN

; ------------------------------------------------------------------------------
; SAVE_PARTIAL - REMOVED: R6 is SCRT linkage, alpha/beta now memory-based
; ------------------------------------------------------------------------------
; SAVE_ALPHA_BETA and RESTORE_ALPHA_BETA removed - they used R6 which is
; corrupted by every CALL. Alpha/beta are now stored in memory (ALPHA_LO/HI,
; BETA_LO/HI) and saved/restored inline in negamax.asm.
; ------------------------------------------------------------------------------

; SAVE_ALPHA_BETA - REMOVED: R6 is SCRT linkage, alpha/beta now memory-based
; RESTORE_ALPHA_BETA - REMOVED: R6 is SCRT linkage, alpha/beta now memory-based
; SAVE_DEPTH_COLOR - REMOVED: R5 is SRET, depth is now in memory (SEARCH_DEPTH)
; RESTORE_DEPTH_COLOR - REMOVED: R5 is SRET, depth is now in memory (SEARCH_DEPTH)

; ------------------------------------------------------------------------------
; Stack Utilities
; ------------------------------------------------------------------------------

; PUSH_BYTE - Push single byte to stack
PUSH_BYTE:
    ; Input: D = byte to push
    STXD
    RETN

; POP_BYTE - Pop single byte from stack
POP_BYTE:
    ; Output: D = popped byte
    IRX
    LDXA
    RETN

; GET_STACK_DEPTH - Get current stack usage
; Output: R9 = bytes used (stack depth) - NOT R6! R6 is SCRT linkage!
GET_STACK_DEPTH:
    LDI $7F
    PHI 9
    LDI $FF
    PLO 9              ; R9 = $7FFF (initial stack)

    ; Subtract current stack pointer
    GLO 2
    STR 2
    GLO 9
    SM
    PLO 9

    GHI 2
    STR 2
    GHI 9
    SMB
    PHI 9
    ; R9 now contains bytes used
    RETN

; ------------------------------------------------------------------------------
; DEBUG: Stack overflow check (optional, for development)
; ------------------------------------------------------------------------------
; Call periodically to ensure stack hasn't overflowed into other memory
; Checks if 2 < $7800 (bottom of 2KB stack area)
; If overflow detected, could halt or set error flag
; ------------------------------------------------------------------------------
CHECK_STACK_OVERFLOW:
    GHI 2
    SMI $78             ; Compare with $78
    BDF STACK_OK        ; If DF=1, 2 >= $7800, OK
    ; Stack overflow detected
    ; TODO: Set error flag or halt
    ; For now, just return
STACK_OK:
    RETN

; ==============================================================================
; End of Stack Management
; ==============================================================================
