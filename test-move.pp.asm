; ==============================================================================
; Move Parsing Test
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
; ==============================================================================
; BOARD MODULE - Chess board representation and display
; ==============================================================================
; ------------------------------------------------------------------------------
; Piece encoding constants
; ------------------------------------------------------------------------------
EMPTY EQU 00H
PAWN EQU 01H
KNIGHT EQU 02H
BISHOP EQU 03H
ROOK EQU 04H
QUEEN EQU 05H
KING EQU 06H
BLACK EQU 80H ; OR with piece type for black pieces
COLOR_MASK EQU 80H
PIECE_MASK EQU 0FH
; Black pieces
BPAWN EQU 81H
BKNIGHT EQU 82H
BBISHOP EQU 83H
BROOK EQU 84H
BQUEEN EQU 85H
BKING EQU 86H
; Castling flags
WK_CASTLE EQU 01H ; White kingside
WQ_CASTLE EQU 02H ; White queenside
BK_CASTLE EQU 04H ; Black kingside
BQ_CASTLE EQU 08H ; Black queenside
; Special values
NO_EP EQU 0FFH ; No en passant square
; ==============================================================================
; BOARD_INIT - Initialize board to starting position
; ==============================================================================
BOARD_INIT:
    ; Set up black back rank (indices 0-7)
    LDI HIGH(BOARD)
    PHI 8
    LDI LOW(BOARD)
    PLO 8
    LDI BROOK
    STR 8
    INC 8
    LDI BKNIGHT
    STR 8
    INC 8
    LDI BBISHOP
    STR 8
    INC 8
    LDI BQUEEN
    STR 8
    INC 8
    LDI BKING
    STR 8
    INC 8
    LDI BBISHOP
    STR 8
    INC 8
    LDI BKNIGHT
    STR 8
    INC 8
    LDI BROOK
    STR 8
    INC 8
    ; Black pawns (indices 8-15)
    LDI 8
    PLO 9
BI_BPAWNS:
    LDI BPAWN
    STR 8
    INC 8
    DEC 9
    GLO 9
    BNZ BI_BPAWNS
    ; Empty squares (indices 16-47)
    LDI 32
    PLO 9
BI_EMPTY:
    LDI EMPTY
    STR 8
    INC 8
    DEC 9
    GLO 9
    BNZ BI_EMPTY
    ; White pawns (indices 48-55)
    LDI 8
    PLO 9
BI_WPAWNS:
    LDI PAWN
    STR 8
    INC 8
    DEC 9
    GLO 9
    BNZ BI_WPAWNS
    ; White back rank (indices 56-63)
    LDI ROOK
    STR 8
    INC 8
    LDI KNIGHT
    STR 8
    INC 8
    LDI BISHOP
    STR 8
    INC 8
    LDI QUEEN
    STR 8
    INC 8
    LDI KING
    STR 8
    INC 8
    LDI BISHOP
    STR 8
    INC 8
    LDI KNIGHT
    STR 8
    INC 8
    LDI ROOK
    STR 8
    ; Initialize game state
    LDI HIGH(SIDE)
    PHI 8
    LDI LOW(SIDE)
    PLO 8
    LDI 00H ; White to move
    STR 8
    INC 8
    LDI WK_CASTLE+WQ_CASTLE+BK_CASTLE+BQ_CASTLE ; All castling available
    STR 8
    INC 8
    LDI NO_EP ; No en passant
    STR 8
    INC 8
    LDI 00H ; Halfmove clock = 0
    STR 8
    INC 8
    ; King squares: White=60 (e1), Black=4 (e8)
    LDI 60 ; White king on e1
    STR 8
    INC 8
    LDI 4 ; Black king on e8
    STR 8
    SEP 5 ; Return
; ==============================================================================
; BOARD_PRINT - Print the board to serial
; Uses R8, R9, R12 (R10 reserved for PIECE_TO_CHAR)
; ==============================================================================
BOARD_PRINT:
    ; Print newline first
    LDI 0DH
    SEP 4
    DW SERIAL_WRITE_CHAR
    LDI 0AH
    SEP 4
    DW SERIAL_WRITE_CHAR
    ; R9.0 = square index (0-63)
    ; R9.1 = rank counter (8 down to 1)
    LDI 0
    PLO 9
    LDI 8
    PHI 9
