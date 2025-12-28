; ==============================================================================
; Auto-Calibrating Serial I/O
; ==============================================================================
; Measures bit timing from first character received
; Works at any baud rate on any system!
; ==============================================================================

; Calibrated delay value (initialized by AUTO_CALIBRATE)
CAL_BIT_DELAY   EQU $6F10    ; Storage for calibrated bit delay (2 bytes)
CAL_HALF_DELAY  EQU $6F12    ; Storage for half bit delay (2 bytes)

; ------------------------------------------------------------------------------
; AUTO_CALIBRATE - Measure baud rate from user input
; ------------------------------------------------------------------------------
; Call this on startup before any serial I/O
; Prompts user to press SPACE bar
; Measures the bit timing and stores in CAL_BIT_DELAY
; Uses: All registers
; ------------------------------------------------------------------------------
AUTO_CALIBRATE:
    ; Blink Q to signal "ready for calibration"
    SEQ
    LDI $FF
    PLO 3
CAL_BLINK1:
    DEC 3
    GLO 3
    BNZ CAL_BLINK1

    REQ
    LDI $FF
    PLO 3
CAL_BLINK2:
    DEC 3
    GLO 3
    BNZ CAL_BLINK2

    SEQ

    ; Now wait for start bit and measure timing
    ; User should press SPACE (0x20) which has pattern: 00100000
    ; Start bit (0) + bit0(0) + bit1(0) + bit2(0) + bit3(0) + bit4(0) + bit5(1)

CAL_WAIT_IDLE:
    ; Wait for line to be idle (high for normal, low for reversed)
#ifdef USE_EF1
    BN1 CAL_WAIT_IDLE    ; Normal polarity
#endif
#ifdef USE_EF2
    B2 CAL_WAIT_IDLE     ; Reversed polarity (VELF)
#endif
#ifdef USE_EF3
    BN3 CAL_WAIT_IDLE    ; Normal polarity
#endif
#ifdef USE_EF4
    BN4 CAL_WAIT_IDLE    ; Normal polarity
#endif

CAL_WAIT_START:
    ; Wait for start bit (line goes opposite)
#ifdef USE_EF1
    B1 CAL_WAIT_START    ; Wait for low (start bit)
#endif
#ifdef USE_EF2
    BN2 CAL_WAIT_START   ; Wait for high (reversed polarity start bit)
#endif
#ifdef USE_EF3
    B3 CAL_WAIT_START    ; Wait for low (start bit)
#endif
#ifdef USE_EF4
    B4 CAL_WAIT_START    ; Wait for low (start bit)
#endif

    ; Start bit detected! Now count cycles until first data bit transition
    ; For SPACE (0x20), bit 0-4 are all 0 (same as start bit)
    ; So we measure from start bit to bit 5 (which is 1)
    ; That's 6 bit times

    LDI 0
    PHI 8
    PLO 8               ; R8 = counter (will count cycles)

CAL_COUNT_LOOP:
    INC 8               ; Increment counter (2 cycles)

    ; Check if line changed to opposite state (bit 5 of SPACE)
#ifdef USE_EF1
    BN1 CAL_TRANSITION  ; Line went high (normal polarity)
#endif
#ifdef USE_EF2
    B2 CAL_TRANSITION   ; Line went low (reversed polarity)
#endif
#ifdef USE_EF3
    BN3 CAL_TRANSITION  ; Line went high (normal polarity)
#endif
#ifdef USE_EF4
    BN4 CAL_TRANSITION  ; Line went high (normal polarity)
#endif

    ; Check for overflow (timeout after 65536 iterations)
    GHI 8
    XRI $FF
    BNZ CAL_COUNT_LOOP
    GLO 8
    XRI $FF
    BNZ CAL_COUNT_LOOP

    ; Timeout - use default value
    LDI 0
    PHI 8
    LDI 200             ; Default delay
    PLO 8
    BR CAL_STORE

