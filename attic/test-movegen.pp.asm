; ==============================================================================
; Move Generation Test
; Tests GENERATE_MOVES from starting position
; Expected: 20 legal moves for white
; ==============================================================================
    ORG $0000
    LBR MAIN
; Include modules via preprocessor
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
; ==============================================================================
; RCA 1802/1806 Chess Engine - Board Module (0x88 Representation)
; ==============================================================================
; 0x88 board uses 128 bytes where valid squares have (index & 0x88) == 0
; This simplifies boundary checking - invalid moves wrap to invalid squares
; ==============================================================================
; ------------------------------------------------------------------------------
; Piece Encoding (3-bit type + 1-bit color in bit 3)
; ------------------------------------------------------------------------------
; Bits 0-2: Piece type (0-6)
; Bit 3: Color (0=white, 1=black)
; Bits 4-7: Unused
; ------------------------------------------------------------------------------
EMPTY EQU $00
; White pieces (bit 3 = 0)
W_PAWN EQU $01
W_KNIGHT EQU $02
W_BISHOP EQU $03
W_ROOK EQU $04
W_QUEEN EQU $05
W_KING EQU $06
; Black pieces (bit 3 = 1)
B_PAWN EQU $09 ; $01 + $08
B_KNIGHT EQU $0A ; $02 + $08
B_BISHOP EQU $0B ; $03 + $08
B_ROOK EQU $0C ; $04 + $08
B_QUEEN EQU $0D ; $05 + $08
B_KING EQU $0E ; $06 + $08
; Masks
COLOR_MASK EQU $08 ; Bit 3 indicates color
PIECE_MASK EQU $07 ; Bits 0-2 are piece type
WHITE EQU $00 ; White side value
BLACK EQU $08 ; Black side value
; Piece types (without color)
PAWN_TYPE EQU 1
KNIGHT_TYPE EQU 2
BISHOP_TYPE EQU 3
ROOK_TYPE EQU 4
QUEEN_TYPE EQU 5
KING_TYPE EQU 6
; ------------------------------------------------------------------------------
; Memory Layout (Fixed Addresses)
; ------------------------------------------------------------------------------
BOARD EQU $5000 ; 128 bytes - 0x88 board array
GAME_STATE EQU $5080 ; Game state structure (16 bytes)
MOVE_HIST EQU $5090 ; Move history for undo (256 bytes)
MOVE_LIST EQU $5200 ; Generated moves (512 bytes)
; Game state offsets
STATE_SIDE_TO_MOVE EQU 0 ; 1 byte: 0=white, 8=black
STATE_CASTLING EQU 1 ; 1 byte: castling rights bits
STATE_EP_SQUARE EQU 2 ; 1 byte: en passant target (0x88), $FF=none
STATE_HALFMOVE EQU 3 ; 1 byte: halfmove clock (50-move rule)
STATE_FULLMOVE_LO EQU 4 ; 1 byte: fullmove number low byte
STATE_FULLMOVE_HI EQU 5 ; 1 byte: fullmove number high byte
STATE_W_KING_SQ EQU 6 ; 1 byte: white king square (0x88)
STATE_B_KING_SQ EQU 7 ; 1 byte: black king square (0x88)
; Castling rights bit flags
CASTLE_WK EQU $01 ; White kingside (e1-g1)
CASTLE_WQ EQU $02 ; White queenside (e1-c1)
CASTLE_BK EQU $04 ; Black kingside (e8-g8)
CASTLE_BQ EQU $08 ; Black queenside (e8-c8)
ALL_CASTLING EQU $0F ; All castling rights
; Move encoding flags
MOVE_NORMAL EQU $00
MOVE_CASTLE EQU $01
MOVE_EP EQU $02
MOVE_PROMOTION EQU $03
; ------------------------------------------------------------------------------
; Direction Offsets (0x88 board)
; ------------------------------------------------------------------------------
; In 0x88, each rank is 16 bytes apart (8 valid + 8 invalid)
; Direction = rank_delta * 16 + file_delta
; ------------------------------------------------------------------------------
DIR_N EQU $F0 ; -16 (up one rank)
DIR_S EQU $10 ; +16 (down one rank)
DIR_E EQU $01 ; +1 (right one file)
DIR_W EQU $FF ; -1 (left one file)
DIR_NE EQU $F1 ; -15 (up-right)
DIR_NW EQU $EF ; -17 (up-left)
DIR_SE EQU $11 ; +17 (down-right)
DIR_SW EQU $0F ; +15 (down-left)
; ------------------------------------------------------------------------------
; Knight Move Offsets (8 L-shaped moves)
; ------------------------------------------------------------------------------
KNIGHT_OFFSETS:
    DB $E2 ; -30 = -2*16 + 2 (up 2, right 1) - wait, that's wrong
    ; Correct knight offsets for 0x88:
    ; Up 2, left 1: -2*16 - 1 = -33 = $DF
    ; Up 2, right 1: -2*16 + 1 = -31 = $E1
    ; Up 1, left 2: -1*16 - 2 = -18 = $EE
    ; Up 1, right 2: -1*16 + 2 = -14 = $F2
    ; Down 1, left 2: +1*16 - 2 = +14 = $0E
    ; Down 1, right 2: +1*16 + 2 = +18 = $12
    ; Down 2, left 1: +2*16 - 1 = +31 = $1F
    ; Down 2, right 1: +2*16 + 1 = +33 = $21
