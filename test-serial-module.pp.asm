; ==============================================================================
; Comprehensive Serial I/O Module Test
; Tests all routines in serial-io.asm
; ==============================================================================
    ORG $0000
    LBR MAIN
; ==============================================================================
; SERIAL I/O MODULE - RCA 1802 Membership Card
; Chuck Yakym's 9600 baud routines + helper functions
; For use with Mark Abene's SCRT implementation
; 1.75 MHz clock, 9600 baud, inverted EF3 logic
; ==============================================================================
;
; ROUTINES:
; SERIAL_READ_CHAR - Read character, returns in D
; SERIAL_WRITE_CHAR - Write character from D
; SERIAL_PRINT_STRING - Print null-terminated string, R8 = pointer
; SERIAL_PRINT_HEX - Print byte as 2 hex digits, D = byte
; SERIAL_READ_LINE - Read line with echo, R8 = buffer, R9.0 = max length
;
; REGISTER USAGE:
; R8 - String/buffer pointer (PRINT_STRING, READ_LINE)
; R9 - R9.0 = max length, R9.1 = count (READ_LINE); R9.0 = temp (PRINT_HEX)
; R10 - Temp storage (READ_LINE)
; R11 - Serial shift register
; R13 - Saved/restored by output routine
; R14 - Baud rate delay counter (must be 2, hardcoded)
; R15 - Bit counter (output routine)
;
; REQUIRES:
; - SCRT initialized (R4 = CALL, R5 = RET)
; - Stack pointer set (R2)
; - Q set to idle state (REQ) before first use
;
; ==============================================================================
; ==============================================================================
; SERIAL_READ_LINE - Read line with echo into buffer
; Input: R8 = pointer to buffer, R9.0 = max length (including null)
; Output: Buffer filled with null-terminated string
; Handles: Echo, Backspace (08H or 7FH), Enter (0DH)
; ==============================================================================
SERIAL_READ_LINE:
    GLO 9 ; Get max length
    SMI 1 ; Reserve space for null terminator
    PLO 9 ; R9.0 = max chars we can store
    LDI 0
    PHI 9 ; R9.1 = current count
SRL_READ_NEXT:
    SEP 4
    DW SERIAL_READ_CHAR ; Read character into D
    ; Check for Enter (CR = 0DH)
    SMI 0DH
    BZ SRL_DONE
    ; Check for Backspace (08H)
    ADI 0DH ; Restore D
    SMI 08H
    BZ SRL_BACKSPACE
    ; Check for DEL (7FH) - also treat as backspace
    ADI 08H ; Restore D
    SMI 7FH
    BZ SRL_BACKSPACE
    ; Regular character - check if buffer full
    ADI 7FH ; Restore D
    PLO 10 ; Save char in R10.0 temporarily
    GHI 9 ; Get current count
    STR 2 ; Store on stack
    GLO 9 ; Get max
    SM ; max - count
    BZ SRL_READ_NEXT ; Buffer full, ignore character
    ; Store character and echo it
    GLO 10 ; Get character back
    STR 8 ; Store in buffer
    INC 8 ; Advance buffer pointer
    GHI 9 ; Increment count
    ADI 1
    PHI 9
    GLO 10 ; Echo the character
    SEP 4
    DW SERIAL_WRITE_CHAR
    BR SRL_READ_NEXT
SRL_BACKSPACE:
    ; Check if anything to delete
    GHI 9 ; Get current count
    BZ SRL_READ_NEXT ; Nothing to delete
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
    BR SRL_READ_NEXT
SRL_DONE:
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
    SEP 5 ; Return
; ==============================================================================
; SERIAL_PRINT_HEX - Print byte as two hex digits
; Input: D = byte to print
; Uses: R9.0 (saved byte)
; ==============================================================================
SERIAL_PRINT_HEX:
    PLO 9 ; Save byte in R9.0
    ; Print high nibble
    SHR
    SHR
    SHR
    SHR
    SEP 4
    DW SERIAL_PRINT_NIBBLE
    ; Print low nibble
    GLO 9 ; Get original byte
    ANI 0FH ; Mask low nibble
    SEP 4
    DW SERIAL_PRINT_NIBBLE
    SEP 5 ; Return
