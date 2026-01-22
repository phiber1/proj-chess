; ==============================================================================
; RCA 1802/1806 Chess Engine - UCI Protocol Implementation
; ==============================================================================
; Universal Chess Interface for communication with GUI
; Implements minimal UCI subset for playability
; ==============================================================================

; ------------------------------------------------------------------------------
; UCI Command Buffer - defined in board-0x88.asm
; ------------------------------------------------------------------------------
; UCI_BUFFER ($6900) and UCI_STATE ($6A00) defined in board-0x88.asm
; All engine variables consolidated at $6800+ region
UCI_BUFFER_LEN  EQU 255     ; Max chars (fits in 8-bit comparison)
UCI_READY       EQU 1       ; Ready state

; ------------------------------------------------------------------------------
; UCI String Constants
; ------------------------------------------------------------------------------
; These would be defined as byte arrays in actual implementation

STR_UCI         DB "uci", 0
STR_ISREADY     DB "isready", 0
STR_POSITION    DB "position", 0
STR_GO          DB "go", 0
STR_QUIT        DB "quit", 0
STR_UCINEWGAME  DB "ucinewgame", 0
STR_STOP        DB "stop", 0

; Response strings (CR+LF for terminal display)
STR_ID_NAME     DB "id name RCA-Chess-1806", 13, 10, 0
STR_ID_AUTHOR   DB "id author Claude Code", 13, 10, 0
STR_UCIOK       DB "uciok", 13, 10, 0
STR_READYOK     DB "readyok", 13, 10, 0
STR_BESTMOVE    DB "bestmove ", 0

; ------------------------------------------------------------------------------
; UCI_INIT - Initialize UCI interface
; ------------------------------------------------------------------------------
UCI_INIT:
    ; Set up serial I/O (if needed)
    ; TODO: Hardware-specific initialization

    ; Set initial state
    LDI UCI_READY
    PLO 13

    LDI HIGH(UCI_STATE)
    PHI 10
    LDI LOW(UCI_STATE)
    PLO 10

    GLO 13
    STR 10

    RETN

; ------------------------------------------------------------------------------
; UCI_READ_LINE - Read a line of input
; ------------------------------------------------------------------------------
; Input:  None
; Output: Line in UCI_BUFFER, null-terminated
;         D = length
; Uses:   A, D
;
; Reads characters until newline or max length
; ------------------------------------------------------------------------------
UCI_READ_LINE:
    LDI HIGH(UCI_BUFFER)
    PHI 10
    LDI LOW(UCI_BUFFER)
    PLO 10              ; A = buffer pointer

    LDI 0
    PLO 13              ; D.0 = character count

UCI_READ_LOOP:
    ; Read character from serial input
    CALL SERIAL_READ_CHAR
    ; Returns character in D

    ; Check for carriage return (CR = 13)
    SMI 13
    LBZ UCI_READ_DONE

    ; Check for newline (LF = 10) - restore D first
    ADI 13              ; Restore: (D-13)+13 = D
    SMI 10              ; Check for LF
    LBZ UCI_READ_DONE
    ADI 10              ; Restore D

    ; Store character
    STR 10
    INC 10

    ; Increment count
    INC 13

    ; Check buffer limit
    GLO 13
    XRI UCI_BUFFER_LEN
    LBZ UCI_READ_DONE

    LBR UCI_READ_LOOP

UCI_READ_DONE:
    ; Null-terminate string
    LDI 0
    STR 10

    ; Echo CR+LF
    LDI 13
    CALL SERIAL_WRITE_CHAR
    LDI 10
    CALL SERIAL_WRITE_CHAR

    ; Return length
    GLO 13
    RETN

; NOTE: UCI_WRITE_STRING removed - use F_MSG with R15 directly
; The old UCI_WRITE_STRING used R10, which clobbered the negamax loop counter!

