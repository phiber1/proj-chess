; ==============================================================================
; Debug Test 19: Two iterations of legal move loop
; Move 1: e1-d1 (should be legal)
; Move 2: e1-e2 (should be illegal - queen attacks e2)
; ==============================================================================

    ORG $0000
    LBR MAIN

#include "serial-io.asm"

INITCALL:
    LDI HIGH(RET)
    PHI 5
    LDI LOW(RET)
    PLO 5
    LDI HIGH(CALL)
    PHI 4
    LDI LOW(CALL)
    PLO 4
    SEP 5
    SEP 3

CALL:
    PLO 7
    GHI 6
    SEX 2
    STXD
    GLO 6
    STXD
    GHI 3
    PHI 6
    GLO 3
    PLO 6
    LDA 6
    PHI 3
    LDA 6
    PLO 3
    GLO 7
    BR CALL-1
    SEP 3

RET:
    PLO 7
    GHI 6
    PHI 3
    GLO 6
    PLO 3
    SEX 2
    IRX
    LDXA
    PLO 6
    LDX
    PHI 6
    GLO 7
    BR RET-1

; ==============================================================================
BOARD       EQU $5000
MOVE_LIST   EQU $5200
MOVE_PIECE  EQU $5090
CAPT_PIECE  EQU $5091
LOOP_COUNT  EQU $5092   ; Loop counter in memory (serial clobbers R15!)
LEGAL_COUNT EQU $5093   ; Legal count in memory
MOVE_PTR_LO EQU $5094   ; Move list pointer low
MOVE_PTR_HI EQU $5095   ; Move list pointer high
CHK_RESULT  EQU $5096   ; Check result storage

EMPTY       EQU $00
COLOR_MASK  EQU $08
WHITE       EQU $00
BLACK       EQU $08
W_KING      EQU $06
B_QUEEN     EQU $0D
B_KING      EQU $0E

SQ_E1       EQU $04
SQ_D1       EQU $03
SQ_E2       EQU $14
SQ_A8       EQU $70
SQ_E8       EQU $74

; ==============================================================================
MAIN:
    LDI HIGH(START)
    PHI 6
    LDI LOW(START)
    PLO 6
    LBR INITCALL

START:
    LDI $7F
    PHI 2
    LDI $FF
    PLO 2
    SEX 2
    REQ

    LDI HIGH(STR_BANNER)
    PHI 8
    LDI LOW(STR_BANNER)
    PLO 8
    CALL SERIAL_PRINT_STRING

    CALL CLEAR_BOARD

    ; Setup: Ke1, BKa8, BQe8
    LDI HIGH(BOARD)
    PHI 10
    LDI SQ_E1
    PLO 10
    LDI W_KING
    STR 10

    LDI SQ_A8
    PLO 10
    LDI B_KING
    STR 10

    LDI SQ_E8
    PLO 10
    LDI B_QUEEN
    STR 10

    ; Create 2 moves in MOVE_LIST
    ; Move 1: e1-d1 (04-03) - should be legal
    ; Move 2: e1-e2 (04-14) - should be illegal
    LDI HIGH(MOVE_LIST)
    PHI 10
    LDI LOW(MOVE_LIST)
    PLO 10

    LDI SQ_E1
    STR 10
    INC 10
    LDI SQ_D1
    STR 10
    INC 10

    LDI SQ_E1
    STR 10
    INC 10
    LDI SQ_E2
    STR 10

    ; Now run the loop with 2 moves
    CALL GEN_LEGAL_MOVES_DEBUG
    STXD                ; Save return value on stack!

    ; Print result
    LDI HIGH(STR_RESULT)
    PHI 8
    LDI LOW(STR_RESULT)
    PLO 8
    CALL SERIAL_PRINT_STRING

    IRX
    LDX                 ; Restore return value
    CALL SERIAL_PRINT_HEX
    CALL PRINT_CRLF

HALT:
    BR HALT

