; ==============================================================================
; Ultra-Simple Q Toggle Test
; ==============================================================================
; Just toggles Q as fast as possible
; Should produce a tone if working
; ==============================================================================

    ORG $0000

START:
    DIS                 ; Disable interrupts

LOOP:
    SEQ                 ; Q high
    REQ                 ; Q low
    BR LOOP             ; Repeat forever

    END START
