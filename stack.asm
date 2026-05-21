; ==============================================================================
; RCA 1802/1806 Chess Engine - Stack Management
; ==============================================================================
; Two roles:
;   - SAVE_PLY_STATE / RESTORE_PLY_STATE: per-ply register-snapshot save
;     and restore around recursive NEGAMAX calls.
;   - CHECK_STACK_OVERFLOW: defensive guard for stack growing past $7D00.
;
; 2026-05-21 — Reclaimed ~85 bytes by removing dead helpers (zero callers):
;   INIT_STACK, PUSH16_R7/8/9/B/C, POP16_R7/8/9/B/C, PUSH_BYTE, POP_BYTE,
;   GET_STACK_DEPTH. The engine inlines its stack ops via direct STXD/LDXA;
;   these wrapper subroutines were never called.
; ==============================================================================

; ------------------------------------------------------------------------------
; SAVE_PLY_STATE - Save registers to ply-indexed state array
; ------------------------------------------------------------------------------
; Saves R7, R8, R9, R11, R12 to PLY_STATE_BASE + (CURRENT_PLY × 10)
; Uses: R10, R13 (clobbered)
; ------------------------------------------------------------------------------
SAVE_PLY_STATE:
    ; Get current ply and calculate frame address
    RLDI 10, CURRENT_PLY
    LDN 10              ; D = current ply (0-7)

    ; Multiply ply by 10: ×10 = ×8 + ×2
    ; Use stack for temp storage (push then immediate pop - net zero change)
    PHI 13              ; R13.1 = ply (save original)
    SHL                 ; D = ply × 2
    SHL                 ; D = ply × 4
    SHL                 ; D = ply × 8
    STXD                ; Push ply×8 to stack (R2 decremented)
    GHI 13              ; D = ply (original)
    SHL                 ; D = ply × 2
    IRX                 ; Point R2 back at ply×8
    ADD                 ; D = ply×2 + ply×8 = ply × 10 (R2 unchanged)

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
    RLDI 10, CURRENT_PLY
    LDN 10              ; D = current ply (0-7)

    ; Multiply ply by 10: ×10 = ×8 + ×2
    ; Use stack for temp storage (push then immediate pop - net zero change)
    PHI 13              ; R13.1 = ply (save original)
    SHL                 ; D = ply × 2
    SHL                 ; D = ply × 4
    SHL                 ; D = ply × 8
    STXD                ; Push ply×8 to stack (R2 decremented)
    GHI 13              ; D = ply (original)
    SHL                 ; D = ply × 2
    IRX                 ; Point R2 back at ply×8
    ADD                 ; D = ply×2 + ply×8 = ply × 10 (R2 unchanged)

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
; Notes on removed routines (historical context — see git log for the prior code):
; SAVE_ALPHA_BETA / RESTORE_ALPHA_BETA — REMOVED: R6 is SCRT linkage; alpha/beta
;   stored in memory (ALPHA_LO/HI, BETA_LO/HI) and saved/restored inline in negamax.asm.
; SAVE_DEPTH_COLOR / RESTORE_DEPTH_COLOR — REMOVED: R5 is SRET; depth is in
;   memory (SEARCH_DEPTH).
; ------------------------------------------------------------------------------

; ------------------------------------------------------------------------------
; CHECK_STACK_OVERFLOW — defensive guard against stack growing past $7D00
; ------------------------------------------------------------------------------
; Called periodically to ensure the stack hasn't grown below $7D00, which would
; corrupt XMODEM ($7C00-$7CFF) or, deeper, MOVE_LIST ($7800-$7A7F).
;
; Memory map with XMODEM resident:
;   $7800-$7A7F  MOVE_LIST (640 B, 5 plies × 128)
;   $7A80-$7AFF  gap (zeroed by WORKSPACE_CLEAR)
;   $7B00-$7BFF  N2 overflow-page code (2026-05-21)
;   $7C00-$7CFF  XMODEM reserved — DO NOT TOUCH
;   $7D00-$7FFF  stack working zone (768 B usable)
;
; Records R2.HI to STACK_OVERFLOW_FLAG (recoverable via memory dump after
; the trap), then hard-halts via MARK + SEP 1. MARK saves X:P; SEP 1 transfers
; control to R1 (BIOS monitor). No info-string emit attempt — emitting via
; the corrupted stack would garble UART output and mask the real failure
; (changed 2026-05-16).
; ------------------------------------------------------------------------------
CHECK_STACK_OVERFLOW:
    GHI 2
    SMI $7D             ; Compare with $7D
    LBDF STACK_OK       ; If DF=1, R2.HI >= $7D, OK (no overflow)
    RLDI 10, STACK_OVERFLOW_FLAG    ; RLDI clobbers D, must precede GHI 2
    GHI 2
    STR 10              ; STACK_OVERFLOW_FLAG = R2.HI (for post-mortem)
    MARK                ; Save X:P to memory (1802 monitor-trap convention)
    SEP 1               ; Hard halt → R1 (BIOS monitor entry)
STACK_OK:
    RETN

; ==============================================================================
; End of Stack Management
; ==============================================================================
