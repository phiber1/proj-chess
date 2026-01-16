; ==============================================================================
; XMODEM Receiver using BIOS I/O
; ==============================================================================
; Uses BIOS F_TYPE/F_READ with echo disabled
; Receives binary to $0000, runs from $7000
;
; 2026 Mark Abene / Claude
; ==============================================================================

; XMODEM protocol bytes
SOH     EQU $01         ; Start of header (128-byte block)
EOT     EQU $04         ; End of transmission
ACK     EQU $06         ; Acknowledge
NAK     EQU $15         ; Negative acknowledge

; BIOS entry points
F_TYPE  EQU $FF03       ; Output character in D
F_READ  EQU $FF06       ; Read character into D

; Memory
RXDEST  EQU $0000       ; Receive destination
WARMST  EQU $8003       ; Return to monitor

        ORG $7000

; ==============================================================================
; Entry point
; ==============================================================================
START:
        ; Use SCRT - R4=call, R5=RET already set by BIOS

        ; Disable echo: clear bit 0 of R14.1
        GHI 14
        ANI $FE         ; Clear bit 0
        PHI 14

        ; === SERIAL TEST ===
        LDI 'X'
        call F_TYPE

        call F_READ     ; Wait for key (no echo now)

        PLO 15          ; Save char
        LDI '='
        call F_TYPE
        GLO 15
        call F_TYPE
        LDI $0D
        call F_TYPE
        LDI $0A
        call F_TYPE
        ; === END TEST ===

        ; Initialize destination pointer
        LDI HIGH(RXDEST)
        PHI 15
        LDI LOW(RXDEST)
        PLO 15

        ; Initialize expected block number
        LDI 1
        PLO 9           ; R9.0 = expected block

        ; Send initial NAK
        LDI NAK
        call F_TYPE

; ==============================================================================
; Main receive loop
; ==============================================================================
WAIT_BLOCK:
        call F_READ     ; Wait for SOH or EOT

        ; Check for EOT
        XRI EOT
        LBZ XFER_DONE

        ; Check for SOH
        XRI $05         ; EOT^SOH = 5
        LBNZ WAIT_BLOCK

        ; Got SOH - receive block
        call F_READ     ; Block number (ignore)
        call F_READ     ; Inverted block number (ignore)

        ; Receive 128 data bytes
        LDI 128
        PLO 12          ; Counter
        LDI 0
        PLO 10          ; Checksum

RX_DATA_LOOP:
        call F_READ
        STR 15
        INC 15

        ; Add to checksum
        GLO 10
        SEX 15
        DEC 15
        ADD
        PLO 10
        SEX 2
        INC 15

        DEC 12
        GLO 12
        LBNZ RX_DATA_LOOP

        ; Get checksum (ignore for now)
        call F_READ

        ; Send ACK
        LDI ACK
        call F_TYPE

        INC 9           ; Next block
        LBR WAIT_BLOCK

; ==============================================================================
; Transfer complete
; ==============================================================================
XFER_DONE:
        LDI ACK
        call F_TYPE
        LBR WARMST

        END START
