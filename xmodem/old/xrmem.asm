; XMODEM receive for ELPH
; 2026 Mark Abene

SOH		equ	1
EOT		equ	4
ACK		equ	6
NAK		equ	21
warmstart 	equ	$8003
rxbuf		equ	$0000

bufptr		equ	10
blkcnt		equ	11	; high = byte count, low = block count
chksum		equ	12
nakflag		equ	8

delay		equ $fc01
f_msg		equ $ff09

		org	$7000
start:
		ldi high(startmsg)
		phi 15
		ldi	low(startmsg)
		plo 15
		call f_msg

		ldi     high(delay) ; inter-bit delay
		phi     13
		ldi     low(delay)
		plo     13
		
		ldi	0
		plo	blkcnt		; clear block counter
		plo	nakflag		; clear NAK flag
		ldi high(rxbuf)	; initialize buffer pointer
		phi bufptr
		ldi low(rxbuf)
		plo bufptr

		ldi	00	; wait 10 seconds
		phi 9
		ldi $20
		plo 9
delayloop1:
		call	delayloop2
		dec	9
		glo	9
		bnz	delayloop1

		ldi	NAK		; ask for a start
		call serout

blkloop:
		call serin		; read header byte
;		nop
;		str	bufptr
;		inc	bufptr
		smi	EOT		; end of file?
		bz	done
		adi	EOT
		smi	SOH		; start of block?
		bnz	error		; if not then error

 		glo	blkcnt		; get last block count
 		stxd
		call serin	; read blocks so far
;		str	bufptr
;		inc	bufptr
		plo	blkcnt		; remember block number
		irx
		sm			; same block?
		bnz	continue	; if not, continue as normal
		glo	nakflag		; same block because of NAK?
		ani	$ff
		bnz	continue	; if so, continue to re-recv
		glo	nakflag
		sdi	$ff
		plo	nakflag		; flag block as repeat
continue:
		call serin		; consume inverse block counter
;		str	bufptr
;		inc	bufptr

		ldi	0		; clear checksum
		plo	chksum
		
		ldi	128		; 128 bytes per block
		phi	blkcnt
byteloop:
		glo	chksum		; get checksum
		stxd
		call serin		; read next byte in block
		str	bufptr		; store into receive buffer
		inc	bufptr
		irx
		add			; add received byte to checksum
		plo	chksum		; update checksum
		ghi	blkcnt
		smi	1		; decrement byte counter
		phi	blkcnt
		bnz	byteloop	; loop until block received

		glo	chksum		; get our computed checksum
		stxd
		call serin		; read checksum from sender
		irx
		sm			; check against computed checksum
		bnz	badblock	; mismatch? handle it
		ldi	ACK		; otherwise, it is good!
		call serout		; ACK the block
		glo	nakflag		; flagged as repeat?
		shl
		bdf	rewind		; yes, rewind buffer
		lbr	blkloop		; get next block

badblock:
		glo	nakflag		; handle bad block
		adi	1
		plo	nakflag
		ldi	NAK
		call serout		; send NAK to request resend
rewind:
		ldi	128		; roll back receive buffer
rewloop:
		dec	bufptr
		smi	1
		bnz	rewloop
		plo	nakflag		; clear NAK flag
		lbr	blkloop		; retry block

done:
		ldi	ACK		; end of file
		call serout		; ACK the whole xfer
		lbr	warmstart	; exit to monitor

error:
		ldi high(errormsg)
		phi 15
		ldi low(errormsg)
		plo 15
		call f_msg
		lbr	warmstart	; exit to monitor
		
delayloop2:
		ldi $ff
		phi 15
		plo 15
delaylp2:
		dec	15
		ghi	15
		bnz	delaylp2
		glo	15
		bnz	delaylp2
		retn

startmsg:
		db	'Start XMODEM send...',13,10,0
errormsg:
		db	'Fatal error in xfer!',13,10,0

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
		sep     13
		ghi     15                  ; get character
		shr
		plo     14
		retn
recvlp0:
		br      recvlp1             ; equalize between 0 and 1

		end

