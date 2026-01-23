; ==============================================================================
; RCA 1802/1806 Chess Engine - Math Routines
; ==============================================================================
; 16-bit multiplication and division
; No hardware support - all software implementation
; ==============================================================================

; ------------------------------------------------------------------------------
; MUL16 - Multiply two 16-bit values (signed)
; ------------------------------------------------------------------------------
; Input:  6 = multiplicand (16-bit signed)
;         7 = multiplier (16-bit signed)
; Output: 6 = lower 16 bits of result
;         8 = upper 16 bits of result (for 32-bit result)
; Uses:   D, 8, 9, D, E, F, stack
; Cycles: ~400-500 (depends on multiplier value)
;
; Algorithm: Shift-and-add (optimized for fewer shifts)
; Handles signed multiplication by:
;   1. Save sign information
;   2. Work with absolute values
;   3. Negate result if signs differ
; ------------------------------------------------------------------------------
MUL16:
    ; Save sign information
    GHI 6
    ANI $80             ; Check sign bit of 6
    PLO 13              ; D.0 = sign of 6 (bit 7)

    GHI 7
    ANI $80             ; Check sign bit of 7
    STXD                ; Save sign of 7 to stack (R14 is reserved!)

    GLO 13
    IRX
    XOR                 ; XOR signs (D = sign6 XOR sign7)
    PLO 15              ; F.0 = result sign (0 if same, $80 if differ)

    ; Convert to absolute values if negative
    GHI 6
    ANI $80
    BZ MUL16_R6_POS
    ; 6 is negative, negate it - INLINED (R6 used by SCRT)
    GLO 6
    SDI 0
    PLO 6
    GHI 6
    SDBI 0
    PHI 6

MUL16_R6_POS:
    GHI 7
    ANI $80
    BZ MUL16_R7_POS
    ; 7 is negative, negate it
    CALL NEG16_R7

MUL16_R7_POS:
    ; Now both 6 and 7 are positive
    ; Save 6 and 7 for the algorithm
    ; 6 = multiplicand
    ; 7 = multiplier
    ; Result will accumulate in 8:9 (32-bit)

    ; Initialize result to 0
    LDI 0
    PHI 8
    PLO 8
    PHI 9
    PLO 9

    ; Initialize shift counter (16 iterations)
    LDI 16
    PLO 13              ; D.0 = loop counter

MUL16_LOOP:
    ; Check if lowest bit of multiplier (7) is set
    GLO 7
    ANI 1
    BZ MUL16_NO_ADD

    ; Add 6 to result (8:9 += 6)
    GLO 9
    STR 2
    GLO 6
    ADD
    PLO 9

    GHI 9
    STR 2
    GHI 6
    ADC
    PHI 9

    GHI 8
    ADCI 0              ; Add carry to upper word
    PHI 8

    GLO 8
    ADCI 0
    PLO 8

MUL16_NO_ADD:
    ; Shift result left (8:9 << 1)
    ; But we shift multiplier right instead (optimization)
    ; Shift 7 right
    GHI 7
    SHR                 ; Shift right with carry
    PHI 7
    GLO 7
    SHRC                ; Shift right with carry from previous
    PLO 7

    ; Shift 6 left (multiplicand doubles each iteration)
    GLO 6
    SHL
    PLO 6
    GHI 6
    SHLC
    PHI 6

    ; Decrement counter
    DEC 13
    GLO 13
    BNZ MUL16_LOOP

    ; Result is in 9 (lower 16 bits) and 8 (upper 16 bits)
    ; Move 9 to 6 for return (we typically only need lower 16 bits)
    GLO 9
    PLO 6
    GHI 9
    PHI 6

    ; Check if we need to negate result
    GLO 15
    ANI $80
    BZ MUL16_DONE

    ; Negate result (32-bit negate of 8:6) - INLINED (R6 used by SCRT)
    GLO 6
    SDI 0
    PLO 6
    GHI 6
    SDBI 0
    PHI 6
    ; If 6 was 0, we need to also negate 8
    GLO 6
    BNZ MUL16_DONE
    GHI 6
    BNZ MUL16_DONE
    ; 6 is 0, negate 8
    GLO 8
    SDI 0
    PLO 8
    GHI 8
    SDBI 0
    PHI 8

MUL16_DONE:
    RETN

