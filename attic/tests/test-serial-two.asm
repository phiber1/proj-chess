; ==============================================================================
; Serial Two Character Test - Output "Hi" at 9600 baud
; For 1.75 MHz Membership Card
; ==============================================================================

    ORG $0000

START:
    DIS                     ; Disable interrupts
    SEQ                     ; Q idle high

; ==============================================================================
; AUTO-BAUD CALIBRATION
; Wait for user to press space bar
; ==============================================================================

; EF3 polarity on Membership Card: idle=EF3=1, start/low bits=EF3=0
WAIT_IDLE:
    B3 WAIT_IDLE            ; Loop while EF3=1 (idle)
WAIT_LOW_BITS:
    BN3 WAIT_LOW_BITS       ; Loop while EF3=0 (start + bits 0-4 for space)

; Now EF3=1 (bit 5 of space char) - measure this single bit period
    LDI $00

MEASURE_LOOP:
    ADI $01
    B3 MEASURE_LOOP         ; Loop while EF3=1 (measuring bit 5)

    PLO 15                  ; Save raw calibration count
    SMI 3
    PLO 15                  ; Save adjusted count

WAIT_HIGH_BITS:
    BN3 WAIT_HIGH_BITS      ; Loop while EF3=0 (bits 6-7)

; ==============================================================================
; Output "Hi" followed by CR/LF repeatedly
; ==============================================================================

MAIN_LOOP:
    ; Send 'U' (0x55) first as timing check
    LDI $55
    PLO 13
    LDI 8
    PLO 12

    GLO 13
    SHR
    PLO 13

    REQ
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP

SEND_BIT1:
    BDF BIT_ONE1
    REQ
    BR BIT_DELAY1
BIT_ONE1:
    SEQ
    BR BIT_DELAY1
BIT_DELAY1:
    NOP
    NOP
    GLO 13
    SHR
    PLO 13
    DEC 12
    GLO 12
    BNZ SEND_BIT1

    SEQ
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP

    ; Inter-character pause - much longer
    LDI $FF
    PLO 7
PAUSE1:
    DEC 7
    GLO 7
    BNZ PAUSE1

    ; Send 'i' (0x69)
    LDI $69
    PLO 13
    LDI 8
    PLO 12

    GLO 13
    SHR
    PLO 13

    REQ
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP

SEND_BIT2:
    BDF BIT_ONE2
    REQ
    BR BIT_DELAY2
BIT_ONE2:
    SEQ
    BR BIT_DELAY2
BIT_DELAY2:
    NOP
    NOP
    GLO 13
    SHR
    PLO 13
    DEC 12
    GLO 12
    BNZ SEND_BIT2

    SEQ
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP

    ; Inter-character pause - much longer
    LDI $FF
    PLO 7
PAUSE2:
    DEC 7
    GLO 7
    BNZ PAUSE2

    ; Send CR (0x0D)
    LDI $0D
    PLO 13
    LDI 8
    PLO 12

    GLO 13
    SHR
    PLO 13

    REQ
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP

SEND_BIT3:
    BDF BIT_ONE3
    REQ
    BR BIT_DELAY3
BIT_ONE3:
    SEQ
    BR BIT_DELAY3
BIT_DELAY3:
    NOP
    NOP
    GLO 13
    SHR
    PLO 13
    DEC 12
    GLO 12
    BNZ SEND_BIT3

    SEQ
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP

    ; Inter-character pause - much longer
    LDI $FF
    PLO 7
PAUSE3:
    DEC 7
    GLO 7
    BNZ PAUSE3

    ; Send LF (0x0A)
    LDI $0A
    PLO 13
    LDI 8
    PLO 12

    GLO 13
    SHR
    PLO 13

    REQ
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP

SEND_BIT4:
    BDF BIT_ONE4
    REQ
    BR BIT_DELAY4
BIT_ONE4:
    SEQ
    BR BIT_DELAY4
BIT_DELAY4:
    NOP
    NOP
    GLO 13
    SHR
    PLO 13
    DEC 12
    GLO 12
    BNZ SEND_BIT4

    SEQ
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP

    ; Longer pause between messages
    LDI $80
    PLO 7
PAUSE4:
    DEC 7
    GLO 7
    BNZ PAUSE4

    BR MAIN_LOOP

    END START
