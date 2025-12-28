; ==============================================================================
; RCA 1802/1806 Chess Engine - SCRT Support
; ==============================================================================
; Mark Abene's SCRT implementation
; Uses R7 for D storage (NOT R14 - that's for serial baud rate!)
; ==============================================================================

; Place SCRT at $6F00 to avoid low-memory conflicts
    ORG $6F00

; ==============================================================================
; SCRT Overview
; ==============================================================================
; Uses SEP 4 / DW target for calls, SEP 5 for returns
;
; Register usage:
;   R2 - Stack pointer
;   R3 - Program counter
;   R4 - Points to CALL routine
;   R5 - Points to RET routine
;   R6 - Linkage register (return address)
;   R7 - Temporary D storage (NOT R14!)
; ==============================================================================

; ------------------------------------------------------------------------------
; INITCALL - Initialize SCRT and transfer control
; ------------------------------------------------------------------------------
; Before calling: Set R6 to the address where execution should continue
; Example:
;   LDI HIGH(START)
;   PHI 6
;   LDI LOW(START)
;   PLO 6
;   LBR INITCALL
; START:
;   ; Stack setup here, then use CALL/RETN macros
; ------------------------------------------------------------------------------
INITCALL:
    LDI HIGH(SRET)
    PHI 5
    LDI LOW(SRET)
    PLO 5
    LDI HIGH(SCALL)
    PHI 4
    LDI LOW(SCALL)
    PLO 4
    SEP 5               ; Transfer to address in R6 via SRET

; ------------------------------------------------------------------------------
; SCALL - Standard Call Handler (executed via SEP 4)
; ------------------------------------------------------------------------------
; a18's CALL macro expands to: SEP 4, followed by 16-bit target address
; Uses R7 to preserve D across the call (NOT R14 - that's for serial!)
; ------------------------------------------------------------------------------
    SEP 3
SCALL:
    PLO 7               ; Save D in R7 (NOT R14!)
    GHI 6
    SEX 2
    STXD                ; Push R6 high
    GLO 6
    STXD                ; Push R6 low
    GHI 3
    PHI 6               ; R6 = return address (current R3)
    GLO 3
    PLO 6
    LDA 6               ; Get target high byte
    PHI 3
    LDA 6               ; Get target low byte
    PLO 3
    GLO 7               ; Restore D
    BR SCALL-1          ; SEP 3

; ------------------------------------------------------------------------------
; SRET - Standard Return Handler (executed via SEP 5)
; ------------------------------------------------------------------------------
; a18's RETN macro expands to: SEP 5
; Uses R7 to preserve D across the return
; ------------------------------------------------------------------------------
    SEP 3
SRET:
    PLO 7               ; Save D in R7
    GHI 6
    PHI 3               ; R3 = R6 (return address)
    GLO 6
    PLO 3
    SEX 2
    IRX
    LDXA                ; Pop R6 low
    PLO 6
    LDX                 ; Pop R6 high
    PHI 6
    GLO 7               ; Restore D
    BR SRET-1           ; SEP 3

; ==============================================================================
; End of SCRT Support
; ==============================================================================

; Reset location counter for subsequent modules
    ORG $0000
