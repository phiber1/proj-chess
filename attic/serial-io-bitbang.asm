; ==============================================================================
; RCA 1802/1806 Chess Engine - Serial I/O (Bit-Bang Version)
; ==============================================================================
; Software serial I/O for systems without UART hardware
; Uses Q output and EF input flags
; ==============================================================================

; ------------------------------------------------------------------------------
; Configuration
; ------------------------------------------------------------------------------
; Adjust these for your hardware and desired baud rate

; I/O pins:
; - TX: Q output (pin 26 on 1802) - STANDARD
; - RX: EF3 input (pin 27 on 1802) - STANDARD for most systems
;
; EF line selection (build-time option):
; Most systems use EF3 for console input
; Define one of these before including this file:
;   USE_EF1, USE_EF2, USE_EF3 (default), or USE_EF4
;
; If no symbol defined, EF3 is used (most common configuration)

; Baud rate: 9600 baud
; Bit time = 1/9600 = 104.17 µs
; At 12 MHz: 104.17 µs × 12 cycles/µs = 1250 cycles per bit

; Actual timing needs adjustment for instruction cycles
; These constants are approximations - tune for your specific hardware

; Delay constants (for 12 MHz clock, 9600 baud)
; Note: These are defined here for standalone use. If config.asm is included
;       in your build, these will be overridden by the values in config.asm
BIT_DELAY   EQU 312     ; Cycles for one bit time (9600 baud @ 12 MHz)
HALF_DELAY  EQU 156     ; Half bit time (for centering in bit period)

; ------------------------------------------------------------------------------
; SERIAL_READ_CHAR - Bit-bang serial receive
; ------------------------------------------------------------------------------
; Input:  None (reads from EF1 pin)
; Output: D = character received
; Uses:   C (bit counter), D (accumulator), E (scratch)
;
; Format: 8-N-1 (8 data bits, no parity, 1 stop bit)
; LSB first
; ------------------------------------------------------------------------------
SERIAL_READ_CHAR:
    ; Wait for start bit
    ; NOTE: VELF EF2 has REVERSED polarity!
    ;   Normal: idle HIGH, start bit LOW
    ;   VELF EF2: idle LOW, start bit HIGH
WAIT_START:
#ifdef USE_EF1
    BN1 WAIT_START      ; Loop while EF1 is high (idle) - NORMAL polarity
#endif
#ifdef USE_EF2
    B2 WAIT_START       ; Loop while EF2 is LOW (idle) - REVERSED polarity!
#endif
#ifdef USE_EF4
    BN4 WAIT_START      ; Loop while EF4 is high (idle) - NORMAL polarity
#endif
#ifndef USE_EF1
#ifndef USE_EF2
#ifndef USE_EF4
    BN3 WAIT_START      ; Loop while EF3 is high (idle) - NORMAL polarity
#endif
#endif
#endif

    ; Start bit detected, delay to center of first data bit
    CALL DELAY_HALF_BIT_CAL
    CALL DELAY_BIT_CAL      ; Now in middle of start bit

    ; Read 8 data bits
    LDI 8
    PLO 12              ; C.0 = bit counter
    LDI 0
    PLO 13              ; D.0 = accumulator

READ_BIT_LOOP:
    CALL DELAY_BIT_CAL      ; Wait one bit time

    ; Read bit from configured EF input
    ; NOTE: EF2 logic is INVERTED due to reversed polarity!
#ifdef USE_EF1
    B1 BIT_IS_HIGH      ; Branch if EF1 is high = 1 (NORMAL)
#endif
#ifdef USE_EF2
    BN2 BIT_IS_HIGH     ; Branch if EF2 is LOW = 1 (REVERSED!)
#endif
#ifdef USE_EF4
    B4 BIT_IS_HIGH      ; Branch if EF4 is high = 1 (NORMAL)
#endif
#ifndef USE_EF1
#ifndef USE_EF2
#ifndef USE_EF4
    B3 BIT_IS_HIGH      ; Branch if EF3 is high = 1 (NORMAL)
#endif
#endif
#endif
    ; Bit is low (0)
    GLO 13
    SHR                 ; Shift right (LSB first)
    PLO 13
    BR READ_NEXT_BIT

BIT_IS_HIGH:
    ; Bit is high (1)
    GLO 13
    SHR
    ORI $80             ; Set MSB
    PLO 13