; ------------------------------------------------------------------------------
; MUL16_FAST - Fast multiply for small values (8x16)
; ------------------------------------------------------------------------------
; Input:  D = 8-bit unsigned multiplier
;         6 = 16-bit multiplicand
; Output: 6 = D * 6 (lower 16 bits)
; Uses:   7, 8, D
; Cycles: ~150-200 (faster than full MUL16)
;
; Optimized for multiplying by small constants (piece values, etc.)
; ------------------------------------------------------------------------------
MUL16_FAST:
    ; Save multiplier in 7.0
    PLO 7
    LDI 0
    PHI 7              ; 7 = 8-bit multiplier (extended to 16-bit)

    ; Initialize result
    LDI 0
    PHI 8
    PLO 8

    ; Loop counter
    LDI 8
    PLO 13

MUL16_FAST_LOOP:
    ; Check lowest bit of multiplier
    GLO 7
    ANI 1
    BZ MUL16_FAST_NO_ADD

    ; Add 6 to result
    GLO 8
    STR 2
    GLO 6
    ADD
    PLO 8

    GHI 8
    STR 2
    GHI 6
    ADC
    PHI 8

MUL16_FAST_NO_ADD:
    ; Shift multiplier right
    GLO 7
    SHR
    PLO 7

    ; Shift multiplicand left
    GLO 6
    SHL
    PLO 6
    GHI 6
    SHLC
    PHI 6

    ; Decrement counter
    DEC 13
    GLO 13
    BNZ MUL16_FAST_LOOP

    ; Move result to 6
    GLO 8
    PLO 6
    GHI 8
    PHI 6

    RETN

; ------------------------------------------------------------------------------
; DIV16 - Divide two 16-bit unsigned values
; ------------------------------------------------------------------------------
; Input:  6 = dividend (16-bit unsigned)
;         7 = divisor (16-bit unsigned)
; Output: 6 = quotient (6 / 7)
;         8 = remainder (6 % 7)
; Uses:   D, 8, 9, D, E
; Cycles: ~600-800
;
; Algorithm: Restoring division (shift and subtract)
; Note: Does NOT check for divide by zero!
; ------------------------------------------------------------------------------
DIV16:
    ; Initialize quotient to 0
    LDI 0
    PHI 8
    PLO 8              ; 8 = quotient

    ; Initialize remainder to 0
    PHI 9
    PLO 9              ; 9 = remainder

    ; Loop counter (16 bits)
    LDI 16
    PLO 13

DIV16_LOOP:
    ; Shift dividend (6) left into remainder (9)
    ; remainder = (remainder << 1) | (dividend >> 15)
    GLO 9
    SHL
    PLO 9
    GHI 9
    SHLC
    PHI 9

    ; Get high bit of dividend
    GHI 6
    ANI $80
    BZ DIV16_NO_BIT
    ; Set low bit of remainder
    GLO 9
    ORI 1
    PLO 9

DIV16_NO_BIT:
    ; Shift dividend left
    GLO 6
    SHL
    PLO 6
    GHI 6
    SHLC
    PHI 6

    ; Compare remainder with divisor
    ; Save remainder in case we need to restore (use stack, R14 is reserved!)
    GLO 9
    STXD
    GHI 9
    STXD

    ; Subtract divisor from remainder
    GLO 7
    STR 2
    GLO 9
    SM
    PLO 9

    GHI 7
    STR 2
    GHI 9
    SMB
    PHI 9

    ; Check if subtraction was successful (DF = 1 means no borrow)
    BDF DIV16_SUBTRACT_OK

    ; Restore remainder from stack
    IRX
    LDXA
    PHI 9
    LDX
    PLO 9
    LBR DIV16_SHIFT_QUOT

DIV16_SUBTRACT_OK:
    ; Clean up stack (discard saved remainder)
    IRX
    IRX
    ; Set bit in quotient
    GLO 8
    ORI 1
    PLO 8

DIV16_SHIFT_QUOT:
    ; Shift quotient left (for next iteration)
    DEC 13
    GLO 13
    LBZ DIV16_DONE      ; Don't shift on last iteration

    GLO 8
    SHL
    PLO 8
    GHI 8
    SHLC
    PHI 8

    LBR DIV16_LOOP

DIV16_DONE:
    ; Move quotient to 6
    GLO 8
    PLO 6
    GHI 8
    PHI 6

    ; Remainder is already in 9, move to 8 for return
    GLO 9
    PLO 8
    GHI 9
    PHI 8

    RETN

; ==============================================================================
; End of Math Routines
; ==============================================================================
