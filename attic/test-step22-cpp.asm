; ==============================================================================
; Step 22: Depth-3 Search Test
; Tests deeper search with alpha-beta cutoffs
; ==============================================================================
;
; Same position as step-21 but at depth 3
; Removed per-move printing for faster execution
;
; Test position: WKe1 WQd1 WPa2 vs BKe8 BPa7
;
; ==============================================================================
    ORG $0000
    LBR MAIN
; ==============================================================================
; SERIAL I/O MODULE - RCA 1802 Membership Card
; Chuck Yakym's 9600 baud routines + helper functions
; For use with Mark Abene's SCRT implementation
; 1.75 MHz clock, 9600 baud, inverted EF3 logic
; ==============================================================================
;
; ROUTINES:
; SERIAL_READ_CHAR - Read character, returns in D
; SERIAL_WRITE_CHAR - Write character from D
; SERIAL_PRINT_STRING - Print null-terminated string, R8 = pointer
; SERIAL_PRINT_HEX - Print byte as 2 hex digits, D = byte
; SERIAL_READ_LINE - Read line with echo, R8 = buffer, R9.0 = max length
;
; REGISTER USAGE:
; R8 - String/buffer pointer (PRINT_STRING, READ_LINE)
; R9 - R9.0 = max length, R9.1 = count (READ_LINE); R9.0 = temp (PRINT_HEX)
; R10 - Temp storage (READ_LINE)
; R11 - Serial shift register
; R13 - Saved/restored by output routine
; R14 - Baud rate delay counter (must be 2, hardcoded)
; R15 - Bit counter (output routine)
;
; REQUIRES:
; - SCRT initialized (R4 = CALL, R5 = RET)
; - Stack pointer set (R2)
; - Q set to idle state (REQ) before first use
;
; ==============================================================================
; ==============================================================================
; SERIAL_READ_LINE - Read line with echo into buffer
; Input: R8 = pointer to buffer, R9.0 = max length (including null)
; Output: Buffer filled with null-terminated string
; Handles: Echo, Backspace (08H or 7FH), Enter (0DH)
; ==============================================================================
SERIAL_READ_LINE:
    GLO 9 ; Get max length
    SMI 1 ; Reserve space for null terminator
    PLO 9 ; R9.0 = max chars we can store
    LDI 0
    PHI 9 ; R9.1 = current count
SRL_READ_NEXT:
    SEP 4
    DW SERIAL_READ_CHAR ; Read character into D
    ; Check for Enter (CR = 0DH)
    SMI 0DH
    BZ SRL_DONE
    ; Check for Backspace (08H)
    ADI 0DH ; Restore D
    SMI 08H
    BZ SRL_BACKSPACE
    ; Check for DEL (7FH) - also treat as backspace
    ADI 08H ; Restore D
    SMI 7FH
    BZ SRL_BACKSPACE
    ; Regular character - check if buffer full
    ADI 7FH ; Restore D
    PLO 10 ; Save char in R10.0 temporarily
    GHI 9 ; Get current count
    STR 2 ; Store on stack
    GLO 9 ; Get max
    SM ; max - count
    BZ SRL_READ_NEXT ; Buffer full, ignore character
    ; Store character and echo it
    GLO 10 ; Get character back
    STR 8 ; Store in buffer
    INC 8 ; Advance buffer pointer
    GHI 9 ; Increment count
    ADI 1
    PHI 9
    GLO 10 ; Echo the character
    SEP 4
    DW SERIAL_WRITE_CHAR
    BR SRL_READ_NEXT
SRL_BACKSPACE:
    ; Check if anything to delete
    GHI 9 ; Get current count
    BZ SRL_READ_NEXT ; Nothing to delete
    ; Decrement count and pointer
    SMI 1
    PHI 9
    DEC 8
    ; Echo: backspace, space, backspace (erase character on terminal)
    LDI 08H
    SEP 4
    DW SERIAL_WRITE_CHAR
    LDI ' '
    SEP 4
    DW SERIAL_WRITE_CHAR
    LDI 08H
    SEP 4
    DW SERIAL_WRITE_CHAR
    BR SRL_READ_NEXT
SRL_DONE:
    ; Null-terminate the buffer
    LDI 0
    STR 8
    ; Echo CR+LF
    LDI 0DH
    SEP 4
    DW SERIAL_WRITE_CHAR
    LDI 0AH
    SEP 4
    DW SERIAL_WRITE_CHAR
    SEP 5 ; Return
; ==============================================================================
; SERIAL_PRINT_HEX - Print byte as two hex digits
; Input: D = byte to print
; Uses: R9.0 (saved byte)
; ==============================================================================
SERIAL_PRINT_HEX:
    PLO 9 ; Save byte in R9.0
    ; Print high nibble
    SHR
    SHR
    SHR
    SHR
    SEP 4
    DW SERIAL_PRINT_NIBBLE
    ; Print low nibble
    GLO 9 ; Get original byte
    ANI 0FH ; Mask low nibble
    SEP 4
    DW SERIAL_PRINT_NIBBLE
    SEP 5 ; Return
; ==============================================================================
; SERIAL_PRINT_NIBBLE - Print single hex digit (0-F)
; Input: D = value 0-15
; ==============================================================================
SERIAL_PRINT_NIBBLE:
    SMI 10 ; Is it >= 10?
    BDF SPN_AF ; Yes, it's A-F
    ADI 10+'0' ; Restore and add '0'
    SEP 4
    DW SERIAL_WRITE_CHAR
    SEP 5
SPN_AF:
    ADI 'A' ; Add 'A' (already subtracted 10)
    SEP 4
    DW SERIAL_WRITE_CHAR
    SEP 5
; ==============================================================================
; SERIAL_PRINT_STRING - Print null-terminated string
; Input: R8 = pointer to null-terminated string
; ==============================================================================
SERIAL_PRINT_STRING:
    LDA 8 ; Load byte, increment pointer
    BZ SPS_DONE ; Null terminator - done
    SEP 4
    DW SERIAL_WRITE_CHAR
    BR SERIAL_PRINT_STRING
SPS_DONE:
    SEP 5 ; Return
; ==============================================================================
; SERIAL_READ_CHAR - Chuck's B96IN (Inverted EF3 logic)
; Returns received character in D
; R11.0 = shift register, R14.0 = delay counter
; ==============================================================================
SERIAL_READ_CHAR:
B96IN:
    B3 B96IN ; WAIT FOR STOP BIT (EF3 HIGH = idle)
    LDI 0FFH ; Initialize input to FFh
    PLO 11
    GLO 14 ; Get delay count
B96IN1:
    BN3 B96IN1 ; WAIT FOR START BIT (EF3 LOW)
    SHR ; Half bit delay
    SKP
B96IN2:
    GLO 14 ; Get delay count
B96IN3:
    SMI 01H
    BNZ B96IN3 ; Delay loop
    B3 B96IN4 ; Sample bit
    SKP ; EF3 HIGH = 0, leave DF=0
B96IN4:
    SHR ; EF3 LOW = 1, set DF=1
    GLO 11
    SHRC ; Shift bit into byte
    PLO 11
    LBDF B96IN2 ; Loop until start bit shifts out
    GLO 14 ; Final delay
B96IN5:
    SMI 1
    BNZ B96IN5
    GLO 11 ; Return character in D
    GLO 11
    SEP 5 ; Return
; ==============================================================================
; SERIAL_WRITE_CHAR - Chuck's B96OUT (Inverted Q logic)
; Input: D = character to send
; R11.0 = shift register, R14.0 = delay, R15.0 = bit counter
; ==============================================================================
SERIAL_WRITE_CHAR:
    PLO 11 ; Save character
B96OUT:
    LDI 02H
    PLO 14 ; R14.0 = 2 for 9600 baud
    LDI 08H
    PLO 15 ; 8 bits
    GLO 11
    STR 2
    DEC 2
    GLO 13
    STR 2
    DEC 2
    DEC 14 ; R14.0 = 1 for delay loops
STBIT:
    SEQ ; START BIT
    NOP
    NOP
    GLO 11
    SHRC
    PLO 11
    PLO 11
    NOP
    BDF STBIT1
    BR QLO
STBIT1:
    BR QHI
QLO1:
    DEC 15
    GLO 15
    BZ DONE96
    GLO 14
LDELAY:
    SMI 01H
    BZ QLO
    NOP
    NOP
    NOP
    NOP
    NOP
    SEX 2
    BR LDELAY
QLO:
    SEQ ; Output 0
    GLO 11
    SHRC
    PLO 11
    LBNF QLO1
QHI1:
    DEC 15
    GLO 15
    BZ DONE96
    GLO 14
HDELAY:
    SMI 01H
    BZ QHI
    NOP
    NOP
    NOP
    NOP
    NOP
    SEX 2
    BR HDELAY
QHI:
    REQ ; Output 1
    GLO 11
    SHRC
    PLO 11
    LBDF QHI1
    DEC 15
    GLO 15
    BZ DONE96
    GLO 14
XDELAY:
    SMI 01H
    BZ QLO
    NOP
    NOP
    NOP
    NOP
    NOP
    SEX 2
    BR XDELAY
