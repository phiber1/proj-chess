; ==============================================================================
; RCA 1802/1806 Chess Engine - Support Routines
; ==============================================================================
; 16-bit arithmetic helpers.
;
; All routines except NEG16_R7 REMOVED 2026-06-04 — zero external call-sites
; (the engine inlines its 16-bit add/sub/compare, and loads immediates with the
; native 1806 RLDI). Reclaimed for SEE. Removed set: NEG16, ADD16, SUB16,
; CMP16_S, CMP16_U, SWAP16, LOAD16_R6/R7/R8, MIN16_S/MIN16_R7, MAX16_S/MAX16_R6,
; and the unused INFINITY/NEG_INF EQUs.
; ==============================================================================

; ------------------------------------------------------------------------------
; NEG16_R7 - Negate 16-bit value in R7 (two's complement)
; ------------------------------------------------------------------------------
; Input:  R7 = 16-bit value to negate
; Output: R7 = negated value
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

; ==============================================================================
; End of Support Routines
; ==============================================================================