; ------------------------------------------------------------------------------
; UCI_PROCESS_COMMAND - Process UCI command from buffer
; ------------------------------------------------------------------------------
; Input:  Command in UCI_BUFFER
; Output: Appropriate action taken
; ------------------------------------------------------------------------------
UCI_PROCESS_COMMAND:
    ; Compare command with known commands

    ; Check "uci"
    LDI HIGH(UCI_BUFFER)
    PHI 10
    LDI LOW(UCI_BUFFER)
    PLO 10

    LDI HIGH(STR_UCI)
    PHI 11
    LDI LOW(STR_UCI)
    PLO 11

    CALL STRCMP
    LBZ UCI_CMD_UCI

    ; Check "isready"
    LDI HIGH(UCI_BUFFER)
    PHI 10
    LDI LOW(UCI_BUFFER)
    PLO 10

    LDI HIGH(STR_ISREADY)
    PHI 11
    LDI LOW(STR_ISREADY)
    PLO 11

    CALL STRCMP
    LBZ UCI_CMD_ISREADY

    ; Check "position"
    LDI HIGH(UCI_BUFFER)
    PHI 10
    LDI LOW(UCI_BUFFER)
    PLO 10

    LDI HIGH(STR_POSITION)
    PHI 11
    LDI LOW(STR_POSITION)
    PLO 11

    CALL STRNCMP        ; Compare first 8 chars
    LBZ UCI_CMD_POSITION

    ; Check "go"
    LDI HIGH(UCI_BUFFER)
    PHI 10
    LDI LOW(UCI_BUFFER)
    PLO 10

    LDI HIGH(STR_GO)
    PHI 11
    LDI LOW(STR_GO)
    PLO 11

    CALL STRNCMP
    LBZ UCI_CMD_GO

    ; Check "quit"
    LDI HIGH(UCI_BUFFER)
    PHI 10
    LDI LOW(UCI_BUFFER)
    PLO 10

    LDI HIGH(STR_QUIT)
    PHI 11
    LDI LOW(STR_QUIT)
    PLO 11

    CALL STRCMP
    LBZ UCI_CMD_QUIT

    ; Check "ucinewgame"
    LDI HIGH(UCI_BUFFER)
    PHI 10
    LDI LOW(UCI_BUFFER)
    PLO 10

    LDI HIGH(STR_UCINEWGAME)
    PHI 11
    LDI LOW(STR_UCINEWGAME)
    PLO 11

    CALL STRCMP
    LBZ UCI_CMD_UCINEWGAME

    ; Check "stop"
    LDI HIGH(UCI_BUFFER)
    PHI 10
    LDI LOW(UCI_BUFFER)
    PLO 10

    LDI HIGH(STR_STOP)
    PHI 11
    LDI LOW(STR_STOP)
    PLO 11

    CALL STRCMP
    LBZ UCI_CMD_STOP

    ; Unknown command - ignore
    RETN

; ------------------------------------------------------------------------------
; UCI Command Handlers
; ------------------------------------------------------------------------------

UCI_CMD_UCI:
    ; Send identification
    LDI HIGH(STR_ID_NAME)
    PHI 15
    LDI LOW(STR_ID_NAME)
    PLO 15
    SEP 4
    DW F_MSG

    LDI HIGH(STR_ID_AUTHOR)
    PHI 15
    LDI LOW(STR_ID_AUTHOR)
    PLO 15
    SEP 4
    DW F_MSG

    ; Send options (none for now)

    ; Send uciok
    LDI HIGH(STR_UCIOK)
    PHI 15
    LDI LOW(STR_UCIOK)
    PLO 15
    SEP 4
    DW F_MSG

    RETN

UCI_CMD_ISREADY:
    ; Send readyok
    LDI HIGH(STR_READYOK)
    PHI 15
    LDI LOW(STR_READYOK)
    PLO 15
    SEP 4
    DW F_MSG

    RETN

