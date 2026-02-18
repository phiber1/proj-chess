; ==============================================================================
; Read Line Test - RCA 1802 Membership Card
; Tests SERIAL_READ_LINE routine with echo and backspace
; 9600 baud at 1.75 MHz
; ==============================================================================

    ORG $0000

; ==============================================================================
; Entry point - set R6 to main, then jump to INITCALL
; ==============================================================================
    LDI HIGH(MAIN)
    PHI 6
    LDI LOW(MAIN)
    PLO 6
    LBR INITCALL

; ==============================================================================
; SERIAL_READ_LINE - Read line with echo into buffer
; Input: R8 = pointer to buffer, R9.0 = max length (including null)
; Output: Buffer filled with null-terminated string
; Handles: Echo, Backspace (08H or 7FH), Enter (0DH)
; ==============================================================================
SERIAL_READ_LINE:
    GLO 9               ; Get max length
    SMI 1               ; Reserve space for null terminator
    PLO 9               ; R9.0 = max chars we can store
    LDI 0
    PHI 9               ; R9.1 = current count

READ_NEXT:
    SEP 4
    DW SERIAL_READ_CHAR ; Read character into D

    ; Check for Enter (CR = 0DH)
    SMI 0DH
    BZ READ_DONE

    ; Check for Backspace (08H)
    ADI 0DH             ; Restore D
    SMI 08H
    BZ DO_BACKSPACE

    ; Check for DEL (7FH) - also treat as backspace
    ADI 08H             ; Restore D
    SMI 7FH
    BZ DO_BACKSPACE

    ; Regular character - check if buffer full
    ADI 7FH             ; Restore D
    PLO 10              ; Save char in R10.0 temporarily

    GHI 9               ; Get current count
    STR 2               ; Store on stack
    GLO 9               ; Get max
    SM                  ; max - count
    BZ READ_NEXT        ; Buffer full, ignore character

    ; Store character and echo it
    GLO 10              ; Get character back
    STR 8               ; Store in buffer
    INC 8               ; Advance buffer pointer
    GHI 9               ; Increment count
    ADI 1
    PHI 9

    GLO 10              ; Echo the character
    SEP 4
    DW SERIAL_WRITE_CHAR

    BR READ_NEXT

DO_BACKSPACE:
    ; Check if anything to delete
    GHI 9               ; Get current count
    BZ READ_NEXT        ; Nothing to delete

    ; Decrement count and pointer
    SMI 1
    PHI 9
    DEC 8

    ; Echo: backspace, space, backspace (erase character on terminal)
    LDI 08H
    SEP 4
    DW SERIAL_WRITE_CHAR
    LDI ' '
    SEP 4
    DW SERIAL_WRITE_CHAR
    LDI 08H
    SEP 4
    DW SERIAL_WRITE_CHAR

    BR READ_NEXT

READ_DONE:
    ; Null-terminate the buffer
    LDI 0
    STR 8

    ; Echo CR+LF
    LDI 0DH
    SEP 4
    DW SERIAL_WRITE_CHAR
    LDI 0AH
    SEP 4
    DW SERIAL_WRITE_CHAR

    SEP 5               ; Return

; ==============================================================================
; SERIAL_PRINT_STRING - Print null-terminated string
; Input: R8 = pointer to null-terminated string
; ==============================================================================
SERIAL_PRINT_STRING:
    LDA 8
    BZ PRINT_STR_DONE
    SEP 4
    DW SERIAL_WRITE_CHAR
    BR SERIAL_PRINT_STRING
PRINT_STR_DONE:
    SEP 5

; ==============================================================================
; Chuck's serial INPUT routine (Inverted EF3 logic)
; Returns received character in D
; ==============================================================================
SERIAL_READ_CHAR:
B96IN:
    B3 B96IN            ; WAIT FOR STOP BIT (EF3 HIGH = idle)

    LDI 0FFH
    PLO 11
    GLO 14

B96IN1:
    BN3 B96IN1          ; WAIT FOR START BIT (EF3 LOW = start)

    SHR
    SKP

B96IN2:
    GLO 14
