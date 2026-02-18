; Simplest possible delay test
    ORG $0000

START:
    DIS

    ; Initialize E properly
    LDI 0
    PHI 14       ; E.1 = 0
    LDI 10
    PLO 14       ; E.0 = 10, so E = 0x000A

    ; Set Q high
    SEQ

LOOP:
    ; Toggle Q
    REQ
    
    ; Delay
    LDI 0
    PHI 14
    LDI 207
    PLO 14
DELAY:
    DEC 14       ; Decrement 16-bit E
    GLO 14       ; Check low byte
    BNZ DELAY
    GHI 14       ; Check high byte!
    BNZ DELAY
    
    ; Toggle Q back
    SEQ
    
    ; Another delay
    LDI 0
    PHI 14
    LDI 207
    PLO 14
DELAY2:
    DEC 14
    GLO 14
    BNZ DELAY2
    GHI 14       ; Check high byte!
    BNZ DELAY2
    
    BR LOOP

    END START
