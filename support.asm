; ==============================================================================
; RCA 1802/1806 Chess Engine - Support Routines
; ==============================================================================
; 16-bit arithmetic and utility functions
;
; 2026-05-21 — Reclaimed ~150 bytes by removing dead helpers (zero callers):
;   NEG16, ADD16, SUB16, CMP16_S, CMP16_U, SWAP16, LOAD16_R6/7/8,
;   MIN16_S/MIN16_R7, MAX16_S/MAX16_R6. The engine inlines its 16-bit
;   arithmetic via direct GLO/GHI/ADD/SM/etc. — these helper subroutines
;   were never called. INFINITY and NEG_INF EQUs were also unused.
;
; Only NEG16_R7 is kept (called by math.asm in the past, now also
; cross-referenced by evaluate.asm via the listing — preserved for
; safety until verified independently dead).
; ==============================================================================

; ------------------------------------------------------------------------------
; NEG16_R7 - Negate 16-bit value in R7
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
