; ==============================================================================
; SERIAL I/O MODULE - RCA 1802/1806
; Supports two modes via compile-time BIOS define:
;   - BIOS mode: Uses BIOS entry points (F_TYPE, F_READ, F_MSG)
;   - Standalone mode: Chuck Yakym's 9600 baud bit-bang routines
;
; For use with Mark Abene's SCRT implementation (R4=CALL, R5=RET, R2=stack)
; ==============================================================================
;
; ROUTINES:
;   SERIAL_READ_CHAR    - Read character, returns in D
;   SERIAL_WRITE_CHAR   - Write character from D
;   SERIAL_PRINT_STRING - Print null-terminated string, R15 = pointer
;   SERIAL_PRINT_HEX    - Print byte as 2 hex digits, D = byte
;   SERIAL_READ_LINE    - Read line with echo, R8 = buffer, R9.0 = max length
;
; REGISTER USAGE:
;   R7  - Buffer pointer (READ_LINE internal - copies from R8 to preserve R8)
;   R8  - Buffer pointer input (READ_LINE), preserved for caller
;   R9  - R9.0 = max length, R9.1 = count (READ_LINE only)
;         NOTE: R9 is NOT used by PRINT_HEX - it's the move list pointer!
;   R10 - Temp storage (READ_LINE)
;   R11 - Serial shift register (standalone mode only)
;   R13 - Saved/restored by output routine
;   R14 - BIOS: R14.1 = baud constant (DO NOT TOUCH), R14.0 clobbered by F_TYPE
;         PRINT_HEX uses R14.0 for temp (already clobbered by F_TYPE anyway)
;         Standalone: R14.0 = baud rate delay counter
;   R15 - BIOS: Used by F_MSG for string pointer
;         Standalone: Bit counter (output routine)
;
; IMPORTANT: R9 is reserved for NEGAMAX move list pointer - never clobber!
;
; REQUIRES:
;   - SCRT initialized (R4 = CALL, R5 = RET)
;   - Stack pointer set (R2)
;   - Standalone mode: Q set to idle state (REQ) before first use
;
; ==============================================================================

#ifdef BIOS
; ==============================================================================
; BIOS I/O Entry Points
; ==============================================================================
F_TYPE  EQU $FF03       ; Output character in D
F_READ  EQU $FF06       ; Read character into D (with echo)
F_MSG      EQU $FF09       ; Output string pointed to by R15
F_UINTOUT  EQU $FF60       ; Convert R13 (16-bit unsigned) to ASCII at R15, R15 left at end
#endif

; ==============================================================================
; SERIAL_READ_LINE - Read line with echo into buffer
; Input: R8 = pointer to buffer, R9.0 = max length (including null)
; Output: Buffer filled with null-terminated string
; Handles: Echo, Backspace (08H or 7FH), Enter (0DH)
; ==============================================================================
SERIAL_READ_LINE:
    ; Copy R8 to R7 (preserve R8 for caller)
    GHI 8
    PHI 7
    GLO 8
    PLO 7

    GLO 9               ; Get max length
    SMI 1               ; Reserve space for null terminator
    PLO 9               ; R9.0 = max chars we can store
    LDI 0
    PHI 9               ; R9.1 = current count

SRL_READ_NEXT:
    SEP 4
    DW SERIAL_READ_CHAR ; Read character into D

    ; Check for Enter (CR = 0DH)
    SMI 0DH
    BZ SRL_DONE

    ; Check for LF (0AH) - also treat as Enter (for GUI compatibility)
    ADI 0DH             ; Restore D
    SMI 0AH
    BZ SRL_DONE

    ; Check for Backspace (08H)
    ADI 0AH             ; Restore D
    SMI 08H
    BZ SRL_BACKSPACE

    ; Check for DEL (7FH) - also treat as backspace
    ADI 08H             ; Restore D
    SMI 7FH
    BZ SRL_BACKSPACE

    ; Regular character - check if buffer full
    ADI 7FH             ; Restore D
    PLO 10              ; Save char in R10.0 temporarily

    GHI 9               ; Get current count
    STR 2               ; Store on stack
    GLO 9               ; Get max
    SM                  ; max - count
    BZ SRL_READ_NEXT    ; Buffer full, ignore character

    ; Store character and echo it
    GLO 10              ; Get character back
    STR 7               ; Store in buffer
    INC 7               ; Advance buffer pointer
    GHI 9               ; Increment count
    ADI 1
    PHI 9

    GLO 10              ; Echo the character
    SEP 4
    DW SERIAL_WRITE_CHAR

    BR SRL_READ_NEXT

SRL_BACKSPACE:
    ; Check if anything to delete
    GHI 9               ; Get current count
    BZ SRL_READ_NEXT    ; Nothing to delete

    ; Decrement count and pointer
    SMI 1
    PHI 9
    DEC 7

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
    STR 7

    ; Echo CR+LF
    LDI 0DH
    SEP 4
    DW SERIAL_WRITE_CHAR
    LDI 0AH
    SEP 4
    DW SERIAL_WRITE_CHAR

    SEP 5               ; Return

