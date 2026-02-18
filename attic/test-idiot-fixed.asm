; ==============================================================================
; IDIOT TYPE routine with FIXED baud rate (no calibration)
; Uses the exact IDIOT bit output logic
; EFHI=0, QHI=0 (active low)
; ==============================================================================

    ORG $0000

; Register assignments
DELAY   EQU 12      ; RC = delay subroutine PC
BAUD    EQU 14      ; RE.1 = baud constant
ASCII   EQU 15      ; RF.1 = character, RF.0 = bit count

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

    ; Set up R2 as stack pointer and X=R2 for SD instruction
    LDI $01
    PHI 2
    LDI $FF
    PLO 2
    SEX 2                   ; X = R2

    ; Set up RC to point to DELAY routine
    LDI HIGH(DELAY1)
    PHI DELAY
    LDI LOW(DELAY1)
    PLO DELAY

    ; Set fixed baud rate constant
    ; BAUD=3='x', BAUD=5='`', BAUD=6='@', try BAUD=7
    LDI 7                   ; Try baud constant = 7
    PHI BAUD
    LDI 0
    PLO BAUD                ; Clear delay flag

    ; Wait for keypress to start
WAIT_IDLE:
    BN3 WAIT_IDLE
WAIT_START:
    B3 WAIT_START
WAIT_DONE:
    BN3 WAIT_DONE

OUTPUT_LOOP:
    ; Load 'H' into ASCII.1
    LDI 'H'
    PHI ASCII

    ; === TYPE routine from IDIOT ===

    ; Set up for 11 bits: 1 start + 8 data + 2 stop
    LDI $0B
    PLO ASCII

    ; Get character into RD.0
    GHI ASCII
    PLO 13

    ; If delay flag > 0, wait 2 bit times first
    GLO BAUD
    LSZ
    SEP DELAY
    DB 23

    ; Start bit (QHI=0: REQ = Q low = space)
    REQ

NEXTBIT:
    SEP DELAY               ; Wait 1 bit time
    DB 7
    NOP                     ; 6 NOPs for equalization
    NOP
    NOP
    NOP
    NOP
    NOP

    DEC ASCII               ; Decrement bit count
    LDI 0                   ; D = 0
    SD                      ; D = M(X) - 0 - notDF, sets DF=1
    GLO 13                  ; Get character byte
    SHRC                    ; Shift right through carry, LSB -> DF
    PLO 13                  ; Save shifted char

    ; Output bit based on DF
    ; INVERTED for our hardware: 0=SEQ, 1=REQ
    LSDF                    ; Skip next instruction if DF=1
    SEQ                     ; DF=0 (bit=0): Q high (inverted)
    LSKP                    ; Skip REQ+NOP
    REQ                     ; DF=1 (bit=1): Q low (inverted)
    NOP

    GLO ASCII
    ANI $0F
    BNZ NEXTBIT

    ; Character done, pause and repeat
    LDI $60
    PLO 5
PAUSE:
    DEC 5
    GLO 5
    BNZ PAUSE

    BR OUTPUT_LOOP

; ==============================================================================
; DELAY subroutine - exact copy from IDIOT
; ==============================================================================

    ORG $00E0

    SEP 3                   ; Return point
DELAY1:
    GHI BAUD                ; Get baud constant
    SHR                     ; Remove echo flag bit
    PLO BAUD
DELAY_LOOP:
    DEC BAUD
    LDA 3                   ; Get inline #bits parameter
    SMI 1
    BNZ $-2                 ; Loop #bits times
    GLO BAUD
    BZ $-11                 ; If baud counter=0, return
    DEC 3                   ; Back up to re-read #bits
    BR DELAY_LOOP

    END START