; ==============================================================================
; GEN_LEGAL_MOVES_DEBUG - Uses memory for all state (serial clobbers registers!)
; ==============================================================================
GEN_LEGAL_MOVES_DEBUG:
    ; Initialize state in memory
    LDI HIGH(LOOP_COUNT)
    PHI 10

    LDI LOW(LOOP_COUNT)
    PLO 10
    LDI 2
    STR 10              ; LOOP_COUNT = 2

    LDI LOW(LEGAL_COUNT)
    PLO 10
    LDI 0
    STR 10              ; LEGAL_COUNT = 0

    LDI LOW(MOVE_PTR_LO)
    PLO 10
    LDI LOW(MOVE_LIST)
    STR 10              ; MOVE_PTR_LO

    LDI LOW(MOVE_PTR_HI)
    PLO 10
    LDI HIGH(MOVE_LIST)
    STR 10              ; MOVE_PTR_HI

GLM_LOOP:
    ; Check loop count
    LDI HIGH(LOOP_COUNT)
    PHI 10
    LDI LOW(LOOP_COUNT)
    PLO 10
    LDN 10
    LBZ GLM_DONE

    ; Print iteration number
    LDI HIGH(STR_ITER)
    PHI 8
    LDI LOW(STR_ITER)
    PLO 8
    CALL SERIAL_PRINT_STRING
    LDI HIGH(LOOP_COUNT)
    PHI 10
    LDI LOW(LOOP_COUNT)
    PLO 10
    LDN 10
    CALL SERIAL_PRINT_HEX
    CALL PRINT_CRLF

    ; Load move pointer into R10
    LDI HIGH(MOVE_PTR_HI)
    PHI 9
    LDI LOW(MOVE_PTR_HI)
    PLO 9
    LDN 9
    PHI 10
    DEC 9
    LDN 9
    PLO 10

    ; Read move into R11
    LDA 10
    PLO 11              ; from
    LDA 10
    PHI 11              ; to

    ; Save updated move pointer
    GLO 10
    STR 9
    INC 9
    GHI 10
    STR 9

    ; Make move
    CALL MAKE_MOVE_MEM

    ; Check if in check
    LDI WHITE
    PLO 12
    CALL IS_IN_CHECK
    PLO 13              ; Save result in R13 temporarily

    ; Save check result to memory
    LDI HIGH(CHK_RESULT)
    PHI 10
    LDI LOW(CHK_RESULT)
    PLO 10
    GLO 13              ; Get result back from R13
    STR 10

    ; Print check result
    LDI HIGH(STR_CHK)
    PHI 8
    LDI LOW(STR_CHK)
    PLO 8
    CALL SERIAL_PRINT_STRING
    LDI HIGH(CHK_RESULT)
    PHI 10
    LDI LOW(CHK_RESULT)
    PLO 10
    LDN 10
    CALL SERIAL_PRINT_HEX
    CALL PRINT_CRLF

    ; Reload move pointer (go back 2 to re-read move for unmake)
    LDI HIGH(MOVE_PTR_HI)
    PHI 9
    LDI LOW(MOVE_PTR_HI)
    PLO 9
    LDN 9
    PHI 10
    DEC 9
    LDN 9
    PLO 10
    DEC 10
    DEC 10

    ; Re-read move into R11
    LDA 10
    PLO 11
    LDA 10
    PHI 11

    ; Unmake move
    CALL UNMAKE_MOVE_MEM

    ; Check result and update legal count if 0
    LDI HIGH(CHK_RESULT)
    PHI 10
    LDI LOW(CHK_RESULT)
    PLO 10
    LDN 10
    LBNZ GLM_NEXT

    ; Legal move - print "L" and increment count
    LDI 'L'
    CALL SERIAL_WRITE_CHAR

    LDI HIGH(LEGAL_COUNT)
    PHI 10
    LDI LOW(LEGAL_COUNT)
    PLO 10
    LDN 10
    ADI 1
    STR 10

    ; Verify: print the new count
    LDI HIGH(LEGAL_COUNT)
    PHI 10
    LDI LOW(LEGAL_COUNT)
    PLO 10
    LDN 10
    CALL SERIAL_PRINT_HEX
    CALL PRINT_CRLF

GLM_NEXT:
    ; Decrement loop count (must set BOTH bytes - serial may clobber R10.1!)
    LDI HIGH(LOOP_COUNT)
    PHI 10
    LDI LOW(LOOP_COUNT)
    PLO 10
    LDN 10
    SMI 1
    STR 10
    LBR GLM_LOOP

