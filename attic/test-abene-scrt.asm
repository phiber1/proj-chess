; ==============================================================================
; Test using Abene's SCRT pattern exactly
; ==============================================================================

    ORG $6F00

; ------------------------------------------------------------------------------
; SCRT using Abene's pattern
; ------------------------------------------------------------------------------
; R4 = CALL, R5 = RET, R6 = linkage, R2 = stack, RE.0 = temp for D
; ------------------------------------------------------------------------------

    SEP 3               ; At CALL-1: return to caller
CALL:
    PLO 14              ; Save D in RE.0
    GHI 6               ; Save old R6 to stack
    SEX 2
    STXD
    GLO 6
    STXD
    GHI 3               ; Copy R3 to R6
    PHI 6
    GLO 3
    PLO 6
    LDA 6               ; Get subroutine address high
    PHI 3               ; Put into R3
    LDA 6               ; Get subroutine address low
    PLO 3
    GLO 14              ; Recover D
    BR CALL-1           ; Transfer control (SEP 3)

    SEP 3               ; At RET-1: return to caller
RET:
    PLO 14              ; Save D
    GHI 6               ; Copy R6 to R3 (return address)
    PHI 3
    GLO 6
    PLO 3
    SEX 2
    IRX                 ; Point to old R6
    LDXA
    PLO 6
    LDX
    PHI 6
    GLO 14              ; Recover D
    BR RET-1            ; Transfer control (SEP 3)

; ------------------------------------------------------------------------------
; Test at $7000
; ------------------------------------------------------------------------------
    ORG $7000

TEST_START:
    SEQ                 ; Show we started

    ; Stack at $7FFF
    LDI $7F
    PHI 2
    LDI $FF
    PLO 2
    SEX 2

    ; R6 = starting address of MAIN (for INITCALL pattern)
    LDI HIGH(MAIN)
    PHI 6
    LDI LOW(MAIN)
    PLO 6

    ; CRITICAL: Push dummy R6 to stack before INITCALL
    ; because RET will try to "restore" R6 even on first call
    GHI 6
    STXD
    GLO 6
    STXD

    ; Now do INITCALL pattern
    LBR INITCALL

INITCALL:
    LDI HIGH(RET)
    PHI 5
    LDI LOW(RET)
    PLO 5
    LDI HIGH(CALL)
    PHI 4
    LDI LOW(CALL)
    PLO 4
    SEP 5               ; This jumps to RET which will set R3=R6 and SEP 3

MAIN:
    ; Made it here via INITCALL
    REQ
    SEQ

    ; Save R2 for checking
    GHI 2
    PHI 8
    GLO 2
    PLO 8

    ; Do a CALL/RET
    SEP 4
    DW DUMMY

    ; Check stack balance
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

SUCCESS:
    REQ
    LDI $20
    PLO 9
S1: DEC 9
    GLO 9
    BNZ S1
    SEQ
    LDI $20
    PLO 9
S2: DEC 9
    GLO 9
    BNZ S2
    BR SUCCESS

FAIL:
    SEQ
    LDI $FF
    PLO 9
    PHI 9
F1: DEC 9
    GHI 9
    BNZ F1
    GLO 9
    BNZ F1
    REQ
    LDI $FF
    PLO 9
    PHI 9
F2: DEC 9
    GHI 9
    BNZ F2
    GLO 9
    BNZ F2
    BR FAIL

DUMMY:
    SEP 5               ; Return (equivalent to RETN)

    END