DONE96:
    GLO 14
    GLO 14
    GLO 14
DNE961:
    REQ ; STOP BIT
    NOP
    NOP
    NOP
    NOP
    NOP
    SEX 2
    SMI 01H
    BNZ DNE961
    INC 2
    LDN 2
    PLO 13
    INC 2
    LDN 2
    PLO 11
    LDI 02H
    PLO 14 ; Restore for next call
    SEP 5 ; Return
; ==============================================================================
; END OF SERIAL I/O MODULE
; ==============================================================================
; SCRT Implementation
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
; Constants
; ==============================================================================
BOARD EQU $5000
GAME_STATE EQU $5080
GS_CASTLE EQU 0
GS_EP EQU 1
SCORE_LO EQU $5088
SCORE_HI EQU $5089
; Ply-indexed storage (4 plies max)
PLY_BASE EQU $5090
PLY_SIZE EQU $10
; Offsets within each ply's storage
PLY_MOVE_PIECE EQU 0
PLY_CAPT_PIECE EQU 1
PLY_MOVE_FROM EQU 2
PLY_MOVE_TO EQU 3
PLY_ALPHA_LO EQU 4
PLY_ALPHA_HI EQU 5
PLY_BETA_LO EQU 6
PLY_BETA_HI EQU 7
PLY_PTR_LO EQU 8
PLY_PTR_HI EQU 9
PLY_BEST_LO EQU 10
PLY_BEST_HI EQU 11
; Search state
SEARCH_DEPTH EQU $50D0
CURRENT_PLY EQU $50D1
BEST_MOVE_FROM EQU $50D2
BEST_MOVE_TO EQU $50D3
BEST_SCORE_LO EQU $50D4
BEST_SCORE_HI EQU $50D5
NODE_COUNT_LO EQU $50D6
NODE_COUNT_HI EQU $50D7
CUTOFF_COUNT_LO EQU $50D8
CUTOFF_COUNT_HI EQU $50DA
TEMP_PLY EQU $50D9 ; Save ply during movegen
SIDE_TO_MOVE EQU $50DB ; 0=White, 8=Black
; Per-ply move lists (32 bytes each = max 15 moves + terminator)
MOVELIST_PLY0 EQU $5100
MOVELIST_PLY1 EQU $5120
MOVELIST_PLY2 EQU $5140
MOVELIST_PLY3 EQU $5160
; Piece codes
EMPTY EQU $00
WHITE EQU $00
BLACK EQU $08
COLOR_MASK EQU $08
PIECE_MASK EQU $07
W_PAWN EQU $01
W_KNIGHT EQU $02
W_BISHOP EQU $03
W_ROOK EQU $04
W_QUEEN EQU $05
W_KING EQU $06
B_PAWN EQU $09
B_KNIGHT EQU $0A
B_BISHOP EQU $0B
B_ROOK EQU $0C
B_QUEEN EQU $0D
B_KING EQU $0E
; Squares
SQ_A1 EQU $00
SQ_B1 EQU $01
SQ_C1 EQU $02
SQ_D1 EQU $03
SQ_E1 EQU $04
SQ_F1 EQU $05
SQ_G1 EQU $06
SQ_H1 EQU $07
SQ_A2 EQU $10
SQ_E8 EQU $74
SQ_A7 EQU $60
SQ_H8 EQU $77
; Castling rights
CASTLE_WK EQU $01
CASTLE_WQ EQU $02
CASTLE_BK EQU $04
CASTLE_BQ EQU $08
SQ_D8 EQU $73
SQ_C8 EQU $72
SQ_B8 EQU $71
SQ_F8 EQU $75
SQ_G8 EQU $76
; Direction offsets
DIR_N EQU $F0
DIR_S EQU $10
DIR_E EQU $01
DIR_W EQU $FF
DIR_NE EQU $F1
DIR_NW EQU $EF
DIR_SE EQU $11
DIR_SW EQU $0F
; Infinity
NEG_INF_LO EQU $01
NEG_INF_HI EQU $80
POS_INF_LO EQU $FF
POS_INF_HI EQU $7F
; ==============================================================================
; Main
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
    ; Print banner
    LDI HIGH(STR_BANNER)
    PHI 8
    LDI LOW(STR_BANNER)
    PLO 8
    CALL SERIAL_PRINT_STRING
    ; Set up position
    CALL CLEAR_BOARD
    CALL SETUP_POSITION
    CALL INIT_GAME_STATE
    ; Print position
    LDI HIGH(STR_POS)
    PHI 8
    LDI LOW(STR_POS)
    PLO 8
    CALL SERIAL_PRINT_STRING
    ; Initialize counters
    LDI HIGH(NODE_COUNT_LO)
    PHI 10
    LDI LOW(NODE_COUNT_LO)
    PLO 10
    LDI 0
    STR 10
    INC 10
    STR 10 ; NODE_COUNT_HI = 0
    INC 10
    STR 10 ; CUTOFF_COUNT_LO = 0
    INC 10
    INC 10 ; Skip TEMP_PLY
    STR 10 ; CUTOFF_COUNT_HI = 0
    ; Set search depth to 2 (sanity check)
    LDI HIGH(SEARCH_DEPTH)
    PHI 10
    LDI LOW(SEARCH_DEPTH)
    PLO 10
    LDI 2
    STR 10
    ; Set side to move = WHITE
    LDI HIGH(SIDE_TO_MOVE)
    PHI 10
    LDI LOW(SIDE_TO_MOVE)
    PLO 10
    LDI WHITE
    STR 10
    ; Print search info
    LDI HIGH(STR_SEARCH)
    PHI 8
    LDI LOW(STR_SEARCH)
    PLO 8
    CALL SERIAL_PRINT_STRING
    ; Initialize current ply to 0
    LDI HIGH(CURRENT_PLY)
    PHI 10
    LDI LOW(CURRENT_PLY)
    PLO 10
    LDI 0
    STR 10
    ; Call search
    CALL NEGAMAX_ROOT
    ; Print result
    LDI HIGH(STR_BEST)
    PHI 8
    LDI LOW(STR_BEST)
    PLO 8
    CALL SERIAL_PRINT_STRING
    LDI HIGH(BEST_MOVE_FROM)
    PHI 10
    LDI LOW(BEST_MOVE_FROM)
    PLO 10
    LDN 10
    CALL SERIAL_PRINT_HEX
    LDI '-'
    CALL SERIAL_WRITE_CHAR
    LDI HIGH(BEST_MOVE_TO)
    PHI 10
    LDI LOW(BEST_MOVE_TO)
    PLO 10
    LDN 10
    CALL SERIAL_PRINT_HEX
    LDI ' '
    CALL SERIAL_WRITE_CHAR
    LDI HIGH(BEST_SCORE_HI)
    PHI 10
    LDI LOW(BEST_SCORE_HI)
    PLO 10
    LDN 10
    CALL SERIAL_PRINT_HEX
    LDI HIGH(BEST_SCORE_LO)
    PHI 10
    LDI LOW(BEST_SCORE_LO)
    PLO 10
    LDN 10
    CALL SERIAL_PRINT_HEX
    CALL PRINT_CRLF
    ; Print nodes
    LDI HIGH(STR_NODES)
    PHI 8
    LDI LOW(STR_NODES)
    PLO 8
    CALL SERIAL_PRINT_STRING
    LDI HIGH(NODE_COUNT_HI)
    PHI 10
    LDI LOW(NODE_COUNT_HI)
    PLO 10
    LDN 10
    CALL SERIAL_PRINT_HEX
    LDI HIGH(NODE_COUNT_LO)
    PHI 10
    LDI LOW(NODE_COUNT_LO)
    PLO 10
    LDN 10
    CALL SERIAL_PRINT_HEX
    CALL PRINT_CRLF
    ; Print cutoffs
    LDI HIGH(STR_CUTOFFS)
    PHI 8
    LDI LOW(STR_CUTOFFS)
    PLO 8
    CALL SERIAL_PRINT_STRING
    LDI HIGH(CUTOFF_COUNT_HI)
    PHI 10
    LDI LOW(CUTOFF_COUNT_HI)
    PLO 10
    LDN 10
    CALL SERIAL_PRINT_HEX
    LDI HIGH(CUTOFF_COUNT_LO)
    PHI 10
    LDI LOW(CUTOFF_COUNT_LO)
    PLO 10
    LDN 10
    CALL SERIAL_PRINT_HEX
    CALL PRINT_CRLF
    ; Done
    LDI HIGH(STR_DONE)
    PHI 8
    LDI LOW(STR_DONE)
    PLO 8
    CALL SERIAL_PRINT_STRING
HALT:
    BR HALT