GLM_DONE:
    ; Debug: print LEGAL_COUNT before returning
    LDI HIGH(STR_FINAL)
    PHI 8
    LDI LOW(STR_FINAL)
    PLO 8
    CALL SERIAL_PRINT_STRING
    LDI HIGH(LEGAL_COUNT)
    PHI 10
    LDI LOW(LEGAL_COUNT)
    PLO 10
    LDN 10
    CALL SERIAL_PRINT_HEX
    CALL PRINT_CRLF

    ; Return legal count
    LDI HIGH(LEGAL_COUNT)
    PHI 10
    LDI LOW(LEGAL_COUNT)
    PLO 10
    LDN 10
    RETN

STR_FINAL:
    DB "Final LC=", 0

; ==============================================================================
PRINT_CRLF:
    LDI HIGH(STR_CRLF)
    PHI 8
    LDI LOW(STR_CRLF)
    PLO 8
    CALL SERIAL_PRINT_STRING
    RETN

CLEAR_BOARD:
    LDI HIGH(BOARD)
    PHI 10
    LDI LOW(BOARD)
    PLO 10
    LDI 128
    PLO 13
CB_LOOP:
    LDI EMPTY
    STR 10
    INC 10
    DEC 13
    GLO 13
    LBNZ CB_LOOP
    RETN

MAKE_MOVE_MEM:
    LDI HIGH(BOARD)
    PHI 8
    LDI HIGH(MOVE_PIECE)
    PHI 10
    LDI LOW(MOVE_PIECE)
    PLO 10
    GLO 11
    PLO 8
    LDN 8
    STR 10
    GHI 11
    PLO 8
    LDN 8
    INC 10
    STR 10
    GHI 11
    PLO 8
    DEC 10
    LDN 10
    STR 8
    GLO 11
    PLO 8
    LDI EMPTY
    STR 8
    RETN

UNMAKE_MOVE_MEM:
    LDI HIGH(BOARD)
    PHI 8
    LDI HIGH(MOVE_PIECE)
    PHI 10
    LDI LOW(MOVE_PIECE)
    PLO 10
    GLO 11
    PLO 8
    LDN 10
    STR 8
    GHI 11
    PLO 8
    INC 10
    LDN 10
    STR 8
    RETN

IS_IN_CHECK:
    LDI HIGH(BOARD)
    PHI 10
    LDI LOW(BOARD)
    PLO 10
    LDI 6
    STR 2
    GLO 12
    ADD
    PLO 14
    LDI 0
    PLO 11

IIC_FIND_KING:
    GLO 11
    ANI $88
    LBNZ IIC_FIND_NEXT
    LDN 10
    STR 2
    GLO 14
    SM
    LBZ IIC_FOUND_KING

IIC_FIND_NEXT:
    INC 10
    INC 11
    GLO 11
    ANI $80
    LBZ IIC_FIND_KING
    LDI 0
    RETN

IIC_FOUND_KING:
    GLO 12
    XRI BLACK
    PLO 13
    LDI HIGH(ROOK_DIRS)
    PHI 8
    LDI LOW(ROOK_DIRS)
    PLO 8
    LDI 4
    PLO 14
    LDI 4
    STR 2
    GLO 13
    ADD
    PHI 14

IIC_ORTH_DIR:
    LDN 8
    PHI 13
    GLO 11
    PLO 7

IIC_ORTH_RAY:
    GLO 7
    STR 2
    GHI 13
    ADD
    PLO 7
    ANI $88
    LBNZ IIC_ORTH_NEXT
    LDI HIGH(BOARD)
    PHI 10
    GLO 7
    PLO 10
    LDN 10
    LBZ IIC_ORTH_RAY
    PLO 10
    STR 2
    GHI 14
    SM
    LBZ IIC_IN_CHECK
    GHI 14
    ADI 1
    STR 2
    GLO 10
    SM
    LBZ IIC_IN_CHECK
    LBR IIC_ORTH_NEXT

IIC_ORTH_NEXT:
    INC 8
    DEC 14
    GLO 14
    LBNZ IIC_ORTH_DIR
    LDI 0
    RETN

IIC_IN_CHECK:
    LDI 1
    RETN

ROOK_DIRS:
    DB $F0, $10, $FF, $01

; ==============================================================================
STR_BANNER:
    DB "Debug19: 2-iteration test", 0DH, 0AH, 0

STR_ITER:
    DB "Iter ", 0

STR_CHK:
    DB "Chk=", 0

STR_RESULT:
    DB "Legal=", 0

STR_CRLF:
    DB 0DH, 0AH, 0

    END
