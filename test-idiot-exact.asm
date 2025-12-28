; ==============================================================================
; Exact IDIOT monitor serial routines
; TIMALC for baud calibration, TYPE for output
; Press CR or LF to calibrate, then outputs 'H' repeatedly
; EFHI=0, QHI=0 (active low EF3 and Q)
; ==============================================================================

    ORG $0000

; Register assignments (matching IDIOT)
DELAY   EQU 12      ; RC = delay subroutine PC
BAUD    EQU 14      ; RE.1 = baud constant, RE.0 = delay flag
ASCII   EQU 15      ; RF.1 = character, RF.0 = temp

START:
    DIS
    DB 0

    ; Set up R3 as main PC
    LDI HIGH(MAIN)
    PHI 3
    LDI LOW(MAIN)
    PLO 3
    SEP 3

MAIN:
    SEQ                     ; Q idle high (mark)

    ; Set up RC to point to DELAY1
    LDI HIGH(DELAY1)
    PHI DELAY
    LDI LOW(DELAY1)
    PLO DELAY

    ; Call TIMALC to calibrate baud rate
    ; User must press CR (0x0D) for full duplex or LF (0x0A) for half duplex

TIMALC:
    LDI 0
    PLO BAUD
    PLO ASCII

    ; EFHI=0: wait for start bit (EF3 goes low)
    BN3 $                   ; Wait while EF3=1 (idle)
    B3 $                    ; Wait while EF3=0 (start bit) until data

    LDI 3                   ; Wait 14 machine cycles
TC:
    SMI 1
    BNZ TC

    GLO ASCII
    ; EFHI=0: measure zero bit
    BNZ ZTO1
    BN3 INCR                ; If EF3=1, increment
    INC ASCII
ZTO1:
    BN3 DAUX                ; If EF3=1, done measuring

INCR:
    INC BAUD
    LDI 7
    BR TC

DAUX:
    DEC BAUD                ; BAUD = #loops in 2 bit times
    DEC BAUD
    GLO BAUD
    ORI 1                   ; Set echo flag (LSB=1 means no echo)
    PHI BAUD

    SEP DELAY               ; Wait 1.5 bit times
    DB $0C

    ; EFHI=0: check if LF or CR
    B3 WAIT                 ; If EF3=0, is LF (no echo)

    GHI BAUD                ; Is CR, clear echo flag
    ANI $FE
    PHI BAUD

WAIT:
    SEP DELAY               ; Wait for end of character
    DB $26

    ; Baud rate calibrated, now output characters

OUTPUT_LOOP:
    ; Load 'H' into ASCII.1
    LDI 'H'
    PHI ASCII

    ; Call TYPE
    LDI HIGH(TYPE)
    PHI 3
    LDI LOW(TYPE)
    PLO 3
    SEP 3

    ; Small delay between characters
    LDI $40
    PLO 5
PAUSE:
    DEC 5
    GLO 5
    BNZ PAUSE

    BR OUTPUT_LOOP

; ==============================================================================
; DELAY subroutine from IDIOT
; Delay = 4 + 4(BAUD)(#BITS + 3)
; Called via SEP RC, returns via SEP R3
; ==============================================================================

    ORG $00E0

    SEP 3                   ; Return to caller
DELAY1:
    GHI BAUD                ; Get baud constant
    SHR                     ; Remove echo flag
    PLO BAUD                ; Repeat...
DELAY2:
    DEC BAUD                ; - Decrement baud
    LDA 3                   ; - Get #bits
    SMI 1                   ;   Decrement until zero
    BNZ $-2
    GLO BAUD                ; ...until baud=0
    BZ $-11                 ; Return
    DEC 3
    BR DELAY2

; ==============================================================================
; TYPE routine from IDIOT (simplified - just TYPE, not TYPE5/TYPE2)
; Types character in ASCII.1 (RF.1)
; ==============================================================================

    ORG $0100

TYPE:
    ; Set up for 11 bits: 1 start + 8 data + 2 stop
    LDI $0B                 ; Code byte for normal character
    PLO ASCII

    GLO ASCII               ; Get character to send
    GHI ASCII
    PLO 13                  ; RD.0 = character

BEGIN:
    GLO BAUD                ; If delay flag > 0
    LSZ                     ; wait 2 bit times
    SEP DELAY
    DB 23

    ; QHI=0: Start bit = REQ
    REQ

NEXTBIT:
    SEP DELAY               ; Wait 1 bit time
    DB 7
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP

    DEC ASCII               ; Decrement bit count
    LDI 0
    SD                      ; Set DF=1

    GLO 13                  ; Get next bit of character
    SHRC
    PLO 13

    LSDF                    ; If bit=0
    ; QHI=0: bit=0 -> REQ (space)
    REQ
    LSKP
    ; QHI=0: bit=1 -> SEQ (mark)
    SEQ
    NOP

    GLO ASCII               ; Check bit count
    ANI $0F
    BNZ NEXTBIT

    ; Done - return to caller
    LDI HIGH(OUTPUT_LOOP)
    PHI 3
    LDI LOW(OUTPUT_LOOP)
    PLO 3
    SEP 3

STRING:
    DB "H", 0

    END START