READ_NEXT_BIT:
    DEC 12
    GLO 12
    BNZ READ_BIT_LOOP

    ; Read stop bit (just wait, don't need to verify)
    CALL DELAY_BIT_CAL

    ; Return character in D
    GLO 13
    RETN

; ------------------------------------------------------------------------------
; SERIAL_WRITE_CHAR - Bit-bang serial transmit
; ------------------------------------------------------------------------------
; Input:  D = character to send
; Output: None (sends to Q output)
; Uses:   C (bit counter), D (shift register)
;
; Format: 8-N-1 (8 data bits, no parity, 1 stop bit)
; LSB first
; ------------------------------------------------------------------------------
SERIAL_WRITE_CHAR:
    ; Save character
    PLO 13              ; D.0 = character to send

    ; Send start bit (low)
    REQ                 ; Reset Q (low)
    CALL DELAY_BIT_CAL

    ; Send 8 data bits
    LDI 8
    PLO 12              ; C.0 = bit counter

WRITE_BIT_LOOP:
    ; Check LSB of character
    GLO 13
    ANI $01             ; Test bit 0
    BZ SEND_LOW_BIT

    ; Send high bit
    SEQ                 ; Set Q (high)
    BR SEND_BIT_DONE

SEND_LOW_BIT:
    ; Send low bit
    REQ                 ; Reset Q (low)

SEND_BIT_DONE:
    CALL DELAY_BIT_CAL      ; Hold bit for one bit time

    ; Shift character right for next bit
    GLO 13
    SHR
    PLO 13

    DEC 12
    GLO 12
    BNZ WRITE_BIT_LOOP

    ; Send stop bit (high)
    SEQ                 ; Set Q (high)
    CALL DELAY_BIT_CAL

    ; Leave line high (idle state)
    RETN

; ------------------------------------------------------------------------------
; Delay Routines
; ------------------------------------------------------------------------------
; These need fine-tuning for exact baud rate
; Adjust loop counts based on actual instruction timing
; ------------------------------------------------------------------------------

; DELAY_BIT - Delay for one bit time (~104 µs @ 9600 baud)
; Uses E (R14) as counter to preserve D
DELAY_BIT:
    LDI BIT_DELAY       ; Load delay constant
    PLO 14               ; Save in E (R14.0)
DELAY_BIT_LOOP:
    DEC 14               ; Decrement E
    GLO 14               ; Load E to D for test
    BNZ DELAY_BIT_LOOP  ; Loop if not zero
    ; Total per iteration: ~4-5 cycles
    ; For 1250 cycles: need ~312 iterations
    ; Adjust BIT_DELAY constant accordingly
    RETN

; DELAY_HALF_BIT - Delay for half bit time (~52 µs)
; Uses E (R14) as counter to preserve D
DELAY_HALF_BIT:
    LDI HALF_DELAY
    PLO 14               ; Save in E (R14.0)
DELAY_HALF_LOOP:
    DEC 14               ; Decrement E
    GLO 14               ; Load E to D for test
    BNZ DELAY_HALF_LOOP
    RETN

; ------------------------------------------------------------------------------
; SERIAL_INIT - Initialize bit-bang serial
; ------------------------------------------------------------------------------
; Sets Q output to idle state (high)
; Call from main initialization
; ------------------------------------------------------------------------------
SERIAL_INIT:
    SEQ                 ; Set Q high (idle state for serial line)
    RETN

; ==============================================================================
; Timing Calibration
; ==============================================================================
;
; To calibrate timing for accurate baud rate:
;
; 1. Send test pattern (e.g., 'U' = 0x55 = 01010101)
; 2. Measure actual bit time with oscilloscope or logic analyzer
; 3. Adjust BIT_DELAY and HALF_DELAY constants
;
; Formula for delay constant:
;   Target_cycles = Clock_MHz × Bit_time_µs
;   Iterations = Target_cycles / Cycles_per_loop
;
; Example for 9600 baud @ 12 MHz:
;   Bit_time = 104.17 µs
;   Target = 12 × 104.17 = 1250 cycles
;   Loop = 4 cycles/iteration
;   Iterations = 1250 / 4 = 312
;
; So BIT_DELAY should be ~312
;
; ==============================================================================
; Alternative Baud Rates
; ==============================================================================
;
; For different baud rates, adjust delays:
;
; 4800 baud:
;   Bit time: 208.33 µs
;   Cycles @ 12 MHz: 2500
;   BIT_DELAY = 625, HALF_DELAY = 312
;
; 19200 baud:
;   Bit time: 52.08 µs
;   Cycles @ 12 MHz: 625
;   BIT_DELAY = 156, HALF_DELAY = 78
;
; 38400 baud:
;   Bit time: 26.04 µs
;   Cycles @ 12 MHz: 312
;   BIT_DELAY = 78, HALF_DELAY = 39
;
; Note: Higher baud rates are harder to achieve accurately with bit-bang
;       and leave less CPU time for other tasks
;
; ==============================================================================
; Hardware Connections
; ==============================================================================
;
; Typical connections:
;
; 1802/1806 Side:
;   Q (pin 26) → TX → RS-232 Level Shifter → PC RXD
;   EF1 (pin 25) ← RX ← RS-232 Level Shifter ← PC TXD
;   GND (pin 7) ← → GND
;
; Level Shifter:
;   - MAX232 or similar (converts 0/5V to ±12V RS-232)
;   - Or use USB-TTL serial adapter (3.3V/5V logic levels, no shifter needed)
;
; For USB-TTL adapter (easier):
;   Q → Adapter RXD (3.3V/5V tolerant)
;   EF1 ← Adapter TXD
;   GND → Adapter GND
;   (Ensure voltage levels are compatible - 1802 is 5V CMOS)
;
; ==============================================================================