; ==============================================================================
; SERIAL_PRINT_NIBBLE - Print single hex digit (0-F)
; Input: D = value 0-15
; ==============================================================================
SERIAL_PRINT_NIBBLE:
    SMI 10 ; Is it >= 10?
    BDF SPN_AF ; Yes, it's A-F
    ADI 10+'0' ; Restore and add '0'
    SEP 4
    DW SERIAL_WRITE_CHAR
    SEP 5
SPN_AF:
    ADI 'A' ; Add 'A' (already subtracted 10)
    SEP 4
    DW SERIAL_WRITE_CHAR
    SEP 5
; ==============================================================================
; SERIAL_PRINT_STRING - Print null-terminated string
; Input: R8 = pointer to null-terminated string
; ==============================================================================
SERIAL_PRINT_STRING:
    LDA 8 ; Load byte, increment pointer
    BZ SPS_DONE ; Null terminator - done
    SEP 4
    DW SERIAL_WRITE_CHAR
    BR SERIAL_PRINT_STRING
SPS_DONE:
    SEP 5 ; Return
; ==============================================================================
; SERIAL_READ_CHAR - Chuck's B96IN (Inverted EF3 logic)
; Returns received character in D
; R11.0 = shift register, R14.0 = delay counter
; ==============================================================================
SERIAL_READ_CHAR:
B96IN:
    B3 B96IN ; WAIT FOR STOP BIT (EF3 HIGH = idle)
    LDI 0FFH ; Initialize input to FFh
    PLO 11
    GLO 14 ; Get delay count
B96IN1:
    BN3 B96IN1 ; WAIT FOR START BIT (EF3 LOW)
    SHR ; Half bit delay
    SKP
B96IN2:
    GLO 14 ; Get delay count
B96IN3:
    SMI 01H
    BNZ B96IN3 ; Delay loop
    B3 B96IN4 ; Sample bit
    SKP ; EF3 HIGH = 0, leave DF=0
B96IN4:
    SHR ; EF3 LOW = 1, set DF=1
    GLO 11
    SHRC ; Shift bit into byte
    PLO 11
    LBDF B96IN2 ; Loop until start bit shifts out
    GLO 14 ; Final delay
B96IN5:
    SMI 1
    BNZ B96IN5
    GLO 11 ; Return character in D
    GLO 11
    SEP 5 ; Return
; ==============================================================================
; SERIAL_WRITE_CHAR - Chuck's B96OUT (Inverted Q logic)
; Input: D = character to send
; R11.0 = shift register, R14.0 = delay, R15.0 = bit counter
; ==============================================================================
SERIAL_WRITE_CHAR:
    PLO 11 ; Save character
B96OUT:
    LDI 02H
    PLO 14 ; R14.0 = 2 for 9600 baud
    LDI 08H
    PLO 15 ; 8 bits
    GLO 11
    STR 2
    DEC 2
    GLO 13
    STR 2
    DEC 2
    DEC 14 ; R14.0 = 1 for delay loops
STBIT:
    SEQ ; START BIT
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
    SEQ ; Output 0
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
    REQ ; Output 1
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
    REQ ; STOP BIT
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
    PLO 14 ; Restore for next call
    SEP 5 ; Return
; ==============================================================================
; END OF SERIAL I/O MODULE
; ==============================================================================
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
    ; Set R6 to continue after INITCALL
    LDI HIGH(START)
    PHI 6
    LDI LOW(START)
    PLO 6
    LBR INITCALL
