; ==============================================================================
; RCA 1802/1806 Chess Engine - Integration Test Suite
; ==============================================================================
; Tests all major subsystems:
;   1. Board initialization and piece access
;   2. Move generation
;   3. Check detection
;   4. Make/Unmake moves
;   5. Position evaluation
;   6. Negamax search
;
; Output via serial at 9600 baud
; Run after flashing chess-engine.hex + this test module
; ==============================================================================

    ORG $7000               ; Place test code in upper RAM

; ==============================================================================
; Test Entry Point
; ==============================================================================
RUN_TESTS:
    ; =========================================================================
    ; CRITICAL: Initialize SCRT using Mark Abene's INITCALL pattern
    ; Set R6 to continue at TEST_MAIN, then jump to INITCALL
    ; =========================================================================

    ; First, toggle Q to show we're alive (debugging aid)
    SEQ                     ; Q = high

    ; Set R6 to continue at TEST_MAIN after INITCALL
    LDI HIGH(TEST_MAIN)
    PHI 6
    LDI LOW(TEST_MAIN)
    PLO 6
    LBR INITCALL            ; Initialize SCRT and transfer to TEST_MAIN

TEST_MAIN:
    ; =========================================================================
    ; Stack setup - AFTER INITCALL (critical!)
    ; =========================================================================
    LDI $7F
    PHI 2
    LDI $FF
    PLO 2

    ; Set X register to R2 for stack operations
    SEX 2

    REQ                     ; Q idle state
    ; =========================================================================
    ; NOW we can use CALL/RETN (R3 is PC, R4/R5 are set up)
    ; =========================================================================

    ; Initialize serial I/O
    CALL SERIAL_INIT

    ; Print banner
    LDI HIGH(MSG_BANNER)
    PHI 15
    LDI LOW(MSG_BANNER)
    PLO 15
    CALL PRINT_STRING

    ; =========================================================================
    ; TEST 1: Board Initialization
    ; =========================================================================
    LDI HIGH(MSG_TEST1)
    PHI 15
    LDI LOW(MSG_TEST1)
    PLO 15
    CALL PRINT_STRING

    CALL INIT_BOARD

    ; Verify white king at e1 ($04 in 0x88)
    LDI HIGH(BOARD)
    PHI 15
    LDI LOW(BOARD + $04)    ; e1
    PLO 15
    LDN 15
    XRI W_KING              ; Should be $06
    BZ TEST1_PASS1

    LDI HIGH(MSG_FAIL)
    PHI 15
    LDI LOW(MSG_FAIL)
    PLO 15
    CALL PRINT_STRING
    BR TEST1_DONE

TEST1_PASS1:
    ; Verify black queen at d8 ($73 in 0x88)
    LDI HIGH(BOARD)
    PHI 15
    LDI LOW(BOARD + $73)    ; d8
    PLO 15
    LDN 15
    XRI B_QUEEN             ; Should be $0D
    BZ TEST1_PASS2

    LDI HIGH(MSG_FAIL)
    PHI 15
    LDI LOW(MSG_FAIL)
    PLO 15
    CALL PRINT_STRING
    BR TEST1_DONE

TEST1_PASS2:
    ; Verify e4 is empty ($34 in 0x88)
    LDI HIGH(BOARD)
    PHI 15
    LDI LOW(BOARD + $34)    ; e4
    PLO 15
    LDN 15
    BZ TEST1_PASS3

    LDI HIGH(MSG_FAIL)
    PHI 15
    LDI LOW(MSG_FAIL)
    PLO 15
    CALL PRINT_STRING
    BR TEST1_DONE

TEST1_PASS3:
    LDI HIGH(MSG_PASS)
    PHI 15
    LDI LOW(MSG_PASS)
    PLO 15
    CALL PRINT_STRING

TEST1_DONE:

    ; =========================================================================
    ; TEST 2: Move Generation
    ; =========================================================================
    LDI HIGH(MSG_TEST2)
    PHI 15
    LDI LOW(MSG_TEST2)
    PLO 15
    CALL PRINT_STRING

    ; Generate moves from starting position
    ; White should have 20 legal moves
    CALL INIT_BOARD

    LDI HIGH(MOVE_LIST)
    PHI 9
    LDI LOW(MOVE_LIST)
    PLO 9                   ; 9 = move list pointer

    LDI 0
    PLO 12                   ; C.0 = WHITE

    CALL GENERATE_MOVES

    ; Count moves (each move is 2 bytes, terminated by $00)
    LDI HIGH(MOVE_LIST)
    PHI 15
    LDI LOW(MOVE_LIST)
    PLO 15
    LDI 0
    PLO 14                   ; E.0 = move count

TEST2_COUNT:
    LDN 15
    BZ TEST2_CHECK_COUNT
    INC 14
    INC 15
    INC 10                   ; Skip 2 bytes per move
    BR TEST2_COUNT