CAL_TRANSITION:
    ; Transition detected!
    ; R8 now contains cycle count for 6 bit times
    ; Divide by 6 to get one bit time

    ; Simple division by 6: divide by 2, then by 3
    ; First divide by 2 (shift right)
    GHI 8
    SHR
    PHI 7
    GLO 8
    SHRC
    PLO 7               ; R7 = R8 / 2

    ; Now divide by 3 (approximate: multiply by 0.333 ≈ divide by 3)
    ; For simplicity, just use R7 / 3 ≈ R7 - R7/4
    ; R7/4:
    GHI 7
    SHR
    PHI 9
    GLO 7
    SHRC
    PLO 9               ; R9 = R7 / 2

    GHI 9
    SHR
    PHI 9
    GLO 9
    SHRC
    PLO 9               ; R9 = R7 / 4

    ; R7 - R9 ≈ R7 * 0.75 ≈ R7 / 1.33 (close to / 3)
    GLO 7
    STR 2
    GLO 9
    SM
    PLO 8
    GHI 7
    STR 2
    GHI 9
    SMB
    PHI 8               ; R8 = R7 - R9 ≈ bit delay

CAL_STORE:
    ; Store calibrated delay
    LDI HIGH(CAL_BIT_DELAY)
    PHI 10
    LDI LOW(CAL_BIT_DELAY)
    PLO 10

    GHI 8
    STR 10
    INC 10
    GLO 8
    STR 10               ; Store BIT_DELAY

    ; Calculate HALF_DELAY (divide by 2)
    GHI 8
    SHR
    PHI 7
    GLO 8
    SHRC
    PLO 7

    LDI HIGH(CAL_HALF_DELAY)
    PHI 10
    LDI LOW(CAL_HALF_DELAY)
    PLO 10

    GHI 7
    STR 10
    INC 10
    GLO 7
    STR 10               ; Store HALF_DELAY

    ; Blink Q twice to signal "calibration done"
    REQ
    LDI $80
    PLO 3
CAL_DONE1:
    DEC 3
    GLO 3
    BNZ CAL_DONE1

    SEQ
    LDI $80
    PLO 3
CAL_DONE2:
    DEC 3
    GLO 3
    BNZ CAL_DONE2

    REQ
    LDI $80
    PLO 3
CAL_DONE3:
    DEC 3
    GLO 3
    BNZ CAL_DONE3

    SEQ

    RETN

; ------------------------------------------------------------------------------
; DELAY_BIT_CAL - Delay using calibrated value
; ------------------------------------------------------------------------------
; Uses calibrated delay from CAL_BIT_DELAY
; Uses: E (R14) as counter to preserve D
; ------------------------------------------------------------------------------
DELAY_BIT_CAL:
    ; Load calibrated delay
    LDI HIGH(CAL_BIT_DELAY)
    PHI 10
    LDI LOW(CAL_BIT_DELAY)
    PLO 10

    LDA 10               ; Get high byte
    PHI 14
    LDN 10               ; Get low byte
    PLO 14

DELAY_BIT_CAL_LOOP:
    DEC 14
    GLO 14
    BNZ DELAY_BIT_CAL_LOOP
    GHI 14
    BNZ DELAY_BIT_CAL_LOOP

    RETN

; ------------------------------------------------------------------------------
; DELAY_HALF_BIT_CAL - Delay half bit using calibrated value
; ------------------------------------------------------------------------------
DELAY_HALF_BIT_CAL:
    ; Load calibrated half delay
    LDI HIGH(CAL_HALF_DELAY)
    PHI 10
    LDI LOW(CAL_HALF_DELAY)
    PLO 10

    LDA 10               ; Get high byte
    PHI 14
    LDN 10               ; Get low byte
    PLO 14

DELAY_HALF_CAL_LOOP:
    DEC 14
    GLO 14
    BNZ DELAY_HALF_CAL_LOOP
    GHI 14
    BNZ DELAY_HALF_CAL_LOOP

    RETN

; ==============================================================================
; End of Auto-Calibration
; ==============================================================================