BP_RANK_LOOP:
    ; Print rank number
    GHI 9
    ADI '0' ; Convert to ASCII
    SEP 4
    DW SERIAL_WRITE_CHAR
    LDI ' '
    SEP 4
    DW SERIAL_WRITE_CHAR
    ; Print 8 squares for this rank
    LDI 8
    PLO 12 ; File counter in R12 (R10 used by PIECE_TO_CHAR)
BP_FILE_LOOP:
    ; Get piece at current square
    LDI HIGH(BOARD)
    PHI 8
    LDI LOW(BOARD)
    PLO 8
    SEX 2
    GLO 9 ; Square index
    STR 2
    GLO 8
    ADD
    PLO 8
    GHI 8
    ADCI 0
    PHI 8
    LDN 8 ; D = piece at square
    ; Convert piece to character
    SEP 4
    DW PIECE_TO_CHAR
    ; Print the character
    SEP 4
    DW SERIAL_WRITE_CHAR
    LDI ' '
    SEP 4
    DW SERIAL_WRITE_CHAR
    ; Next square
    INC 9
    DEC 12
    GLO 12
    BNZ BP_FILE_LOOP
    ; End of rank - print newline
    LDI 0DH
    SEP 4
    DW SERIAL_WRITE_CHAR
    LDI 0AH
    SEP 4
    DW SERIAL_WRITE_CHAR
    ; Next rank
    GHI 9
    SMI 1
    PHI 9
    BNZ BP_RANK_LOOP
    ; Print file labels
    LDI HIGH(STR_FILES)
    PHI 8
    LDI LOW(STR_FILES)
    PLO 8
    SEP 4
    DW SERIAL_PRINT_STRING
    SEP 5 ; Return
; ==============================================================================
; PIECE_TO_CHAR - Convert piece code to ASCII character
; Input: D = piece code
; Output: D = ASCII character
; Uses lookup table approach
; ==============================================================================
PIECE_TO_CHAR:
    LBZ PTC_EMPTY ; Empty square - quick exit (use long branch)
    PLO 10 ; Save piece in R10.0
    ANI PIECE_MASK ; Get piece type (1-6)
    ; Use piece type as index into character table
    SMI 1 ; Adjust to 0-based (PAWN=0, KNIGHT=1, etc)
    LBNF PTC_UNKNOWN ; If negative, unknown piece (long branch)
    ; Bounds check - piece type must be 0-5
    SMI 6
    LBDF PTC_UNKNOWN ; If >= 6, unknown piece
    ADI 6 ; Restore index
    ; Load character from table
    PHI 10 ; Save index in R10.1
    LDI HIGH(PTC_TABLE)
    PHI 8
    LDI LOW(PTC_TABLE)
    PLO 8
    SEX 2
    GHI 10 ; Get index
    STR 2
    GLO 8
    ADD
    PLO 8
    LDN 8 ; D = character from table
    BR PTC_CHECK_COLOR
PTC_UNKNOWN:
    LDI '?'
    SEP 5
PTC_EMPTY:
    LDI '.'
    SEP 5
PTC_CHECK_COLOR:
    ; D has uppercase letter, R10.0 has original piece
    PLO 8 ; Save letter in R8.0
    GLO 10 ; Get original piece
    ANI COLOR_MASK ; Check color bit
    BZ PTC_WHITE ; White piece - keep uppercase
    ; Black piece - convert to lowercase (add 20H)
    GLO 8
    ADI 20H
    SEP 5
PTC_WHITE:
    GLO 8
    SEP 5
; Character lookup table (index 0-5 = PAWN..KING)
PTC_TABLE:
    DB 'P', 'N', 'B', 'R', 'Q', 'K'
; ==============================================================================
; String constants
; ==============================================================================
STR_FILES:
    DB "  a b c d e f g h", 0DH, 0AH, 0
; ==============================================================================
; Game state data
; ==============================================================================
BOARD:
    DS 64 ; 64 squares
SIDE:
    DS 1 ; Side to move (00=White, 80=Black)