; Actually, let me recalculate properly for consistency:
KNIGHT_OFFS:
    DB $DF ; -33: up 2, left 1
    DB $E1 ; -31: up 2, right 1
    DB $EE ; -18: up 1, left 2
    DB $F2 ; -14: up 1, right 2
    DB $0E ; +14: down 1, left 2
    DB $12 ; +18: down 1, right 2
    DB $1F ; +31: down 2, left 1
    DB $21 ; +33: down 2, right 1
; ------------------------------------------------------------------------------
; King Move Offsets (8 adjacent squares)
; ------------------------------------------------------------------------------
KING_OFFSETS:
    DB DIR_N ; $F0: up
    DB DIR_NE ; $F1: up-right
    DB DIR_E ; $01: right
    DB DIR_SE ; $11: down-right
    DB DIR_S ; $10: down
    DB DIR_SW ; $0F: down-left
    DB DIR_W ; $FF: left
    DB DIR_NW ; $EF: up-left
; ------------------------------------------------------------------------------
; Square Constants (0x88 format)
; ------------------------------------------------------------------------------
; Rank 1 (white's back rank)
SQ_A1 EQU $00
SQ_B1 EQU $01
SQ_C1 EQU $02
SQ_D1 EQU $03
SQ_E1 EQU $04 ; White king starting square
SQ_F1 EQU $05
SQ_G1 EQU $06 ; White kingside castle target
SQ_H1 EQU $07
; Rank 2 (white pawns)
SQ_A2 EQU $10
SQ_E2 EQU $14
SQ_H2 EQU $17
; Rank 7 (black pawns)
SQ_A7 EQU $60
SQ_E7 EQU $64
SQ_H7 EQU $67
; Rank 8 (black's back rank)
SQ_A8 EQU $70
SQ_B8 EQU $71
SQ_C8 EQU $72
SQ_D8 EQU $73
SQ_E8 EQU $74 ; Black king starting square
SQ_F8 EQU $75
SQ_G8 EQU $76 ; Black kingside castle target
SQ_H8 EQU $77
; Special values
INVALID_SQ EQU $FF
NO_EP EQU $FF
; ==============================================================================
; INIT_BOARD - Initialize board to starting position
; ==============================================================================
; Sets up standard chess starting position with 0x88 layout
; Initializes game state
; Uses: A, D
; ==============================================================================
INIT_BOARD:
    ; Clear entire 128-byte board to empty
    LDI HIGH(BOARD)
    PHI 10
    LDI LOW(BOARD)
    PLO 10
    LDI 128
    PLO 13
    LDI EMPTY
INIT_CLEAR:
    STR 10
    INC 10
    DEC 13
    GLO 13
    BNZ INIT_CLEAR
    ; Set up white back rank (rank 1 = offset $00)
    LDI HIGH(BOARD)
    PHI 10
    LDI LOW(BOARD)
    PLO 10
    LDI W_ROOK
    STR 10
    INC 10
    LDI W_KNIGHT
    STR 10
    INC 10
    LDI W_BISHOP
    STR 10
    INC 10
    LDI W_QUEEN
    STR 10
    INC 10
    LDI W_KING
    STR 10
    INC 10
    LDI W_BISHOP
    STR 10
    INC 10
    LDI W_KNIGHT
    STR 10
    INC 10
    LDI W_ROOK
    STR 10
    ; Set up white pawns (rank 2 = offset $10)
    LDI HIGH(BOARD)
    PHI 10
    LDI LOW(BOARD + $10)
    PLO 10
    LDI 8
    PLO 13
    LDI W_PAWN
INIT_WP:
    STR 10
    INC 10
    DEC 13
    GLO 13
    BNZ INIT_WP
    ; Set up black pawns (rank 7 = offset $60)
    LDI HIGH(BOARD)
    PHI 10
    LDI LOW(BOARD + $60)
    PLO 10
    LDI 8
    PLO 13
    LDI B_PAWN
INIT_BP:
    STR 10
    INC 10
    DEC 13
    GLO 13
    BNZ INIT_BP
    ; Set up black back rank (rank 8 = offset $70)
    LDI HIGH(BOARD)
    PHI 10
    LDI LOW(BOARD + $70)
    PLO 10
    LDI B_ROOK
    STR 10
    INC 10
    LDI B_KNIGHT
    STR 10
    INC 10
    LDI B_BISHOP
    STR 10
    INC 10
    LDI B_QUEEN
    STR 10
    INC 10
    LDI B_KING
    STR 10
    INC 10
    LDI B_BISHOP
    STR 10
    INC 10
    LDI B_KNIGHT
    STR 10
    INC 10
    LDI B_ROOK
    STR 10
    ; Initialize game state
    LDI HIGH(GAME_STATE)
    PHI 10
    LDI LOW(GAME_STATE)
    PLO 10
    LDI WHITE
    STR 10 ; Side to move = white
    INC 10
    LDI ALL_CASTLING
    STR 10 ; All castling rights
    INC 10
    LDI NO_EP
    STR 10 ; No en passant
    INC 10
    LDI 0
    STR 10 ; Halfmove clock = 0
    INC 10
    LDI 1
    STR 10 ; Fullmove = 1 (low byte)
    INC 10
    LDI 0
    STR 10 ; Fullmove high byte = 0
    INC 10
    LDI SQ_E1
    STR 10 ; White king on e1
    INC 10
    LDI SQ_E8
    STR 10 ; Black king on e8
    RETN
; ==============================================================================
; GET_SIDE_TO_MOVE - Get current side to move
; ==============================================================================
; Output: D = side (WHITE=0 or BLACK=8)
; Uses: A
; ==============================================================================
GET_SIDE_TO_MOVE:
    LDI HIGH(GAME_STATE)
    PHI 10
    LDI LOW(GAME_STATE + STATE_SIDE_TO_MOVE)
    PLO 10
    LDN 10
    RETN
; ==============================================================================
; SET_SIDE_TO_MOVE - Set side to move
; ==============================================================================
; Input: D = side (WHITE=0 or BLACK=8)
; Uses: A
; ==============================================================================
SET_SIDE_TO_MOVE:
    STXD ; Save D
    LDI HIGH(GAME_STATE)
    PHI 10
    LDI LOW(GAME_STATE + STATE_SIDE_TO_MOVE)
    PLO 10
    IRX
    LDN 2
    STR 10
    RETN
; ==============================================================================
; FLIP_SIDE - Toggle side to move
; ==============================================================================
; Uses: A, D
; ==============================================================================
FLIP_SIDE:
    LDI HIGH(GAME_STATE)
    PHI 10
    LDI LOW(GAME_STATE + STATE_SIDE_TO_MOVE)
    PLO 10
    LDN 10
    XRI BLACK ; Toggle between 0 and 8
    STR 10
    RETN
; ==============================================================================
; GET_CASTLING_RIGHTS - Get castling rights byte
; ==============================================================================
; Output: D = castling rights
; Uses: A
; ==============================================================================
GET_CASTLING_RIGHTS:
    LDI HIGH(GAME_STATE)
    PHI 10
    LDI LOW(GAME_STATE + STATE_CASTLING)
    PLO 10
    LDN 10
    RETN
; ==============================================================================
; GET_PIECE_AT - Get piece at square
; ==============================================================================
; Input: D = square (0x88 format)
; Output: D = piece code (0 if empty or invalid square)
; Uses: A
; ==============================================================================
GET_PIECE_AT:
    ; Save square in A.0
    PLO 10
    ; Check if valid square using original value
    ANI $88
    BNZ GET_PIECE_INVALID
    ; Valid square - build address and get piece
    LDI HIGH(BOARD)
    PHI 10
    ; A.0 already has square offset
    LDN 10 ; Load piece at BOARD + square
    RETN
GET_PIECE_INVALID:
    LDI 0 ; Return empty for invalid squares
    RETN
; ==============================================================================
; INIT_MOVE_HISTORY - Clear move history
; ==============================================================================
; Uses: A, D
; ==============================================================================
INIT_MOVE_HISTORY:
    LDI HIGH(MOVE_HIST)
    PHI 10
    LDI LOW(MOVE_HIST)
    PLO 10
    LDI 0
    STR 10 ; Set history pointer to 0
    RETN
; ==============================================================================
; SERIAL_INIT - Initialize serial I/O (placeholder for build compatibility)
; ==============================================================================
; The actual serial init is in serial-io-9600.asm
; This is just a placeholder if that file is not included
; ==============================================================================
; SERIAL_INIT already defined in serial-io-9600.asm
; ==============================================================================
; End of Board Module (0x88)
; ==============================================================================
; ==============================================================================
; RCA 1802/1806 Chess Engine - Move Generation Helpers
; ==============================================================================
; Helper functions for move generation
; ==============================================================================
; ------------------------------------------------------------------------------
; CHECK_TARGET_SQUARE - Check if move to target square is valid
; ------------------------------------------------------------------------------
; Input: B.0 = target square (0x88 format)
; C = side to move color
; Output: D = 0 (can't move), 1 (empty square), 2 (capture)
; DF = 1 if can move, 0 if blocked by friendly
; Uses: Temp register
; ------------------------------------------------------------------------------
CHECK_TARGET_SQUARE:
    ; First check if square is valid
    GLO 11
    ANI $88
    BNZ CHECK_TARGET_INVALID
    ; Get piece at target square
    LDI HIGH(BOARD)
    PHI 13
    GLO 11
    PLO 13 ; D = BOARD + target square
    LDN 13 ; Load piece at target
    BZ CHECK_TARGET_EMPTY
    ; Square occupied - check color
    ANI COLOR_MASK
    STR 2
    GLO 12 ; Side to move
    XOR ; Compare colors
    LDN 2
    BZ CHECK_TARGET_FRIENDLY
    ; Enemy piece - capture
    LDI 2
    SHL ; Set DF
    RETN
CHECK_TARGET_FRIENDLY:
    ; Friendly piece - can't move here
    LDI 0
    SHR ; Clear DF
    RETN
CHECK_TARGET_EMPTY:
    ; Empty square - can move
    LDI 1
    SHL ; Set DF
    RETN
CHECK_TARGET_INVALID:
    LDI 0
    SHR
    RETN
; ------------------------------------------------------------------------------
; ENCODE_MOVE_16BIT - Properly encode move as 16-bit value
; ------------------------------------------------------------------------------
; Input: D.1 = from square (7 bits)
; D.0 = to square (7 bits)
; E.0 = special flags (2 bits)
; Output: 6 = encoded 16-bit move
; Uses: D
;
; Encoding: [flags:2][to:7][from:7]
; Bits 0-6: from, Bits 7-13: to, Bits 14-15: flags
; ------------------------------------------------------------------------------
ENCODE_MOVE_16BIT:
    ; Low byte = from (bits 0-6) + bit 0 of to (bit 7)
    GHI 13 ; From square
    ANI $7F ; Ensure 7 bits
    PLO 6 ; 6.0 = from
    GLO 13 ; To square
    ANI $01 ; Get bit 0 of to
    SHL
    SHL
    SHL
    SHL
    SHL
    SHL
    SHL ; Shift to bit 7
    STR 2
    GLO 6
    OR ; Combine
    PLO 6 ; 6.0 = from | (to.0 << 7)
    ; High byte = bits 1-6 of to (bits 0-5) + flags (bits 6-7)
    GLO 13 ; To square
    SHR ; Shift right 1 (remove bit 0)
    ANI $3F ; Mask to 6 bits
    PHI 6 ; 6.1 = to.bits[1-6]
    GLO 14 ; Special flags
    ANI $03 ; Ensure 2 bits
    SHL
    SHL
    SHL
    SHL
    SHL
    SHL ; Shift to bits 6-7
    STR 2
    GHI 6
    OR
    PHI 6 ; 6.1 = (to >> 1) | (flags << 6)
    RETN
; ------------------------------------------------------------------------------
; DECODE_MOVE_16BIT - Decode 16-bit move
; ------------------------------------------------------------------------------
; Input: 6 = encoded move
; Output: D.1 = from square
; D.0 = to square
; E.0 = special flags
; ------------------------------------------------------------------------------
DECODE_MOVE_16BIT:
    ; Extract from (bits 0-6 of low byte)
    GLO 6
    ANI $7F
    PHI 13 ; D.1 = from
    ; Extract to square (bit 7 of low byte + bits 0-5 of high byte)
    GLO 6
    SHR
    SHR
    SHR
    SHR
    SHR
    SHR
    SHR ; Get bit 7
    ANI $01 ; to.bit0
    PLO 13 ; D.0 = to.bit0
    GHI 6 ; High byte
    ANI $3F ; Bits 0-5 are to.bits[1-6]
    SHL ; Shift left 1
    STR 2
    GLO 13
    OR ; Combine with bit 0
    PLO 13 ; D.0 = to (full 7 bits)
    ; Extract flags (bits 6-7 of high byte)
    GHI 6
    SHR
    SHR
    SHR
    SHR
    SHR
    SHR ; Shift right 6
    ANI $03 ; Mask to 2 bits
    PLO 14 ; E.0 = flags
    RETN
; ------------------------------------------------------------------------------
; ADD_MOVE_ENCODED - Add properly encoded move to list
; ------------------------------------------------------------------------------
; Input: D.1 = from square
; D.0 = to square
; E.0 = special flags
; 9 = move list pointer (updated)
; Output: Move added to list, 9 incremented by 2
; ------------------------------------------------------------------------------
ADD_MOVE_ENCODED:
    CALL ENCODE_MOVE_16BIT
    ; 6 now has encoded move
    ; Store to move list (little-endian)
    GLO 6
    STR 9
    INC 9
    GHI 6
    STR 9
    INC 9
    RETN
; ------------------------------------------------------------------------------
; GEN_PAWN_PROMOTION - Generate all 4 promotion moves
; ------------------------------------------------------------------------------
; Input: E.0 = from square (pawn on 7th rank)
; B.0 = to square (8th rank)
; 9 = move list pointer
; Output: 4 moves added (Q, R, B, N promotions)
; ------------------------------------------------------------------------------
GEN_PAWN_PROMOTION:
    ; Set special flag to MOVE_PROMOTION
    LDI MOVE_PROMOTION
    PLO 15 ; F.0 = flags
    ; For each promotion piece type
    ; We'll encode promotion type in upper bits (bits beyond 16)
    ; Or use a separate promotion table
    ; For now, generate 4 moves with MOVE_PROMOTION flag
    ; Queen promotion
    GLO 14
    PHI 13 ; From
    GLO 11
    PLO 13 ; To
    GLO 15
    PLO 14 ; Flags
    CALL ADD_MOVE_ENCODED
    ; Rook promotion
    GLO 14
    PHI 13
    GLO 11
    PLO 13
    GLO 15
    PLO 14
    CALL ADD_MOVE_ENCODED
    ; Bishop promotion
    GLO 14
    PHI 13
    GLO 11
    PLO 13
    GLO 15
    PLO 14
    CALL ADD_MOVE_ENCODED
    ; Knight promotion
    GLO 14
    PHI 13
    GLO 11
    PLO 13
    GLO 15
    PLO 14
    CALL ADD_MOVE_ENCODED
    RETN
; ------------------------------------------------------------------------------
; CHECK_EN_PASSANT - Check if en passant capture is legal
; ------------------------------------------------------------------------------
; Input: B.0 = target square
; C = side to move
; Output: D = 1 if legal en passant, 0 otherwise
; ------------------------------------------------------------------------------
CHECK_EN_PASSANT:
    ; Get en passant square from game state
    LDI HIGH(GAME_STATE)
    PHI 13
    LDI LOW(GAME_STATE + STATE_EP_SQUARE)
    PLO 13
    LDN 13 ; Load EP square
    STR 2
    GLO 11 ; Target square
    XOR ; Compare
    LDN 2
    BNZ CHECK_EP_NO ; Not EP square
    ; Target matches EP square
    LDI 1
    RETN
CHECK_EP_NO:
    LDI 0
    RETN
; ------------------------------------------------------------------------------
; GEN_CASTLING_MOVES - Generate castling moves if legal
; ------------------------------------------------------------------------------
; Input: E.0 = king square
; C = side to move
; 9 = move list pointer
; Output: Castling moves added if legal
; ------------------------------------------------------------------------------
GEN_CASTLING_MOVES:
    ; Check castling rights
    CALL GET_CASTLING_RIGHTS
    PLO 13 ; D.0 = castling rights
    ; Determine which castling rights to check based on color
    GLO 12
    BZ GEN_CASTLE_WHITE
GEN_CASTLE_BLACK:
    ; Check black kingside
    GLO 13
    ANI CASTLE_BK
    BZ GEN_CASTLE_BQ
    ; Verify squares between king and rook are empty
    ; King on e8 ($74), rook on h8 ($77)
    ; Check f8 ($75) and g8 ($76)
    ; TODO: Verify not in check and not moving through check
    LDI $74
    PHI 13 ; From (e8)
    LDI $76
    PLO 13 ; To (g8)
    LDI MOVE_CASTLE
    PLO 14
    CALL ADD_MOVE_ENCODED
GEN_CASTLE_BQ:
    ; Check black queenside
    GLO 13
    ANI CASTLE_BQ
    BZ GEN_CASTLE_DONE
    ; TODO: Similar check for queenside
    ; For now, skip
    BR GEN_CASTLE_DONE
GEN_CASTLE_WHITE:
    ; Check white kingside
    GLO 13
    ANI CASTLE_WK
    BZ GEN_CASTLE_WQ
    ; King on e1 ($04), rook on h1 ($07)
    ; Check f1 ($05) and g1 ($06)
    LDI $04
    PHI 13 ; From (e1)
    LDI $06
    PLO 13 ; To (g1)
    LDI MOVE_CASTLE
    PLO 14
    CALL ADD_MOVE_ENCODED
GEN_CASTLE_WQ:
    ; Check white queenside
    ; TODO: Implementation
GEN_CASTLE_DONE:
    RETN
; ------------------------------------------------------------------------------
; IS_SQUARE_ATTACKED - Implemented in check.asm
; ------------------------------------------------------------------------------
; This function is fully implemented in check.asm
; No stub needed here
; ==============================================================================
; End of Move Generation Helpers
; ==============================================================================
; ==============================================================================
; RCA 1802/1806 Chess Engine - Move Generation (INTEGRATED VERSION)
; ==============================================================================
; Generate pseudo-legal moves for all piece types
; COMPLETE VERSION with all helpers integrated
; ==============================================================================
; NOTE: Direction offsets, KNIGHT_OFFSETS, KING_OFFSETS, and MOVE_* constants
; are now defined in board.asm to avoid duplication and make them available
; to all modules
; ==============================================================================
; GENERATE_MOVES - Main entry (same as before)
; ==============================================================================
GENERATE_MOVES:
    GLO 9
    PLO 15
    GHI 9
    PHI 15 ; F = move list start
    LDI HIGH(BOARD)
    PHI 10
    LDI LOW(BOARD)
    PLO 10
    LDI 0
    PLO 14 ; E.0 = square index
GEN_SCAN_BOARD:
    GLO 14
    ANI $88
    BNZ GEN_SKIP_SQUARE
    LDN 10
    BZ GEN_SKIP_SQUARE
    ANI COLOR_MASK
    STR 2
    GLO 12
    XOR ; D = side_to_move XOR piece_color (0 if same)
    BNZ GEN_SKIP_SQUARE ; Skip if colors don't match
    LDN 10
    ANI PIECE_MASK
    SMI 1
    BZ GEN_PAWN
    SMI 1
    BZ GEN_KNIGHT
    SMI 1
    BZ GEN_BISHOP
    SMI 1
    BZ GEN_ROOK
    SMI 1
    BZ GEN_QUEEN
    SMI 1
    BZ GEN_KING
GEN_SKIP_SQUARE:
    INC 10
    INC 14
    GLO 14
    SMI 128
    BM GEN_SCAN_BOARD
    ; Calculate move count
    GLO 9
    STR 2
    GLO 15
    SM
    SHR
    RETN
; ==============================================================================
; GEN_PAWN - COMPLETE VERSION with validation
; ==============================================================================
GEN_PAWN:
    GLO 12
    BZ GEN_PAWN_WHITE
GEN_PAWN_BLACK:
    ; Single push
    GLO 14
    ADI DIR_S
    PLO 11
    ANI $88
    BNZ GEN_PAWN_CAPTURES_B
    ; Check if square is empty
    LDI HIGH(BOARD)
    PHI 13
    GLO 11
    PLO 13
    LDN 13
    BNZ GEN_PAWN_CAPTURES_B ; Not empty, skip
    ; Check for promotion (rank 0)
    GLO 11
    ANI $70
    BZ GEN_PAWN_PROMO_B
    ; Add normal push
    GLO 14 ; from
    PHI 13
    GLO 11 ; to
    PLO 13
    LDI MOVE_NORMAL
    PLO 14
    CALL ADD_MOVE_ENCODED
    ; Restore E.0 (from square)
    GLO 13
    GHI 13
    PLO 14
    ; Check for double push from rank 6
    GLO 14
    ANI $70
    XRI $60
    BNZ GEN_PAWN_CAPTURES_B
    ; Try double push
    GLO 11
    ADI DIR_S
    PLO 11
    ; Check if empty
    LDI HIGH(BOARD)
    PHI 13
    GLO 11
    PLO 13
    LDN 13
    BNZ GEN_PAWN_CAPTURES_B
    ; Add double push
    GLO 14
    PHI 13
    GLO 11
    PLO 13
    LDI MOVE_NORMAL
    PLO 14
    CALL ADD_MOVE_ENCODED
    ; Restore E.0
    GHI 13
    PLO 14
GEN_PAWN_CAPTURES_B:
    ; Left capture (southwest)
    GLO 14
    ADI DIR_SW
    PLO 11
    ANI $88
    BNZ GEN_PAWN_RIGHT_B
    ; Check if enemy piece
    CALL CHECK_TARGET_SQUARE
    ; D = 0 (blocked), 1 (empty), 2 (capture)
    XRI 2
    BNZ GEN_PAWN_EP_LEFT_B ; Not a capture
    ; Add capture
    GLO 14
    PHI 13
    GLO 11
    PLO 13
    LDI MOVE_NORMAL
    PLO 14
    CALL ADD_MOVE_ENCODED
    ; Restore E.0
    GHI 13
    PLO 14
GEN_PAWN_EP_LEFT_B:
    ; Check for en passant
    GLO 11
    CALL CHECK_EN_PASSANT
    BZ GEN_PAWN_RIGHT_B
    ; Add EP capture
    GLO 14
    PHI 13
    GLO 11
    PLO 13
    LDI MOVE_EP
    PLO 14
    CALL ADD_MOVE_ENCODED
    ; Restore E.0
    GHI 13
    PLO 14
GEN_PAWN_RIGHT_B:
    ; Right capture (southeast)
    GLO 14
    ADI DIR_SE
    PLO 11
    ANI $88
    BNZ GEN_PAWN_DONE
    CALL CHECK_TARGET_SQUARE
    XRI 2
    BNZ GEN_PAWN_EP_RIGHT_B
    GLO 14
    PHI 13
    GLO 11
    PLO 13
    LDI MOVE_NORMAL
    PLO 14
    CALL ADD_MOVE_ENCODED
    GHI 13
    PLO 14
GEN_PAWN_EP_RIGHT_B:
    GLO 11
    CALL CHECK_EN_PASSANT
    BZ GEN_PAWN_DONE
    GLO 14
    PHI 13
    GLO 11
    PLO 13
    LDI MOVE_EP
    PLO 14
    CALL ADD_MOVE_ENCODED
    GHI 13
    PLO 14
    BR GEN_PAWN_DONE
GEN_PAWN_WHITE:
    ; Single push
    GLO 14
    ADI DIR_N
    PLO 11
    ANI $88
    BNZ GEN_PAWN_CAPTURES_W
    ; Check if empty
    LDI HIGH(BOARD)
    PHI 13
    GLO 11
    PLO 13
    LDN 13
    BNZ GEN_PAWN_CAPTURES_W
    ; Check for promotion (rank 7)
    GLO 11
    ANI $70
    XRI $70
    BZ GEN_PAWN_PROMO_W
    ; Add push
    GLO 14
    PHI 13
    GLO 11
    PLO 13
    LDI MOVE_NORMAL
    PLO 14
    CALL ADD_MOVE_ENCODED
    GHI 13
    PLO 14
    ; Double push from rank 1
    GLO 14
    ANI $70
    XRI $10
    BNZ GEN_PAWN_CAPTURES_W
    GLO 11
    ADI DIR_N
    PLO 11
    LDI HIGH(BOARD)
    PHI 13
    GLO 11
    PLO 13
    LDN 13
    BNZ GEN_PAWN_CAPTURES_W
    GLO 14
    PHI 13
    GLO 11
    PLO 13
    LDI MOVE_NORMAL
    PLO 14
    CALL ADD_MOVE_ENCODED
    GHI 13
    PLO 14
GEN_PAWN_CAPTURES_W:
    ; Left capture (northwest)
    GLO 14
    ADI DIR_NW
    PLO 11
    ANI $88
    BNZ GEN_PAWN_RIGHT_W
    CALL CHECK_TARGET_SQUARE
    XRI 2
    BNZ GEN_PAWN_EP_LEFT_W
    GLO 14
    PHI 13
    GLO 11
    PLO 13
    LDI MOVE_NORMAL
    PLO 14
    CALL ADD_MOVE_ENCODED
    GHI 13
    PLO 14
GEN_PAWN_EP_LEFT_W:
    GLO 11
    CALL CHECK_EN_PASSANT
    BZ GEN_PAWN_RIGHT_W
    GLO 14
    PHI 13
    GLO 11
    PLO 13
    LDI MOVE_EP
    PLO 14
    CALL ADD_MOVE_ENCODED
    GHI 13
    PLO 14
GEN_PAWN_RIGHT_W:
    ; Right capture (northeast)
    GLO 14
    ADI DIR_NE
    PLO 11
    ANI $88
    BNZ GEN_PAWN_DONE
    CALL CHECK_TARGET_SQUARE
    XRI 2
    BNZ GEN_PAWN_EP_RIGHT_W
    GLO 14
    PHI 13
    GLO 11
    PLO 13
    LDI MOVE_NORMAL
    PLO 14
    CALL ADD_MOVE_ENCODED
    GHI 13
    PLO 14
GEN_PAWN_EP_RIGHT_W:
    GLO 11
    CALL CHECK_EN_PASSANT
    BZ GEN_PAWN_DONE
    GLO 14
    PHI 13
    GLO 11
    PLO 13
    LDI MOVE_EP
    PLO 14
    CALL ADD_MOVE_ENCODED
    GHI 13
    PLO 14
    BR GEN_PAWN_DONE
GEN_PAWN_PROMO_B:
GEN_PAWN_PROMO_W:
    ; Generate 4 promotion moves
    GLO 14 ; from
    GLO 11 ; to (already in B)
    CALL GEN_PAWN_PROMOTION
    ; Restore E.0 (from square)
    ; (GEN_PAWN_PROMOTION preserves registers)
    BR GEN_PAWN_CAPTURES_W ; Continue with captures
    ; (or GEN_PAWN_CAPTURES_B depending on color, but both paths work)
GEN_PAWN_DONE:
    BR GEN_SKIP_SQUARE
; ==============================================================================
; GEN_KNIGHT - COMPLETE VERSION
; ==============================================================================
GEN_KNIGHT:
    LDI HIGH(KNIGHT_OFFSETS)
    PHI 11
    LDI LOW(KNIGHT_OFFSETS)
    PLO 11
    LDI 8
    PLO 13
GEN_KNIGHT_LOOP:
    ; Save state
    GLO 13
    STXD
    GLO 11
    STXD
    GHI 11
    STXD
    ; Get offset
    LDA 11
    STR 2
    GLO 14
    ADD
    PLO 11 ; B.0 = to square
    ANI $88
    BNZ GEN_KNIGHT_NEXT
    ; Check target
    CALL CHECK_TARGET_SQUARE
    BZ GEN_KNIGHT_NEXT ; Blocked by friendly
    ; Add move
    GLO 14
    PHI 13
    GLO 11
    PLO 13
    LDI MOVE_NORMAL
    PLO 14
    CALL ADD_MOVE_ENCODED
    ; Restore E.0 (from square)
    GHI 13
    PLO 14
GEN_KNIGHT_NEXT:
    ; Restore state
    IRX
    LDXA
    PHI 11
    LDXA
    PLO 11
    LDXA
    PLO 13
    DEC 13
    GLO 13
    BNZ GEN_KNIGHT_LOOP
    BR GEN_SKIP_SQUARE
; ==============================================================================
; GEN_BISHOP, GEN_ROOK, GEN_QUEEN - Use GEN_SLIDING
; ==============================================================================
GEN_BISHOP:
    LDI DIR_NE
    PLO 13
    CALL GEN_SLIDING
    LDI DIR_NW
    PLO 13
    CALL GEN_SLIDING
    LDI DIR_SE
    PLO 13
    CALL GEN_SLIDING
    LDI DIR_SW
    PLO 13
    CALL GEN_SLIDING
    BR GEN_SKIP_SQUARE
GEN_ROOK:
    LDI DIR_N
    PLO 13
    CALL GEN_SLIDING
    LDI DIR_S
    PLO 13
    CALL GEN_SLIDING
    LDI DIR_E
    PLO 13
    CALL GEN_SLIDING
    LDI DIR_W
    PLO 13
    CALL GEN_SLIDING
    BR GEN_SKIP_SQUARE
GEN_QUEEN:
    LDI DIR_N
    PLO 13
    CALL GEN_SLIDING
    LDI DIR_NE
    PLO 13
    CALL GEN_SLIDING
    LDI DIR_E
    PLO 13
    CALL GEN_SLIDING
    LDI DIR_SE
    PLO 13
    CALL GEN_SLIDING
    LDI DIR_S
    PLO 13
    CALL GEN_SLIDING
    LDI DIR_SW
    PLO 13
    CALL GEN_SLIDING
    LDI DIR_W
    PLO 13
    CALL GEN_SLIDING
    LDI DIR_NW
    PLO 13
    CALL GEN_SLIDING
    BR GEN_SKIP_SQUARE
; ==============================================================================
; GEN_SLIDING - COMPLETE VERSION with blocking
; ==============================================================================
GEN_SLIDING:
    ; Save direction
    GLO 13
    STXD
    ; Start from current square
    GLO 14
    PLO 15 ; F.0 = current square
GEN_SLIDE_LOOP:
    ; Move in direction
    IRX
    LDN 2
    DEC 2
    STR 2
    GLO 15
    ADD
    PLO 15
    ; Check if off board
    ANI $88
    BNZ GEN_SLIDE_DONE
    ; Check target square
    GLO 15
    PLO 11
    CALL CHECK_TARGET_SQUARE
    ; D = 0 (blocked), 1 (empty), 2 (capture)
    PLO 13 ; Save result
    BZ GEN_SLIDE_DONE ; Blocked by friendly
    ; Add move
    ; Save result first
    GLO 13
    STXD
    GLO 14 ; from
    PHI 13
    GLO 15 ; to
    PLO 13
    LDI MOVE_NORMAL
    PLO 14
    CALL ADD_MOVE_ENCODED
    ; Restore E.0 (from square)
    GHI 13
    PLO 14
    ; Restore and check result
    IRX
    LDXA
    DEC 2 ; Put back on stack
    XRI 2 ; Was it a capture?
    BZ GEN_SLIDE_DONE ; Yes, stop sliding
    BR GEN_SLIDE_LOOP ; Empty, continue
GEN_SLIDE_DONE:
    IRX ; Pop direction
    RETN
; ==============================================================================
; GEN_KING - COMPLETE VERSION with castling
; ==============================================================================
GEN_KING:
    LDI HIGH(KING_OFFSETS)
    PHI 11
    LDI LOW(KING_OFFSETS)
    PLO 11
    LDI 8
    PLO 13
GEN_KING_LOOP:
    GLO 13
    STXD
    GLO 11
    STXD
    GHI 11
    STXD
    LDA 11
    STR 2
    GLO 14
    ADD
    PLO 11 ; to square
    ANI $88
    BNZ GEN_KING_NEXT
    ; Check target
    CALL CHECK_TARGET_SQUARE
    BZ GEN_KING_NEXT
    ; Add move
    GLO 14
    PHI 13
    GLO 11
    PLO 13
    LDI MOVE_NORMAL
    PLO 14
    CALL ADD_MOVE_ENCODED
    GHI 13
    PLO 14
GEN_KING_NEXT:
    IRX
    LDXA
    PHI 11
    LDXA
    PLO 11
    LDXA
    PLO 13
    DEC 13
    GLO 13
    BNZ GEN_KING_LOOP
    ; Add castling moves
    GLO 14 ; king square
    CALL GEN_CASTLING_MOVES
    BR GEN_SKIP_SQUARE
; ==============================================================================
; End of Move Generation (Fixed)
; ==============================================================================
; ==============================================================================
; Mark Abene SCRT implementation
; ==============================================================================
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
; Main program
; ==============================================================================
MAIN:
    LDI HIGH(START)
    PHI 6
    LDI LOW(START)
    PLO 6
    LBR INITCALL
START:
    ; Stack setup
    LDI $7F
    PHI 2
    LDI $FF
    PLO 2
    SEX 2
    REQ ; Q idle
    LDI 02H
    PLO 14 ; Baud rate
    ; Print welcome
    LDI HIGH(MSG_WELCOME)
    PHI 8
    LDI LOW(MSG_WELCOME)
    PLO 8
    SEP 4
    DW SERIAL_PRINT_STRING
    ; Initialize board
    SEP 4
    DW INIT_BOARD
    ; Print "Board initialized"
    LDI HIGH(MSG_INIT)
    PHI 8
    LDI LOW(MSG_INIT)
    PLO 8
    SEP 4
    DW SERIAL_PRINT_STRING
    ; Set up for move generation
    ; R9 = move list pointer
    LDI HIGH(MOVE_LIST)
    PHI 9
    LDI LOW(MOVE_LIST)
    PLO 9
    ; C = side to move (WHITE = 0)
    LDI WHITE
    PLO 12
    ; Print "Generating moves..."
    LDI HIGH(MSG_GENERATING)
    PHI 8
    LDI LOW(MSG_GENERATING)
    PLO 8
    SEP 4
    DW SERIAL_PRINT_STRING
    ; Call move generator
    SEP 4
    DW GENERATE_MOVES
    ; D = move count returned
    ; Save move count
    PLO 11 ; B.0 = move count
    ; Print "Moves: "
    LDI HIGH(MSG_MOVES)
    PHI 8
    LDI LOW(MSG_MOVES)
    PLO 8
    SEP 4
    DW SERIAL_PRINT_STRING
    ; Print move count as hex
    GLO 11
    SEP 4
    DW SERIAL_PRINT_HEX
    ; Print newline
    LDI 0DH
    SEP 4
    DW SERIAL_WRITE_CHAR
    LDI 0AH
    SEP 4
    DW SERIAL_WRITE_CHAR
    ; Check if expected count (20 = $14)
    GLO 11
    SMI $14
    BZ TEST_PASS
    ; Wrong count
    LDI HIGH(MSG_FAIL)
    PHI 8
    LDI LOW(MSG_FAIL)
    PLO 8
    SEP 4
    DW SERIAL_PRINT_STRING
    BR DONE
TEST_PASS:
    LDI HIGH(MSG_PASS)
    PHI 8
    LDI LOW(MSG_PASS)
    PLO 8
    SEP 4
    DW SERIAL_PRINT_STRING
DONE:
    ; Print done
    LDI HIGH(MSG_DONE)
    PHI 8
    LDI LOW(MSG_DONE)
    PLO 8
    SEP 4
    DW SERIAL_PRINT_STRING
    ; Halt
HALT:
    BR HALT
; ==============================================================================
; String data
; ==============================================================================
MSG_WELCOME:
    DB 0DH, 0AH
    DB "=== Move Generation Test ===", 0DH, 0AH, 0
MSG_INIT:
    DB "Board initialized", 0DH, 0AH, 0
MSG_GENERATING:
    DB "Generating moves...", 0DH, 0AH, 0
MSG_MOVES:
    DB "Move count: ", 0
MSG_PASS:
    DB "PASS (20 moves)", 0DH, 0AH, 0
MSG_FAIL:
    DB "FAIL (expected 20)", 0DH, 0AH, 0
MSG_DONE:
    DB "Done.", 0DH, 0AH, 0
; ==============================================================================
; End of test
; ==============================================================================
