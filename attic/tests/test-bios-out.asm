; ==============================================================================
; BIOS Output Test - Minimal test of F_TYPE and F_MSG
; ==============================================================================

    ORG $0000

#ifdef BIOS
; BIOS I/O Entry Points
F_TYPE  EQU $FF03       ; Output character in D
F_MSG   EQU $FF09       ; Output string pointed to by R15

START:
    ; Test 1: Single character output via F_TYPE
    LDI 'A'
    SEP 4
    DW F_TYPE

    LDI 'B'
    SEP 4
    DW F_TYPE

    LDI 'C'
    SEP 4
    DW F_TYPE

    ; Newline
    LDI 0DH
    SEP 4
    DW F_TYPE
    LDI 0AH
    SEP 4
    DW F_TYPE

    ; Test 2: String output via F_MSG
    LDI HIGH(STR_TEST)
    PHI 15
    LDI LOW(STR_TEST)
    PLO 15
    SEP 4
    DW F_MSG

    ; Exit back to monitor
    LBR $8003

STR_TEST:
    DB "Hello from BIOS!",0DH,0AH,0

#else
    ; Standalone mode - just halt
    IDL
#endif