CASTLING:
    DS 1 ; Castling rights
EP_SQUARE:
    DS 1 ; En passant target square
HALFMOVE:
    DS 1 ; Halfmove clock
KING_SQ:
    DS 2 ; King squares [0]=White, [1]=Black
; ==============================================================================
; END OF BOARD MODULE
; ==============================================================================
; ==============================================================================
; MOVE MODULE - Move parsing and representation
; ==============================================================================
; ------------------------------------------------------------------------------
; Move structure (stored in MOVE_FROM, MOVE_TO)
; From square: 0-63
; To square: 0-63
; Special flags can be added later for promotion, castling, etc.
; ------------------------------------------------------------------------------
; ==============================================================================
; PARSE_SQUARE - Convert algebraic notation to square index
; Input: R8 points to 2-character string (e.g., "e2")
; Output: D = square index (0-63), or FFH if invalid
; R8 advanced by 2
; ==============================================================================
PARSE_SQUARE:
    ; Get file character (a-h)
    LDA 8 ; Load file char, advance R8
    SMI 'a' ; Convert to 0-7
    BM PS_INVALID ; If negative, invalid
    SMI 8 ; Check if >= 8
    BDF PS_INVALID ; If >= 8, invalid
    ADI 8 ; Restore 0-7 value
    PLO 10 ; Save file in R10.0
    ; Get rank character (1-8)
    LDA 8 ; Load rank char, advance R8
    SMI '1' ; Convert to 0-7
    BM PS_INVALID ; If negative, invalid
    SMI 8 ; Check if >= 8
    BDF PS_INVALID ; If >= 8, invalid
    ADI 8 ; Restore 0-7 value
    ; Convert rank 1-8 to internal 7-0
    ; rank_internal = 7 - rank = 7 - (char - '1')
    STR 2 ; Store rank (0-7) on stack
    LDI 7
    SM ; D = 7 - rank
    ; Calculate index = rank_internal * 8 + file
    ; Multiply by 8 = shift left 3 times
    SHL
    SHL
    SHL
    STR 2 ; Store rank*8 on stack
    GLO 10 ; Get file
    ADD ; D = rank*8 + file
    SEP 5 ; Return with index in D
PS_INVALID:
    LDI 0FFH ; Return FFH for invalid
    SEP 5
; ==============================================================================
; PARSE_MOVE - Parse 4-character move string (e.g., "e2e4")
; Input: R8 points to move string
; Output: MOVE_FROM = from square, MOVE_TO = to square
; D = 0 if valid, FFH if invalid
; R8 advanced by 4
; ==============================================================================
PARSE_MOVE:
    ; Parse "from" square
    SEP 4
    DW PARSE_SQUARE
    ; Check if valid
    ADI 1 ; FFH + 1 = 0 with carry
    BZ PM_INVALID ; If was FFH, invalid
    SMI 1 ; Restore value
    ; Store "from" square
    PHI 10 ; Save in R10.1 temporarily
    ; Parse "to" square
    SEP 4
    DW PARSE_SQUARE
    ; Check if valid
    ADI 1
    BZ PM_INVALID
    SMI 1 ; Restore value
    ; Store both squares
    PLO 9 ; Save "to" in R9.0 temporarily
    LDI HIGH(MOVE_FROM)
    PHI 8
    LDI LOW(MOVE_FROM)
    PLO 8
    GHI 10 ; Get "from"
    STR 8
    INC 8
    GLO 9 ; Get "to"
    STR 8
    LDI 0 ; Return success
    SEP 5
PM_INVALID:
    LDI 0FFH ; Return invalid
    SEP 5
; ==============================================================================
; PRINT_SQUARE - Print square in algebraic notation
; Input: D = square index (0-63)
; Output: Prints 2 characters (e.g., "e2")
; ==============================================================================
PRINT_SQUARE:
    PLO 10 ; Save square in R10.0
    ; Calculate file = index AND 7
    ANI 07H
    ADI 'a' ; Convert to 'a'-'h'
    SEP 4
    DW SERIAL_WRITE_CHAR
    ; Calculate rank = 8 - (index >> 3)
    GLO 10 ; Get square
    SHR ; Divide by 8
    SHR
    SHR
    STR 2 ; Store on stack
    LDI 8
    SM ; D = 8 - (index/8)
    ADI '0' ; Convert to '1'-'8'
    SEP 4
    DW SERIAL_WRITE_CHAR
    SEP 5
