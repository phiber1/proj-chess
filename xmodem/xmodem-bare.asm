; ==============================================================================
; XMODEM Bare-Metal Receiver for RCA 1802
; ==============================================================================
; Minimal XMODEM receiver - no BIOS, no SCRT overhead
; Receives binary to $0000, runs from $7000
;
; Hardware: EF3 = serial input (active low), Q = serial output (active low)
; Baud: 9600 (delay constant in R14.0)
; BAUD_DELAY: ~35 for 2MHz, ~70 for 4MHz, adjust as needed
;
; 2026 Mark Abene / Claude
; ==============================================================================

; XMODEM protocol bytes
SOH     EQU $01         ; Start of header (128-byte block)
EOT     EQU $04         ; End of transmission
ACK     EQU $06         ; Acknowledge
NAK     EQU $15         ; Negative acknowledge

; Register allocation (no SCRT, all registers available)
; R0  = PC after reset (we jump here)
; R1  = not used
; R2  = stack (minimal use)
; R3  = main PC
; R4  = not used
; R5  = not used
; R6  = not used
; R7  = receive subroutine PC
; R8  = transmit subroutine PC
; R9  = block counter (expected)
; R10 = checksum accumulator
; R11 = shift register for serial
; R12 = byte counter (128 or 1024)
; R13 = temp
; R14 = R14.0 = baud delay, R14.1 = unused
; R15 = destination pointer

RXDEST  EQU $0000       ; Receive destination
WARMST  EQU $8003       ; Return to monitor
BAUD_DLY EQU 178        ; Baud delay: 178 for 12MHz (with NOPs in loop)

        ORG $7000

; ==============================================================================
; Entry point - initialize and start
; ==============================================================================
START:
        ; Set up R3 as main PC
        LDI HIGH(MAIN)
        PHI 3
        LDI LOW(MAIN)
        PLO 3
        SEP 3           ; Switch to R3 as PC

MAIN:
        ; Initialize baud rate delay (9600 baud)
        LDI BAUD_DLY
        PLO 14          ; R14.0 = baud delay constant

        ; Set up receive subroutine at R7
        LDI HIGH(RX_BYTE)
        PHI 7
        LDI LOW(RX_BYTE)
        PLO 7

        ; Set up transmit subroutine at R8
        LDI HIGH(TX_BYTE)
        PHI 8
        LDI LOW(TX_BYTE)
        PLO 8

        ; === SERIAL TEST ===
        ; Print "X" to verify TX works
        LDI 'X'
        SEP 8           ; TX_BYTE

        ; Wait for any key to verify RX works
        SEP 7           ; RX_BYTE

        ; Echo it back with "=" prefix
        PLO 13          ; Save received char
        LDI '='
        SEP 8
        GLO 13
        SEP 8           ; Echo received char

        ; Print newline
        LDI $0D
        SEP 8
        LDI $0A
        SEP 8
        ; === END TEST ===

        ; Initialize destination pointer
        LDI HIGH(RXDEST)
        PHI 15
        LDI LOW(RXDEST)
        PLO 15

        ; Initialize expected block number
        LDI 1
        PLO 9           ; R9.0 = expected block (starts at 1)

        ; Send initial NAK to start transfer
        LDI NAK
        SEP 8           ; TX_BYTE

; ==============================================================================
; Main receive loop - process XMODEM blocks
; ==============================================================================
WAIT_BLOCK:
        SEP 7           ; RX_BYTE - wait for SOH or EOT

        ; Check for EOT
        XRI EOT
        LBZ XFER_DONE

        ; Check for SOH (EOT=4, SOH=1, so 4^1=5)
        XRI $05         ; XOR to check for SOH
        LBNZ WAIT_BLOCK ; Not SOH, keep waiting

        ; Got SOH - receive block
        ; Get block number
        SEP 7           ; RX_BYTE
        PLO 13          ; Save block number

        ; Get inverted block number (ignore for now)
        SEP 7           ; RX_BYTE

        ; Initialize for 128 bytes
        LDI 128
        PLO 12          ; R12.0 = byte counter
        LDI 0
        PLO 10          ; R10.0 = checksum

        ; Receive data bytes
