; ==============================================================================
; SCRT Debug Test - Toggle Q at each stage to find where it fails
; ==============================================================================

; ------------------------------------------------------------------------------
; SCRT Routines at $0000 (must be here for CALL/RETN to work)
; ------------------------------------------------------------------------------
    ORG $0000

SCALL:
    ; Read target address from inline data (R3 points to it)
    LDA 3               ; D = high byte, R3++
    PHI 6               ; R6.1 = target high
    LDA 3               ; D = low byte, R3++
    PLO 6               ; R6.0 = target low

    ; Save return address (R3) to stack
    GHI 3
    STXD                ; Push high byte
    GLO 3
    STXD                ; Push low byte

    ; Set PC (R3) to target address (R6)
    GHI 6
    PHI 3
    GLO 6
    PLO 3

    ; Jump to target
    SEP 3

SRET:
    ; Restore return address from stack to R3
    IRX                 ; R2++
    LDXA                ; D = low byte, R2++
    PLO 3               ; R3.0 = return address low
    LDX                 ; D = high byte (no increment)
    PHI 3               ; R3.1 = return address high

    ; Return to caller
    SEP 3

; ------------------------------------------------------------------------------
; Test code at $7000
; ------------------------------------------------------------------------------
    ORG $7000

DEBUG_START:
    ; Stage 1: We're alive
    SEQ                     ; Q HIGH = Stage 1 reached

    ; Short delay so we can see Q state
    LDI $20
    PLO 8
DELAY1:
    DEC 8
    GLO 8
    BNZ DELAY1

    REQ                     ; Q LOW = Stage 1 complete

    ; Brief pause
    LDI $20
    PLO 8
DELAY1B:
    DEC 8
    GLO 8
    BNZ DELAY1B

    ; Stage 2: Set up stack (R2)
    LDI $7F
    PHI 2
    LDI $FF
    PLO 2
    SEX 2

    SEQ                     ; Q HIGH = Stage 2 complete (stack ready)

    LDI $20
    PLO 8
DELAY2:
    DEC 8
    GLO 8
    BNZ DELAY2

    REQ                     ; Q LOW

    LDI $20
    PLO 8
DELAY2B:
    DEC 8
    GLO 8
    BNZ DELAY2B

    ; Stage 3: Set up R4 (SCALL at $0000)
    LDI $00                 ; HIGH(SCALL)
    PHI 4
    LDI $00                 ; LOW(SCALL)
    PLO 4

    SEQ                     ; Q HIGH = Stage 3 complete (R4 ready)

    LDI $20
    PLO 8
DELAY3:
    DEC 8
    GLO 8
    BNZ DELAY3

    REQ

    LDI $20
    PLO 8
DELAY3B:
    DEC 8
    GLO 8
    BNZ DELAY3B

    ; Stage 4: Set up R5 (SRET at $000D)
    LDI $00                 ; HIGH(SRET)
    PHI 5
    LDI $0D                 ; LOW(SRET)
    PLO 5

    SEQ                     ; Q HIGH = Stage 4 complete (R5 ready)

    LDI $20
    PLO 8
DELAY4:
    DEC 8
    GLO 8
    BNZ DELAY4

    REQ

    LDI $20
    PLO 8
DELAY4B:
    DEC 8
    GLO 8
    BNZ DELAY4B

    ; Stage 5: Set up R3 and switch PC
    LDI HIGH(STAGE5_CONT)
    PHI 3
    LDI LOW(STAGE5_CONT)
    PLO 3

    SEP 3                   ; Switch to R3 as PC!

STAGE5_CONT:
    ; If we get here, SEP 3 worked!
    SEQ                     ; Q HIGH = Stage 5 complete (SEP 3 worked!)

    LDI $20
    PLO 8
DELAY5:
    DEC 8
    GLO 8
    BNZ DELAY5

    REQ

    LDI $20
    PLO 8
DELAY5B:
    DEC 8
    GLO 8
    BNZ DELAY5B

    ; Stage 6: Try a CALL!
    ; CALL expands to SEP 4 followed by address
    ; This tests the full SCRT mechanism

    CALL TEST_SUBROUTINE

    ; If we get here, CALL and RETN worked!
    SEQ                     ; Q HIGH = Stage 6 complete (CALL/RETN works!)

    ; Success - fast blink forever
SUCCESS_LOOP:
    SEQ
    LDI $10
    PLO 8
DELAYS1:
    DEC 8
    GLO 8
    BNZ DELAYS1
    REQ
    LDI $10
    PLO 8
DELAYS2:
    DEC 8
    GLO 8
    BNZ DELAYS2
    BR SUCCESS_LOOP

; ------------------------------------------------------------------------------
; Simple test subroutine
; ------------------------------------------------------------------------------
TEST_SUBROUTINE:
    ; Just toggle Q twice quickly to show we're in the subroutine
    SEQ
    NOP
    NOP
    NOP
    NOP
    REQ
    NOP
    NOP
    NOP
    NOP
    SEQ
    NOP
    NOP
    NOP
    NOP
    REQ
    RETN                    ; Return to caller

    END
