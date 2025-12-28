; ==============================================================================
; RCA 1802/1806 Chess Engine - Serial I/O (9600 Baud Bit-Bang)
; ==============================================================================
; Proven working serial I/O based on Chuck's timing-critical routine
; For Membership Card at 1.75 MHz, 9600 baud
;
; Q output: SEQ = space/0, REQ = mark/1
; EF3 input: Idle high, start bit low (inverted)
;
; Register usage for serial output:
;   R11.0 = character being transmitted (shift register)
;   R14.0 = delay counter (must be 2 on entry, decremented to 1)
;   R15.0 = bit counter (8 bits)
;   R2 = stack pointer (for saving R11, R13)
; ==============================================================================

; ------------------------------------------------------------------------------
; SERIAL_INIT - Initialize serial I/O
; ------------------------------------------------------------------------------
; Sets Q output to idle state (high = mark)
; Sets R14.0 = 2 for 9600 baud output routine
; ------------------------------------------------------------------------------
SERIAL_INIT:
    SEQ                 ; Set Q high (idle/mark state)
    LDI 02H
    PLO 14              ; R14.0 = 2 for 9600 baud
    RETN

; ------------------------------------------------------------------------------
; SERIAL_WRITE_CHAR - Output one character at 9600 baud
; ------------------------------------------------------------------------------
; Input:  D = character to send
; Output: None
; Uses:   R11, R13 (saved/restored), R14, R15
;
; This is Chuck's proven bit-bang serial output routine with interleaved
; timing. The bit is output first, then processing happens during the
; bit period.
; ------------------------------------------------------------------------------
SERIAL_WRITE_CHAR:
    PLO 11              ; R11.0 = character to output

; B96OUT - Entry point (9600 baud output, R14.0 must = 2)
B96OUT:
    LDI 08H
    PLO 15              ; R15.0 = 8 bits to send

    ; Save R11 and R13 on stack
    GLO 11              ; Load D with R11.0
    STR 2               ; Push R11.0 onto stack
    DEC 2
    GLO 13              ; Load D with R13.0
    STR 2               ; Push R13.0 onto stack
    DEC 2

    DEC 14              ; Set delay counter = 1

; Send start bit
STBIT:
    SEQ                 ; Q OFF = start bit (space/0)
    NOP                 ; 2.5
    NOP                 ; 4
    GLO 11              ; 5
    SHRC                ; 6 - DF = first bit
    PLO 11              ; 7
    PLO 11              ; 8 (dummy for timing)
    NOP                 ; 9.5 instructions since start bit

    ; Determine first bit and output it
    BDF STBIT1          ; DF = 1, branch to output high
    BR QLO              ; Jump at 11.5 instruction time, Q=OFF

STBIT1:
    BR QHI              ; Jump at 11.5 instruction time, Q=ON

; --- Output bit = 0 (Q OFF / SEQ) path ---
QLO1:
    DEC 15
    GLO 15
    BZ DONE96           ; At 8.5 instructions either done or REQ

    ; Delay loop for low bit
    GLO 14
LDELAY:
    SMI 01H
    BZ QLO              ; If delay is done then output Q OFF
    ; Waste 9.5 instruction times
    NOP                 ; 1.5
    NOP                 ; 3
    NOP                 ; 4.5
    NOP                 ; 6
    NOP                 ; 7.5
    SEX 2               ; 8.5
    BR LDELAY           ; At 9.5 instruction times jump to LDELAY

QLO:
    SEQ                 ; Q OFF (bit = 0 / space)
    GLO 11
    SHRC                ; Put next bit in DF
    PLO 11
    LBNF QLO1           ; 5.5 - turn Q OFF after 6 more instruction times

; --- Output bit = 1 (Q ON / REQ) path ---
QHI1:
    DEC 15
    GLO 15
    BZ DONE96           ; At 8.5 instructions either done or SEQ

    ; Delay loop for high bit
    GLO 14
