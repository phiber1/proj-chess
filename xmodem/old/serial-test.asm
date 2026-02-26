; These routines assume inverted Q and EF3

	org 7000h
	ldi high(message)
	phi 10
	ldi low(message)
	plo 10
loop:
	lda 10
	bz done
	call serout
	br loop
done:
	lbr 8003h

message:
	db "Hello!", $0D, $0A, 0

delay equ $fc01

	org 7100h
serout:		 ;entry from assembly with char in D
           phi     15
           ldi     9                   ; 9 bits to send
           plo     15
           ldi     high(delay)
           phi     13
           ldi     low(delay)
           plo     13
           ldi     0
           shr
sendlp:    bdf     sendnb              ; jump if no bit
           seq                         ; set output
           br      sendct
sendnb:    req                         ; reset output
           br      sendct
sendct:    sep     13                  ; perform bit dela
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

           end