; ==============================================================================
; PRINT_MOVE - Print move in algebraic notation
; Input: MOVE_FROM and MOVE_TO contain the move
; Output: Prints 4 characters (e.g., "e2e4")
; ==============================================================================
PRINT_MOVE:
    LDI HIGH(MOVE_FROM)
    PHI 8
    LDI LOW(MOVE_FROM)
    PLO 8
    LDA 8 ; Get "from" square
    SEP 4
    DW PRINT_SQUARE
    LDN 8 ; Get "to" square
    SEP 4
    DW PRINT_SQUARE
    SEP 5
; ==============================================================================
; Move data storage
; ==============================================================================
MOVE_FROM:
    DS 1 ; From square (0-63)
MOVE_TO:
    DS 1 ; To square (0-63)
; ==============================================================================
; END OF MOVE MODULE
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
    ; Initialize and display board
    SEP 4
    DW BOARD_INIT
    SEP 4
    DW BOARD_PRINT
MOVE_LOOP:
    ; Prompt for move
    LDI HIGH(MSG_PROMPT)
    PHI 8
    LDI LOW(MSG_PROMPT)
    PLO 8
    SEP 4
    DW SERIAL_PRINT_STRING
    ; Read move input
    LDI HIGH(INPUT_BUF)
    PHI 8
    LDI LOW(INPUT_BUF)
    PLO 8
    LDI 8 ; Max 8 chars
    PLO 9
    SEP 4
    DW SERIAL_READ_LINE
    ; Parse the move
    LDI HIGH(INPUT_BUF)
    PHI 8
    LDI LOW(INPUT_BUF)
    PLO 8
    SEP 4
    DW PARSE_MOVE
    ; Check if valid
    BNZ MOVE_INVALID
    ; Valid move - print confirmation
    LDI HIGH(MSG_PARSED)
    PHI 8
    LDI LOW(MSG_PARSED)
    PLO 8
    SEP 4
    DW SERIAL_PRINT_STRING
    ; Print the move back
    SEP 4
    DW PRINT_MOVE
    ; Print indices
    LDI HIGH(MSG_FROM)
    PHI 8
    LDI LOW(MSG_FROM)
    PLO 8
    SEP 4
    DW SERIAL_PRINT_STRING
    ; Print from index as hex
    LDI HIGH(MOVE_FROM)
    PHI 8
    LDI LOW(MOVE_FROM)
    PLO 8
    LDN 8
    SEP 4
    DW SERIAL_PRINT_HEX
    LDI HIGH(MSG_TO)
    PHI 8
    LDI LOW(MSG_TO)
    PLO 8
    SEP 4
    DW SERIAL_PRINT_STRING
    ; Print to index as hex
    LDI HIGH(MOVE_TO)
    PHI 8
    LDI LOW(MOVE_TO)
    PLO 8
    LDN 8
    SEP 4
    DW SERIAL_PRINT_HEX
    ; Newline
    LDI 0DH
    SEP 4
    DW SERIAL_WRITE_CHAR
    LDI 0AH
    SEP 4
    DW SERIAL_WRITE_CHAR
    BR MOVE_LOOP
MOVE_INVALID:
    LDI HIGH(MSG_INVALID)
    PHI 8
    LDI LOW(MSG_INVALID)
    PLO 8
    SEP 4
    DW SERIAL_PRINT_STRING
    BR MOVE_LOOP
; ==============================================================================
; String data
; ==============================================================================
MSG_WELCOME:
    DB "Move Parser Test", 0DH, 0AH, 0
MSG_PROMPT:
    DB "Enter move (e.g. e2e4): ", 0
MSG_PARSED:
    DB "Parsed: ", 0
MSG_FROM:
    DB " (from=", 0
MSG_TO:
    DB ", to=", 0
MSG_INVALID:
    DB "Invalid move!", 0DH, 0AH, 0
INPUT_BUF:
    DS 8
    END MAIN