B96IN3:
    SMI 01H
    BNZ B96IN3

    B3 B96IN4
    SKP
B96IN4:
    SHR
    GLO 11
    SHRC
    PLO 11
    LBDF B96IN2

    GLO 14
B96IN5:
    SMI 1
    BNZ B96IN5

    GLO 11
    GLO 11
    SEP 5

; ==============================================================================
; Chuck's serial OUTPUT routine - character in D on entry
; ==============================================================================
SERIAL_WRITE_CHAR:
    PLO 11

B96OUT:
    LDI 02H
    PLO 14

    LDI 08H
    PLO 15

    GLO 11
    STR 2
    DEC 2
    GLO 13
    STR 2
    DEC 2

    DEC 14

STBIT:
    SEQ
    NOP
    NOP
    GLO 11
    SHRC
    PLO 11
    PLO 11
    NOP

    BDF STBIT1
    BR QLO

STBIT1:
    BR QHI

QLO1:
    DEC 15
    GLO 15
    BZ DONE96

    GLO 14
LDELAY:
    SMI 01H
    BZ QLO
    NOP
    NOP
    NOP
    NOP
    NOP
    SEX 2
    BR LDELAY

QLO:
    SEQ
    GLO 11
    SHRC
    PLO 11
    LBNF QLO1

QHI1:
    DEC 15
    GLO 15
    BZ DONE96

    GLO 14
HDELAY:
    SMI 01H
    BZ QHI
    NOP
    NOP
    NOP
    NOP
    NOP
    SEX 2
    BR HDELAY

QHI:
    REQ
    GLO 11
    SHRC
    PLO 11
    LBDF QHI1

    DEC 15
    GLO 15
    BZ DONE96

    GLO 14
XDELAY:
    SMI 01H
    BZ QLO
    NOP
    NOP
    NOP
    NOP
    NOP
    SEX 2
    BR XDELAY

DONE96:
    GLO 14
    GLO 14
    GLO 14

DNE961:
    REQ
    NOP
    NOP
    NOP
    NOP
    NOP
    SEX 2
    SMI 01H
    BNZ DNE961

    INC 2
    LDN 2
    PLO 13
    INC 2
    LDN 2
    PLO 11

    LDI 02H
    PLO 14

    SEP 5

; ==============================================================================
; Mark Abene's SCRT implementation
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
; Main program
; ==============================================================================
MAIN:
    ; Set up stack pointer (R2)
    LDI $7F
    PHI 2
    LDI $FF
    PLO 2
    SEX 2

    ; Set Q high (idle)
    REQ

    ; Initialize R14.0 = 2 for 9600 baud
    LDI 02H
    PLO 14

INPUT_LOOP:
    ; Print prompt
    LDI HIGH(MSG_PROMPT)
    PHI 8
    LDI LOW(MSG_PROMPT)
    PLO 8
    SEP 4
    DW SERIAL_PRINT_STRING

    ; Read line into buffer (max 16 chars including null)
    LDI HIGH(INPUT_BUF)
    PHI 8
    LDI LOW(INPUT_BUF)
    PLO 8
    LDI 16              ; Max 16 characters
    PLO 9
    SEP 4
    DW SERIAL_READ_LINE

    ; Print "You entered: "
    LDI HIGH(MSG_ECHO)
    PHI 8
    LDI LOW(MSG_ECHO)
    PLO 8
    SEP 4
    DW SERIAL_PRINT_STRING

    ; Print what was entered
    LDI HIGH(INPUT_BUF)
    PHI 8
    LDI LOW(INPUT_BUF)
    PLO 8
    SEP 4
    DW SERIAL_PRINT_STRING

    ; Print newline
    LDI 0DH
    SEP 4
    DW SERIAL_WRITE_CHAR
    LDI 0AH
    SEP 4
    DW SERIAL_WRITE_CHAR

    BR INPUT_LOOP       ; Loop forever

; ==============================================================================
; Data
; ==============================================================================
MSG_PROMPT:
    DB "> ", 0
MSG_ECHO:
    DB "You entered: ", 0

INPUT_BUF:
    DS 16               ; 16-byte input buffer

    END MAIN
