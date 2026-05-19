; ==============================================================================
; RCA 1802/1806 Chess Engine - Main Program
; ==============================================================================
; Entry point and main loop
; ==============================================================================

; ==============================================================================
; Program Entry Point (build script adds ORG $0000)
; ==============================================================================

#ifdef BIOS
; ------------------------------------------------------------------------------
; BIOS Mode Entry - SCRT set up by BIOS, use BIOS stack
; ------------------------------------------------------------------------------
START:
    ; BIOS has set up R4=CALL, R5=RET, R2=stack (at $7F77)
    ; DO NOT reset R2! Monitor uses $7F78-$7FFF for static variables.
    ; If we set R2=$7FFF, our stack would overwrite monitor variables,
    ; breaking warm start at $8003.
    SEX 2               ; Ensure X = R2 for stack operations
    ; Serial I/O uses BIOS entry points, no init needed
#else
; ------------------------------------------------------------------------------
; Standalone Mode Entry - Must initialize SCRT and stack
; ------------------------------------------------------------------------------
START:
    ; Initialize system - using Mark Abene's SCRT pattern
    ; Set R6 to continue at MAIN_CONTINUE, then jump to INITCALL
    RLDI 6, MAIN_CONTINUE
    LBR INITCALL

MAIN_CONTINUE:
    ; Stack setup - AFTER INITCALL (critical!)
    LDI $7F
    PHI 2
    LDI $FF
    PLO 2              ; 2 = $7FFF (stack top)
    SEX 2              ; Set X register to R2 for stack operations

    DIS                 ; Disable interrupts

    ; SCRT is now initialized (R4 = SCALL, R5 = SRET)
    ; Initialize serial I/O (sets Q high for idle, R14.0 = 2)
    CALL SERIAL_INIT
#endif

    ; Clear workspace RAM ($6200-$64FF) to prevent stale variable bugs
    CALL WORKSPACE_CLEAR

    ; Initialize board to starting position
    CALL INIT_BOARD

    ; Initialize move history
    CALL INIT_MOVE_HISTORY

    ; Clear transposition table (once at startup)
    CALL TT_CLEAR

    ; Send startup message
    RLDI 15, MSG_STARTUP
    CALL PRINT_STRING

    ; Initialize UCI
    CALL UCI_INIT

    ; Enter main loop
    LBR MAIN_LOOP

; ==============================================================================
; Main Loop
; ==============================================================================
MAIN_LOOP:
    ; UCI: No prompt - engine waits silently for commands
    ; Read and process UCI commands
    CALL UCI_READ_LINE
    CALL UCI_PROCESS_COMMAND
    LBR MAIN_LOOP

; ==============================================================================
; PRINT_STRING - Output null-terminated string
; ==============================================================================
; Input:  F (R15) = pointer to string
; Uses:   F, D, R8 (temp save in standalone mode)
; ==============================================================================
PRINT_STRING:
#ifdef BIOS
    ; BIOS F_MSG uses R15 directly - single call, efficient
    SEP 4
    DW F_MSG
    RETN
#else
PRINT_LOOP:
    LDA 15              ; Load char and increment R15
    BZ PRINT_DONE       ; If zero, done
    ; Standalone mode: Save R15 (bit-bang clobbers it as bit counter)
    STXD                ; Save character to stack
    GHI 15
    PHI 8               ; R8.1 = R15.1
    GLO 15
    PLO 8               ; R8.0 = R15.0
    IRX
    LDX                 ; Restore character
    CALL SERIAL_WRITE_CHAR
    ; Restore R15
    GHI 8
    PHI 15
    GLO 8
    PLO 15
    BR PRINT_LOOP

PRINT_DONE:
    RETN
#endif

; ==============================================================================
; WORKSPACE_CLEAR - Zero all workspace RAM ($6200-$67FF)
; ==============================================================================
; Clears 1536 bytes ($0600) to prevent stale variable bugs between runs.
; Must be called before INIT_BOARD (which populates the board area).
;
; Range expanded 2026-04-24 from $6200-$64FF (768 bytes) to $6200-$67FF
; (1536 bytes) to cover variables that have been added at $6500+ over time:
;   $6500-$66FD: HASH_HIST (510 bytes - repetition detection)
;   $6700-$670F: NODE_BEST_MOVE (16 bytes - per-ply best move)
;   $6710-$671F: W/B_PAWN_FILE_CT (16 bytes - eval transients)
;   $6720-$6721: W/B_QUEEN_SQ (eval transients)
;   $6722-$6741: FUTILITY_TABLE (relocated 2026-04-24, 8-ply futility data)
;   $6742-$67FF: free zone, cleared defensively
; TT at $6800-$6FFF has its own TT_CLEAR routine.
;
; Uses: R9 (counter), R10 (pointer)
; ==============================================================================
WORKSPACE_CLEAR:
    LDI $62
    PHI 10
    LDI $00
    PLO 10              ; R10 = $6200

    ; 1536 bytes = $0600
    LDI $06
    PHI 9
    LDI $00
    PLO 9               ; R9 = $0600

WORKSPACE_CLEAR_LOOP:
    LDI 0               ; Value to write (must reload — GHI/GLO clobber D)
    STR 10
    INC 10
    DEC 9
    GHI 9
    LBNZ WORKSPACE_CLEAR_LOOP
    GLO 9
    LBNZ WORKSPACE_CLEAR_LOOP

    ; Also clear MOVE_LIST area $7800-$7AFF (768 bytes).
    ; MOVE_LIST was relocated $6200→$7800 in commit 3b16d64 for the d=5
    ; expansion. Its zone now sits immediately below stack guard $7B00.
    ; If GENERATE_MOVES is ever called with a corrupted count value, or
    ; pointer math wanders past the per-ply allocation, residual data here
    ; would decode as phantom moves. Zeroing means stale-bytes decode to
    ; a1→a1 — still illegal but at least not a "real-looking" coordinates.
    LDI $78
    PHI 10
    LDI $00
    PLO 10              ; R10 = $7800

    LDI $03
    PHI 9
    LDI $00
    PLO 9               ; R9 = $0300 (768 bytes)

WORKSPACE_CLEAR_ML_LOOP:
    LDI 0
    STR 10
    INC 10
    DEC 9
    GHI 9
    LBNZ WORKSPACE_CLEAR_ML_LOOP
    GLO 9
    LBNZ WORKSPACE_CLEAR_ML_LOOP

    RETN

; ==============================================================================
; Dead test/utility stubs (TEST_MOVE_GEN, TEST_MAKE_UNMAKE, TEST_SEARCH,
; PRINT_BOARD, MOVE_TO_STRING, STRING_TO_MOVE) and the unused leftover strings
; VERSION_STRING/ENGINE_NAME/ENGINE_AUTHOR removed 2026-05-18. The live UCI id
; strings are STR_ID_NAME/STR_ID_AUTHOR in uci.asm; these had zero references.
; Reclaims space so the binary tail stays below \$6000 (BOARD) after item-C.
; ==============================================================================

; ==============================================================================
; Messages
; ==============================================================================

MSG_STARTUP:
    DB 13, 10
    DB "RCA 1802/1806 Chess Engine", 13, 10
    DB "Initializing...", 13, 10
    DB 0

; ==============================================================================
; End of Main Program
; ==============================================================================
