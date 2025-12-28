		ORG		$0000
START	LDI		02H
		PLO		14
		LDI		HIGH(STRING)	; STRING TO OUTPUT
		PHI		8
		LDI		LOW(STRING)
		PLO		8
NEXT	LDA		8		; GET FIRST CHAR TO OUTPUT
		BZ		START	; LOOP FOREVER
		PLO		11
;-----------------------
;9600 BAUD RATE ONLY OUTPUT ROUTINE - NORMAL LOGIC

;15.0 = BIT COUNT
;       THE FIRST BIT IS BEING PROCESSED WHILE THE START BIT
;       IS BEING SENT OUT, AS SOON AS THE START BIT IS DONE
;       IT OUTPUTS THE FIRST BIT.

;11.0 = CHARACTER TO OUTPUT


;14.0   DELAY COUNTER = 1 AT 9600 BAUD
;NOTE:  ON ENTRY 14.0 MUST = 2

;SEND START BIT
;ENTRY POINT FOR THE OUTPUT ROUTINE
B96OUT  LDI     08H
        PLO     15

        GLO     11      ; LOAD D WITH 11.0
        STR     2      ; PUSH 11,0 ONTO THE STACK
        DEC     2
        GLO     13      ; LOAD D WITH 13.0
        STR     2      ; PUSH 13.0 ONTO THE STACK
        DEC     2

        DEC     14      ;SET DELAY COUNTER = 1

STBIT   SEQ             ;1      START BIT
        NOP             ;2.5
        NOP             ;4
        GLO     11      ;5
        SHRC            ;6      DF=1ST BIT OUT
        PLO     11      ;7
        PLO     11      ;8
        NOP             ;9.5 INSTUCTIONS SINCE START BIT

                        ;DETERMINE FIRST BIT AND OUTPUT IT
        BDF     STBIT1  ;DF = 1, IF BIT IS LOW THEN JUMP TO OUTPUT4
        BR      QLO             ;JUMP AT 11.5 INSTRUCTION TIME, Q=OFF

STBIT1  BR      QHI             ;JUMP AT 11.5 INSTRUCTION TIME, Q=ON



QLO1    DEC     15
        GLO     15
        BZ      DONE96  ;AT 8.5 INSTRUCTIONS EITHER DONE OR REQ

;DELAY
        GLO     14
LDELAY  SMI     01H
        BZ      QLO     ;IF DELAY IS DONE THEN TURN Q OFF
                        ;ADJUST DELAY FOR LOWER BAUD RATES
                        ;WASTE 9.5 INSTRUCTION TIMES
        NOP             ;1.5
        NOP             ;3
        NOP             ;4.5
        NOP             ;6
        NOP             ;7.5
        SEX     2      ;8.5
        BR      LDELAY  ;AT 9.5 INSTRUCTION TIMES JUMP TO LDELAY

QLO     SEQ             ;Q OFF
        GLO     11
        SHRC            ;PUT NEXT BIT IN DF
        PLO     11
        LBNF    QLO1    ;5.5 TURN Q OFF AFTER 6 MORE INSTRUCTION TIMES

QHI1    DEC     15
        GLO     15
        BZ      DONE96  ;AT 8.5 INSTRUCTIONS EITHER DONE OR SEQ

;DELAY
        GLO     14
HDELAY  SMI     01H
        BZ      QHI     ;IF DELAY IS DONE THEN TURN Q ON
                        ;ADJUST DELAY FOR LOWER BAUD RATES
                        ;WASTE 9.5 INSTRUCTION TIMES
        NOP             ;1.5
        NOP             ;3
        NOP             ;4.5
        NOP             ;6
        NOP             ;7.5
        SEX     2      ;8.5
        BR      HDELAY  ;AT 9.5 INSTRUCTION TIMES JUMP TO HDELAY

                        ;BIT IS LO 11.5 INSTRUCTIONS TURN Q ON
QHI     REQ             ;Q ON
        GLO     11
        SHRC            ;PUT NEXT BIT IN DF
        PLO     11
        LBDF    QHI1    ;5.5 TURN Q ON AFTER 6 MORE INSTRUCTION TIMES

        DEC     15
        GLO     15
        BZ      DONE96  ;AT 8.5 INSTRUCTIONS EITHER DONE OR REQ

;DELAY
        GLO     14
XDELAY  SMI     01H
        BZ      QLO     ;IF DELAY IS DONE THEN TURN Q OFF

                        ;ADJUST DELAY FOR LOWER BAUD RATES
                        ;WASTE 9.5 INSTRUCTION TIMES
        NOP             ;1.5
        NOP             ;3
        NOP             ;4.5
        NOP             ;6
        NOP             ;7.5
        SEX     2      ;8.5
        BR      XDELAY  ;AT 9.5 INSTRUCTION TIMES JUMP TO XDELAY

                        ;FINISH LAST BIT TIMING
DONE96  GLO     14
        GLO     14
        GLO     14

DNE961  REQ             ;1 SEND STOP BIT
        NOP             ;2.5
        NOP             ;4
        NOP             ;5.5
        NOP             ;7
        NOP             ;8.5
        SEX     2      ;9.5
        SMI     01H     ;10.5
        BNZ     DNE961  ;11.5
                        ;NOTE - STOP BIT IS 2 INSTRUCTION TIMES LONGER THEN NEEDED
                        ;       PLUS THE RETURN TO CALLER TIME

        INC     2      ; INCREMENT THE STACK POINTER
        LDN     2      ; LOAD D FROM THE STACK , AND THE STACK IS INCREMENTED
        PLO     13      ; STORE IT IN 13.0 , 13 RESTORED
        INC     2      ; INCREMENT THE STACK POINTER
        LDN     2      ; LOAD D FROM THE STACK , AND THE STACK IS INCREMENTED
        PLO     11      ; STORE IT IN 11.0 , 11 RESTORED


        LDI     02H
        PLO     14      ;RESTORE 14.0 FOR 9600 BAUD INPUT ROUTINE

		BR		NEXT	; LOOP TO GET NEXT CHAR
        ;SEP     5      ;DONE WITH STOP BIT - RETURN TO CALLER
STRING	DB "Hello, world!", 0DH, 0AH, 0

