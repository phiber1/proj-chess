; ==============================================================================
; Opening Book Lookup - Check if current position is in opening book
; ==============================================================================
;
; Book format (from opening-book.asm):
;   Each entry: [ply] [move1_from] [move1_to] ... [response_from] [response_to]
;   Terminated with $FF
;   Entries sorted by ply
;
; Uses: GAME_PLY - number of moves played since start
;       MOVE_HIST - array of (from, to) pairs for game moves
;       BOOK_MOVE_FROM/TO - output for book response
;
; ==============================================================================

; ==============================================================================
; BOOK_LOOKUP - Search opening book for current position
; ==============================================================================
; Input:  GAME_PLY = number of moves played
;         MOVE_HIST = game move history (2 bytes per move)
; Output: D = 1 if book hit, 0 if no match
;         BOOK_MOVE_FROM/TO = response move (if hit)
; Uses:   R7, R8, R9, R10
; ==============================================================================
BOOK_LOOKUP:
    ; R8 = pointer to current book entry
    LDI HIGH(OPENING_BOOK)
    PHI 8
    LDI LOW(OPENING_BOOK)
    PLO 8

    ; Load GAME_PLY into R7.1 for quick comparison
    LDI HIGH(GAME_PLY)
    PHI 10
    LDI LOW(GAME_PLY)
    PLO 10
    LDN 10
    PHI 7               ; R7.1 = GAME_PLY

BL_ENTRY_LOOP:
    ; Read entry ply byte
    LDN 8               ; D = entry ply
    XRI $FF             ; Check for end marker
    LBZ BL_NO_MATCH     ; End of book, no match

    ; Restore ply value
    XRI $FF
    PLO 7               ; R7.0 = entry_ply

    ; Check if entry_ply > GAME_PLY (early exit - book sorted by ply)
    GHI 7               ; D = GAME_PLY
    STR 2               ; Store on stack
    GLO 7               ; D = entry_ply
    SD                  ; D = GAME_PLY - entry_ply
    LBNF BL_NO_MATCH    ; If borrow (entry_ply > GAME_PLY), no match possible

    ; Check if entry_ply == GAME_PLY
    LBZ BL_CHECK_MOVES  ; If equal, check the moves

    ; entry_ply < GAME_PLY, skip to next entry
    ; Entry length = 1 + entry_ply*2 + 2 = 3 + entry_ply*2
    GLO 7               ; D = entry_ply
    SHL                 ; D = entry_ply * 2
    ADI 3               ; D = 3 + entry_ply * 2
    STR 2               ; Save skip amount
    GLO 8
    ADD
    PLO 8
    GHI 8
    ADCI 0
    PHI 8
    LBR BL_ENTRY_LOOP

BL_CHECK_MOVES:
    ; entry_ply == GAME_PLY, compare all moves
    ; R8 points to ply byte, moves start at R8+1
    ; R9 = pointer to MOVE_HIST
    LDI HIGH(MOVE_HIST)
    PHI 9
    LDI LOW(MOVE_HIST)
    PLO 9

    ; R10.0 = move counter (number of move pairs to compare)
    GLO 7               ; entry_ply = number of moves to compare
    PLO 10

    ; Move past ply byte
    INC 8

    ; If ply == 0, no moves to compare - direct match!
    GLO 10
    LBZ BL_MATCH_FOUND

BL_COMPARE_LOOP:
    ; Compare from square
    LDN 8               ; Book from
    STR 2
    LDN 9               ; History from
    XOR                 ; Compare
    LBNZ BL_SKIP_ENTRY  ; Mismatch

    ; Compare to square
    INC 8
    INC 9
    LDN 8               ; Book to
    STR 2
    LDN 9               ; History to
    XOR                 ; Compare
    LBNZ BL_SKIP_ENTRY  ; Mismatch

    ; Move to next pair
    INC 8
    INC 9
    DEC 10
    GLO 10
    LBNZ BL_COMPARE_LOOP

BL_MATCH_FOUND:
    ; All moves matched! R8 now points to response
    ; Store response in BOOK_MOVE_FROM/TO
    LDI HIGH(BOOK_MOVE_FROM)
    PHI 9
    LDI LOW(BOOK_MOVE_FROM)
    PLO 9

    LDA 8               ; Response from
    STR 9
    INC 9
    LDN 8               ; Response to
    STR 9

    ; Return success
    LDI 1
    RETN

BL_SKIP_ENTRY:
    ; Mismatch during comparison, skip to next entry
    ; We need to find where we are and skip to end of entry
    ; Entry format: [ply] [moves...] [response]
    ; R10.0 has remaining moves to compare
    ; Skip: remaining_moves*2 + 2 (response bytes)
    GLO 10              ; Remaining moves
    SHL                 ; * 2
    ADI 2               ; + response
    STR 2
    GLO 8
    ADD
    PLO 8
    GHI 8
    ADCI 0
    PHI 8

    ; Reset book pointer past ply (we compared some moves already)
    LBR BL_ENTRY_LOOP

BL_NO_MATCH:
    ; No book match found
    LDI 0
    RETN

; ==============================================================================
; End of Opening Book Lookup
; ==============================================================================
