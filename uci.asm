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

; ------------------------------------------------------------------------------
; UCI_WRITE_STRING - Write string to output
; ------------------------------------------------------------------------------
; Input:  A = pointer to null-terminated string
; Output: String sent to serial output
; ------------------------------------------------------------------------------
UCI_WRITE_STRING:
    LDN 10              ; Load character
    LBZ UCI_WRITE_DONE   ; Null terminator

    ; Send character
    CALL SERIAL_WRITE_CHAR

    INC 10
    LBR UCI_WRITE_STRING

UCI_WRITE_DONE:
    RETN

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

    ; Unknown command - ignore
    RETN

; ------------------------------------------------------------------------------
; UCI Command Handlers
; ------------------------------------------------------------------------------

UCI_CMD_UCI:
    ; Send identification
    LDI HIGH(STR_ID_NAME)
    PHI 10
    LDI LOW(STR_ID_NAME)
    PLO 10
    CALL UCI_WRITE_STRING

    LDI HIGH(STR_ID_AUTHOR)
    PHI 10
    LDI LOW(STR_ID_AUTHOR)
    PLO 10
    CALL UCI_WRITE_STRING

    ; Send options (none for now)

    ; Send uciok
    LDI HIGH(STR_UCIOK)
    PHI 10
    LDI LOW(STR_UCIOK)
    PLO 10
    CALL UCI_WRITE_STRING

    RETN

UCI_CMD_ISREADY:
    ; Send readyok
    LDI HIGH(STR_READYOK)
    PHI 10
    LDI LOW(STR_READYOK)
    PLO 10
    CALL UCI_WRITE_STRING

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

    ; Check for " moves"
    ; TODO: Parse and apply move list

UCI_POS_DONE:
    RETN

UCI_CMD_GO:
    ; Debug: show we entered GO
    LDI 'G'
    CALL SERIAL_WRITE_CHAR

    ; Parse go command
    ; Format: "go depth 6" or "go infinite", etc.
    ; For now, default to depth 6
    ; Store in memory (R5 is SRET in BIOS mode!)

    LDI HIGH(SEARCH_DEPTH)
    PHI 13
    LDI LOW(SEARCH_DEPTH)
    PLO 13
    LDI 0
    STR 13              ; SEARCH_DEPTH high = 0
    INC 13
    LDI 6
    STR 13              ; SEARCH_DEPTH low = 6

    ; TODO: Parse depth parameter from command

    ; Debug: about to call search
    LDI 'S'
    CALL SERIAL_WRITE_CHAR

    ; Run search
    CALL SEARCH_POSITION

    ; Debug: search returned
    LDI 'R'
    CALL SERIAL_WRITE_CHAR

    ; 6 has score, best move at BEST_MOVE

    ; Send best move
    LDI HIGH(STR_BESTMOVE)
    PHI 10
    LDI LOW(STR_BESTMOVE)
    PLO 10
    CALL UCI_WRITE_STRING

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
    ; Clean shutdown
    ; TODO: Could save state, etc.
    ; For now, just halt
    DIS
UCI_HALT:
    BR UCI_HALT         ; Infinite loop (1802 has no IDLE)
    ; Or jump to exit routine
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
    PLO 13              ; Save square

    ; Get file (0-7 → 'a'-'h')
    ANI $07             ; File bits
    ADI 'a'             ; Convert to ASCII
    CALL SERIAL_WRITE_CHAR

    ; Get rank (0-7 → '1'-'8')
    GLO 13
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