HDELAY:
    SMI 01H
    BZ QHI              ; If delay is done then output Q ON
    ; Waste 9.5 instruction times
    NOP                 ; 1.5
    NOP                 ; 3
    NOP                 ; 4.5
    NOP                 ; 6
    NOP                 ; 7.5
    SEX 2               ; 8.5
    BR HDELAY           ; At 9.5 instruction times jump to HDELAY

QHI:
    REQ                 ; Q ON (bit = 1 / mark)
    GLO 11
    SHRC                ; Put next bit in DF
    PLO 11
    LBDF QHI1           ; 5.5 - turn Q ON after 6 more instruction times

    ; Fall through for bit = 0 after high bit
    DEC 15
    GLO 15
    BZ DONE96           ; At 8.5 instructions either done or REQ

    ; Delay loop for transitioning to low
    GLO 14
XDELAY:
    SMI 01H
    BZ QLO              ; If delay is done then turn Q OFF
    ; Waste 9.5 instruction times
    NOP                 ; 1.5
    NOP                 ; 3
    NOP                 ; 4.5
    NOP                 ; 6
    NOP                 ; 7.5
    SEX 2               ; 8.5
    BR XDELAY           ; At 9.5 instruction times jump to XDELAY

; Finish last bit timing
DONE96:
    GLO 14
    GLO 14
    GLO 14

; Send stop bit(s)
DNE961:
    REQ                 ; Q ON = stop bit (mark/1)
    NOP                 ; 2.5
    NOP                 ; 4
    NOP                 ; 5.5
    NOP                 ; 7
    NOP                 ; 8.5
    SEX 2               ; 9.5
    SMI 01H             ; 10.5
    BNZ DNE961          ; 11.5 (loops for 2 stop bits when R14.0=2)
    ; NOTE: Stop bit is 2 instruction times longer than needed
    ;       plus the return to caller time

    ; Restore R13 and R11 from stack
    INC 2               ; Increment stack pointer
    LDN 2               ; Load D from stack
    PLO 13              ; Restore R13.0
    INC 2               ; Increment stack pointer
    LDN 2               ; Load D from stack
    PLO 11              ; Restore R11.0

    ; Restore R14.0 for next character
    LDI 02H
    PLO 14              ; R14.0 = 2 for 9600 baud

    RETN

; ------------------------------------------------------------------------------
; SERIAL_READ_CHAR - Input one character at 9600 baud
; ------------------------------------------------------------------------------
; Input:  None (reads from EF3)
; Output: D = character received
; Uses:   R11, R14, R15
;
; EF3 is inverted: idle = EF3 high, start bit = EF3 low
; Data: 0 = EF3 high, 1 = EF3 low (same inversion as Q output)
; ------------------------------------------------------------------------------
SERIAL_READ_CHAR:
    ; Wait for idle state (EF3 high)
WAIT_RX_IDLE:
    BN3 WAIT_RX_IDLE    ; Loop while EF3 is low

    ; Wait for start bit (EF3 goes low)
WAIT_RX_START:
    B3 WAIT_RX_START    ; Loop while EF3 is high (idle)

    ; Start bit detected
    ; Delay 1.5 bit times to center on first data bit
    LDI 08H
    PLO 15              ; R15.0 = 8 bits to receive
    LDI 00H
    PLO 11              ; R11.0 = received character (initially 0)

    ; Half bit delay (center of start bit)
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP
    NOP

    ; Full bit delay to center of bit 0
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

; Read 8 data bits
RX_BIT_LOOP:
    ; Sample bit from EF3
    ; EF3 high (BN3 true) = 0, EF3 low (B3 true) = 1
    B3 RX_BIT_ONE

RX_BIT_ZERO:
    ; Bit is 0 - shift in 0
    GLO 11
    SHR
    PLO 11
    BR RX_BIT_DELAY

RX_BIT_ONE:
    ; Bit is 1 - shift in 1 (set MSB)
    GLO 11
    SHR
    ORI 80H
    PLO 11

RX_BIT_DELAY:
    ; Delay one bit time
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

    ; Wait for stop bit (just delay, don't verify)
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
    ; Return character in D
    GLO 11
    RETN

; ==============================================================================
; End of Serial I/O
; ==============================================================================
