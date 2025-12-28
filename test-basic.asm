; ==============================================================================
; Most Basic Test - Just set Q and halt
; ==============================================================================
; No loops, no calls, just linear execution
; ==============================================================================

    ORG $0000

START:
    SEX 2              ; Set X to R2

    ; Set Q high
    SEQ

    ; Infinite loop by branching to same address
HALT:
    IDL                ; Idle instruction - stops execution
    BR HALT            ; Should never reach here

    END