UCI_CMD_POSITION:
    ; Parse position command
    ; Format: "position startpos" or "position startpos moves e2e4 ..."

    ; Check if "startpos"
    LDI HIGH(UCI_BUFFER)
    PHI 10
    LDI LOW(UCI_BUFFER + 9)  ; Skip "position "
    PLO 10

    ; Check for "startpos"
    LDN 10
    XRI 's'
    LBNZ UCI_POS_DONE   ; Not startpos (FEN not supported yet)

    ; Initialize to starting position
    CALL INIT_BOARD
    CALL INIT_MOVE_HISTORY

    ; Skip past "startpos" (8 chars) to check for " moves"
    ; Buffer now at "startpos..." - need to find " moves "
    LDI HIGH(UCI_BUFFER + 17) ; "position startpos" = 17 chars
    PHI 10
    LDI LOW(UCI_BUFFER + 17)
    PLO 10

    ; Check if there's more (should be space or null)
    LDN 10
    LBZ UCI_POS_DONE    ; End of string, no moves
    XRI ' '
    LBNZ UCI_POS_DONE   ; Not a space, unexpected

    ; Skip the space
    INC 10

    ; Check for "moves" (5 chars)
    LDN 10
    XRI 'm'
    LBNZ UCI_POS_DONE
    INC 10
    LDN 10
    XRI 'o'
    LBNZ UCI_POS_DONE
    INC 10
    LDN 10
    XRI 'v'
    LBNZ UCI_POS_DONE
    INC 10
    LDN 10
    XRI 'e'
    LBNZ UCI_POS_DONE
    INC 10
    LDN 10
    XRI 's'
    LBNZ UCI_POS_DONE
    INC 10              ; R10 now past "moves"

    ; Now parse move list: " e2e4 e7e5 ..."
UCI_POS_MOVE_LOOP:
    ; Skip spaces
    LDN 10
    LBZ UCI_POS_DONE    ; End of string
    XRI ' '
    LBNZ UCI_POS_PARSE_MOVE  ; Not a space, should be move
    INC 10
    LBR UCI_POS_MOVE_LOOP

UCI_POS_PARSE_MOVE:
    ; R10 points to start of move (e.g., "e2e4")
    ; Parse from square (2 chars)
    CALL ALGEBRAIC_TO_SQUARE
    XRI $FF
    LBZ UCI_POS_DONE    ; Invalid square, abort

    ; Save from square
    XRI $FF             ; Restore value (XRI is self-inverse)
    PHI 7               ; R7.1 = from square

    ; Parse to square (2 chars)
    CALL ALGEBRAIC_TO_SQUARE
    XRI $FF
    LBZ UCI_POS_DONE    ; Invalid square, abort
    XRI $FF             ; Restore value

    ; Store from and to in MOVE_FROM/MOVE_TO
    PLO 7               ; R7.0 = to square

    LDI HIGH(MOVE_FROM)
    PHI 8
    LDI LOW(MOVE_FROM)
    PLO 8
    GHI 7
    STR 8               ; MOVE_FROM = from
    INC 8
    GLO 7
    STR 8               ; MOVE_TO = to

    ; ---- Record move in MOVE_HIST for opening book ----
    ; Calculate offset: GAME_PLY * 2
    LDI HIGH(GAME_PLY)
    PHI 8
    LDI LOW(GAME_PLY)
    PLO 8
    LDN 8               ; D = GAME_PLY
    SHL                 ; D = GAME_PLY * 2
    PLO 9               ; R9.0 = offset

    ; R9 = MOVE_HIST + offset
    LDI HIGH(MOVE_HIST)
    PHI 9
    LDI LOW(MOVE_HIST)
    SEX 2
    STR 2
    GLO 9               ; D = offset
    ADD                 ; D = LOW(MOVE_HIST) + offset
    PLO 9
    LDI HIGH(MOVE_HIST)
    ADCI 0              ; Add carry to high byte
    PHI 9

    ; Store from square
    GHI 7               ; from square
    STR 9
    INC 9
    ; Store to square
    GLO 7               ; to square
    STR 9

    ; Increment GAME_PLY
    LDN 8               ; R8 still points to GAME_PLY
    ADI 1
    STR 8
    ; ---- End of MOVE_HIST recording ----

    ; Apply the move (save R10 - MAKE_MOVE clobbers it!)
    GHI 10
    STXD
    GLO 10
    STXD
    CALL MAKE_MOVE
    IRX
    LDXA
    PLO 10
    LDX
    PHI 10

    ; Continue parsing
    LBR UCI_POS_MOVE_LOOP

