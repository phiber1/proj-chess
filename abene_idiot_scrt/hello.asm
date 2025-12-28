		titl	"Hello world demonstration with IDIOT. phiber 1/2019"
scall		equ	4
sret		equ	5
link		equ	6
initcall	equ	0400h
call		equ	040eh
ret		equ	0420h
f_msg		equ	043eh

		org	8000h
start		ldi	high main	; tell main PC to point to main
		phi	link
		ldi	low main
		plo	link
		lbr	initcall

main		ldi	high message	; main program begins
		phi	10
		ldi	low message
		plo	10
		sep	scall		; display text pointed to by R10
		dw	f_msg
		sep	1		; exit to monitor warm restart

message		db	"Hello, world!",0dh,0ah
		end

