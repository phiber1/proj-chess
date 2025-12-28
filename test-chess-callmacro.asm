; ==============================================================================
; Test CALL/RETN macros with Friday's SCRT pattern
; ==============================================================================
; Verifies that a18's CALL/RETN macros work with CALL/RET labels
; ==============================================================================

    ORG $0000
    LBR MAIN

#include "serial-io.asm"

; ==============================================================================
; Mark Abene's SCRT implementation (uses R7 for D, not R14!)
; ==============================================================================
INITCALL:
    LDI HIGH(RET)
    PHI 5
    LDI LOW(RET)
    PLO 5
    LDI HIGH(CALL)
    PHI 4
    LDI LOW(CALL)
    PLO 4
    SEP 5

    SEP 3
CALL:
    PLO 7
    GHI 6
    SEX 2
    STXD
    GLO 6
    STXD
    GHI 3
    PHI 6
    GLO 3
    PLO 6
    LDA 6
    PHI 3
    LDA 6
    PLO 3
    GLO 7
    BR CALL-1

    SEP 3
RET:
    PLO 7
    GHI 6
    PHI 3
    GLO 6
    PLO 3
    SEX 2
    IRX
    LDXA
    PLO 6
    LDX
    PHI 6
    GLO 7
    BR RET-1

; ==============================================================================
; Test function using RETN macro
; ==============================================================================
PRINT_MSG:
    ; R8 already has string pointer
    SEP 4
    DW SERIAL_PRINT_STRING
    RETN                    ; <-- Test RETN macro

; ==============================================================================
; Main program
; ==============================================================================
MAIN:
    LDI HIGH(START)
    PHI 6
    LDI LOW(START)
    PLO 6
    LBR INITCALL

START:
    LDI $7F
    PHI 2
    LDI $FF
    PLO 2
    SEX 2
    REQ

    ; Test 1: Use SEP 4/DW directly (known working)
    LDI HIGH(MSG1)
    PHI 8
    LDI LOW(MSG1)
    PLO 8
    SEP 4
    DW SERIAL_PRINT_STRING

    ; Test 2: Use CALL macro to call our function
    LDI HIGH(MSG2)
    PHI 8
    LDI LOW(MSG2)
    PLO 8
    CALL PRINT_MSG          ; <-- Test CALL macro

    ; Test 3: Direct CALL to serial
    LDI HIGH(MSG3)
    PHI 8
    LDI LOW(MSG3)
    PLO 8
    CALL SERIAL_PRINT_STRING

    ; Success
    LDI HIGH(MSG_OK)
    PHI 8
    LDI LOW(MSG_OK)
    PLO 8
    SEP 4
    DW SERIAL_PRINT_STRING

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

MSG1:
    DB "Test 1: SEP 4/DW direct - ", 0
MSG2:
    DB "Test 2: CALL macro - ", 0
MSG3:
    DB "Test 3: CALL SERIAL - ", 0
MSG_OK:
    DB "All OK!", 0DH, 0AH, 0

    END MAIN