UCI_POS_DONE:
    RETN

; ------------------------------------------------------------------------------
; ALGEBRAIC_TO_SQUARE - Convert algebraic notation to 0x88 square
; ------------------------------------------------------------------------------
; Input:  R10 = pointer to 2-char string (e.g., "e2"), advanced by 2
; Output: D = 0x88 square index, or $FF if invalid
; Uses:   R7.0 for file temp
; ------------------------------------------------------------------------------
ALGEBRAIC_TO_SQUARE:
    ; Get file character (a-h)
    LDA 10              ; Load file char, advance R10
    SMI 'a'             ; Convert to 0-7
    LBNF ATS_INVALID    ; If DF=0 (borrow), char < 'a', invalid
    PLO 7               ; Save potential file in R7.0
    SMI 8               ; Check if >= 8
    LBDF ATS_INVALID    ; If >= 8, invalid

    ; Get rank character (1-8)
    LDA 10              ; Load rank char, advance R10
    SMI '1'             ; Convert to 0-7
    LBNF ATS_INVALID    ; If DF=0 (borrow), char < '1', invalid
    SMI 8               ; Check if >= 8
    LBDF ATS_INVALID    ; If >= 8, invalid
    ADI 8               ; Restore 0-7 value

    ; Calculate 0x88 square = rank * 16 + file
    ; rank is in D (0-7), file in R7.0
    SHL                 ; D = rank * 2
    SHL                 ; D = rank * 4
    SHL                 ; D = rank * 8
    SHL                 ; D = rank * 16
    STR 2               ; Save rank*16 on stack
    GLO 7               ; Get file (0-7)
    ADD                 ; D = rank*16 + file
    RETN

ATS_INVALID:
    INC 10              ; Skip second char even on error (keep R10 consistent)
    LDI $FF
    RETN

UCI_CMD_GO:
    ; Parse go command
    ; Format: "go depth 6" or "go infinite", etc.
    ; Default to depth 1, parse "depth N" if present
    ; Store in memory (R5 is SRET in BIOS mode!)

    ; Default depth = 1
    LDI 1
    PLO 7               ; R7.0 = depth (default 1)

    ; Check for "depth " after "go "
    ; Buffer: "go depth 3" or "go" or "go infinite"
    LDI HIGH(UCI_BUFFER + 3)  ; Skip "go "
    PHI 10
    LDI LOW(UCI_BUFFER + 3)
    PLO 10

    ; Check if we have "depth"
    LDN 10
    XRI 'd'
    LBNZ UCI_GO_SET_DEPTH   ; Not "depth", use default
    INC 10
    LDN 10
    XRI 'e'
    LBNZ UCI_GO_SET_DEPTH
    INC 10
    LDN 10
    XRI 'p'
    LBNZ UCI_GO_SET_DEPTH
    INC 10
    LDN 10
    XRI 't'
    LBNZ UCI_GO_SET_DEPTH
    INC 10
    LDN 10
    XRI 'h'
    LBNZ UCI_GO_SET_DEPTH
    INC 10
    LDN 10
    XRI ' '
    LBNZ UCI_GO_SET_DEPTH
    INC 10              ; R10 now at the number

    ; Parse the depth number (1-9, single digit only)
    ; Depths > 9 would take impractically long on the 1802 anyway
    LDN 10
    SMI '0'             ; Convert ASCII to value
    LBNF UCI_GO_SET_DEPTH ; Invalid (< '0'), use default
    SMI 10              ; Check if >= 10
    LBDF UCI_GO_SET_DEPTH ; >= 10, use default
    ADI 10              ; Restore 0-9 value
    LBZ UCI_GO_SET_DEPTH ; Depth 0 invalid, use default
    PLO 7               ; R7.0 = parsed depth (1-9)