; ==============================================================================
; NEGAMAX_ROOT - Root-level search
; Generates moves using full movegen, iterates through them
; ==============================================================================
NEGAMAX_ROOT:
    SEX 2
    ; Initialize best score to -infinity
    LDI HIGH(BEST_SCORE_LO)
    PHI 10
    LDI LOW(BEST_SCORE_LO)
    PLO 10
    LDI NEG_INF_LO
    STR 10
    INC 10
    LDI NEG_INF_HI
    STR 10
    ; Set up ply 0 alpha/beta
    LDI HIGH(PLY_BASE)
    PHI 10
    LDI LOW(PLY_BASE + PLY_ALPHA_LO)
    PLO 10
    LDI NEG_INF_LO
    STR 10
    INC 10
    LDI NEG_INF_HI
    STR 10
    INC 10
    LDI POS_INF_LO
    STR 10
    INC 10
    LDI POS_INF_HI
    STR 10
    ; Generate moves for ply 0 (WHITE)
    LDI 0
    PLO 12 ; ply = 0
    CALL GENERATE_MOVES_FOR_PLY
    ; Set move pointer for ply 0
    LDI HIGH(PLY_BASE)
    PHI 10
    LDI LOW(PLY_BASE + PLY_PTR_LO)
    PLO 10
    LDI LOW(MOVELIST_PLY0)
    STR 10
    INC 10
    LDI HIGH(MOVELIST_PLY0)
    STR 10
NR_LOOP:
    ; Get move list pointer
    LDI HIGH(PLY_BASE)
    PHI 10
    LDI LOW(PLY_BASE + PLY_PTR_LO)
    PLO 10
    LDN 10
    PLO 11
    INC 10
    LDN 10
    PHI 11
    ; Check end of moves
    LDN 11
    XRI $FF
    LBZ NR_DONE
    ; Load move
    LDA 11
    PLO 9
    LDA 11
    PHI 9
    ; Save updated pointer
    LDI LOW(PLY_BASE + PLY_PTR_LO)
    PLO 10
    GLO 11
    STR 10
    INC 10
    GHI 11
    STR 10
    ; Save move in ply storage
    LDI LOW(PLY_BASE + PLY_MOVE_FROM)
    PLO 10
    GLO 9
    STR 10
    INC 10
    GHI 9
    STR 10
    ; Reload and make move
    LDI 0
    PLO 12
    LDI HIGH(PLY_BASE)
    PHI 10
    LDI LOW(PLY_BASE + PLY_MOVE_FROM)
    PLO 10
    LDN 10
    PLO 11
    INC 10
    LDN 10
    PHI 11
    CALL MAKE_MOVE_PLY
    ; Increment node count
    CALL INC_NODE_COUNT
    ; Call negamax for opponent (ply 1)
    LDI 1
    PLO 12 ; R12.0 = ply 1
    CALL NEGAMAX_PLY
    ; Negate score (negamax)
    CALL NEGATE_SCORE
    ; Test: Mimic what serial does - push/pop to stack
    SEX 2
    GLO 11
    STXD ; Push R11.0
    GLO 13
    STXD ; Push R13.0
    IRX
    LDXA ; Pop back to D
    PLO 13 ; Restore R13.0
    LDX ; Pop back to D
    PLO 11 ; Restore R11.0
    ; Unmake move
    LDI 0
    PLO 12
    LDI HIGH(PLY_BASE)
    PHI 10
    LDI LOW(PLY_BASE + PLY_MOVE_FROM)
    PLO 10
    LDN 10
    PLO 11
    INC 10
    LDN 10
    PHI 11
    CALL UNMAKE_MOVE_PLY
    ; Compare: if SCORE > BEST_SCORE, update
    CALL COMPARE_SCORE_GT_BEST
    LBZ NR_NOT_BETTER
    ; Update best move and score
    LDI HIGH(PLY_BASE)
    PHI 10
    LDI LOW(PLY_BASE + PLY_MOVE_FROM)
    PLO 10
    LDN 10
    PLO 9
    INC 10
    LDN 10
    PHI 9
    LDI HIGH(BEST_MOVE_FROM)
    PHI 10
    LDI LOW(BEST_MOVE_FROM)
    PLO 10
    GLO 9
    STR 10
    INC 10
    GHI 9
    STR 10
    LDI HIGH(SCORE_LO)
    PHI 10
    LDI LOW(SCORE_LO)
    PLO 10
    LDN 10
    PLO 9
    INC 10
    LDN 10
    PHI 9
    LDI HIGH(BEST_SCORE_LO)
    PHI 10
    LDI LOW(BEST_SCORE_LO)
    PLO 10
    GLO 9
    STR 10
    INC 10
    GHI 9
    STR 10
    ; Update alpha at root level (for proper propagation to children)
    ; alpha = max(alpha, score)
    CALL UPDATE_ROOT_ALPHA
NR_NOT_BETTER:
    LBR NR_LOOP
NR_DONE:
    RETN
; ==============================================================================
; UPDATE_ROOT_ALPHA - Update ply 0 alpha if SCORE > current alpha
; ==============================================================================
UPDATE_ROOT_ALPHA:
    ; Get current alpha
    LDI HIGH(PLY_BASE)
    PHI 10
    LDI LOW(PLY_BASE + PLY_ALPHA_LO)
    PLO 10
    LDN 10
    PLO 9
    INC 10
    LDN 10
    PHI 9 ; R9 = current alpha
    ; Get score
    LDI HIGH(SCORE_LO)
    PHI 10
    LDI LOW(SCORE_LO)
    PLO 10
    LDN 10
    PLO 15
    INC 10
    LDN 10
    PHI 15 ; R15 = score
    ; Compare R15 > R9 (signed)
    GHI 15
    STR 2
    GHI 9
    XOR
    ANI $80
    LBNZ URA_DIFF_SIGN
    ; Same sign comparison
    GHI 9
    STR 2
    GHI 15
    SD
    BNZ URA_HI_DIFF
    GLO 9
    STR 2
    GLO 15
    SD
    BZ URA_NO_UPDATE
    BNF URA_UPDATE
    RETN
URA_HI_DIFF:
    BNF URA_UPDATE
    RETN
URA_DIFF_SIGN:
    GHI 15
    ANI $80
    LBNZ URA_NO_UPDATE
    ; Score is positive, alpha is negative - update
URA_UPDATE:
    ; Update alpha = score
    LDI HIGH(PLY_BASE)
    PHI 10
    LDI LOW(PLY_BASE + PLY_ALPHA_LO)
    PLO 10
    GLO 15
    STR 10
    INC 10
    GHI 15
    STR 10
URA_NO_UPDATE:
    RETN
; ==============================================================================
; NEGAMAX_PLY - Search at ply level (in R12.0)
; Returns score in SCORE_LO/HI
; NOW WITH ALPHA-BETA CUTOFFS!
; ==============================================================================
NEGAMAX_PLY:
    SEX 2
    ; Check if at leaf (depth reached)
    LDI HIGH(SEARCH_DEPTH)
    PHI 10
    LDI LOW(SEARCH_DEPTH)
    PLO 10
    LDN 10 ; D = search depth
    STR 2
    GLO 12 ; D = current ply
    SD ; D = depth - ply
    LBNF NP_EVALUATE ; If ply >= depth, evaluate
    LBZ NP_EVALUATE
    ; Not at leaf - set up alpha/beta from parent
    CALL SETUP_PLY_BOUNDS
    ; Generate moves for this ply
    CALL GENERATE_MOVES_FOR_PLY
    ; Set move pointer
    GLO 12
    SHL
    SHL
    SHL
    SHL
    SHL ; ply * 32
    STR 2
    LDI LOW(MOVELIST_PLY0)
    ADD
    PLO 9
    LDI HIGH(MOVELIST_PLY0)
    ADCI 0
    PHI 9
    ; Store in ply's PTR
    GLO 12
    SHL
    SHL
    SHL
    SHL
    STR 2
    LDI LOW(PLY_BASE + PLY_PTR_LO)
    ADD
    PLO 10
    LDI HIGH(PLY_BASE)
    PHI 10
    GLO 9
    STR 10
    INC 10
    GHI 9
    STR 10
    ; Initialize best to -infinity
    GLO 12
    SHL
    SHL
    SHL
    SHL
    STR 2
    LDI LOW(PLY_BASE + PLY_BEST_LO)
    ADD
    PLO 10
    LDI HIGH(PLY_BASE)
    PHI 10
    LDI NEG_INF_LO
    STR 10
    INC 10
    LDI NEG_INF_HI
    STR 10
