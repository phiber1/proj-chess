; *******************************************************************
; *** This software is copyright 2005 by Michael H Riley          ***
; *** You have permission to use, modify, copy, and distribute    ***
; *** this software so long as this copyright notice is retained. ***
; *** This software may not be used in commercial applications    ***
; *** without express written permission from the author.         ***
; *******************************************************************

include    bios.inc
include    kernel.inc

           org     8000h
           db      'XR',0
           dw      9000h
           dw      endrom+7000h
           dw      2000h
           dw      endrom-2000h
           dw      2000h
           db      0

           org     2000h
           br      start

include    date.inc

fildes:    db      0,0,0,0
           dw      dta
           db      0,0
           db      0
           db      0,0,0,0
           dw      0,0
           db      0,0,0,0
block:     db      0

dta:       equ     7000h
dtapage:   equ     070h
stack:     equ     7fffh

start:     ghi     ra                  ; copy argument address to rf
           phi     rf
           glo     ra
           plo     rf
loop1:     lda     ra                  ; look for first less <= space
           smi     33
           bdf     loop1
           dec     ra                  ; backup to char
           ldi     0                   ; need proper termination
           str     ra
           ldi     high fildes         ; get file descriptor
           phi     rd
           ldi     low fildes
           plo     rd
           ldi     3                   ; create/truncate file
           plo     r7
           sep     scall               ; attempt to open file
           dw      o_open
           bnf     opened              ; jump if file opened
           ldi     high errmsg         ; point to error message
           phi     rf
           ldi     low errmsg
           plo     rf
           sep     scall               ; display error message
           dw      o_msg
           lbr     o_wrmboot           ; return to Elf/OS
errmsg:    db      'file error',10,13,0
opened:    ldi     high block          ; get address of data block
           phi     r9
           ldi     low block           ; need to set starting block number
           plo     r9
           ldi     1
           str     r9
           ldi     15h                 ; need to send NAK to start
           sep     scall
           dw      o_type
filelp:    sep     scall               ; read a block 
           dw      readblk
           bdf     filedn              ; jump if done
           ldi     high rxbuffer       ; point to buffer
           phi     rf
           ldi     low rxbuffer
           plo     rf
           sep     scall               ; write buffer to file
           dw      o_write
           ldi     6h                  ; send an ACK
           sep     scall
           dw      o_type
           br      filelp              ; loop back for more
filedn:    sep     scall               ; close file
           dw      o_close
           ldi     6h                  ; acknowledge end of transmission
           sep     scall
           dw      o_type
           lbr     o_wrmboot           ; and return to os

readblk:   ldi     high rxbuffer       ; set receive buffer
           phi     rf
           ldi     low rxbuffer
           plo     rf
           ldi     128                 ; 128 bytes to receive
           plo     rc
           plo     rb
           ldi     0
           phi     rc
           phi     rb
           sep     scall               ; wait for next incoming character
           dw      o_read
           smi     2                   ; check for stx
           lbz     stx                 ; jump if so
           smi     2h                  ; check for EOT
           bz      readeot             ; jump if so
           br      readgo
stx:       ldi     4                   ; set block size of 1k
           phi     rc
           phi     rb
           ldi     0
           plo     rc
           plo     rb
readgo:    sep     scall               ; read block number
           dw      o_read
           sep     scall               ; read inverted block number
           dw      o_read
readlp:    sep     scall               ; read data byte
           dw      o_read
           str     rf                  ; store into output buffer
           inc     rf                  ; point to next position
           dec     rb                  ; decrement block count
           glo     rb                  ; see if done
           bnz     readlp              ; loop back if not
           ghi     rb                  ; check high byte as well
           sep     scall               ; read checksum byte
           dw      o_read
           smi     0                   ; signal not eot
           sep     sret                ; and return
readeot:   adi     1                   ; signal end
           sep     sret

endrom:    equ     $

rxbuffer:  equ     $

