; ==============================================================================
; RCA 1802/1806 Chess Engine - Support Routines
; ==============================================================================
; 16-bit arithmetic and utility functions
; All operations preserve registers unless noted
; ==============================================================================

; ------------------------------------------------------------------------------
; NEG16 - Negate 16-bit value (two's complement)
; ------------------------------------------------------------------------------
; Input:  6 = 16-bit value to negate
; Output: 6 = negated value
; Uses:   D (accumulator)
; Cycles: ~10-12
;
; Algorithm: -x = ~x + 1 (two's complement)
; ------------------------------------------------------------------------------
NEG16:
    ; NOTE: Cannot use R6 for parameters - SCRT uses R6 as linkage register!
    ; This function is BROKEN with SCRT and should be inlined instead.
    ; Keeping for reference but marking as deprecated.
    ;
    ; WORKAROUND: Use memory-based approach via NEG16_MEM
    GLO 6              ; Get low byte
    SDI 0               ; D = 0 - 6.0 (subtract from 0)
    PLO 6              ; Store negated low byte
    GHI 6              ; Get high byte
    SDBI 0              ; D = 0 - 6.1 - borrow
    PHI 6              ; Store negated high byte
    RETN                ; Return

; ------------------------------------------------------------------------------
; NEG16_R7 - Negate 16-bit value in 7
; ------------------------------------------------------------------------------
; Input:  7 = 16-bit value to negate
; Output: 7 = negated value
; Uses:   D (accumulator)
; ------------------------------------------------------------------------------
NEG16_R7:
    GLO 7
    SDI 0
    PLO 7
    GHI 7
    SDBI 0
    PHI 7
    RETN

; ------------------------------------------------------------------------------
; ADD16 - Add two 16-bit values
; ------------------------------------------------------------------------------
; Input:  6 = first operand
;         7 = second operand
; Output: 6 = 6 + 7
; Uses:   D (accumulator)
; Cycles: ~15-18
; ------------------------------------------------------------------------------
ADD16:
    GLO 6              ; Get 6 low byte
    STR 2              ; Store to memory (pointed by stack)
    GLO 7              ; Get 7 low byte
    ADD                 ; D = 6.0 + 7.0
    PLO 6              ; Store result low byte

    GHI 6              ; Get 6 high byte
    STR 2              ; Store to memory
    GHI 7              ; Get 7 high byte
    ADC                 ; D = 6.1 + 7.1 + carry
    PHI 6              ; Store result high byte
    RETN

; ------------------------------------------------------------------------------
; SUB16 - Subtract two 16-bit values
; ------------------------------------------------------------------------------
; Input:  6 = minuend
;         7 = subtrahend
; Output: 6 = 6 - 7
;         DF = 1 if no borrow (6 >= 7), 0 if borrow (6 < 7)
; Uses:   D (accumulator)
; Cycles: ~15-18
; ------------------------------------------------------------------------------
SUB16:
    GLO 7              ; Get 7 low byte
    STR 2              ; Store to memory
    GLO 6              ; Get 6 low byte
    SM                  ; D = 6.0 - 7.0 (subtract from memory)
    PLO 6              ; Store result low byte

    GHI 7              ; Get 7 high byte
    STR 2              ; Store to memory
    GHI 6              ; Get 6 high byte
    SMB                 ; D = 6.1 - 7.1 - borrow
    PHI 6              ; Store result high byte
    RETN                ; DF contains final borrow flag

; ------------------------------------------------------------------------------
; CMP16_S - Compare two 16-bit signed values
; ------------------------------------------------------------------------------
; Input:  6 = first value (signed)
;         7 = second value (signed)
; Output: DF = 1 if 6 >= 7, 0 if 6 < 7
;         D = sign of difference (for three-way comparison)
; Uses:   D (accumulator), modifies 6
; Notes:  6 is destroyed (contains 6-7 after call)
; Cycles: ~20-25
;
; For signed comparison, we need to handle the sign bit carefully
; ------------------------------------------------------------------------------
CMP16_S:
    ; Subtract 7 from 6 to get difference
    GLO 7
    STR 2
    GLO 6
    SM
    PLO 6              ; 6.0 = 6.0 - 7.0

    GHI 7
    STR 2
    GHI 6
    SMB
    PHI 6              ; 6.1 = 6.1 - 7.1 - borrow

    ; Result is in 6, DF has borrow flag
    ; For signed: if high bit is set, result is negative
    ; DF already contains correct result for >=
    RETN

; ------------------------------------------------------------------------------
; CMP16_U - Compare two 16-bit unsigned values
; ------------------------------------------------------------------------------
; Input:  6 = first value (unsigned)
;         7 = second value (unsigned)
; Output: DF = 1 if 6 >= 7, 0 if 6 < 7
; Uses:   D (accumulator), modifies 6
; Notes:  6 is destroyed (contains 6-7 after call)
; Cycles: ~15-18
; ------------------------------------------------------------------------------
CMP16_U:
    ; Same as signed for unsigned when we only care about >=
    GLO 7
    STR 2
    GLO 6
    SM
    PLO 6

    GHI 7
    STR 2
    GHI 6
    SMB
    PHI 6
    ; DF = 1 if 6 >= 7 (unsigned)
    RETN

; ------------------------------------------------------------------------------
; SWAP16 - Swap two 16-bit register values
; ------------------------------------------------------------------------------
; Input:  6, 7 = values to swap
; Output: 6, 7 = swapped
; Uses:   D (accumulator)
; Cycles: ~24
; ------------------------------------------------------------------------------
SWAP16:
    ; Swap low bytes
    GLO 6              ; D = 6.0
    STR 2              ; Save to stack
    GLO 7              ; D = 7.0
    PLO 6              ; 6.0 = 7.0
    LDN 2              ; D = old 6.0
    PLO 7              ; 7.0 = old 6.0

    ; Swap high bytes
    GHI 6              ; D = 6.1
    STR 2              ; Save to stack
    GHI 7              ; D = 7.1
    PHI 6              ; 6.1 = 7.1
    LDN 2              ; D = old 6.1
    PHI 7              ; 7.1 = old 6.1
    RETN

; ------------------------------------------------------------------------------
; LOAD16_IMM - Load 16-bit immediate value into register
; ------------------------------------------------------------------------------
; This is typically done inline, but provided as reference
; Input:  Inline: high byte, low byte following call
;         RX = target register (must be set before call)
; Output: RX = 16-bit value
; Uses:   3 (program counter), D
; ------------------------------------------------------------------------------
; Example usage:
;   CALL LOAD16_R6
;   DB $12, $34         ; Load $1234 into 6
; ------------------------------------------------------------------------------

LOAD16_R6:
    LDA 3              ; Load high byte, increment PC
    PHI 6              ; Store in 6 high
    LDA 3              ; Load low byte, increment PC
    PLO 6              ; Store in 6 low
    RETN

LOAD16_R7:
    LDA 3
    PHI 7
    LDA 3
    PLO 7
    RETN

LOAD16_R8:
    LDA 3
    PHI 8
    LDA 3
    PLO 8
    RETN

; ------------------------------------------------------------------------------
; MIN16_S - Return minimum of two signed 16-bit values
; ------------------------------------------------------------------------------
; Input:  6 = first value
;         7 = second value
; Output: 6 = min(6, 7)
; Uses:   D, stack
; Cycles: ~30-35
; ------------------------------------------------------------------------------
MIN16_S:
    ; Save 6 to stack
    GLO 6
    STXD
    GHI 6
    STXD

    ; Compare 6 and 7 (6 - 7)
    GLO 7
    STR 2
    GLO 6
    SM
    PLO 6              ; Temp store difference low

    GHI 7
    STR 2
    GHI 6
    SMB
    PHI 6              ; Temp store difference high

    ; Check sign of result
    ANI $80             ; Mask high bit (sign)
    BNZ MIN16_R7        ; If negative, 6 < 7, use 7

    ; 6 >= 7, restore 6 from stack
    IRX
    LDXA
    PHI 6
    LDXA
    PLO 6
    RETN

MIN16_R7:
    ; 6 < 7, use 7 (move 7 to 6)
    IRX                 ; Discard saved 6
    IRX
    GLO 7
    PLO 6
    GHI 7
    PHI 6
    RETN

; ------------------------------------------------------------------------------
; MAX16_S - Return maximum of two signed 16-bit values
; ------------------------------------------------------------------------------
; Input:  6 = first value
;         7 = second value
; Output: 6 = max(6, 7)
; Uses:   D, stack
; Cycles: ~30-35
; ------------------------------------------------------------------------------
MAX16_S:
    ; Save 6 to stack
    GLO 6
    STXD
    GHI 6
    STXD

    ; Compare 6 and 7
    GLO 7
    STR 2
    GLO 6
    SM
    PLO 6

    GHI 7
    STR 2
    GHI 6
    SMB
    PHI 6

    ; Check sign of result
    ANI $80
    BNZ MAX16_R6        ; If negative, 6 < 7, use 7

    ; 6 >= 7, restore 6 from stack
    IRX
    LDXA
    PHI 6
    LDXA
    PLO 6
    RETN

MAX16_R6:
    ; 6 < 7, use 7
    IRX
    IRX
    GLO 7
    PLO 6
    GHI 7
    PHI 6
    RETN

; ------------------------------------------------------------------------------
; Constants
; ------------------------------------------------------------------------------
INFINITY:   EQU $7FFF   ; Maximum positive 16-bit signed value
NEG_INF:    EQU $8000   ; Minimum negative 16-bit signed value (−32768)

; ==============================================================================
; End of Support Routines
; ==============================================================================
