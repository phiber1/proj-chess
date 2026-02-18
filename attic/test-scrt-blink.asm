; ==============================================================================
; Minimal SCRT Test with Q Blink
; ==============================================================================
; Tests SCRT by:
;   1. Q blinks once BEFORE calling subroutine
;   2. Calls TEST_SUB which does a delay
;   3. Q blinks twice AFTER returning from subroutine
; If Q only blinks once, SCRT crashed
; If Q blinks 3 times, SCRT works!
; ==============================================================================
;
; IMPORTANT: Register Usage Restrictions
; R2 = Stack pointer (DO NOT MODIFY)
; R3 = Program counter (managed by hardware/SCRT)
; R4 = SCALL handler (DO NOT USE in application code)
; R5 = SRET handler (DO NOT USE in application code)
; R6 = Temp for SCRT (safe to use in application, but will be modified by CALL)
; R7-RF = Available for application use
; ==============================================================================

    ORG $0000

START:
    DIS                 ; Disable interrupts

    ; Set up stack pointer (R2)
    LDI $7F
    PHI 2
    LDI $FF
    PLO 2              ; R2 = $7FFF (stack top)
    SEX 2              ; Set X register to R2

    ; Initialize SCRT
    LDI HIGH(SCALL)
    PHI 4
    LDI LOW(SCALL)
    PLO 4

    LDI HIGH(SRET)
    PHI 5
    LDI LOW(SRET)
    PLO 5

    ; Blink Q once (before CALL)
    SEQ
    LDI $80
    PLO 3
BLINK1:
    DEC 3
    GLO 3
    BNZ BLINK1
    REQ

    ; Delay
    LDI $80
    PLO 3
DELAY1:
    DEC 3
    GLO 3
    BNZ DELAY1

    ; TEST SCRT: Call a subroutine
    CALL TEST_SUB

    ; If we get here, CALL/RETN worked!
    ; Blink Q twice more (total 3 blinks = success)
    SEQ
    LDI $80
    PLO 3
BLINK2:
    DEC 3
    GLO 3
    BNZ BLINK2
    REQ

    LDI $80
    PLO 3
DELAY2:
    DEC 3
    GLO 3
    BNZ DELAY2

    SEQ
    LDI $80
    PLO 3
BLINK3:
    DEC 3
    GLO 3
    BNZ BLINK3
    REQ

    ; Repeat forever to confirm success
REPEAT:
    LDI $FF
    PHI 3
    LDI $FF
    PLO 3
LONG_DELAY:
    DEC 3
    GLO 3
    BNZ LONG_DELAY
    GHI 3
    BNZ LONG_DELAY

    BR START

; ==============================================================================
; Test Subroutine
; ==============================================================================
TEST_SUB:
    ; Just do a small delay to show we're in the subroutine
    LDI $40
    PLO 7              ; Use R7, not R4! (R4/R5 are reserved for SCRT)
SUB_DELAY:
    DEC 7
    GLO 7
    BNZ SUB_DELAY

    RETN

; ==============================================================================
; SCRT Support
; ==============================================================================
SCALL:
    LDA 3               ; Read target address high byte
    PHI 6
    LDA 3               ; Read target address low byte
    PLO 6

    GHI 3               ; Save return address to stack
    STXD
    GLO 3
    STXD

    GHI 6               ; Set PC to target
    PHI 3
    GLO 6
    PLO 3

    SEP 3               ; Jump

SRET:
    IRX                 ; Restore return address
    LDXA                ; Load low byte, R2++
    PLO 3
    LDXA                ; Load high byte, R2++ (FIX: was LDX)
    PHI 3
    SEP 3               ; Return

    END START
