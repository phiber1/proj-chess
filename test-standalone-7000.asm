; ==============================================================================
; Standalone Test at $7000 - No dependencies on main engine
; ==============================================================================
; This file ONLY puts code at $7000, won't overwrite monitor at $0000
; ==============================================================================

    ORG $7000

TEST_START:
    ; Toggle Q forever to prove execution works
LOOP:
    SEQ                     ; Q = high
    
    ; Delay
    LDI $00
    PHI 8
    LDI $00
    PLO 8
DELAY1:
    DEC 8
    GHI 8
    BNZ DELAY1
    GLO 8  
    BNZ DELAY1
    
    REQ                     ; Q = low
    
    ; Delay
    LDI $00
    PHI 8
    LDI $00
    PLO 8
DELAY2:
    DEC 8
    GHI 8
    BNZ DELAY2
    GLO 8
    BNZ DELAY2
    
    BR LOOP

    END
