; ==============================================================================
; Test Serial I/O Integration
; ==============================================================================
; Minimal test to verify serial-io-9600.asm works correctly
; Outputs "Hello, world!" and then echoes received characters
;
; For Membership Card at 1.75 MHz, 9600 baud
;
; IMPORTANT: Serial routines must be at start of code to keep short branches
; in range. The timing is cycle-critical - do not change to long branches!
; ==============================================================================

    ORG $0000

; ------------------------------------------------------------------------------
; Entry point - jump to START (CPU begins execution here)
; ------------------------------------------------------------------------------
    LBR START

; ==============================================================================
; Serial I/O - Chuck's proven 9600 baud routine (MUST BE EARLY)
; ==============================================================================

; ------------------------------------------------------------------------------
; SERIAL_INIT - Initialize serial I/O
; ------------------------------------------------------------------------------
SERIAL_INIT:
    SEQ                 ; Set Q high (idle/mark state)
    LDI 02H
    PLO 14              ; R14.0 = 2 for 9600 baud
    SEP 5               ; RETN

; ------------------------------------------------------------------------------
; SERIAL_WRITE_CHAR - Output one character at 9600 baud
; ------------------------------------------------------------------------------
SERIAL_WRITE_CHAR:
    PLO 11              ; R11.0 = character to output

B96OUT:
    LDI 08H
    PLO 15              ; R15.0 = 8 bits to send

    GLO 11
    STR 2
    DEC 2
    GLO 13
    STR 2
    DEC 2

    DEC 14              ; Set delay counter = 1

STBIT:
    SEQ                 ; Q OFF = start bit
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

    SEP 5               ; RETN

; ------------------------------------------------------------------------------
; SERIAL_READ_CHAR - Input one character at 9600 baud
; ------------------------------------------------------------------------------
SERIAL_READ_CHAR:
WAIT_RX_IDLE:
    BN3 WAIT_RX_IDLE

WAIT_RX_START:
    B3 WAIT_RX_START

    LDI 08H
    PLO 15
    LDI 00H
    PLO 11

    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP

    GLO 14
RX_DELAY1:
    SMI 01H
    BZ RX_BIT_LOOP
    NOP
    NOP
    NOP
    NOP
    NOP
    SEX 2
    BR RX_DELAY1

RX_BIT_LOOP:
    B3 RX_BIT_ONE

RX_BIT_ZERO:
    GLO 11
    SHR
    PLO 11
    BR RX_BIT_DELAY

RX_BIT_ONE:
    GLO 11
    SHR
    ORI 80H
    PLO 11

RX_BIT_DELAY:
    GLO 14
RX_DLOOP:
    SMI 01H
    BZ RX_NEXT_BIT
    NOP
    NOP
    NOP
    NOP
    NOP
    SEX 2
    BR RX_DLOOP

RX_NEXT_BIT:
    DEC 15
    GLO 15
    BNZ RX_BIT_LOOP

    GLO 14
RX_STOP:
    SMI 01H
    BZ RX_DONE
    NOP
    NOP
    NOP
    NOP
    NOP
    SEX 2
    BR RX_STOP

RX_DONE:
    GLO 11
    SEP 5               ; RETN

; ==============================================================================
; SCRT - Standard Call/Return Technique
; ==============================================================================
SCALL:
    GHI 6
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
    SEP 3

SRET:
    GHI 6
    PHI 3
    GLO 6
    PLO 3
    IRX
    LDXA
    PLO 6
    LDX
    PHI 6
    SEP 3

; ==============================================================================
; Main entry point
; ==============================================================================
START:
    ; Set up stack pointer (R2)
    LDI $7F
    PHI 2
    LDI $FF
    PLO 2               ; R2 = $7FFF (stack top)
    SEX 2

    ; Set up SCRT
    LDI HIGH(SCALL)
    PHI 4
    LDI LOW(SCALL)
    PLO 4

    LDI HIGH(SRET)
    PHI 5
    LDI LOW(SRET)
    PLO 5

    ; Initialize serial I/O (sets Q high, R14.0 = 2)
    SEP 4
    DB HIGH(SERIAL_INIT), LOW(SERIAL_INIT)

    ; Output startup message
    LDI HIGH(MSG_HELLO)
    PHI 8
    LDI LOW(MSG_HELLO)
    PLO 8

PRINT_LOOP:
    LDA 8
    LBZ ECHO_MODE
    SEP 4
    DB HIGH(SERIAL_WRITE_CHAR), LOW(SERIAL_WRITE_CHAR)
    LBR PRINT_LOOP

ECHO_MODE:
    LDI HIGH(MSG_ECHO)
    PHI 8
    LDI LOW(MSG_ECHO)
    PLO 8

ECHO_PROMPT:
    LDA 8
    BZ ECHO_LOOP
    SEP 4
    DB HIGH(SERIAL_WRITE_CHAR), LOW(SERIAL_WRITE_CHAR)
    BR ECHO_PROMPT

ECHO_LOOP:
    SEP 4
    DB HIGH(SERIAL_READ_CHAR), LOW(SERIAL_READ_CHAR)
    SEP 4
    DB HIGH(SERIAL_WRITE_CHAR), LOW(SERIAL_WRITE_CHAR)
    BR ECHO_LOOP

; ------------------------------------------------------------------------------
; Messages
; ------------------------------------------------------------------------------
MSG_HELLO:
    DB "Hello!", 0DH, 0AH, 0

MSG_ECHO:
    DB ">", 0

    END START
