; ==============================================================================
; Test CALL/RETN with proper SCRT initialization
; ==============================================================================
; This tests whether CALL/RETN work with R6 initialized

    ORG $0000

START:
    DIS                 ; Disable interrupts

    ; Set up stack pointer (R2)
    LDI $7F
    PHI 2
    LDI $FF
    PLO 2              ; R2 = $7FFF (stack top)

    ; CRITICAL: Initialize R6 for SCRT (Standard Call/Return Technique)
    ; R6 must be set as the subroutine program counter
    LDI HIGH(SCALL)
    PHI 6
    LDI LOW(SCALL)
    PLO 6              ; R6 = SCALL routine address

    ; Now R3 needs to be the main program counter
    ; (R3 is already the PC after reset on 1802)

    ; Blink Q once before calling subroutine
    SEQ
    LDI $FF
    PLO 3
BLINK1:
    DEC 3
    GLO 3
    BNZ BLINK1
    REQ

    ; Test CALL/RETN
    CALL TEST_SUB

    ; If we get here, CALL/RETN worked!
    ; Blink Q twice to signal success
    SEQ
    LDI $FF
    PLO 3
BLINK2:
    DEC 3
    GLO 3
    BNZ BLINK2
    REQ

    LDI $FF
    PLO 3
BLINK3:
    DEC 3
    GLO 3
    BNZ BLINK3
    SEQ

    LDI $FF
    PLO 3
BLINK4:
    DEC 3
    GLO 3
    BNZ BLINK4
    REQ

HALT:
    IDL
    BR HALT

; ==============================================================================
; Test subroutine
; ==============================================================================
TEST_SUB:
    ; Do nothing, just return
    RETN

; ==============================================================================
; SCRT Support Routines
; ==============================================================================
; Standard Call/Return Technique for 1802

; SCALL - Standard call routine (called via SEP 6)
SCALL:
    ; Save return address from R3 (current PC) to stack
    GHI 3
    STR 2
    DEC 2
    GLO 3
    STR 2
    DEC 2

    ; Load subroutine address from R6 into R3 (PC)
    LDA 6
    PHI 3
    LDA 6
    PLO 3

    ; Jump to subroutine
    SEP 3

; SRET - Standard return routine
SRET:
    ; Restore return address from stack to R3 (PC)
    INC 2
    LDN 2
    PLO 3
    INC 2
    LDN 2
    PHI 3

    ; Return to caller
    SEP 3

; ==============================================================================
; CALL and RETN Macros (these should match what a18 uses)
; ==============================================================================
CALL:   MACRO target
        LDI HIGH(target)
        PHI 6
        LDI LOW(target)
        PLO 6
        SEP 6
        ENDM

RETN:   MACRO
        SEP 5
        ENDM

    END START
