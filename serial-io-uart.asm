; ==============================================================================
; RCA 1802/1806 Chess Engine - Serial I/O (UART Version)
; ==============================================================================
; Hardware-specific serial I/O for systems with UART
; Replace stubs in uci.asm with these implementations
; ==============================================================================

; ------------------------------------------------------------------------------
; UART Configuration
; ------------------------------------------------------------------------------
; Adjust these constants for your hardware
UART_DATA   EQU $01     ; I/O port for UART data register
UART_STATUS EQU $02     ; I/O port for UART status register

; Status register bits (adjust for your UART)
UART_RX_RDY EQU $01     ; Bit 0: Receive data available
UART_TX_RDY EQU $02     ; Bit 1: Transmit buffer empty

; ------------------------------------------------------------------------------
; SERIAL_READ_CHAR - Read one character from UART
; ------------------------------------------------------------------------------
; Input:  None
; Output: D = character received
; Uses:   D only
;
; Waits for character to be available, then reads it
; Blocking call - will wait indefinitely
; ------------------------------------------------------------------------------
SERIAL_READ_CHAR:
    ; Poll status register until data available
SERIAL_RX_WAIT:
    INP UART_STATUS     ; Read status register into D
    ANI UART_RX_RDY     ; Check RX ready bit
    BZ SERIAL_RX_WAIT   ; Loop if not ready

    ; Data is ready, read it
    INP UART_DATA       ; Read data register into D
    RETN

; ------------------------------------------------------------------------------
; SERIAL_WRITE_CHAR - Write one character to UART
; ------------------------------------------------------------------------------
; Input:  D = character to send
; Output: None
; Uses:   D (to save character)
;
; Waits for transmit buffer to be empty, then sends character
; Blocking call - will wait indefinitely
; ------------------------------------------------------------------------------
SERIAL_WRITE_CHAR:
    ; Save character
    PLO 13              ; Save to D.0

    ; Poll status register until TX ready
SERIAL_TX_WAIT:
    INP UART_STATUS     ; Read status register
    ANI UART_TX_RDY     ; Check TX ready bit
    BZ SERIAL_TX_WAIT   ; Loop if not ready

    ; Transmitter is ready, send character
    GLO 13              ; Get character back
    OUT UART_DATA       ; Send to UART data register
    ; Note: Some UARTs need a pulse, adjust if needed

    RETN

; ------------------------------------------------------------------------------
; UART_INIT - Initialize UART (if needed)
; ------------------------------------------------------------------------------
; Call this from main initialization
; Configure baud rate, parity, stop bits, etc.
; Implementation depends on your specific UART chip
; ------------------------------------------------------------------------------
UART_INIT:
    ; Example for typical UART initialization
    ; Adjust for your hardware

    ; Set baud rate (if programmable)
    ; This depends heavily on UART type (8250, 16550, CDP1854, etc.)

    ; For CDP1854 ACIA (common with 1802):
    ; Control register setup
    ; LDI $95            ; Example: 8N1, /16 clock
    ; OUT UART_CONTROL
    ; ... etc

    ; For now, assume UART is pre-configured by system
    ; or doesn't need initialization

    RETN

; ==============================================================================
; Usage Notes
; ==============================================================================
;
; To use these implementations:
;
; 1. Copy SERIAL_READ_CHAR and SERIAL_WRITE_CHAR to replace the stubs in uci.asm
;
; 2. Adjust UART_DATA and UART_STATUS to match your hardware I/O ports
;
; 3. Adjust status bit masks (UART_RX_RDY, UART_TX_RDY) for your UART
;
; 4. Call UART_INIT from your main initialization routine
;
; 5. Common 1802 UARTs:
;    - CDP1854 UART/ACIA (RCA)
;    - CDP1863 Baud Rate Generator (with CDP1854)
;    - CDP18S641 UART
;    - 8250/16450/16550 (PC-compatible)
;    - 6850 ACIA (Motorola)
;
; ==============================================================================
; Example Hardware Configurations
; ==============================================================================
;
; COSMAC ELF II / QUEST:
;   - Often use CDP1854 UART
;   - Data port: $01
;   - Status port: $01 (same, read for status, write for control)
;
; Netronics ELF II:
;   - CDP1854 at port 1
;
; Quest Super ELF:
;   - CDP1854 configurable
;
; Modern FPGA implementations:
;   - Check your specific implementation
;   - May use different port assignments
;
; ==============================================================================
