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
; SAVE_SEARCH_CONTEXT - Save all registers used in search
; ------------------------------------------------------------------------------
; Saves 7-9, B, C to stack (NOT R5/R6 - they're SCRT registers!)
; Call at entry to NEGAMAX
; Uses: 10 bytes of stack (5 registers × 2 bytes)
;
; CRITICAL FIX (Dec 28, 2025): SCRT pushes R6 linkage onto stack when this
; function is called. If we push context then do RETN, RETN will pop context
; bytes (thinking they're linkage) and corrupt R6! We must handle this like
; RESTORE: pop SCRT linkage first, do our work, then manually return.
; ------------------------------------------------------------------------------
SAVE_SEARCH_CONTEXT:
    ; Pop SCRT's R6 linkage first and save to R13 (temp)
    IRX                 ; R2 at old R6.lo
    LDXA                ; D = old R6.lo, R2 at old R6.hi
    PLO 13              ; R13.0 = old R6.lo
    LDXA                ; D = old R6.hi, R2 past linkage
    PHI 13              ; R13 = old R6 (saved for later)

    ; R2 is now 3 bytes higher than entry (IRX + 2*LDXA).
    ; Restore R2 to entry position so context is stored at same locations
    ; that RESTORE expects (just above where SCRT linkage was).
    DEC 2
    DEC 2
    DEC 2               ; R2 back to entry position

    ; Push context (same positions as original design)
    ; Save in reverse order so POP restores in correct order
    GLO 12
    STXD
    GHI 12
    STXD

    GLO 11
    STXD
    GHI 11
    STXD

    GLO 9
    STXD
    GHI 9
    STXD

    GLO 8
    STXD
    GHI 8
    STXD

    GLO 7
    STXD
    GHI 7
    STXD

    ; Manually return using R7/R15 trampoline (can't modify R3 while P=3!)
    ; R6 = our return address (set by SCRT CALL)
    ; R13 = old R6 (caller's linkage that was pushed)
    ; R7 is caller-save, OK to use as temp

    ; Save return address to R7
    GHI 6
    PHI 7
    GLO 6
    PLO 7

    ; Point R15 to trampoline
    LDI HIGH(SAVE_TRAMPOLINE)
    PHI 15
    LDI LOW(SAVE_TRAMPOLINE)
    PLO 15

    ; Restore R6 from R13
    GHI 13
    PHI 6
    GLO 13
    PLO 6

    ; Jump to trampoline (switches to P=15)
    SEP 15

SAVE_TRAMPOLINE:
    ; Now P=15, can safely modify R3
    GHI 7
    PHI 3
    GLO 7
    PLO 3
    ; Switch to R3 and jump to return address
    SEP 3

; ------------------------------------------------------------------------------
; RESTORE_SEARCH_CONTEXT - Restore all registers used in search
; ------------------------------------------------------------------------------
; Restores 7-9, B, C from stack (NOT R5/R6 - they're SCRT registers!)
; Call before return from NEGAMAX
;
; CRITICAL FIX (Dec 28, 2025): SCRT pushes R6 linkage onto stack when this
; function is called. We must skip past it to get to the saved context, then
; manually restore R6 and return (bypassing SRET to avoid stack mismatch).
; ------------------------------------------------------------------------------
RESTORE_SEARCH_CONTEXT:
    ; When called via SCRT, the stack has:
    ;   [saved R12..R7 context] (10 bytes)
    ;   [old R6.hi]
    ;   [old R6.lo]  <-- SCRT pushed this during CALL
    ;   R2 points below here
    ;
    ; Pop SCRT's R6 linkage first and save to R13 (temp)
    IRX                 ; R2 at old R6.lo
    LDXA                ; D = old R6.lo, R2 at old R6.hi
    PLO 13              ; R13.0 = old R6.lo
    LDXA                ; D = old R6.hi, R2 at R7.1
    PHI 13              ; R13 = old R6 (saved for later)

    ; Now R2 is at R7.1 (first saved byte), read context normally
    LDXA
    PHI 7
    LDXA
    PLO 7

    LDXA
    PHI 8
    LDXA
    PLO 8

    LDXA
    PHI 9
    LDXA
    PLO 9

    LDXA
    PHI 11
    LDXA
    PLO 11

    LDXA
    PHI 12
    LDX                 ; R2 at R12.0
    PLO 12

    ; All registers restored. Now manually return using trampoline
    ; (can't modify R3 while P=3!)
    ; Current R6 = our return address (set by SCRT CALL)
    ; R13 = old R6 (caller's linkage that was pushed)

    ; Point R15 to trampoline
    LDI HIGH(RESTORE_TRAMPOLINE)
    PHI 15
    LDI LOW(RESTORE_TRAMPOLINE)
    PLO 15

    ; Jump to trampoline (switches to P=15)
    SEP 15

RESTORE_TRAMPOLINE:
    ; Now P=15, can safely modify R3
    ; R6 = return address, R13 = old linkage
    GHI 6
    PHI 3
    GLO 6
    PLO 3
    ; Restore R6 from R13
    GHI 13
    PHI 6
    GLO 13
    PLO 6
    ; Switch to R3 and jump to return address
    SEP 3

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
