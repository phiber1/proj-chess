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
; WARNING: R6 is SCRT linkage register - NEVER touch it!
; ------------------------------------------------------------------------------
SAVE_SEARCH_CONTEXT:
    ; Save in reverse order so POP restores in correct order
    ; NOTE: R4, R5, R6 are SCRT registers - NEVER touch them!
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

    ; R6 is SCRT linkage - DO NOT save/restore it!

    RETN

; ------------------------------------------------------------------------------
; RESTORE_SEARCH_CONTEXT - Restore all registers used in search
; ------------------------------------------------------------------------------
; Restores 7-9, B, C from stack (NOT R5/R6 - they're SCRT registers!)
; Call before return from NEGAMAX
; WARNING: R6 is SCRT linkage register - NEVER touch it!
; ------------------------------------------------------------------------------
RESTORE_SEARCH_CONTEXT:
    ; Restore in forward order
    ; First IRX to point to first saved byte, then LDXA pairs
    ; NO extra IRX between registers - LDXA already advances R2!
    ; NOTE: R4, R5, R6 are SCRT registers - NEVER touch them!

    ; R6 is SCRT linkage - DO NOT save/restore it!

    IRX                 ; Point to 7.1
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
    LDX                 ; Last byte: use LDX (no increment) to balance
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
