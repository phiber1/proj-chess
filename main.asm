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
    LDI HIGH(MAIN_CONTINUE)
    PHI 6
    LDI LOW(MAIN_CONTINUE)
    PLO 6
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
    LDI HIGH(MSG_STARTUP)
    PHI 15
    LDI LOW(MSG_STARTUP)
    PLO 15
    CALL PRINT_STRING

    ; Initialize UCI
    CALL UCI_INIT

    ; Enter main loop
    BR MAIN_LOOP

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
; WORKSPACE_CLEAR - Zero all workspace RAM ($6200-$64FF)
; ==============================================================================
; Clears 768 bytes ($0300) to prevent stale variable bugs between runs.
; Must be called before INIT_BOARD (which populates the board area).
;
; Uses: R9 (counter), R10 (pointer)
; ==============================================================================
WORKSPACE_CLEAR:
    LDI $62
    PHI 10
    LDI $00
    PLO 10              ; R10 = $6200

    ; 768 bytes = $0300
    LDI $03
    PHI 9
    LDI $00
    PLO 9               ; R9 = $0300

    LDI 0               ; Value to write
WORKSPACE_CLEAR_LOOP:
    STR 10
    INC 10
    DEC 9
    GHI 9
    LBNZ WORKSPACE_CLEAR_LOOP
    GLO 9
    LBNZ WORKSPACE_CLEAR_LOOP

    RETN

; ==============================================================================
; Test Functions (SEARCH_POSITION is in negamax.asm)
; ==============================================================================

TEST_MOVE_GEN:
    CALL INIT_BOARD

    LDI HIGH(MOVE_LIST)
    PHI 9
    LDI LOW(MOVE_LIST)
    PLO 9

    LDI HIGH(BOARD)
    PHI 10
    LDI LOW(BOARD)
    PLO 10

    CALL GET_SIDE_TO_MOVE
    PLO 12

    CALL GENERATE_MOVES
    RETN

TEST_MAKE_UNMAKE:
    CALL INIT_BOARD
    CALL TEST_MOVE_GEN

    ; Load first move from move list into R11 (NOT R6 - R6 is SCRT linkage!)
    LDI HIGH(MOVE_LIST)
    PHI 10
    LDI LOW(MOVE_LIST)
    PLO 10

    LDA 10
    PLO 11
    LDN 10
    PHI 11              ; R11 = first move

    LDI HIGH(BOARD)
    PHI 10
    LDI LOW(BOARD)
    PLO 10

    CALL MAKE_MOVE
    CALL UNMAKE_MOVE
    RETN

TEST_SEARCH:
    CALL INIT_BOARD

    ; Set depth in memory (R5 is SRET - cannot use!)
    LDI HIGH(SEARCH_DEPTH)
    PHI 13
    LDI LOW(SEARCH_DEPTH)
    PLO 13
    LDI 0
    STR 13              ; SEARCH_DEPTH high = 0
    INC 13
    LDI 3
    STR 13              ; SEARCH_DEPTH low = 3

    CALL SEARCH_POSITION
    RETN

; ==============================================================================
; Utility Functions
; ==============================================================================

PRINT_BOARD:
    ; TODO: Implementation
    RETN

MOVE_TO_STRING:
    CALL DECODE_MOVE_16BIT
    ; TODO: Implementation
    RETN

STRING_TO_MOVE:
    ; TODO: Implementation
    RETN

; ==============================================================================
; Messages
; ==============================================================================

MSG_STARTUP:
    DB 13, 10
    DB "RCA 1802/1806 Chess Engine", 13, 10
    DB "Initializing...", 13, 10
    DB 0

; Version string
VERSION_STRING:
    DB "RCA Chess Engine v0.1", 0

ENGINE_NAME:
    DB "RCA-Chess-1806", 0

ENGINE_AUTHOR:
    DB "Generated with Claude Code", 0

; ==============================================================================
; End of Main Program
; ==============================================================================