NP_LOOP:
    ; Get move pointer
    GLO 12
    SHL
    SHL
    SHL
    SHL
    STR 2
    LDI LOW(PLY_BASE + PLY_PTR_LO)
    ADD
    PLO 10
    LDI HIGH(PLY_BASE)
    PHI 10
    LDN 10
    PLO 11
    INC 10
    LDN 10
    PHI 11
    ; Check end
    LDN 11
    XRI $FF
    LBZ NP_RETURN_BEST
    ; Load move
    LDA 11
    PLO 9
    LDA 11
    PHI 9
    ; Save updated pointer
    GLO 12
    SHL
    SHL
    SHL
    SHL
    STR 2
    LDI LOW(PLY_BASE + PLY_PTR_LO)
    ADD
    PLO 10
    LDI HIGH(PLY_BASE)
    PHI 10
    GLO 11
    STR 10
    INC 10
    GHI 11
    STR 10
    ; Save move in ply storage
    GLO 12
    SHL
    SHL
    SHL
    SHL
    STR 2
    LDI LOW(PLY_BASE + PLY_MOVE_FROM)
    ADD
    PLO 10
    LDI HIGH(PLY_BASE)
    PHI 10
    GLO 9
    STR 10
    INC 10
    GHI 9
    STR 10
    ; Make move
    DEC 10
    LDN 10
    PLO 11
    INC 10
    LDN 10
    PHI 11
    CALL MAKE_MOVE_PLY
    ; Increment node count
    CALL INC_NODE_COUNT
    ; Recurse
    GLO 12
    ADI 1
    PLO 12
    CALL NEGAMAX_PLY
    GLO 12
    SMI 1
    PLO 12
    ; Negate score
    CALL NEGATE_SCORE
    ; Unmake move
    GLO 12
    SHL
    SHL
    SHL
    SHL
    STR 2
    LDI LOW(PLY_BASE + PLY_MOVE_FROM)
    ADD
    PLO 10
    LDI HIGH(PLY_BASE)
    PHI 10
    LDN 10
    PLO 11
    INC 10
    LDN 10
    PHI 11
    CALL UNMAKE_MOVE_PLY
    ; Update best if score > best
    CALL CHECK_SCORE_GT_PLY_BEST
    LBZ NP_LOOP
    ; Update PLY_BEST = SCORE
    LDI HIGH(SCORE_LO)
    PHI 10
    LDI LOW(SCORE_LO)
    PLO 10
    LDN 10
    PLO 9
    INC 10
    LDN 10
    PHI 9
    GLO 12
    SHL
    SHL
    SHL
    SHL
    STR 2
    LDI LOW(PLY_BASE + PLY_BEST_LO)
    ADD
    PLO 10
    LDI HIGH(PLY_BASE)
    PHI 10
    GLO 9
    STR 10
    INC 10
    GHI 9
    STR 10
    ; =========================================================================
    ; ALPHA-BETA CUTOFF CHECK
    ; If best >= beta, we have a cutoff - stop searching this node
    ; =========================================================================
    CALL CHECK_BEST_GE_BETA
    LBZ NP_NO_CUTOFF
    ; CUTOFF! Increment counter and return
    CALL INC_CUTOFF_COUNT
    LBR NP_RETURN_BEST
NP_NO_CUTOFF:
    ; Update alpha = max(alpha, best)
    CALL UPDATE_PLY_ALPHA
    LBR NP_LOOP
NP_RETURN_BEST:
    ; Return PLY_BEST in SCORE
    GLO 12
    SHL
    SHL
    SHL
    SHL
    STR 2
    LDI LOW(PLY_BASE + PLY_BEST_LO)
    ADD
    PLO 10
    LDI HIGH(PLY_BASE)
    PHI 10
    LDN 10
    PLO 9
    INC 10
    LDN 10
    PHI 9
    LDI HIGH(SCORE_LO)
    PHI 10
    LDI LOW(SCORE_LO)
    PLO 10
    GLO 9
    STR 10
    INC 10
    GHI 9
    STR 10
    RETN