UCI_GO_SET_DEPTH:
    ; Set SEARCH_DEPTH from R7.0
    LDI HIGH(SEARCH_DEPTH)
    PHI 13
    LDI LOW(SEARCH_DEPTH)
    PLO 13
    LDI 0
    STR 13              ; SEARCH_DEPTH high = 0
    INC 13
    GLO 7
    STR 13              ; SEARCH_DEPTH low = depth

    ; ---- Check opening book first ----
    CALL BOOK_LOOKUP
    LBZ UCI_GO_SEARCH   ; D=0: no book hit, do normal search

    ; Book hit! Copy BOOK_MOVE to BEST_MOVE
    LDI HIGH(BOOK_MOVE_FROM)
    PHI 8
    LDI LOW(BOOK_MOVE_FROM)
    PLO 8
    LDI HIGH(BEST_MOVE)
    PHI 9
    LDI LOW(BEST_MOVE)
    PLO 9

    ; Store book move in BEST_MOVE (from in high, to in low)
    LDA 8               ; BOOK_MOVE_FROM
    STR 9               ; BEST_MOVE high = from
    INC 9
    LDN 8               ; BOOK_MOVE_TO
    STR 9               ; BEST_MOVE low = to
    LBR UCI_GO_SEND_MOVE

UCI_GO_SEARCH:
    ; Run search
    CALL SEARCH_POSITION

UCI_GO_SEND_MOVE:
    ; Best move now at BEST_MOVE

    ; Send best move
    LDI HIGH(STR_BESTMOVE)
    PHI 15
    LDI LOW(STR_BESTMOVE)
    PLO 15
    SEP 4
    DW F_MSG

    ; Convert best move to algebraic and send
    ; TODO: Load best move and convert
    CALL UCI_SEND_BEST_MOVE

    ; Send CR+LF
    LDI 13
    CALL SERIAL_WRITE_CHAR
    LDI 10
    CALL SERIAL_WRITE_CHAR

    RETN

UCI_CMD_QUIT:
    ; Return to monitor at $8000
    LBR $8003

; ------------------------------------------------------------------------------
; UCI_CMD_UCINEWGAME - Prepare for a new game
; ------------------------------------------------------------------------------
; Clears transposition table and resets game state
; ------------------------------------------------------------------------------
UCI_CMD_UCINEWGAME:
    ; Clear transposition table
    CALL TT_CLEAR

    ; Reset game ply counter
    LDI HIGH(GAME_PLY)
    PHI 10
    LDI LOW(GAME_PLY)
    PLO 10
    LDI 0
    STR 10

    ; Clear move history
    CALL INIT_MOVE_HISTORY

    ; Initialize board to starting position
    CALL INIT_BOARD

    RETN

; ------------------------------------------------------------------------------
; UCI_CMD_STOP - Stop calculating (no-op for now)
; ------------------------------------------------------------------------------
; On a single-threaded system we cannot interrupt search.
; GUI should wait for bestmove response.
; This is here for protocol compatibility.
; ------------------------------------------------------------------------------
UCI_CMD_STOP:
    ; No-op - search completes naturally
    ; GUI will receive bestmove when search finishes
    RETN

