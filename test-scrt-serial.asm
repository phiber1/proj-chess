; ==============================================================================
; Test SCRT and Serial Output (no auto-calibration)
; ==============================================================================
; Tests:
;   1. SCRT initialization
;   2. Q blinks once (shows we reached main code)
;   3. Sends "OK\r\n" via serial
;   4. Q blinks twice (shows serial succeeded)
; ==============================================================================

    ORG $0000

; Configuration (same as main project)
USE_EF4 EQU 1

; Fixed delay for 9600 baud @ 12 MHz
BIT_DELAY   EQU 207
HALF_DELAY  EQU 104

START:
    DIS                 ; Disable interrupts

    ; Set up stack pointer (R2)
    LDI $7F
    PHI 2
    LDI $FF
    PLO 2              ; R2 = $7FFF (stack top)
    SEX 2              ; Set X register to R2

    ; Initialize SCRT BEFORE any CALL
    LDI HIGH(SCALL)
    PHI 4
    LDI LOW(SCALL)
    PLO 4

    LDI HIGH(SRET)
    PHI 5
    LDI LOW(SRET)
    PLO 5

    ; Initialize serial (Q = high/idle)
    SEQ

    ; Blink Q once to show we're starting
    LDI $FF
    PLO 3
BLINK1:
    DEC 3
    GLO 3
    BNZ BLINK1
    REQ

    LDI $FF
    PLO 3
DELAY1:
    DEC 3
    GLO 3
    BNZ DELAY1
    SEQ

    ; Send "OK\r\n"
    LDI 'O'
    CALL SERIAL_WRITE_CHAR

    LDI 'K'
    CALL SERIAL_WRITE_CHAR

    LDI 13              ; CR
    CALL SERIAL_WRITE_CHAR

    LDI 10              ; LF
    CALL SERIAL_WRITE_CHAR

    ; Blink Q twice to show success
    REQ
    LDI $FF
    PLO 3
BLINK2:
    DEC 3
    GLO 3
    BNZ BLINK2
    SEQ

    LDI $FF
    PLO 3
DELAY2:
    DEC 3
    GLO 3
    BNZ DELAY2
    REQ

    LDI $FF
    PLO 3
BLINK3:
    DEC 3
    GLO 3
    BNZ BLINK3
    SEQ

HALT:
    IDL
    BR HALT

; ==============================================================================
; SCRT Support
; ==============================================================================
SCALL:
    LDA 3               ; Read target address high byte
    PHI 6
    LDA 3               ; Read target address low byte
    PLO 6

    GHI 3               ; Save return address to stack
    STXD
    GLO 3
    STXD

    GHI 6               ; Set PC to target
    PHI 3
    GLO 6
    PLO 3

    SEP 3               ; Jump

SRET:
    IRX                 ; Restore return address
    LDXA                ; Load low byte, R2++
    PLO 3
    LDXA                ; Load high byte, R2++ (FIX: was LDX)
    PHI 3
    SEP 3               ; Return

; ==============================================================================
; Serial I/O (simplified, no auto-calibration)
; ==============================================================================
SERIAL_WRITE_CHAR:
    PLO 13              ; Save character

    ; Start bit (low)
    REQ
    CALL DELAY_BIT

    ; Send 8 data bits
    LDI 8
    PLO 12

WRITE_BIT_LOOP:
    GLO 13
    ANI $01
    BZ SEND_LOW

    SEQ                 ; Send high bit
    BR SEND_DONE

SEND_LOW:
    REQ                 ; Send low bit

SEND_DONE:
    CALL DELAY_BIT

    GLO 13               ; Shift right for next bit
    SHR
    PLO 13

    DEC 12
    GLO 12
    BNZ WRITE_BIT_LOOP

    ; Stop bit (high)
    SEQ
    CALL DELAY_BIT

    RETN

; ==============================================================================
; Delay Routines
; ==============================================================================
DELAY_BIT:
    LDI BIT_DELAY
    PLO 14

DELAY_BIT_LOOP:
    DEC 14
    GLO 14
    BNZ DELAY_BIT_LOOP

    RETN

    END START