RX_DATA_LOOP:
        SEP 7           ; RX_BYTE
        STR 15          ; Store at destination
        INC 15          ; Advance pointer

        ; Add to checksum
        SEX 15
        DEC 15
        GLO 10
        ADD             ; D = checksum + byte
        PLO 10          ; Update checksum
        SEX 2           ; Restore X
        INC 15          ; Re-advance pointer

        DEC 12          ; Decrement counter
        GLO 12
        LBNZ RX_DATA_LOOP

        ; Get checksum byte
        SEP 7           ; RX_BYTE

        ; Compare with calculated (simple: just accept for now)
        ; TODO: verify checksum, NAK if bad

        ; Send ACK
        LDI ACK
        SEP 8           ; TX_BYTE

        ; Increment expected block
        INC 9

        ; Wait for next block
        LBR WAIT_BLOCK

; ==============================================================================
; Transfer complete
; ==============================================================================
XFER_DONE:
        ; Send final ACK
        LDI ACK
        SEP 8           ; TX_BYTE

        ; Jump to warm start / monitor
        LBR WARMST

; ==============================================================================
; RX_BYTE - Receive one byte via bit-bang serial
; ==============================================================================
; Entry: SEP 7
; Exit:  D = received byte, returns via SEP 3
; Uses:  R11.0 = shift register, R14.0 = delay
; EF3 active low: HIGH = idle/0, LOW = 1
; ==============================================================================
RX_BYTE:
        ; Reset R7 to point back to start of this routine
        LDI LOW(RX_BYTE)
        PLO 7

        ; Wait for idle (stop bit from previous byte)
RX_IDLE:
        B3 RX_IDLE      ; Wait while EF3 low (wait for high = idle)

        LDI $FF
        PLO 11          ; Initialize shift register

        ; Wait for start bit
RX_START:
        BN3 RX_START    ; Wait while EF3 high (wait for low = start bit)

        ; Half-bit delay to center in start bit
        GLO 14
        SHR             ; Half delay
RX_HALF:
        SMI 1
        BNZ RX_HALF

        ; Receive 8 data bits
RX_BIT_LOOP:
        ; Full bit delay (~7 cycles/iteration for 12MHz)
        GLO 14
RX_DELAY:
        NOP             ; Extend loop for 12MHz
        SMI 1
        BNZ RX_DELAY

        ; Sample bit - EF3 HIGH = idle/0, EF3 LOW = active/1
        ; After delay, D = 0
        B3 RX_GOT_ZERO  ; EF3 HIGH = 0 bit, branch
        SKP             ; EF3 LOW = 1 bit, skip SHR
RX_GOT_ZERO:
        SHR             ; D=0, SHR gives DF=0 for zero bit
                        ; (skipped for 1 bit, DF=1 from SHRC below)

        ; Shift bit into byte (LSB first)
        GLO 11
        SHRC            ; Shift DF into MSB, LSB out to DF
        PLO 11
        LBDF RX_BIT_LOOP ; Loop until start bit (0) shifts out

        ; Stop bit delay
        GLO 14
RX_STOP:
        NOP
        SMI 1
        BNZ RX_STOP

        ; Return byte in D
        GLO 11
        SEP 3           ; Return to main

; ==============================================================================
; TX_BYTE - Transmit one byte via bit-bang serial
; ==============================================================================
; Entry: SEP 8, D = byte to send
; Exit:  Returns via SEP 3
; Uses:  R11.0 = shift register, R13.0 = bit counter, R14.0 = delay
; Q active low: SEQ = low = mark/1, REQ = high = space/0
; ==============================================================================
TX_BYTE:
        ; Reset R8 to point back to start of this routine
        PLO 11          ; Save byte to shift register first!
        LDI LOW(TX_BYTE)
        PLO 8

        LDI 8
        PLO 13          ; 8 bits to send

        ; Set Q to idle state (mark = low)
        SEQ

        ; Send start bit (space = 0 = Q high)
        REQ

        ; Bit delay
        GLO 14
TX_START_DLY:
        NOP
        SMI 1
        BNZ TX_START_DLY

        ; Send 8 data bits
TX_BIT_LOOP:
        GLO 11
        SHR             ; LSB to DF
        PLO 11

        BDF TX_SEND_ONE
        ; Send 0 (space = Q high)
        SEQ
        BR TX_BIT_DELAY

TX_SEND_ONE:
        ; Send 1 (mark = Q low)
        REQ

TX_BIT_DELAY:
        GLO 14
TX_DATA_DLY:
        NOP
        SMI 1
        BNZ TX_DATA_DLY

        DEC 13
        GLO 13
        BNZ TX_BIT_LOOP

        ; Send stop bit (mark = 1 = Q low)
        REQ

        ; Stop bit delay
        GLO 14
TX_STOP_DLY:
        NOP
        SMI 1
        BNZ TX_STOP_DLY

        SEP 3           ; Return to main

        END
