; Serial I/O test for ELPH
; 2026 Mark Abene

warmstart 	equ	$8003
delay		equ	$fc01

		org	$7000
start:
		ldi     high(delay) ; inter-bit delay
		phi     13
		ldi     low(delay)
		plo     13
		call	serin
		smi		$0d
		bz		done
		adi		$0d
		call	serout
		br		start
done:
		lbr		warmstart

		org $7100
;entry with char in D
serout:
		phi     15
		ldi     9                   ; 9 bits to send
		plo     15
		ldi     0
		shr
sendlp:
		bdf     sendnb              ; jump if no bit
		seq                         ; set output
		br      sendct
sendnb:
		req                         ; reset output
		br      sendct
sendct:
		sep     13                  ; perform bit delay
		sex     2
		sex     2
		ghi     15
		shrc
		phi     15
		dec     15
		glo     15
		bnz     sendlp
		req                         ; set stop bits
		sep     13
		retn

		org $7200
; character read into D and R14.0
serin:
		ldi     8                   ; 8 bits to receive
		plo     15
		ghi     14                  ; first delay is half bit size
		phi     15
		shr
		smi     01
		phi     14
		b3      $                   ; wait for transmission
		sep     13                  ; wait half the pulse width
		ghi     15                  ; recover baud constant
		phi     14
		sep     13                  ; wait half the pulse width
recvlp:
		ghi     15
		shr                         ; shift right
		bn3     recvlp0             ; jump if zero bit
		ori     128                 ; set bit
recvlp1:
		phi     15
		sep     13                  ; perform bit delay
		dec     15                  ; decrement bit count
		nop
		nop
		glo     15                  ; check for zero
		bnz     recvlp              ; loop if not
recvdone:
		sex		2
		sep     13                  ; get past stop bit
		ghi     15                  ; get character
		plo     14
		retn
recvlp0:
		br      recvlp1             ; equalize between 0 and 1

		end