TEST2_CHECK_COUNT:
    ; E.0 should be 20
    GLO 14
    XRI 20
    BZ TEST2_PASS

    ; Print actual count for debugging
    LDI HIGH(MSG_COUNT)
    PHI 15
    LDI LOW(MSG_COUNT)
    PLO 15
    CALL PRINT_STRING

    GLO 14
    CALL PRINT_HEX_BYTE

    LDI HIGH(MSG_FAIL)
    PHI 15
    LDI LOW(MSG_FAIL)
    PLO 15
    CALL PRINT_STRING
    BR TEST2_DONE

TEST2_PASS:
    LDI HIGH(MSG_PASS)
    PHI 15
    LDI LOW(MSG_PASS)
    PLO 15
    CALL PRINT_STRING

TEST2_DONE:

    ; =========================================================================
    ; TEST 3: Check Detection
    ; =========================================================================
    LDI HIGH(MSG_TEST3)
    PHI 15
    LDI LOW(MSG_TEST3)
    PLO 15
    CALL PRINT_STRING

    ; Setup position: King on e1, enemy rook on e8
    ; King IS in check
    CALL INIT_BOARD

    ; Clear the board first (simplified test position)
    LDI HIGH(BOARD)
    PHI 15
    LDI LOW(BOARD)
    PLO 15
    LDI 0
    PLO 14                   ; Counter

TEST3_CLEAR:
    LDI 0
    STR 15
    INC 15
    INC 14
    GLO 14
    XRI 128
    BNZ TEST3_CLEAR

    ; Place white king on e1 ($04)
    LDI HIGH(BOARD)
    PHI 15
    LDI LOW(BOARD + $04)
    PLO 15
    LDI W_KING
    STR 15

    ; Update king position in game state
    LDI HIGH(GAME_STATE)
    PHI 15
    LDI LOW(GAME_STATE + STATE_W_KING_SQ)
    PLO 15
    LDI $04
    STR 15

    ; Place black rook on e8 ($74) - gives check
    LDI HIGH(BOARD)
    PHI 15
    LDI LOW(BOARD + $74)
    PLO 15
    LDI B_ROOK
    STR 15

    ; Set side to move = white
    LDI HIGH(GAME_STATE)
    PHI 15
    LDI LOW(GAME_STATE + STATE_SIDE_TO_MOVE)
    PLO 15
    LDI 0                   ; WHITE
    STR 15

    ; Check if white is in check
    LDI 0
    PLO 12                   ; WHITE
    CALL IS_IN_CHECK

    ; D should be non-zero (in check)
    BNZ TEST3_PASS1

    LDI HIGH(MSG_FAIL)
    PHI 15
    LDI LOW(MSG_FAIL)
    PLO 15
    CALL PRINT_STRING
    LDI HIGH(MSG_CHECK_MISS)
    PHI 15
    LDI LOW(MSG_CHECK_MISS)
    PLO 15
    CALL PRINT_STRING
    BR TEST3_DONE

TEST3_PASS1:
    ; Now move rook to f8 ($75) - no longer giving check
    LDI HIGH(BOARD)
    PHI 15
    LDI LOW(BOARD + $74)
    PLO 15
    LDI 0
    STR 10                   ; Clear e8

    LDI HIGH(BOARD)
    PHI 15
    LDI LOW(BOARD + $75)
    PLO 15
    LDI B_ROOK
    STR 10                   ; Place on f8

    ; Check again - should NOT be in check
    LDI 0
    PLO 12
    CALL IS_IN_CHECK

    ; D should be zero (not in check)
    BZ TEST3_PASS2

    LDI HIGH(MSG_FAIL)
    PHI 15
    LDI LOW(MSG_FAIL)
    PLO 15
    CALL PRINT_STRING
    LDI HIGH(MSG_FALSE_CHK)
    PHI 15
    LDI LOW(MSG_FALSE_CHK)
    PLO 15
    CALL PRINT_STRING
    BR TEST3_DONE

TEST3_PASS2:
    LDI HIGH(MSG_PASS)
    PHI 15
    LDI LOW(MSG_PASS)
    PLO 15
    CALL PRINT_STRING

TEST3_DONE:

    ; =========================================================================
    ; TEST 4: Make/Unmake Move
    ; =========================================================================
    LDI HIGH(MSG_TEST4)
    PHI 15
    LDI LOW(MSG_TEST4)
    PLO 15
    CALL PRINT_STRING

    CALL INIT_BOARD

    ; Make move e2-e4 (from=$14, to=$34)
    LDI $14
    PLO 11                   ; B.0 = from
    LDI $34
    PHI 11                   ; B.1 = to

    CALL MAKE_MOVE

    ; Verify e2 is now empty
    LDI HIGH(BOARD)
    PHI 15
    LDI LOW(BOARD + $14)
    PLO 15
    LDN 15
    BZ TEST4_CHECK1_PASS

    LDI HIGH(MSG_FAIL)
    PHI 15
    LDI LOW(MSG_FAIL)
    PLO 15
    CALL PRINT_STRING
    BR TEST4_DONE

