; ==============================================================================
; BIOS Input Test - Test F_READ
; ==============================================================================

    ORG $0000

#ifdef BIOS
; BIOS I/O Entry Points
F_TYPE  EQU $FF03       ; Output character in D
F_READ  EQU $FF06       ; Read character into D (with echo)
F_MSG   EQU $FF09       ; Output string pointed to by R15

START:
    ; Print prompt
    LDI HIGH(STR_PROMPT)
    PHI 15
    LDI LOW(STR_PROMPT)
    PLO 15
    SEP 4
    DW F_MSG

    ; Read a character (F_READ includes echo)
    SEP 4
    DW F_READ

    ; Save it
    PLO 11

    ; Print response
    LDI HIGH(STR_GOT)
    PHI 15
    LDI LOW(STR_GOT)
    PLO 15
    SEP 4
    DW F_MSG

    ; Print the character again
    GLO 11
    SEP 4
    DW F_TYPE

    ; Newline
    LDI 0DH
    SEP 4
    DW F_TYPE
    LDI 0AH
    SEP 4
    DW F_TYPE

    ; Exit to monitor
    LBR $8003

STR_PROMPT:
    DB "Press a key: ",0
STR_GOT:
    DB 0DH,0AH,"You pressed: ",0

#else
    IDL
#endif
