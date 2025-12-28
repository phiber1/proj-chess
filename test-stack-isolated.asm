; ==============================================================================
; Isolated Stack Test - Minimal SCRT test
; ==============================================================================
; Tests CALL/RETN stack balance with Q blinks to show progress
; No serial I/O, no complex code - just stack operations
; ==============================================================================

    ORG $0000

; ------------------------------------------------------------------------------
; SCRT Routines
; ------------------------------------------------------------------------------
SCALL:
    LDA 3               ; D = high byte, R3++
    PHI 6               ; R6.1 = target high
    LDA 3               ; D = low byte, R3++
    PLO 6               ; R6.0 = target low

    ; Save return address (R3) to stack
    GHI 3
    STXD                ; Push high byte (store then decrement)
    GLO 3
    STXD                ; Push low byte (store then decrement)

    ; Set PC (R3) to target address (R6)
    GHI 6
    PHI 3
    GLO 6
    PLO 3

    SEP 3               ; Jump to target

SRET:
    IRX                 ; R2++
    LDXA                ; D = low byte, R2++ (post-increment)
    PLO 3
    LDX                 ; D = high byte (NO increment)
    PHI 3

    SEP 3               ; Return to caller

; ------------------------------------------------------------------------------
; Test code at $7000
; ------------------------------------------------------------------------------
    ORG $7000

TEST_START:
    ; Initialize R2 (stack pointer)
    LDI $7F
    PHI 2
    LDI $FF
    PLO 2
    SEX 2

    ; Initialize R4 (SCALL)
    LDI $00
    PHI 4
    LDI $00             ; SCALL at $0000
    PLO 4

    ; Initialize R5 (SRET)
    LDI $00
    PHI 5
    LDI $0D             ; SRET at $000D
    PLO 5

    ; Save initial R2 value in R8
    GHI 2
    PHI 8               ; R8.1 = $7F
    GLO 2
    PLO 8               ; R8.0 = $FF, R8 = $7FFF

    ; Switch to R3 as PC
    LDI HIGH(TEST_MAIN)
    PHI 3
    LDI LOW(TEST_MAIN)
    PLO 3
    SEP 3

TEST_MAIN:
    ; Blink 1: Show we're alive
    SEQ
    CALL DELAY
    REQ
    CALL DELAY

    ; Check R2 - should still be $7FFF
    GHI 2
    STR 2
    GHI 8
    XOR
    BNZ FAIL
    GLO 2
    STR 2
    GLO 8
    XOR
    BNZ FAIL

    ; Blink 2: First CALL/RETN worked
    SEQ
    CALL DELAY
    REQ
    CALL DELAY

    ; Do another CALL
    CALL DUMMY_SUB

    ; Check R2 again
    GHI 2
    STR 2
    GHI 8
    XOR
    BNZ FAIL
    GLO 2
    STR 2
    GLO 8
    XOR
    BNZ FAIL

    ; Blink 3: Second CALL/RETN worked
    SEQ
    CALL DELAY
    REQ
    CALL DELAY

    ; Do 10 more CALLs
    CALL DUMMY_SUB
    CALL DUMMY_SUB
    CALL DUMMY_SUB
    CALL DUMMY_SUB
    CALL DUMMY_SUB
    CALL DUMMY_SUB
    CALL DUMMY_SUB
    CALL DUMMY_SUB
    CALL DUMMY_SUB
    CALL DUMMY_SUB

    ; Check R2 after 10 calls
    GHI 2
    STR 2
    GHI 8
    XOR
    BNZ FAIL
    GLO 2
    STR 2
    GLO 8
    XOR
    BNZ FAIL

    ; SUCCESS! Fast blink forever
SUCCESS:
    SEQ
    LDI $08
    PLO 9
S_DELAY1:
    DEC 9
    GLO 9
    BNZ S_DELAY1
    REQ
    LDI $08
    PLO 9
S_DELAY2:
    DEC 9
    GLO 9
    BNZ S_DELAY2
    BR SUCCESS

FAIL:
    ; FAIL - slow blink with long pause
FAIL_LOOP:
    SEQ
    LDI $00
    PHI 9
    LDI $00
    PLO 9
F_DELAY1:
    DEC 9
    GHI 9
    BNZ F_DELAY1
    GLO 9
    BNZ F_DELAY1
    REQ
    LDI $00
    PHI 9
    LDI $00
    PLO 9
F_DELAY2:
    DEC 9
    GHI 9
    BNZ F_DELAY2
    GLO 9
    BNZ F_DELAY2
    BR FAIL_LOOP

; ------------------------------------------------------------------------------
; Subroutines
; ------------------------------------------------------------------------------
DELAY:
    LDI $40
    PLO 9
DELAY_LOOP:
    DEC 9
    GLO 9
    BNZ DELAY_LOOP
    RETN

DUMMY_SUB:
    ; Do nothing, just return
    RETN

    END
