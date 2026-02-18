; ==============================================================================
; Simple CALL/RETN Test for a18 assembler
; ==============================================================================
; Tests whether a18's built-in CALL/RETN work

    ORG $0000

START:
    DIS                 ; Disable interrupts

    ; Set up stack pointer (R2)
    LDI $7F
    PHI 2
    LDI $FF
    PLO 2              ; R2 = $7FFF (stack top)

    ; Initialize R6 for SCRT (if needed by a18's CALL macro)
    LDI HIGH(SCRT_CALL)
    PHI 6
    LDI LOW(SCRT_CALL)
    PLO 6

    ; Initialize R5 for SCRT return (if needed)
    LDI HIGH(SCRT_RET)
    PHI 5
    LDI LOW(SCRT_RET)
    PLO 5

    ; Blink Q once before calling subroutine
    SEQ
    LDI $FF
    PLO 4
BLINK1:
    DEC 4
    GLO 4
    BNZ BLINK1
    REQ

    ; Test CALL/RETN
    CALL TEST_SUB

    ; If we get here, CALL/RETN worked!
    ; Blink Q twice to signal success
    SEQ
    LDI $FF
    PLO 4
BLINK2:
    DEC 4
    GLO 4
    BNZ BLINK2
    REQ

    LDI $FF
    PLO 4
BLINK3:
    DEC 4
    GLO 4
    BNZ BLINK3
    SEQ

HALT:
    IDL
    BR HALT

; ==============================================================================
; Test subroutine
; ==============================================================================
TEST_SUB:
    ; Do a small delay, just to show we're here
    LDI $80
    PLO 4
DELAY:
    DEC 4
    GLO 4
    BNZ DELAY

    RETN

; ==============================================================================
; SCRT Support (Standard Call/Return Technique)
; ==============================================================================
; These routines implement the standard 1802 subroutine mechanism
; R6 = call register, R5 = return register

SCRT_CALL:
    ; Save return address (R3) to stack
    GHI 3
    STR 2
    DEC 2
    GLO 3
    STR 2
    DEC 2

    ; Load target address from inline data following CALL
    ; (a18's CALL macro likely places target address inline)
    ; For now, assume target is in R6
    GHI 6
    PHI 3
    GLO 6
    PLO 3

    SEP 3               ; Jump to subroutine

SCRT_RET:
    ; Restore return address from stack to R3
    INC 2
    LDN 2
    PLO 3
    INC 2
    LDN 2
    PHI 3

    SEP 3               ; Return to caller

    END START