START:
    ; Stack setup
    LDI $7F
    PHI 2
    LDI $FF
    PLO 2
    SEX 2
    REQ ; Q idle
    LDI 02H
    PLO 14 ; Baud rate
    ; ==========================================
    ; TEST 1: SERIAL_PRINT_STRING
    ; ==========================================
    LDI HIGH(MSG_BANNER)
    PHI 8
    LDI LOW(MSG_BANNER)
    PLO 8
    SEP 4
    DW SERIAL_PRINT_STRING
    ; ==========================================
    ; TEST 2: SERIAL_PRINT_HEX
    ; ==========================================
    LDI HIGH(MSG_HEX)
    PHI 8
    LDI LOW(MSG_HEX)
    PLO 8
    SEP 4
    DW SERIAL_PRINT_STRING
    ; Test values: 00, 5A, A5, FF
    LDI 00H
    SEP 4
    DW SERIAL_PRINT_HEX
    LDI ' '
    SEP 4
    DW SERIAL_WRITE_CHAR
    LDI 5AH
    SEP 4
    DW SERIAL_PRINT_HEX
    LDI ' '
    SEP 4
    DW SERIAL_WRITE_CHAR
    LDI 0A5H
    SEP 4
    DW SERIAL_PRINT_HEX
    LDI ' '
    SEP 4
    DW SERIAL_WRITE_CHAR
    LDI 0FFH
    SEP 4
    DW SERIAL_PRINT_HEX
    ; Newline
    LDI 0DH
    SEP 4
    DW SERIAL_WRITE_CHAR
    LDI 0AH
    SEP 4
    DW SERIAL_WRITE_CHAR
    ; ==========================================
    ; TEST 3: SERIAL_READ_CHAR + SERIAL_WRITE_CHAR (echo)
    ; ==========================================
    LDI HIGH(MSG_ECHO)
    PHI 8
    LDI LOW(MSG_ECHO)
    PLO 8
    SEP 4
    DW SERIAL_PRINT_STRING
    ; Echo 5 characters
    LDI 5
    PLO 10 ; Counter in R10.0
ECHO_LOOP:
    SEP 4
    DW SERIAL_READ_CHAR
    SEP 4
    DW SERIAL_WRITE_CHAR
    DEC 10
    GLO 10
    BNZ ECHO_LOOP
    ; Newline
    LDI 0DH
    SEP 4
    DW SERIAL_WRITE_CHAR
    LDI 0AH
    SEP 4
    DW SERIAL_WRITE_CHAR
    ; ==========================================
    ; TEST 4: SERIAL_READ_LINE (loop)
    ; ==========================================
LINE_TEST:
    LDI HIGH(MSG_LINE)
    PHI 8
    LDI LOW(MSG_LINE)
    PLO 8
    SEP 4
    DW SERIAL_PRINT_STRING
    ; Read line into buffer
    LDI HIGH(INPUT_BUF)
    PHI 8
    LDI LOW(INPUT_BUF)
    PLO 8
    LDI 16
    PLO 9
    SEP 4
    DW SERIAL_READ_LINE
    ; Print "You typed: "
    LDI HIGH(MSG_TYPED)
    PHI 8
    LDI LOW(MSG_TYPED)
    PLO 8
    SEP 4
    DW SERIAL_PRINT_STRING
    ; Print the input
    LDI HIGH(INPUT_BUF)
    PHI 8
    LDI LOW(INPUT_BUF)
    PLO 8
    SEP 4
    DW SERIAL_PRINT_STRING
    ; Newline
    LDI 0DH
    SEP 4
    DW SERIAL_WRITE_CHAR
    LDI 0AH
    SEP 4
    DW SERIAL_WRITE_CHAR
    ; Loop back for more line input
    BR LINE_TEST
; ==============================================================================
; String data
; ==============================================================================
MSG_BANNER:
    DB "=== Serial I/O Module Test ===", 0DH, 0AH, 0
MSG_HEX:
    DB "Hex test: ", 0
MSG_ECHO:
    DB "Type 5 chars: ", 0
MSG_LINE:
    DB "> ", 0
MSG_TYPED:
    DB "You typed: ", 0
INPUT_BUF:
    DS 16
    END MAIN