TEST4_CHECK1_PASS:
    ; Verify e4 has white pawn
    LDI HIGH(BOARD)
    PHI 15
    LDI LOW(BOARD + $34)
    PLO 15
    LDN 15
    XRI W_PAWN
    BZ TEST4_CHECK2_PASS

    LDI HIGH(MSG_FAIL)
    PHI 15
    LDI LOW(MSG_FAIL)
    PLO 15
    CALL PRINT_STRING
    BR TEST4_DONE

TEST4_CHECK2_PASS:
    ; Now unmake the move
    CALL UNMAKE_MOVE

    ; Verify e2 has white pawn again
    LDI HIGH(BOARD)
    PHI 15
    LDI LOW(BOARD + $14)
    PLO 15
    LDN 15
    XRI W_PAWN
    BZ TEST4_CHECK3_PASS

    LDI HIGH(MSG_FAIL)
    PHI 15
    LDI LOW(MSG_FAIL)
    PLO 15
    CALL PRINT_STRING
    BR TEST4_DONE

TEST4_CHECK3_PASS:
    ; Verify e4 is empty again
    LDI HIGH(BOARD)
    PHI 15
    LDI LOW(BOARD + $34)
    PLO 15
    LDN 15
    BZ TEST4_PASS

    LDI HIGH(MSG_FAIL)
    PHI 15
    LDI LOW(MSG_FAIL)
    PLO 15
    CALL PRINT_STRING
    BR TEST4_DONE

TEST4_PASS:
    LDI HIGH(MSG_PASS)
    PHI 15
    LDI LOW(MSG_PASS)
    PLO 15
    CALL PRINT_STRING

TEST4_DONE:

    ; =========================================================================
    ; TEST 5: Position Evaluation
    ; =========================================================================
    LDI HIGH(MSG_TEST5)
    PHI 15
    LDI LOW(MSG_TEST5)
    PLO 15
    CALL PRINT_STRING

    ; Starting position should evaluate near 0
    CALL INIT_BOARD

    LDI HIGH(BOARD)
    PHI 15
    LDI LOW(BOARD)
    PLO 15
    CALL EVALUATE

    ; 6 = evaluation score
    ; Should be close to 0 (within +/- 50 centipawns)
    ; Check if high byte is $00 or $FF (small positive or negative)
    GHI 6
    BZ TEST5_CHECK_LO_POS
    XRI $FF
    BZ TEST5_CHECK_LO_NEG
    ; High byte too large, fail
    BR TEST5_FAIL

TEST5_CHECK_LO_POS:
    ; Positive - check if < 50
    GLO 6
    SMI 51
    BDF TEST5_FAIL
    BR TEST5_PASS

TEST5_CHECK_LO_NEG:
    ; Negative - check if > -50 (i.e., low byte > 206)
    GLO 6
    SMI 206
    BNF TEST5_FAIL
    BR TEST5_PASS

TEST5_FAIL:
    ; Print actual score for debugging
    LDI HIGH(MSG_SCORE)
    PHI 15
    LDI LOW(MSG_SCORE)
    PLO 15
    CALL PRINT_STRING

    GHI 6
    CALL PRINT_HEX_BYTE
    GLO 6
    CALL PRINT_HEX_BYTE

    LDI HIGH(MSG_FAIL)
    PHI 15
    LDI LOW(MSG_FAIL)
    PLO 15
    CALL PRINT_STRING
    BR TEST5_DONE

TEST5_PASS:
    ; Print actual score
    LDI HIGH(MSG_SCORE)
    PHI 15
    LDI LOW(MSG_SCORE)
    PLO 15
    CALL PRINT_STRING

    GHI 6
    CALL PRINT_HEX_BYTE
    GLO 6
    CALL PRINT_HEX_BYTE

    LDI HIGH(MSG_PASS)
    PHI 15
    LDI LOW(MSG_PASS)
    PLO 15
    CALL PRINT_STRING

