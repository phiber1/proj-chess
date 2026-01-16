; XMODEM Receiver for ELPH
; 2026 Mark Abene / Claude
; Uses BIOS SCRT - avoids R0-R6, R14

; BIOS entry points
warmstart   equ $8003
delay       equ $fc01

; XMODEM constants
SOH         equ $01         ; Start of header
EOT         equ $04         ; End of transmission
ACK         equ $06         ; Acknowledge
NAK         equ $15         ; Negative acknowledge
BLKSIZE     equ 128         ; Data bytes per block

; Register usage:
; R7  = destination pointer (where to store received data)
; R8  = expected block number
; R9  = received block number / scratch
; R10 = checksum accumulator
; R11 = byte counter
; R12 = scratch
; R13 = delay routine pointer (for serin/serout)
; R15 = used by serin/serout

            org $7000

xmodem_recv:
            ; Set up delay routine pointer for serin/serout
            ldi high(delay)
            phi 13
            ldi low(delay)
            plo 13

            ; Startup delay (~5 seconds) to allow user to start transfer
            ; Triple nested loop: 10 × 256 × 256 = 655,360 delay calls
            ldi 8
            phi 12              ; outermost loop counter
startup_outer2:
            ldi 0
            plo 12              ; outer loop counter (256)
startup_outer:
            ldi 0
            plo 11              ; inner loop counter (256)
startup_inner:
            sep 13              ; bit-time delay
            dec 11
            glo 11
            bnz startup_inner
            dec 12
            glo 12
            bnz startup_outer
            ghi 12
            smi 1
            phi 12
            bnz startup_outer2

            ; Set destination address
            ldi high(dest_addr)
            phi 7
            ldi low(dest_addr)
            plo 7

            ; Initialize expected block number to 1
            ldi 1
            plo 8
            ldi 0
            phi 8

            ; Send NAK to start transfer
start_xfer:
            ldi NAK
            call serout

recv_block:
            ; Wait for SOH or EOT
            call serin
            smi EOT
            bz xfer_done        ; EOT received, we're done
            adi EOT             ; restore D
            smi SOH
            bz got_soh          ; got SOH, receive block
            br recv_block       ; not SOH/EOT, keep waiting

got_soh:
            ; R9.1 = error flag (0=ok, non-zero=error)
            ldi 0
            phi 9

            ; Got SOH - receive block number
            call serin
            plo 9               ; R9.0 = block number

            ; Receive complement of block number
            call serin
            plo 12              ; R12.0 = complement
            glo 9
            str 2               ; M(R2) = block number
            glo 12              ; D = complement
            add                 ; block + ~block should = $FF
            xri $ff
            bz blknum_ok
            ldi 1
            phi 9               ; set error flag
blknum_ok:

            ; Receive 128 data bytes (always, even if error)
            ldi 0
            plo 10              ; clear checksum
            ldi BLKSIZE
            plo 11              ; byte counter = 128

recv_data:
            call serin
            str 7               ; store byte at destination
            inc 7               ; advance destination pointer

            ; Add to checksum (simple 8-bit sum)
            plo 12              ; save byte in R12.0
            glo 10              ; get checksum
            str 2               ; M(R2) = checksum
            glo 12              ; D = byte
            add                 ; D = checksum + byte
            plo 10              ; store new checksum

            dec 11              ; decrement byte counter
            glo 11
            bnz recv_data       ; loop until 128 bytes received

            ; Receive checksum byte
            call serin
            plo 12              ; R12.0 = received checksum
            glo 10              ; our calculated checksum
            str 2
            glo 12
            sm                  ; compare
            bz cksum_ok
            ldi 1
            phi 9               ; set error flag
cksum_ok:

            ; Check error flag
            ghi 9
            bnz block_error

            ; Check if this is the expected block
            glo 9
            str 2
            glo 8               ; expected block
            sm                  ; expected - received
            bnz check_dup       ; not expected block

            ; Block received OK - send ACK
            ldi ACK
            call serout

            ; Increment expected block number (wrap at 256)
            glo 8
            adi 1
            plo 8

            br recv_block       ; get next block

check_dup:
            ; Check if this is a duplicate (previous block resent)
            glo 8
            smi 1               ; expected - 1
            str 2
            glo 9               ; received block
            sm                  ; (expected-1) - received
            bnz block_error     ; not a dup, it's an error

            ; Duplicate block - rewind destination pointer, send ACK
            glo 7
            smi BLKSIZE
            plo 7
            ghi 7
            smbi 0
            phi 7               ; R7 -= 128

            ldi ACK
            call serout
            br recv_block

block_error:
            ; Rewind destination pointer (we wrote garbage)
            glo 7
            smi BLKSIZE
            plo 7
            ghi 7
            smbi 0
            phi 7               ; R7 -= 128

            ; Send NAK to request retransmit
            ldi NAK
            call serout
            br recv_block

xfer_done:
            ; Send final ACK for EOT
            ldi ACK
            call serout
            lbr warmstart

; ============================================================
; Serial I/O routines (from serio-test.asm)
; ============================================================

            org $7100
; Entry with char in D
serout:
            phi 15
            ldi 9               ; 9 bits to send (start + 8 data)
            plo 15
            ldi 0
            shr                 ; DF = 0 (start bit)
sendlp:
            bdf sendnb          ; jump if bit is 1
            seq                 ; Q=1 for 0 bit (inverted)
            br  sendct
sendnb:
            req                 ; Q=0 for 1 bit (inverted)
            br  sendct
sendct:
            sep 13              ; bit delay
            sex 2
            sex 2
            ghi 15
            shrc                ; shift in DF, shift out LSB to DF
            phi 15
            dec 15
            glo 15
            bnz sendlp
            req                 ; stop bit (Q=0 = mark = 1)
            sep 13
            retn

            org $7200
; Character read into D and R14.0
serin:
            ldi 8               ; 8 bits to receive
            plo 15
            ghi 14              ; first delay is half bit size
            phi 15
            shr
            smi 01
            phi 14
            b3  $               ; wait for start bit
            sep 13              ; wait half the pulse width
            ghi 15              ; recover baud constant
            phi 14
recvlp:
            ghi 15
            shr                 ; shift right
            bn3 recvlp0         ; jump if zero bit
            ori 128             ; set bit
recvlp1:
            phi 15
            sep 13              ; perform bit delay
            dec 15              ; decrement bit count
            glo 15              ; check for zero
            bnz recvlp          ; loop if not
recvdone:
            ; Sample bit 7 - we're positioned correctly after tight loop
            ghi 15
            shr                 ; shift existing bits right (start bit to DF)
            bn3 no_b7           ; check EF3 for bit 7
            ori 128             ; set bit 7 if EF3 high (1)
no_b7:
            phi 15              ; store with b7 included
            sex 2
            ghi 15              ; get character (all 8 bits correct now)
            plo 14
            retn
recvlp0:
            br  recvlp1         ; equalize between 0 and 1

; ============================================================
; Destination for received data
; ============================================================

dest_addr   equ $0000           ; Received data starts here

            end