; ------------------------------------------------------------------------------
; UCI_SEND_BEST_MOVE - Send best move in algebraic notation
; ------------------------------------------------------------------------------
UCI_SEND_BEST_MOVE:
    ; BEST_MOVE contains raw from/to squares (not encoded)
    ; BEST_MOVE[0] = from square (0x88), BEST_MOVE[1] = to square (0x88)
    LDI HIGH(BEST_MOVE)
    PHI 10
    LDI LOW(BEST_MOVE)
    PLO 10

    LDA 10              ; from square (raw 0x88)
    PHI 13              ; R13.1 = from
    LDN 10              ; to square (raw 0x88)
    PLO 13              ; R13.0 = to

    ; Convert to algebraic notation (e.g., "e2e4")
    ; From square
    GHI 13              ; From square
    CALL SQUARE_TO_ALGEBRAIC
    ; Sends two characters (file, rank)

    ; To square
    GLO 13              ; To square
    CALL SQUARE_TO_ALGEBRAIC

    RETN

; ------------------------------------------------------------------------------
; SQUARE_TO_ALGEBRAIC - Convert 0x88 square to algebraic notation
; ------------------------------------------------------------------------------
; Input:  D = square (0x88 format)
; Output: Two characters sent (file letter, rank number)
; ------------------------------------------------------------------------------
SQUARE_TO_ALGEBRAIC:
    PLO 7               ; Save square in R7.0 (R13 used by caller!)

    ; Get file (0-7 → 'a'-'h')
    ANI $07             ; File bits
    ADI 'a'             ; Convert to ASCII
    CALL SERIAL_WRITE_CHAR

    ; Get rank (0-7 → '1'-'8')
    GLO 7               ; Get square from R7.0
    SHR
    SHR
    SHR
    SHR                 ; Rank bits
    ADI '1'             ; Convert to ASCII
    CALL SERIAL_WRITE_CHAR

    RETN

; ------------------------------------------------------------------------------
; String Comparison Functions
; ------------------------------------------------------------------------------

; STRCMP - Compare two null-terminated strings
; Input:  A = string 1, B = string 2
; Output: D = 0 if equal, non-zero if different
STRCMP:
    LDN 10              ; D = char from string 1
    STR 2               ; Save to stack
    LDN 11              ; D = char from string 2
    XOR                 ; D = char1 XOR char2 (0 if equal)
    LBNZ STRCMP_DIFF     ; If XOR != 0, characters differ

    ; Characters are equal, check if end of both strings
    LDN 10
    LBZ STRCMP_EQUAL     ; If null terminator, both ended - equal

    ; Continue comparing
    INC 10
    INC 11
    LBR STRCMP

STRCMP_EQUAL:
    LDI 0
    RETN

STRCMP_DIFF:
    LDI 1
    RETN

; STRNCMP - Compare until space or null in string 1
; Input:  R10 = string 1 (command buffer), R11 = string 2 (command name)
; Output: D = 0 if equal, non-zero if different
STRNCMP:
    ; Check if string 1 hit space (end of command word)
    LDN 10
    XRI ' '
    LBZ STRNCMP_CHECK_END

    ; Check if string 1 hit null
    LDN 10
    LBZ STRNCMP_CHECK_END

    ; Compare characters
    LDN 10              ; D = char from string 1
    STR 2               ; Save to stack
    LDN 11              ; D = char from string 2
    XOR                 ; D = char1 XOR char2 (0 if equal)
    LBNZ STRNCMP_DIFF   ; If different, not equal

    INC 10
    INC 11
    LBR STRNCMP

STRNCMP_CHECK_END:
    ; String 1 ended (space or null) - check if string 2 also ended
    LDN 11
    LBZ STRNCMP_EQUAL   ; String 2 is null - match!
    LBR STRNCMP_DIFF    ; String 2 has more chars - no match

STRNCMP_EQUAL:
    LDI 0
    RETN

STRNCMP_DIFF:
    LDI 1
    RETN

; ==============================================================================
; End of UCI Implementation
; ==============================================================================
; NOTE: SERIAL_READ_CHAR and SERIAL_WRITE_CHAR are provided by serial-io-9600.asm
; ==============================================================================