NP_EVALUATE:
    ; Leaf node - evaluate
    ; Even ply = white's perspective, odd = black's
    CALL EVALUATE_MATERIAL
    ; If odd ply, negate (we evaluate from white's view)
    GLO 12
    ANI $01
    LBZ NP_EVAL_DONE
    CALL NEGATE_SCORE
NP_EVAL_DONE:
    RETN
; ==============================================================================
; CHECK_BEST_GE_BETA - Return D=1 if PLY_BEST >= PLY_BETA (signed)
; This is the cutoff condition for alpha-beta
; ==============================================================================
CHECK_BEST_GE_BETA:
    ; Get PLY_BEST into R9
    GLO 12
    SHL
    SHL
    SHL
    SHL
    STR 2
    LDI LOW(PLY_BASE + PLY_BEST_LO)
    ADD
    PLO 10
    LDI HIGH(PLY_BASE)
    PHI 10
    LDN 10
    PLO 9
    INC 10
    LDN 10
    PHI 9 ; R9 = best
    ; Get PLY_BETA into R15
    GLO 12
    SHL
    SHL
    SHL
    SHL
    STR 2
    LDI LOW(PLY_BASE + PLY_BETA_LO)
    ADD
    PLO 10
    LDI HIGH(PLY_BASE)
    PHI 10
    LDN 10
    PLO 15
    INC 10
    LDN 10
    PHI 15 ; R15 = beta
    ; Compare: R9 >= R15? (best >= beta?)
    ; This is equivalent to: NOT (best < beta)
    ; Or: best - beta >= 0
    ; Check if different signs
    GHI 9
    STR 2
    GHI 15
    XOR
    ANI $80
    LBNZ CBGB_DIFF_SIGN
    ; Same sign - subtract and check
    GLO 15
    STR 2
    GLO 9
    SM ; D = best_lo - beta_lo
    PLO 14 ; Save low result
    GHI 15
    STR 2
    GHI 9
    SMB ; D = best_hi - beta_hi - borrow
    ; If high byte result >= 0, and no underflow, best >= beta
    BNF CBGB_YES ; If no borrow, best >= beta
    LDI 0
    RETN
CBGB_DIFF_SIGN:
    ; Different signs
    ; If best is positive (bit 7 = 0) and beta is negative (bit 7 = 1), best >= beta
    ; If best is negative (bit 7 = 1) and beta is positive (bit 7 = 0), best < beta
    GHI 9
    ANI $80
    LBNZ CBGB_NO ; best is negative, beta positive -> best < beta
CBGB_YES:
    LDI 1
    RETN
CBGB_NO:
    LDI 0
    RETN
; ==============================================================================
; UPDATE_PLY_ALPHA - Set alpha = max(alpha, best) for current ply
; ==============================================================================
UPDATE_PLY_ALPHA:
    ; Get PLY_BEST into R9
    GLO 12
    SHL
    SHL
    SHL
    SHL
    STR 2
    LDI LOW(PLY_BASE + PLY_BEST_LO)
    ADD
    PLO 10
    LDI HIGH(PLY_BASE)
    PHI 10
    LDN 10
    PLO 9
    INC 10
    LDN 10
    PHI 9 ; R9 = best
    ; Get PLY_ALPHA into R15
    GLO 12
    SHL
    SHL
    SHL
    SHL
    STR 2
    LDI LOW(PLY_BASE + PLY_ALPHA_LO)
    ADD
    PLO 10
    LDI HIGH(PLY_BASE)
    PHI 10
    LDN 10
    PLO 15
    INC 10
    LDN 10
    PHI 15 ; R15 = alpha
    ; If best > alpha, update alpha = best
    GHI 9
    STR 2
    GHI 15
    XOR
    ANI $80
    LBNZ UPA_DIFF_SIGN
    ; Same sign comparison
    GHI 15
    STR 2
    GHI 9
    SD
    BNZ UPA_HI_DIFF
    GLO 15
    STR 2
    GLO 9
    SD
    BZ UPA_NO_UPDATE
    BNF UPA_UPDATE
    RETN
UPA_HI_DIFF:
    BNF UPA_UPDATE
    RETN
UPA_DIFF_SIGN:
    GHI 9
    ANI $80
    LBNZ UPA_NO_UPDATE
    ; best is positive, alpha is negative - update
UPA_UPDATE:
    ; Update alpha = best
    GLO 12
    SHL
    SHL
    SHL
    SHL
    STR 2
    LDI LOW(PLY_BASE + PLY_ALPHA_LO)
    ADD
    PLO 10
    LDI HIGH(PLY_BASE)
    PHI 10
    GLO 9
    STR 10
    INC 10
    GHI 9
    STR 10
UPA_NO_UPDATE:
    RETN
; ==============================================================================
; INC_CUTOFF_COUNT - Increment the cutoff counter
; ==============================================================================
INC_CUTOFF_COUNT:
    LDI HIGH(CUTOFF_COUNT_LO)
    PHI 10
    LDI LOW(CUTOFF_COUNT_LO)
    PLO 10
    LDN 10
    ADI 1
    STR 10
    INC 10
    INC 10 ; Skip TEMP_PLY to get to CUTOFF_COUNT_HI
    LDN 10
    ADCI 0
    STR 10
    RETN
; ==============================================================================
; GENERATE_MOVES_FOR_PLY - Wrapper for GENERATE_MOVES
; Input: R12.0 = ply
; Output: Moves written to ply's move list, terminated with $FF
; ==============================================================================
GENERATE_MOVES_FOR_PLY:
    SEX 2
    ; Save ply to memory (GENERATE_MOVES will clobber R12)
    LDI HIGH(TEMP_PLY)
    PHI 10
    LDI LOW(TEMP_PLY)
    PLO 10
    GLO 12
    STR 10 ; Save ply
    ; Calculate move list address for this ply
    ; Ply 0: $5100, Ply 1: $5120, Ply 2: $5140, Ply 3: $5160
    SHL
    SHL
    SHL
    SHL
    SHL ; ply * 32
    STR 2
    LDI LOW(MOVELIST_PLY0)
    ADD
    PLO 9
    LDI HIGH(MOVELIST_PLY0)
    ADCI 0
    PHI 9 ; R9 = move list pointer for GENERATE_MOVES
    ; Set R12 = side to move based on ply (even = WHITE/0, odd = BLACK/8)
    LDI HIGH(TEMP_PLY)
    PHI 10
    LDI LOW(TEMP_PLY)
    PLO 10
    LDN 10 ; Get ply back
    ANI $01 ; Odd = black
    LBZ GMFP_WHITE
    LDI BLACK ; $08
    LBR GMFP_SET_SIDE
GMFP_WHITE:
    LDI WHITE ; $00
GMFP_SET_SIDE:
    PLO 12 ; R12.0 = side to move for GENERATE_MOVES
    ; Call the full move generator
    CALL GENERATE_MOVES
    ; D now contains move count - we don't need it, moves are in list
    ; Add terminator to move list (R9 is already past last move)
    LDI $FF
    STR 9
    ; Restore ply to R12
    LDI HIGH(TEMP_PLY)
    PHI 10
    LDI LOW(TEMP_PLY)
    PLO 10
    LDN 10
    PLO 12
    RETN
; ==============================================================================
; SETUP_PLY_BOUNDS - Set alpha/beta from parent (negated and swapped)
; ==============================================================================
SETUP_PLY_BOUNDS:
    ; Get parent ply offset
    GLO 12
    SMI 1
    SHL
    SHL
    SHL
    SHL
    PLO 14 ; parent offset
    ; Get parent beta -> negate -> child alpha
    GLO 14
    STR 2
    LDI LOW(PLY_BASE + PLY_BETA_LO)
    ADD
    PLO 10
    LDI HIGH(PLY_BASE)
    PHI 10
    LDN 10
    PLO 9
    INC 10
    LDN 10
    PHI 9
    ; Negate
    GLO 9
    XRI $FF
    PLO 9
    GHI 9
    XRI $FF
    PHI 9
    GLO 9
    ADI 1
    PLO 9
    GHI 9
    ADCI 0
    PHI 9
    ; Store as child alpha
    GLO 12
    SHL
    SHL
    SHL
    SHL
    STR 2
    LDI LOW(PLY_BASE + PLY_ALPHA_LO)
    ADD
    PLO 10
    LDI HIGH(PLY_BASE)
    PHI 10
    GLO 9
    STR 10
    INC 10
    GHI 9
    STR 10
    ; Get parent alpha -> negate -> child beta
    GLO 14
    STR 2
    LDI LOW(PLY_BASE + PLY_ALPHA_LO)
    ADD
    PLO 10
    LDN 10
    PLO 9
    INC 10
    LDN 10
    PHI 9
    ; Negate
    GLO 9
    XRI $FF
    PLO 9
    GHI 9
    XRI $FF
    PHI 9
    GLO 9
    ADI 1
    PLO 9
    GHI 9
    ADCI 0
    PHI 9
    ; Store as child beta
    GLO 12
    SHL
    SHL
    SHL
    SHL
    STR 2
    LDI LOW(PLY_BASE + PLY_BETA_LO)
    ADD
    PLO 10
    LDI HIGH(PLY_BASE)
    PHI 10
    GLO 9
    STR 10
    INC 10
    GHI 9
    STR 10
    RETN
; ==============================================================================
; NEGATE_SCORE - Negate SCORE_LO/HI in place
; ==============================================================================
NEGATE_SCORE:
    LDI HIGH(SCORE_LO)
    PHI 10
    LDI LOW(SCORE_LO)
    PLO 10
    LDN 10
    XRI $FF
    PLO 9
    INC 10
    LDN 10
    XRI $FF
    PHI 9
    GLO 9
    ADI 1
    PLO 9
    GHI 9
    ADCI 0
    PHI 9
    DEC 10
    GLO 9
    STR 10
    INC 10
    GHI 9
    STR 10
    RETN
; ==============================================================================
; CHECK_SCORE_GT_PLY_BEST - Return D=1 if SCORE > PLY_BEST
; ==============================================================================
CHECK_SCORE_GT_PLY_BEST:
    ; Get PLY_BEST into R9
    GLO 12
    SHL
    SHL
    SHL
    SHL
    STR 2
    LDI LOW(PLY_BASE + PLY_BEST_LO)
    ADD
    PLO 10
    LDI HIGH(PLY_BASE)
    PHI 10
    LDN 10
    PLO 9
    INC 10
    LDN 10
    PHI 9
    ; Get SCORE into R15
    LDI HIGH(SCORE_LO)
    PHI 10
    LDI LOW(SCORE_LO)
    PLO 10
    LDN 10
    PLO 15
    INC 10
    LDN 10
    PHI 15
    ; Compare R15 > R9?
    GHI 15
    STR 2
    GHI 9
    XOR
    ANI $80
    LBNZ CSPB_DIFF
    ; Same sign
    GHI 9
    STR 2
    GHI 15
    SD
    BNZ CSPB_HI_DIFF
    GLO 9
    STR 2
    GLO 15
    SD
    BZ CSPB_EQ
    BNF CSPB_GT
    LDI 0
    RETN
CSPB_HI_DIFF:
    BNF CSPB_GT
    LDI 0
    RETN
CSPB_EQ:
    LDI 0
    RETN
CSPB_GT:
    LDI 1
    RETN
CSPB_DIFF:
    GHI 15
    ANI $80
    LBNZ CSPB_EQ
    LDI 1
    RETN
; ==============================================================================
; Helpers
; ==============================================================================
COMPARE_SCORE_GT_BEST:
    LDI HIGH(BEST_SCORE_LO)
    PHI 10
    LDI LOW(BEST_SCORE_LO)
    PLO 10
    LDN 10
    PLO 9
    INC 10
    LDN 10
    PHI 9 ; R9 = BEST
    LDI HIGH(SCORE_LO)
    PHI 10
    LDI LOW(SCORE_LO)
    PLO 10
    LDN 10
    PLO 15
    INC 10
    LDN 10
    PHI 15 ; R15 = SCORE
    ; Is R15 > R9? (signed comparison)
    GHI 15
    STR 2
    GHI 9
    XOR
    ANI $80
    LBNZ CSGB_DIFF
    ; Same sign
    GHI 9 ; best_hi
    STR 2
    GHI 15 ; score_hi
    SD ; D = best_hi - score_hi
    BNZ CSGB_HI_DIFF
    ; High bytes equal
    GLO 9
    STR 2
    GLO 15
    SD
    BZ CSGB_EQUAL
    BNF CSGB_GT
    LDI 0
    RETN
CSGB_HI_DIFF:
    BNF CSGB_GT
    LDI 0
    RETN
CSGB_EQUAL:
    LDI 0
    RETN
CSGB_GT:
    LDI 1
    RETN
CSGB_DIFF:
    GHI 15
    ANI $80
    LBNZ CSGB_EQUAL
    LDI 1
    RETN
INC_NODE_COUNT:
    LDI HIGH(NODE_COUNT_LO)
    PHI 10
    LDI LOW(NODE_COUNT_LO)
    PLO 10
    LDN 10
    ADI 1
    STR 10
    INC 10
    LDN 10
    ADCI 0
    STR 10
    RETN
PRINT_CRLF:
    LDI HIGH(STR_CRLF)
    PHI 8
    LDI LOW(STR_CRLF)
    PLO 8
    CALL SERIAL_PRINT_STRING
    RETN
; ==============================================================================
; Board setup
; ==============================================================================
CLEAR_BOARD:
    LDI HIGH(BOARD)
    PHI 10
    LDI LOW(BOARD)
    PLO 10
    LDI 128
    PLO 14
CB_LOOP:
    LDI EMPTY
    STR 10
    INC 10
    DEC 14
    GLO 14
    LBNZ CB_LOOP
    RETN
SETUP_POSITION:
    LDI HIGH(BOARD)
    PHI 10
    ; White King at e1 ($04)
    LDI SQ_E1
    PLO 10
    LDI W_KING
    STR 10
    ; White Queen at d1 ($03)
    LDI SQ_D1
    PLO 10
    LDI W_QUEEN
    STR 10
    ; White Pawn at a2 ($10)
    LDI SQ_A2
    PLO 10
    LDI W_PAWN
    STR 10
    ; Black King at e8 ($74)
    LDI SQ_E8
    PLO 10
    LDI B_KING
    STR 10
    ; Black Pawn at a7 ($60)
    LDI SQ_A7
    PLO 10
    LDI B_PAWN
    STR 10
    RETN
INIT_GAME_STATE:
    LDI HIGH(GAME_STATE)
    PHI 10
    LDI LOW(GAME_STATE)
    PLO 10
    ; No castling rights (kings not on original squares with rooks)
    LDI 0
    STR 10
    INC 10
    ; No en passant
    LDI $FF ; $FF = no EP square
    STR 10
    RETN
; ==============================================================================
; MAKE_MOVE_PLY / UNMAKE_MOVE_PLY
; Input: R11.0 = from, R11.1 = to, R12.0 = ply
; ==============================================================================
MAKE_MOVE_PLY:
    GLO 12
    SHL
    SHL
    SHL
    SHL
    STR 2
    LDI LOW(PLY_BASE + PLY_MOVE_PIECE)
    ADD
    PLO 10
    LDI HIGH(PLY_BASE)
    PHI 10
    LDI HIGH(BOARD)
    PHI 8
    GLO 11
    PLO 8
    LDN 8
    STR 10 ; Save moving piece
    GHI 11
    PLO 8
    LDN 8
    INC 10
    STR 10 ; Save captured piece
    GHI 11
    PLO 8
    DEC 10
    LDN 10 ; Get moving piece
    STR 8 ; Place at destination
    GLO 11
    PLO 8
    LDI EMPTY
    STR 8 ; Clear source
    RETN
UNMAKE_MOVE_PLY:
    GLO 12
    SHL
    SHL
    SHL
    SHL
    STR 2
    LDI LOW(PLY_BASE + PLY_MOVE_PIECE)
    ADD
    PLO 10
    LDI HIGH(PLY_BASE)
    PHI 10
    LDI HIGH(BOARD)
    PHI 8
    GLO 11
    PLO 8
    LDN 10
    STR 8 ; Restore piece at source
    GHI 11
    PLO 8
    INC 10
    LDN 10
    STR 8 ; Restore captured piece
    RETN
; ==============================================================================
; EVALUATE_MATERIAL - Simple material count
; ==============================================================================
EVALUATE_MATERIAL:
    SEX 2
    LDI HIGH(SCORE_LO)
    PHI 10
    LDI LOW(SCORE_LO)
    PLO 10
    LDI 0
    STR 10
    INC 10
    STR 10
    LDI HIGH(BOARD)
    PHI 11
    LDI LOW(BOARD)
    PLO 11
    LDI 0
    PLO 14
EM_LOOP:
    GLO 14
    ANI $88
    LBNZ EM_NEXT_RANK
    LDN 11
    LBZ EM_NEXT_SQ
    PLO 15
    ANI $07
    SMI 1
    SHL
    STR 2
    LDI LOW(PIECE_VALUES)
    ADD
    PLO 8
    LDI HIGH(PIECE_VALUES)
    ADCI 0
    PHI 8
    LDA 8
    PHI 9
    LDN 8
    PLO 9
    GLO 15
    ANI $08
    LBNZ EM_SUBTRACT
EM_ADD:
    LDI HIGH(SCORE_LO)
    PHI 10
    LDI LOW(SCORE_LO)
    PLO 10
    LDN 10
    STR 2
    GLO 9
    ADD
    STR 10
    INC 10
    LDN 10
    ADCI 0
    STR 2
    GHI 9
    ADD
    STR 10
    LBR EM_NEXT_SQ
EM_SUBTRACT:
    LDI HIGH(SCORE_LO)
    PHI 10
    LDI LOW(SCORE_LO)
    PLO 10
    LDN 10
    STR 2
    GLO 9
    SD
    STR 10
    INC 10
    LDN 10
    SMBI 0
    STR 2
    GHI 9
    SD
    STR 10
    LBR EM_NEXT_SQ
EM_NEXT_SQ:
    INC 11
    INC 14
    GLO 14
    ANI $80
    LBZ EM_LOOP
    RETN
EM_NEXT_RANK:
    GLO 14
    ADI 8
    PLO 14
    GLO 11
    ADI 8
    PLO 11
    GHI 11
    ADCI 0
    PHI 11
    GLO 14
    ANI $80
    LBNZ EM_DONE
    LBR EM_LOOP
EM_DONE:
    RETN
; ==============================================================================
; Include full move generator
; ==============================================================================
; ==============================================================================
; RCA 1802/1806 Chess Engine - Move Generation (Clean Replacement)
; ==============================================================================
; Based on tested step11 code - proven working
; Supports both white and black via R12 (side to move)
; Simple 2-byte move format: (from, to)
; ==============================================================================
;
; REGISTER ALLOCATION MAP
; ==============================================================================
; R0 = DMA pointer (system - do not use)
; R1 = Interrupt PC (system - do not use)
; R2 = Stack pointer (X=2)
; R3 = Program counter
; R4 = SCRT CALL
; R5 = SCRT RET
; R6 = SCRT link register *** DO NOT USE FOR TEMP STORAGE ***
; R7 = Temp board lookup pointer (piece generators)
; R8 = Offset/direction table pointer (piece generators)
; R9 = Move list pointer (input, updated on output)
; R10 = Board scan pointer (GENERATE_MOVES main loop) *** DO NOT CLOBBER ***
; R11 = Square calculation: R11.1=from square, R11.0=target square
; R12 = Side to move (0=WHITE, 8=BLACK) *** MUST PRESERVE ***
; R13 = R13.0=loop counter, R13.1=direction (sliding pieces)
; R14 = R14.0=current square index (board scan)
; R15 = R15.0=move count
;
; CRITICAL REGISTERS - DO NOT CLOBBER IN PIECE GENERATORS:
; R6 - SCRT link register (will crash on RETN)
; R10 - Board scan pointer (will skip squares)
; R12 - Side to move (will generate wrong color moves)
;
; ==============================================================================
; REGISTER CONVENTIONS:
; R2 = Stack pointer (X=2)
; R4 = SCRT CALL
; R5 = SCRT RET
; R6 = SCRT link register
; R9 = Move list pointer (preserved, updated)
; R12 = Side to move (MUST BE PRESERVED by all functions)
;
; ==============================================================================
; FUNCTION REGISTER DOCUMENTATION
; ==============================================================================
;
; GENERATE_MOVES
; Input: R9 = move list pointer, R12.0 = side (0=WHITE, 8=BLACK)
; Output: D = move count, R9 = updated past last move
; Clobbers: R6,R7,R8,R10,R11,R13,R14,R15
; Preserves: R12
;
; GM_GEN_PAWN
; Input: R14.0 = from square, R12.0 = side, R9 = move list, R15.0 = count
; Output: R9 updated, R15.0 updated
; Clobbers: R11,R13
; Preserves: R12,R14
;
; GM_GEN_KNIGHT
; Input: R14.0 = from square, R12.0 = side, R9 = move list, R15.0 = count
; Output: R9 updated, R15.0 updated
; Clobbers: R7,R8,R11,R13
; Preserves: R12,R14
;
; GM_GEN_BISHOP
; Input: R14.0 = from square, R12.0 = side, R9 = move list, R15.0 = count
; Output: R9 updated, R15.0 updated
; Clobbers: R6,R7,R8,R11,R13
; Preserves: R12,R14
;
; GM_GEN_ROOK
; Input: R14.0 = from square, R12.0 = side, R9 = move list, R15.0 = count
; Output: R9 updated, R15.0 updated
; Clobbers: R6,R7,R8,R11,R13
; Preserves: R12,R14
;
; GM_GEN_QUEEN
; Input: R14.0 = from square, R12.0 = side, R9 = move list, R15.0 = count
; Output: R9 updated, R15.0 updated
; Clobbers: R6,R7,R8,R11,R13
; Preserves: R12,R14
;
; GM_GEN_KING
; Input: R14.0 = from square, R12.0 = side, R9 = move list, R15.0 = count
; Output: R9 updated, R15.0 updated
; Clobbers: R7,R8,R11,R13
; Preserves: R12,R14
;
; ==============================================================================
; ==============================================================================
; GENERATE_MOVES - Main entry point
; ==============================================================================
; Input: R9 = move list pointer
; R12.0 = side to move (0 = WHITE, 8 = BLACK)
; Output: D = move count
; R9 = updated (points past last move)
; ==============================================================================
GENERATE_MOVES:
    LDI HIGH(BOARD)
    PHI 10
    LDI LOW(BOARD)
    PLO 10
    LDI 0
    PLO 14 ; E.0 = square index
    PLO 15 ; F.0 = move count
GM_SCAN_LOOP:
    GLO 14
    ANI $88
    LBNZ GM_SCAN_SKIP ; Invalid square in 0x88
    LDN 10
    LBZ GM_SCAN_SKIP ; Empty square
    ; Check if piece belongs to side to move
    PLO 13 ; Save piece
    ANI COLOR_MASK
    STR 2 ; Store piece color on stack
    GLO 12 ; Side to move
    XOR ; 0 if colors match
    LBNZ GM_SCAN_SKIP ; Not our piece
    ; Dispatch by piece type
    GLO 13
    ANI PIECE_MASK
    SMI 1
    LBZ GM_DO_PAWN
    SMI 1
    LBZ GM_DO_KNIGHT
    SMI 1
    LBZ GM_DO_BISHOP
    SMI 1
    LBZ GM_DO_ROOK
    SMI 1
    LBZ GM_DO_QUEEN
    SMI 1
    LBZ GM_DO_KING
    LBR GM_SCAN_SKIP
GM_DO_PAWN:
    CALL GM_GEN_PAWN
    LBR GM_SCAN_SKIP
GM_DO_KNIGHT:
    CALL GM_GEN_KNIGHT
    LBR GM_SCAN_SKIP
GM_DO_BISHOP:
    CALL GM_GEN_BISHOP
    LBR GM_SCAN_SKIP
GM_DO_ROOK:
    CALL GM_GEN_ROOK
    LBR GM_SCAN_SKIP
GM_DO_QUEEN:
    CALL GM_GEN_QUEEN
    LBR GM_SCAN_SKIP
GM_DO_KING:
    CALL GM_GEN_KING
    LBR GM_SCAN_SKIP
GM_SCAN_SKIP:
    INC 10
    INC 14
    GLO 14
    ANI $80
    LBZ GM_SCAN_LOOP
    GLO 15 ; Return move count in D
    RETN
; ==============================================================================
; GM_GEN_PAWN - Generate pawn moves
; ==============================================================================
GM_GEN_PAWN:
    GLO 12
    LBZ GM_PAWN_WHITE
; --- Black pawn (moves north, toward rank 0) ---
GM_PAWN_BLACK:
    ; Single push
    GLO 14
    ADI DIR_N ; -16
    PLO 11
    ANI $88
    LBNZ GM_PB_CAPTURES
    LDI HIGH(BOARD)
    PHI 13
    GLO 11
    PLO 13
    LDN 13
    LBNZ GM_PB_CAPTURES
    ; Add single push
    INC 15
    GLO 14
    STR 9
    INC 9
    GLO 11
    STR 9
    INC 9
    ; Double push if on rank 6 ($6x)
    GLO 14
    ANI $F0
    XRI $60
    LBNZ GM_PB_CAPTURES
    GLO 11
    ADI DIR_N
    PLO 11
    LDI HIGH(BOARD)
    PHI 13
    GLO 11
    PLO 13
    LDN 13
    LBNZ GM_PB_CAPTURES
    INC 15
    GLO 14
    STR 9
    INC 9
    GLO 11
    STR 9
    INC 9
GM_PB_CAPTURES:
    ; Capture left (NW = -17 = $EF)
    GLO 14
    ADI DIR_NW
    PLO 11
    ANI $88
    LBNZ GM_PB_CAP_R
    ; Check en passant
    LDI HIGH(GAME_STATE)
    PHI 13
    LDI LOW(GAME_STATE + GS_EP)
    PLO 13
    LDN 13
    STR 2
    GLO 11
    SM
    LBZ GM_PB_ADD_CAP_L
    ; Normal capture check
    LDI HIGH(BOARD)
    PHI 13
    GLO 11
    PLO 13
    LDN 13
    LBZ GM_PB_CAP_R
    ANI COLOR_MASK
    XRI BLACK
    LBNZ GM_PB_ADD_CAP_L ; Not black = white = enemy
    LBR GM_PB_CAP_R
GM_PB_ADD_CAP_L:
    INC 15
    GLO 14
    STR 9
    INC 9
    GLO 11
    STR 9
    INC 9
GM_PB_CAP_R:
    ; Capture right (NE = -15 = $F1)
    GLO 14
    ADI DIR_NE
    PLO 11
    ANI $88
    LBNZ GM_PAWN_DONE
    ; Check en passant
    LDI HIGH(GAME_STATE)
    PHI 13
    LDI LOW(GAME_STATE + GS_EP)
    PLO 13
    LDN 13
    STR 2
    GLO 11
    SM
    LBZ GM_PB_ADD_CAP_R
    ; Normal capture
    LDI HIGH(BOARD)
    PHI 13
    GLO 11
    PLO 13
    LDN 13
    LBZ GM_PAWN_DONE
    ANI COLOR_MASK
    XRI BLACK
    LBNZ GM_PB_ADD_CAP_R
    LBR GM_PAWN_DONE
GM_PB_ADD_CAP_R:
    INC 15
    GLO 14
    STR 9
    INC 9
    GLO 11
    STR 9
    INC 9
    LBR GM_PAWN_DONE
; --- White pawn (moves south, toward rank 7) ---
GM_PAWN_WHITE:
    ; Single push
    GLO 14
    ADI DIR_S ; +16
    PLO 11
    ANI $88
    LBNZ GM_PW_CAPTURES
    LDI HIGH(BOARD)
    PHI 13
    GLO 11
    PLO 13
    LDN 13
    LBNZ GM_PW_CAPTURES
    ; Add single push
    INC 15
    GLO 14
    STR 9
    INC 9
    GLO 11
    STR 9
    INC 9
    ; Double push if on rank 1 ($1x)
    GLO 14
    ANI $F0
    XRI $10
    LBNZ GM_PW_CAPTURES
    GLO 11
    ADI DIR_S
    PLO 11
    LDI HIGH(BOARD)
    PHI 13
    GLO 11
    PLO 13
    LDN 13
    LBNZ GM_PW_CAPTURES
    INC 15
    GLO 14
    STR 9
    INC 9
    GLO 11
    STR 9
    INC 9
GM_PW_CAPTURES:
    ; Capture left (SW = +15 = $0F)
    GLO 14
    ADI DIR_SW
    PLO 11
    ANI $88
    LBNZ GM_PW_CAP_R
    ; Check en passant
    LDI HIGH(GAME_STATE)
    PHI 13
    LDI LOW(GAME_STATE + GS_EP)
    PLO 13
    LDN 13
    STR 2
    GLO 11
    SM
    LBZ GM_PW_ADD_CAP_L
    ; Normal capture
    LDI HIGH(BOARD)
    PHI 13
    GLO 11
    PLO 13
    LDN 13
    LBZ GM_PW_CAP_R
    ANI COLOR_MASK
    LBZ GM_PW_CAP_R ; White = friendly
GM_PW_ADD_CAP_L:
    INC 15
    GLO 14
    STR 9
    INC 9
    GLO 11
    STR 9
    INC 9
GM_PW_CAP_R:
    ; Capture right (SE = +17 = $11)
    GLO 14
    ADI DIR_SE
    PLO 11
    ANI $88
    LBNZ GM_PAWN_DONE
    ; Check en passant
    LDI HIGH(GAME_STATE)
    PHI 13
    LDI LOW(GAME_STATE + GS_EP)
    PLO 13
    LDN 13
    STR 2
    GLO 11
    SM
    LBZ GM_PW_ADD_CAP_R
    ; Normal capture
    LDI HIGH(BOARD)
    PHI 13
    GLO 11
    PLO 13
    LDN 13
    LBZ GM_PAWN_DONE
    ANI COLOR_MASK
    LBZ GM_PAWN_DONE ; White = friendly
GM_PW_ADD_CAP_R:
    INC 15
    GLO 14
    STR 9
    INC 9
    GLO 11
    STR 9
    INC 9
GM_PAWN_DONE:
    RETN
; ==============================================================================
; GM_GEN_KNIGHT - Generate knight moves
; ==============================================================================
GM_GEN_KNIGHT:
    GLO 14
    PHI 11 ; B.1 = from square
    LDI HIGH(KNIGHT_OFFSETS)
    PHI 8
    LDI LOW(KNIGHT_OFFSETS)
    PLO 8 ; R8 = offset table (not R12!)
    LDI 8
    PLO 13
GM_KN_LOOP:
    LDN 8
    STR 2
    GHI 11
    ADD
    PLO 11
    ANI $88
    LBNZ GM_KN_NEXT
    ; Check target
    LDI HIGH(BOARD)
    PHI 7
    GLO 11
    PLO 7
    LDN 7
    LBZ GM_KN_ADD ; Empty
    ; Check if enemy
    ANI COLOR_MASK
    STR 2
    GLO 12
    XOR
    LBZ GM_KN_NEXT ; Same color = blocked
GM_KN_ADD:
    INC 15
    GHI 11
    STR 9
    INC 9
    GLO 11
    STR 9
    INC 9
GM_KN_NEXT:
    INC 8
    DEC 13
    GLO 13
    LBNZ GM_KN_LOOP
    RETN
; ==============================================================================
; GM_GEN_BISHOP - Generate bishop moves (4 diagonal rays)
; ==============================================================================
GM_GEN_BISHOP:
    GLO 14
    PHI 11 ; B.1 = from square
    LDI HIGH(BISHOP_DIRS)
    PHI 8
    LDI LOW(BISHOP_DIRS)
    PLO 8 ; R8 = direction table (not R12!)
    LDI 4
    PLO 13
GM_BI_DIR:
    LDN 8
    PHI 13 ; R13.1 = direction (R13.0 is loop counter)
    GHI 11
    PLO 11 ; Reset to from square
GM_BI_RAY:
    GLO 11
    STR 2
    GHI 13 ; Get direction from R13.1
    ADD
    PLO 11
    ANI $88
    LBNZ GM_BI_NEXT_DIR
    LDI HIGH(BOARD)
    PHI 7 ; Use R7 for board lookup (R10 is scan pointer!)
    GLO 11
    PLO 7
    LDN 7
    LBZ GM_BI_ADD ; Empty - add and continue
    ; Occupied - check color
    ANI COLOR_MASK
    STR 2
    GLO 12
    XOR
    LBZ GM_BI_NEXT_DIR ; Same color = blocked
    ; Enemy - capture then stop
    INC 15
    GHI 11
    STR 9
    INC 9
    GLO 11
    STR 9
    INC 9
    LBR GM_BI_NEXT_DIR
GM_BI_ADD:
    INC 15
    GHI 11
    STR 9
    INC 9
    GLO 11
    STR 9
    INC 9
    LBR GM_BI_RAY
GM_BI_NEXT_DIR:
    INC 8
    DEC 13
    GLO 13
    LBNZ GM_BI_DIR
    RETN
; ==============================================================================
; GM_GEN_ROOK - Generate rook moves (4 orthogonal rays)
; ==============================================================================
GM_GEN_ROOK:
    GLO 14
    PHI 11
    LDI HIGH(ROOK_DIRS)
    PHI 8
    LDI LOW(ROOK_DIRS)
    PLO 8 ; R8 = direction table (not R12!)
    LDI 4
    PLO 13
GM_RK_DIR:
    LDN 8
    PHI 13 ; R13.1 = direction (R13.0 is loop counter)
    GHI 11
    PLO 11
GM_RK_RAY:
    GLO 11
    STR 2
    GHI 13 ; Get direction from R13.1
    ADD
    PLO 11
    ANI $88
    LBNZ GM_RK_NEXT_DIR
    LDI HIGH(BOARD)
    PHI 7 ; Use R7 for board lookup (R10 is scan pointer!)
    GLO 11
    PLO 7
    LDN 7
    LBZ GM_RK_ADD
    ANI COLOR_MASK
    STR 2
    GLO 12
    XOR
    LBZ GM_RK_NEXT_DIR
    INC 15
    GHI 11
    STR 9
    INC 9
    GLO 11
    STR 9
    INC 9
    LBR GM_RK_NEXT_DIR
GM_RK_ADD:
    INC 15
    GHI 11
    STR 9
    INC 9
    GLO 11
    STR 9
    INC 9
    LBR GM_RK_RAY
GM_RK_NEXT_DIR:
    INC 8
    DEC 13
    GLO 13
    LBNZ GM_RK_DIR
    RETN
; ==============================================================================
; GM_GEN_QUEEN - Generate queen moves (bishop + rook)
; ==============================================================================
GM_GEN_QUEEN:
    CALL GM_GEN_BISHOP
    CALL GM_GEN_ROOK
    RETN
; ==============================================================================
; GM_GEN_KING - Generate king moves including castling
; ==============================================================================
GM_GEN_KING:
    GLO 14
    PHI 11 ; B.1 = from square
    ; Normal moves (8 directions)
    LDI HIGH(KING_OFFSETS)
    PHI 8
    LDI LOW(KING_OFFSETS)
    PLO 8 ; R8 = offset table (not R12!)
    LDI 8
    PLO 13
GM_KI_LOOP:
    LDN 8
    STR 2
    GHI 11
    ADD
    PLO 11
    ANI $88
    LBNZ GM_KI_NEXT
    LDI HIGH(BOARD)
    PHI 7
    GLO 11
    PLO 7
    LDN 7
    LBZ GM_KI_ADD
    ANI COLOR_MASK
    STR 2
    GLO 12
    XOR
    LBZ GM_KI_NEXT
GM_KI_ADD:
    INC 15
    GHI 11
    STR 9
    INC 9
    GLO 11
    STR 9
    INC 9
GM_KI_NEXT:
    INC 8
    DEC 13
    GLO 13
    LBNZ GM_KI_LOOP
    ; === Castling ===
    GLO 12
    LBZ GM_KI_CASTLE_W
; --- Black castling ---
GM_KI_CASTLE_B:
    GHI 11
    SMI SQ_E8
    LBNZ GM_KI_DONE ; King not on e8
    LDI HIGH(GAME_STATE)
    PHI 13
    LDI LOW(GAME_STATE + GS_CASTLE)
    PLO 13
    LDN 13
    PLO 11 ; Temp store rights in R11.0
    ; Kingside O-O
    GLO 11
    ANI CASTLE_BK
    LBZ GM_KI_BQ
    LDI HIGH(BOARD)
    PHI 13
    LDI SQ_F8
    PLO 13
    LDN 13
    LBNZ GM_KI_BQ
    LDI SQ_G8
    PLO 13
    LDN 13
    LBNZ GM_KI_BQ
    INC 15
    LDI SQ_E8
    STR 9
    INC 9
    LDI SQ_G8
    STR 9
    INC 9
GM_KI_BQ:
    ; Queenside O-O-O
    GLO 11
    ANI CASTLE_BQ
    LBZ GM_KI_DONE
    LDI HIGH(BOARD)
    PHI 13
    LDI SQ_D8
    PLO 13
    LDN 13
    LBNZ GM_KI_DONE
    LDI SQ_C8
    PLO 13
    LDN 13
    LBNZ GM_KI_DONE
    LDI SQ_B8
    PLO 13
    LDN 13
    LBNZ GM_KI_DONE
    INC 15
    LDI SQ_E8
    STR 9
    INC 9
    LDI SQ_C8
    STR 9
    INC 9
    LBR GM_KI_DONE
; --- White castling ---
GM_KI_CASTLE_W:
    GHI 11
    SMI SQ_E1
    LBNZ GM_KI_DONE
    LDI HIGH(GAME_STATE)
    PHI 13
    LDI LOW(GAME_STATE + GS_CASTLE)
    PLO 13
    LDN 13
    PLO 11 ; Temp store rights in R11.0
    ; Kingside O-O
    GLO 11
    ANI CASTLE_WK
    LBZ GM_KI_WQ
    LDI HIGH(BOARD)
    PHI 13
    LDI SQ_F1
    PLO 13
    LDN 13
    LBNZ GM_KI_WQ
    LDI SQ_G1
    PLO 13
    LDN 13
    LBNZ GM_KI_WQ
    INC 15
    LDI SQ_E1
    STR 9
    INC 9
    LDI SQ_G1
    STR 9
    INC 9
GM_KI_WQ:
    ; Queenside O-O-O
    GLO 11
    ANI CASTLE_WQ
    LBZ GM_KI_DONE
    LDI HIGH(BOARD)
    PHI 13
    LDI SQ_D1
    PLO 13
    LDN 13
    LBNZ GM_KI_DONE
    LDI SQ_C1
    PLO 13
    LDN 13
    LBNZ GM_KI_DONE
    LDI SQ_B1
    PLO 13
    LDN 13
    LBNZ GM_KI_DONE
    INC 15
    LDI SQ_E1
    STR 9
    INC 9
    LDI SQ_C1
    STR 9
    INC 9
GM_KI_DONE:
    RETN
; ==============================================================================
; Data Tables
; ==============================================================================
; Knight offsets (8 L-shaped moves)
KNIGHT_OFFSETS:
    DB $DF ; -33: up 2, left 1
    DB $E1 ; -31: up 2, right 1
    DB $EE ; -18: up 1, left 2
    DB $F2 ; -14: up 1, right 2
    DB $0E ; +14: down 1, left 2
    DB $12 ; +18: down 1, right 2
    DB $1F ; +31: down 2, left 1
    DB $21 ; +33: down 2, right 1
; King offsets (8 directions)
KING_OFFSETS:
    DB $EF ; NW (-17)
    DB $F0 ; N (-16)
    DB $F1 ; NE (-15)
    DB $FF ; W (-1)
    DB $01 ; E (+1)
    DB $0F ; SW (+15)
    DB $10 ; S (+16)
    DB $11 ; SE (+17)
; Bishop directions (4 diagonals)
BISHOP_DIRS:
    DB $EF ; NW (-17)
    DB $F1 ; NE (-15)
    DB $0F ; SW (+15)
    DB $11 ; SE (+17)
; Rook directions (4 orthogonals)
ROOK_DIRS:
    DB $F0 ; N (-16)
    DB $10 ; S (+16)
    DB $FF ; W (-1)
    DB $01 ; E (+1)
; ==============================================================================
; End of Move Generation
; ==============================================================================
; ==============================================================================
; Data Tables
; ==============================================================================
PIECE_VALUES:
    DW $0064 ; Pawn = 100
    DW $0140 ; Knight = 320
    DW $014A ; Bishop = 330
    DW $01F4 ; Rook = 500
    DW $0384 ; Queen = 900
    DW $0000 ; King = 0
STR_BANNER:
    DB "Step22: Depth-3 Search", 0DH, 0AH, 0
STR_POS:
    DB "WKe1 WQd1 WPa2 vs BKe8 BPa7", 0DH, 0AH, 0
STR_SEARCH:
    DB "Depth-3 with pruning...", 0DH, 0AH, 0
STR_BEST:
    DB "Best: ", 0
STR_NODES:
    DB "Nodes: ", 0
STR_CUTOFFS:
    DB "Cutoffs: ", 0
STR_DONE:
    DB "Done!", 0DH, 0AH, 0
STR_CRLF:
    DB 0DH, 0AH, 0
    END
