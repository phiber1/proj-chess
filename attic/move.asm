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
;         R8 advanced by 2
; ==============================================================================
PARSE_SQUARE:
    ; Get file character (a-h)
    LDA 8               ; Load file char, advance R8
    SMI 'a'             ; Convert to 0-7
    BM PS_INVALID       ; If negative, invalid
    SMI 8               ; Check if >= 8
    BDF PS_INVALID      ; If >= 8, invalid
    ADI 8               ; Restore 0-7 value
    PLO 10              ; Save file in R10.0

    ; Get rank character (1-8)
    LDA 8               ; Load rank char, advance R8
    SMI '1'             ; Convert to 0-7
    BM PS_INVALID       ; If negative, invalid
    SMI 8               ; Check if >= 8
    BDF PS_INVALID      ; If >= 8, invalid
    ADI 8               ; Restore 0-7 value

    ; Convert rank 1-8 to internal 7-0
    ; rank_internal = 7 - rank = 7 - (char - '1')
    STR 2               ; Store rank (0-7) on stack
    LDI 7
    SM                  ; D = 7 - rank
    
    ; Calculate index = rank_internal * 8 + file
    ; Multiply by 8 = shift left 3 times
    SHL
    SHL
    SHL
    STR 2               ; Store rank*8 on stack
    GLO 10              ; Get file
    ADD                 ; D = rank*8 + file
    SEP 5               ; Return with index in D

PS_INVALID:
    LDI 0FFH            ; Return FFH for invalid
    SEP 5

; ==============================================================================
; PARSE_MOVE - Parse 4-character move string (e.g., "e2e4")
; Input: R8 points to move string
; Output: MOVE_FROM = from square, MOVE_TO = to square
;         D = 0 if valid, FFH if invalid
;         R8 advanced by 4
; ==============================================================================
PARSE_MOVE:
    ; Parse "from" square
    SEP 4
    DW PARSE_SQUARE

    ; Check if valid
    ADI 1               ; FFH + 1 = 0 with carry
    LBZ PM_INVALID      ; If was FFH, invalid (long branch)
    SMI 1               ; Restore value

    ; Store "from" square
    PHI 10              ; Save in R10.1 temporarily

    ; Parse "to" square
    SEP 4
    DW PARSE_SQUARE

    ; Check if valid
    ADI 1
    LBZ PM_INVALID      ; Long branch
    SMI 1               ; Restore value
    
    ; Store both squares
    PLO 9               ; Save "to" in R9.0 temporarily
    
    LDI HIGH(MOVE_FROM)
    PHI 8
    LDI LOW(MOVE_FROM)
    PLO 8
    
    GHI 10              ; Get "from"
    STR 8
    INC 8
    GLO 9               ; Get "to"
    STR 8
    
    LDI 0               ; Return success
    SEP 5

PM_INVALID:
    LDI 0FFH            ; Return invalid
    SEP 5

; ==============================================================================
; PRINT_SQUARE - Print square in algebraic notation
; Input: D = square index (0-63)
; Output: Prints 2 characters (e.g., "e2")
; ==============================================================================
PRINT_SQUARE:
    PLO 10              ; Save square in R10.0
    
    ; Calculate file = index AND 7
    ANI 07H
    ADI 'a'             ; Convert to 'a'-'h'
    SEP 4
    DW SERIAL_WRITE_CHAR
    
    ; Calculate rank = 8 - (index >> 3)
    GLO 10              ; Get square
    SHR                 ; Divide by 8
    SHR
    SHR
    STR 2               ; Store on stack
    LDI 8
    SM                  ; D = 8 - (index/8)
    ADI '0'             ; Convert to '1'-'8'
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
    
    LDA 8               ; Get "from" square
    SEP 4
    DW PRINT_SQUARE
    
    LDN 8               ; Get "to" square
    SEP 4
    DW PRINT_SQUARE
    
    SEP 5

; ==============================================================================
; Move data storage
; ==============================================================================
MOVE_FROM:
    DS 1                ; From square (0-63)
MOVE_TO:
    DS 1                ; To square (0-63)

; ==============================================================================
; END OF MOVE MODULE
; ==============================================================================