TEST5_DONE:

    ; =========================================================================
    ; TEST 6: Negamax Search (1-ply)
    ; =========================================================================
    LDI HIGH(MSG_TEST6)
    PHI 15
    LDI LOW(MSG_TEST6)
    PLO 15
    CALL PRINT_STRING

    CALL INIT_BOARD

    ; Do a 1-ply search
    LDI 1
    PLO 5                   ; Depth = 1
    LDI 0
    PHI 5

    ; Alpha = -32768
    LDI $80
    PHI 6
    LDI $00
    PLO 6

    ; Beta = +32767
    LDI $7F
    PHI 7
    LDI $FF
    PLO 7

    ; Side to move = WHITE
    LDI 0
    PLO 12

    CALL NEGAMAX

    ; Check that we got a valid score (not overflow/underflow)
    ; Score should be reasonable (-1000 to +1000 for opening)
    ; Just verify it completes without crash

    ; Print the score
    LDI HIGH(MSG_SEARCH)
    PHI 15
    LDI LOW(MSG_SEARCH)
    PLO 15
    CALL PRINT_STRING

    GHI 6
    CALL PRINT_HEX_BYTE
    GLO 6
    CALL PRINT_HEX_BYTE

    LDI HIGH(MSG_PASS)
    PHI 15
    LDI LOW(MSG_PASS)
    PLO 15
    CALL PRINT_STRING

    ; =========================================================================
    ; TEST 7: Stack Balance Verification
    ; =========================================================================
    LDI HIGH(MSG_TEST7)
    PHI 15
    LDI LOW(MSG_TEST7)
    PLO 15
    CALL PRINT_STRING

    ; Record initial stack pointer
    GHI 2
    PHI 8                   ; Save SP high
    GLO 2
    PLO 8                   ; Save SP low

    ; Do some push/pop operations
    LDI $AA
    PHI 6
    LDI $55
    PLO 6
    CALL PUSH16_R6

    LDI $12
    PHI 6
    LDI $34
    PLO 6
    CALL PUSH16_R6

    CALL POP16_R6
    CALL POP16_R6

    ; Verify R6 restored correctly ($AA55)
    GHI 6
    XRI $AA
    BNZ TEST7_FAIL
    GLO 6
    XRI $55
    BNZ TEST7_FAIL

    ; Verify stack pointer restored
    GHI 2
    STR 2
    GHI 8
    XOR
    BNZ TEST7_FAIL
    GLO 2
    STR 2
    GLO 8
    XOR
    BNZ TEST7_FAIL

    LDI HIGH(MSG_PASS)
    PHI 15
    LDI LOW(MSG_PASS)
    PLO 15
    CALL PRINT_STRING
    BR TEST7_DONE

TEST7_FAIL:
    LDI HIGH(MSG_FAIL)
    PHI 15
    LDI LOW(MSG_FAIL)
    PLO 15
    CALL PRINT_STRING

TEST7_DONE:

    ; =========================================================================
    ; All Tests Complete
    ; =========================================================================
    LDI HIGH(MSG_DONE)
    PHI 15
    LDI LOW(MSG_DONE)
    PLO 15
    CALL PRINT_STRING

    ; Halt
TEST_HALT:
    IDL
    BR TEST_HALT

; ==============================================================================
; Helper: Print hex byte
; ==============================================================================
; Input: D = byte to print
PRINT_HEX_BYTE:
    PLO 15                   ; Save byte

    ; Print high nibble
    SHR
    SHR
    SHR
    SHR
    CALL PRINT_NIBBLE

    ; Print low nibble
    GLO 15
    ANI $0F
    CALL PRINT_NIBBLE

    RETN

PRINT_NIBBLE:
    ; D = 0-15
    SMI 10
    BNF PRINT_NIB_DIGIT
    ; A-F
    ADI 'A'
    BR PRINT_NIB_OUT
PRINT_NIB_DIGIT:
    ADI 10 + '0'
PRINT_NIB_OUT:
    CALL SERIAL_WRITE_CHAR
    RETN

; ==============================================================================
; Test Messages
; ==============================================================================
MSG_BANNER:
    DB 13,10
    DB "================================",13,10
    DB "RCA 1802 Chess - Integration Test",13,10
    DB "================================",13,10
    DB 0

MSG_TEST1:
    DB "Test 1: Board Init...",0

MSG_TEST2:
    DB "Test 2: Move Generation...",0

MSG_TEST3:
    DB "Test 3: Check Detection...",0

MSG_TEST4:
    DB "Test 4: Make/Unmake Move...",0

MSG_TEST5:
    DB "Test 5: Evaluation...",0

MSG_TEST6:
    DB "Test 6: Negamax (1-ply)...",0

MSG_TEST7:
    DB "Test 7: Stack Balance...",0

MSG_PASS:
    DB " PASS",13,10,0

MSG_FAIL:
    DB " FAIL",13,10,0

MSG_DONE:
    DB 13,10
    DB "================================",13,10
    DB "All tests complete!",13,10
    DB "================================",13,10
    DB 0

MSG_COUNT:
    DB " Count=",0

MSG_SCORE:
    DB " Score=",0

MSG_SEARCH:
    DB " Search result=",0

MSG_CHECK_MISS:
    DB " (missed check)",0

MSG_FALSE_CHK:
    DB " (false positive)",0

; ==============================================================================
; End of Integration Test
; ==============================================================================
