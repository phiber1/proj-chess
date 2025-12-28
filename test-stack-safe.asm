; ==============================================================================
; Safe Stack Test - SCRT at $6F00 to avoid low memory
; ==============================================================================

    ORG $6F00

; ------------------------------------------------------------------------------
; SCRT Routines at $6F00 (safe from any low-memory conflicts)
; ------------------------------------------------------------------------------
SCALL:
    LDA 3               ; D = high byte, R3++
    PHI 6
    LDA 3               ; D = low byte, R3++
    PLO 6

    ; Push return address
    GHI 3
    STXD                ; Store then decrement
    GLO 3
    STXD

    ; Jump to target
    GHI 6
    PHI 3
    GLO 6
    PLO 3
    SEP 3

SRET:
    IRX                 ; Increment
    LDXA                ; Load then increment
    PLO 3
    LDX                 ; Load (no increment)
    PHI 3
    SEP 3

; ------------------------------------------------------------------------------
; Test at $7000
; ------------------------------------------------------------------------------
    ORG $7000

TEST_START:
    ; Blink immediately to show we're alive
    SEQ

    ; Set stack
    LDI $7F
    PHI 2
    LDI $FF
    PLO 2
    SEX 2

    ; Set R4 = SCALL ($6F00)
    LDI $6F
    PHI 4
    LDI $00
    PLO 4

    ; Set R5 = SRET ($6F0D)
    LDI $6F
    PHI 5
    LDI $0D
    PLO 5

    ; Save R2 in R8
    GHI 2
    PHI 8
    GLO 2
    PLO 8

    ; Switch to R3
    LDI HIGH(MAIN)
    PHI 3
    LDI LOW(MAIN)
    PLO 3
    SEP 3

MAIN:
    ; Blink 2 - made it past SEP 3
    REQ
    SEQ

    ; Do one CALL/RETN
    CALL DUMMY

    ; Check R2
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

    ; SUCCESS - fast blink
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
    ; Slow blink
    REQ
    LDI $FF
    PLO 9
    PHI 9
F1: DEC 9
    GHI 9
    BNZ F1
    GLO 9
    BNZ F1
    SEQ
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
    RETN

    END