; ==============================================================================
; SERIAL_PRINT_HEX - Print byte as two hex digits
; Input: D = byte to print
; Uses: Stack (1 byte)
; NOTE: Cannot use R14.0 - F_TYPE clobbers it during first nibble print!
; ==============================================================================
SERIAL_PRINT_HEX:
    STXD                ; Save byte on stack

    ; Print high nibble
    SHR
    SHR
    SHR
    SHR
    SEP 4
    DW SERIAL_PRINT_NIBBLE

    ; Print low nibble
    IRX
    LDX                 ; Pop original byte from stack
    ANI 0FH             ; Mask low nibble
    SEP 4
    DW SERIAL_PRINT_NIBBLE

    SEP 5               ; Return

; ==============================================================================
; SERIAL_PRINT_NIBBLE - Print single hex digit (0-F)
; Input: D = value 0-15
; ==============================================================================
SERIAL_PRINT_NIBBLE:
    SMI 10              ; Is it >= 10?
    BDF SPN_AF          ; Yes, it's A-F
    ADI 10+'0'          ; Restore and add '0'
    SEP 4
    DW SERIAL_WRITE_CHAR
    SEP 5

SPN_AF:
    ADI 'A'             ; Add 'A' (already subtracted 10)
    SEP 4
    DW SERIAL_WRITE_CHAR
    SEP 5

#ifdef BIOS
; ==============================================================================
; BIOS MODE - Thin wrappers around BIOS entry points
; ==============================================================================

; ==============================================================================
; SERIAL_PRINT_STRING - Print null-terminated string
; Input: R15 = pointer to null-terminated string (F_MSG uses R15 directly)
; NOTE: Caller must load R15 directly - R8 is NOT used!
; ==============================================================================
SERIAL_PRINT_STRING:
    SEP 4
    DW F_MSG            ; Call BIOS string output (uses R15)
    SEP 5               ; Return

; ==============================================================================
; SERIAL_READ_CHAR - Read character from console
; Returns: D = character (with echo, handled by BIOS)
; ==============================================================================
SERIAL_READ_CHAR:
    SEP 4
    DW F_READ           ; Call BIOS read (includes echo)
    SEP 5               ; Return

; ==============================================================================
; SERIAL_WRITE_CHAR - Write character to console
; Input: D = character to send
; Note: R14.0 is clobbered, R14.1 (baud constant) preserved by BIOS
; ==============================================================================
SERIAL_WRITE_CHAR:
    SEP 4
    DW F_TYPE           ; Call BIOS character output
    SEP 5               ; Return

#else
; ==============================================================================
; STANDALONE MODE - Chuck Yakym's 9600 baud bit-bang routines
; For 1.75 MHz clock, inverted EF3/Q logic
; ==============================================================================

; ==============================================================================
; SERIAL_PRINT_STRING - Print null-terminated string
; Input: R8 = pointer to null-terminated string
; ==============================================================================
SERIAL_PRINT_STRING:
    LDA 8               ; Load byte, increment pointer
    BZ SPS_DONE         ; Null terminator - done
    SEP 4
    DW SERIAL_WRITE_CHAR
    BR SERIAL_PRINT_STRING
SPS_DONE:
    SEP 5               ; Return

; ==============================================================================
; SERIAL_READ_CHAR - Chuck's B96IN (Inverted EF3 logic)
; Returns received character in D
; R11.0 = shift register, R14.0 = delay counter
; ==============================================================================
SERIAL_READ_CHAR:
B96IN:
    B3 B96IN            ; WAIT FOR STOP BIT (EF3 HIGH = idle)

    LDI 0FFH            ; Initialize input to FFh
    PLO 11
    GLO 14              ; Get delay count

B96IN1:
    BN3 B96IN1          ; WAIT FOR START BIT (EF3 LOW)

    SHR                 ; Half bit delay
    SKP

B96IN2:
    GLO 14              ; Get delay count
B96IN3:
    SMI 01H
    BNZ B96IN3          ; Delay loop

    B3 B96IN4           ; Sample bit
    SKP                 ; EF3 HIGH = 0, leave DF=0
B96IN4:
    SHR                 ; EF3 LOW = 1, set DF=1
    GLO 11
    SHRC                ; Shift bit into byte
    PLO 11
    LBDF B96IN2         ; Loop until start bit shifts out

    GLO 14              ; Final delay
B96IN5:
    SMI 1
    BNZ B96IN5

    GLO 11              ; Return character in D
    GLO 11
    SEP 5               ; Return

; ==============================================================================
; SERIAL_WRITE_CHAR - Chuck's B96OUT (Inverted Q logic)
; Input: D = character to send
; R11.0 = shift register, R14.0 = delay, R15.0 = bit counter
; ==============================================================================
SERIAL_WRITE_CHAR:
    PLO 11              ; Save character

B96OUT:
    LDI 02H
    PLO 14              ; R14.0 = 2 for 9600 baud

    LDI 08H
    PLO 15              ; 8 bits

    GLO 11
    STR 2
    DEC 2
    GLO 13
    STR 2
    DEC 2

    DEC 14              ; R14.0 = 1 for delay loops

STBIT:
    SEQ                 ; START BIT
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
    SEQ                 ; Output 0
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
    REQ                 ; Output 1
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
    REQ                 ; STOP BIT
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
    PLO 14              ; Restore for next call

    SEP 5               ; Return

#endif

; ==============================================================================
; END OF SERIAL I/O MODULE
; ==============================================================================
