; Adapted from Josh Bensadon's VELF serial
; routines, and Bill Rowe's tweaks.
; These routines assume inverted Q and EF3

    org 3100h
serout:         ;entry from assembly with char in D
    phi rf      ;save char in R15.1
    ldi 9       ;9 bits to transmit (1 start + 8 data)
    plo r9
    ghi rf 
    shl     ;set start bit
    rshr        ;DF=0
 
txcloop:
    bdf $+5     ;10.5   jump to req to send a 1 bit
    seq     ;11.5   send a 0 bit
    br $+5      ;1      jump +5 to next shift
    req     ;11.5   send a 1 bit
    br $+2      ;1      jump +2 to next shift (NOP for timing)
    rshr        ;2      shift next bit to DF flag
    phi r9     ;3      save D in r9.1
    dec r9     ;4      dec bit count
    glo r9     ;5      get bit count
    bz txcret  ;6      if 0 then all 9 bits (start and data) sent
    ghi r9     ;7      restore D
;    bitdelay __BAUDRATE,LCC1802CPUSPEED,20,2
    stxd
    rshl    ; save DF
    stxd
    ldi 16
    ldi 16
txdelay1:
    smi 1
    bnz txdelay1
    irx
    ldx
    rshr    ; restore DF
    irx
    ldx
    br txcloop ;9.5    loop back to send next bit
txcret: ghi r9        ;7
;    bitdelay __BAUDRATE,LCC1802CPUSPEED,16,2
    stxd
    ldi 19
    ldi 19
    ldi 19
    ldi 19
txdelay2:
    smi 1
    bnz txdelay2
    irx
    ldx
    req     ;11.5 stop bit
;    bitdelay __BAUDRATE,LCC1802CPUSPEED,4,2
    stxd
    ldi 22
    ldi 22
    ldi 22
    ldi 22
txdelay3:
    smi 1
    bnz txdelay3
    irx
    ldx
    return
;**********************************************************************
;rx_char
;Receive Byte via EF3 connected to RS232 receiver
;Receives 8 bits
;call via sep
;Returns with Byte received in D
;Destroys r9.0
;----------------------------------------------------------------------
    org 3200h
serin:
    ldi 8       ;start bit +7 bits from loop, last bit on returning
    plo r9
    ldi 0
rxcw:          ;wait for start bit
    b3 rxcw   ;each instr takes 9us, we need 104us = 11.5
            ;delay 1/2 bit time to center samples
    NOP     ;     Don't test for correct start bit
    NOP     ;     it will work. if there's too much
    NOP     ;     noise on the line, shorten the cable!
rxcloop:
;    bitdelay __BAUDRATE,LCC1802CPUSPEED,20,2
    stxd
    ldi 18
    ldi 18
    ldi 18
rxdelay1:
    smi 1
    bnz rxdelay1
    irx
    ldx
    bn3 $+6      ;11.5 sample rx input bit
    ori 80h     ;1
    br $+4      ;2
    phi r9     ;1
    phi r9     ;2
    shr     ;3
    phi r9     ;4
    DEC r9     ;5
    glo r9     ;6
    bz rxcret  ;7
    ghi r9     ;8
    br  rxcloop    ;9
rxcret: ghi r9    ;8
    ghi r9     ;9
;    bitdelay __BAUDRATE,LCC1802CPUSPEED,20,2
    stxd
    ldi 18
    ldi 18
    ldi 18
rxdelay2:
    smi 1
    bnz rxdelay2
    irx
    ldx
    bn3 $+4      ;11.5 sample last rx input bit
    ori 80h     ; for a 1 bit
    nop
    return

