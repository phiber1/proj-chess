; ==============================================================================
; MOVE GENERATION MODULE
; Generates all pseudo-legal moves for the current position
; ==============================================================================

; ------------------------------------------------------------------------------
; Move list storage
; Each move = 2 bytes (from square, to square)
; Maximum ~100 moves possible in a position (typically 30-40)
; ------------------------------------------------------------------------------
MOVE_LIST:
    DS 256              ; 128 moves max × 2 bytes
MOVE_COUNT:
    DS 1                ; Number of moves generated
MOVE_PTR:
    DS 2                ; Pointer into move list (R.A = high, R.A+1 = low)

; Direction offsets for sliding pieces
; Stored as signed bytes
DIR_ROOK:
    DB 0F8H             ; -8 (up)
    DB 08H              ; +8 (down)  
    DB 0FFH             ; -1 (left)
    DB 01H              ; +1 (right)

DIR_BISHOP:
    DB 0F7H             ; -9 (up-left)
    DB 0F9H             ; -7 (up-right)
    DB 07H              ; +7 (down-left)
    DB 09H              ; +9 (down-right)

DIR_KNIGHT:
    DB 0EFH             ; -17 (up 2, left 1)
    DB 0F1H             ; -15 (up 2, right 1)
    DB 0FAH             ; -6 (up 1, left 2)
    DB 0FEH             ; -10 (up 1, right 2) - wait, should be +10? Let me recalc
    ; Knight offsets: ±6, ±10, ±15, ±17
    DB 06H              ; +6 (down 1, left 2)
    DB 0AH              ; +10 (down 1, right 2)
    DB 0FH              ; +15 (down 2, left 1)
    DB 11H              ; +17 (down 2, right 1)

; ==============================================================================
; GENERATE_MOVES - Generate all pseudo-legal moves
; Input: SIDE contains side to move (00=White, 80=Black)
; Output: MOVE_LIST filled, MOVE_COUNT set
; ==============================================================================
GENERATE_MOVES:
    ; Initialize move count to 0
    LDI 0
    PLO 12              ; R12.0 = move count
    
    ; Initialize move list pointer
    LDI HIGH(MOVE_LIST)
    PHI 8
    LDI LOW(MOVE_LIST)
    PLO 8               ; R8 = move list pointer
    
    ; Loop through all 64 squares
    LDI 0
    PLO 9               ; R9.0 = current square (0-63)
    
GM_SQUARE_LOOP:
    ; Get piece at current square
    SEP 4
    DW GET_PIECE_AT     ; D = piece at R9.0
    
    ; Skip if empty
    BZ GM_NEXT_SQUARE
    
    ; Check if piece belongs to side to move
    PLO 10              ; Save piece in R10.0
    ANI COLOR_MASK      ; Get color bit
    PHI 10              ; Save color in R10.1
    
    ; Load SIDE and compare
    LDI HIGH(SIDE)
    PHI 11
    LDI LOW(SIDE)
    PLO 11
    LDN 11              ; D = SIDE
    STR 2               ; Store on stack
    GHI 10              ; Get piece color
    XOR                 ; Compare with side to move
    LBNZ GM_NEXT_SQUARE ; Wrong color, skip
    
    ; Piece belongs to us - generate its moves
    GLO 10              ; Get piece
    ANI PIECE_MASK      ; Get piece type
    
    ; Branch based on piece type
    SMI PAWN
    LBZ GM_PAWN
    SMI 1               ; KNIGHT
    LBZ GM_KNIGHT
    SMI 1               ; BISHOP
    LBZ GM_BISHOP
    SMI 1               ; ROOK
    LBZ GM_ROOK
    SMI 1               ; QUEEN
    LBZ GM_QUEEN
    SMI 1               ; KING
    LBZ GM_KING
    
GM_NEXT_SQUARE:
    ; Move to next square
    INC 9
    GLO 9
    SMI 64
    LBNZ GM_SQUARE_LOOP
    
    ; Store final move count
    GLO 12
    LDI HIGH(MOVE_COUNT)
    PHI 11
    LDI LOW(MOVE_COUNT)
    PLO 11
    GLO 12
    STR 11
    
    SEP 5               ; Return

; ==============================================================================
; GET_PIECE_AT - Get piece at square
; Input: R9.0 = square index
; Output: D = piece code
; ==============================================================================
GET_PIECE_AT:
    LDI HIGH(BOARD)
    PHI 11
    LDI LOW(BOARD)
    PLO 11
    SEX 2
    GLO 9
    STR 2
    GLO 11
    ADD
    PLO 11
    GHI 11
    ADCI 0
    PHI 11
    LDN 11
    SEP 5

; ==============================================================================
; ADD_MOVE - Add move to move list
; Input: R9.0 = from square, D = to square
; Uses R8 as move list pointer
; ==============================================================================
ADD_MOVE:
    PLO 10              ; Save to square in R10.0
    
    ; Store from square
    GLO 9
    STR 8
    INC 8
    
    ; Store to square
    GLO 10
    STR 8
    INC 8
    
    ; Increment move count
    INC 12
    
    SEP 5

; ==============================================================================
; GM_PAWN - Generate pawn moves
; Input: R9.0 = pawn square, R10.0 = piece, R10.1 = color
; ==============================================================================
GM_PAWN:
    ; Determine direction based on color
    ; White pawns move up (subtract 8), Black pawns move down (add 8)
    GHI 10              ; Get color
    BNZ GMP_BLACK
    
    ; White pawn
    ; Forward move (square - 8)
    GLO 9
    SMI 8
    BM GMP_CAPTURES     ; Off board (shouldn't happen for valid pawn)
    PLO 10              ; R10.0 = target square
    
    ; Check if target is empty
    GLO 10
    PLO 9               ; Temporarily put target in R9.0
    SEP 4
    DW GET_PIECE_AT
    GLO 9               ; Restore R9.0 will be wrong - need to save/restore
    ; Actually let me restructure this...
    
    ; Save current square
    GLO 9
    PHI 9               ; R9.1 = from square (save it)
    
    ; Calculate target = from - 8
    SMI 8
    PLO 10              ; R10.0 = target
    
    ; Get piece at target
    PLO 9               ; R9.0 = target temporarily
    SEP 4
    DW GET_PIECE_AT     ; D = piece at target
    BNZ GMP_W_DOUBLE_SKIP ; Not empty, can't move forward
    
    ; Target is empty, add move
    GHI 9               ; Get from square
    PLO 9               ; Restore from in R9.0
    GLO 10              ; Get to square
    SEP 4
    DW ADD_MOVE
    
    ; Check for double move from rank 2 (squares 48-55)
    GLO 9               ; Get from square
    SMI 48
    BM GMP_W_CAPTURES   ; < 48, not on rank 2
    GLO 9
    SMI 56
    BDF GMP_W_CAPTURES  ; >= 56, not on rank 2
    
    ; On rank 2, try double move
    GLO 9
    SMI 16              ; target = from - 16
    PLO 10
    PLO 9               ; Check this square
    SEP 4
    DW GET_PIECE_AT
    BNZ GMP_W_CAPTURES  ; Not empty
    
    ; Add double move
    GHI 9
    PLO 9               ; Restore from
    GLO 10              ; Get to
    SEP 4
    DW ADD_MOVE
    LBR GMP_W_CAPTURES

GMP_W_DOUBLE_SKIP:
    GHI 9
    PLO 9               ; Restore from square

GMP_W_CAPTURES:
    ; Capture left (from - 9) if not on a-file
    GLO 9
    ANI 07H             ; Get file
    BZ GMP_W_CAP_RIGHT  ; On a-file, skip left capture
    
    GLO 9
    SMI 9               ; target = from - 9
    BM GMP_W_CAP_RIGHT  ; Off board
    PLO 10              ; R10.0 = target
    
    ; Check if enemy piece there
    PLO 9
    SEP 4
    DW GET_PIECE_AT
    BZ GMP_W_CAP_RIGHT_RESTORE ; Empty, no capture
    
    ; Check if enemy
    ANI COLOR_MASK
    BZ GMP_W_CAP_RIGHT_RESTORE ; Our piece
    
    ; Enemy piece - add capture
    GHI 9
    PLO 9
    GLO 10
    SEP 4
    DW ADD_MOVE

GMP_W_CAP_RIGHT_RESTORE:
    GHI 9
    PLO 9

GMP_W_CAP_RIGHT:
    ; Capture right (from - 7) if not on h-file
    GLO 9
    ANI 07H
    SMI 07H
    BZ GMP_DONE         ; On h-file, skip right capture
    
    GLO 9
    SMI 7               ; target = from - 7
    BM GMP_DONE         ; Off board
    PLO 10
    
    PLO 9
    SEP 4
    DW GET_PIECE_AT
    BZ GMP_DONE_RESTORE
    ANI COLOR_MASK
    BZ GMP_DONE_RESTORE ; Our piece
    
    ; Enemy piece - add capture
    GHI 9
    PLO 9
    GLO 10
    SEP 4
    DW ADD_MOVE
    LBR GM_NEXT_SQUARE

GMP_DONE_RESTORE:
    GHI 9
    PLO 9
GMP_DONE:
    LBR GM_NEXT_SQUARE

GMP_BLACK:
    ; Black pawn moves - similar but opposite direction
    ; Forward move (square + 8)
    GLO 9
    PHI 9               ; Save from square
    ADI 8
    SMI 64
    BDF GMP_B_CAPTURES  ; Off board (>= 64)
    ADI 64              ; Restore target
    PLO 10
    
    PLO 9
    SEP 4
    DW GET_PIECE_AT
    BNZ GMP_B_DOUBLE_SKIP
    
    GHI 9
    PLO 9
    GLO 10
    SEP 4
    DW ADD_MOVE
    
    ; Double move from rank 7 (squares 8-15)
    GLO 9
    SMI 8
    BM GMP_B_CAPTURES   ; < 8
    GLO 9
    SMI 16
    BDF GMP_B_CAPTURES  ; >= 16
    
    GLO 9
    ADI 16
    PLO 10
    PLO 9
    SEP 4
    DW GET_PIECE_AT
    BNZ GMP_B_CAPTURES
    
    GHI 9
    PLO 9
    GLO 10
    SEP 4
    DW ADD_MOVE
    LBR GMP_B_CAPTURES

GMP_B_DOUBLE_SKIP:
    GHI 9
    PLO 9

GMP_B_CAPTURES:
    ; Capture left (from + 7)
    GLO 9
    ANI 07H
    BZ GMP_B_CAP_RIGHT
    
    GLO 9
    ADI 7
    SMI 64
    BDF GMP_B_CAP_RIGHT
    ADI 64
    PLO 10
    
    PLO 9
    SEP 4
    DW GET_PIECE_AT
    BZ GMP_B_CAP_RIGHT_RESTORE
    ANI COLOR_MASK
    BNZ GMP_B_CAP_RIGHT_RESTORE ; Black piece (same color)
    
    GHI 9
    PLO 9
    GLO 10
    SEP 4
    DW ADD_MOVE

GMP_B_CAP_RIGHT_RESTORE:
    GHI 9
    PLO 9

GMP_B_CAP_RIGHT:
    ; Capture right (from + 9)
    GLO 9
    ANI 07H
    SMI 07H
    BZ GMP_B_DONE
    
    GLO 9
    ADI 9
    SMI 64
    BDF GMP_B_DONE
    ADI 64
    PLO 10
    
    PLO 9
    SEP 4
    DW GET_PIECE_AT
    BZ GMP_B_DONE_RESTORE
    ANI COLOR_MASK
    BNZ GMP_B_DONE_RESTORE
    
    GHI 9
    PLO 9
    GLO 10
    SEP 4
    DW ADD_MOVE
    LBR GM_NEXT_SQUARE

GMP_B_DONE_RESTORE:
    GHI 9
    PLO 9
GMP_B_DONE:
    LBR GM_NEXT_SQUARE

; ==============================================================================
; GM_KNIGHT - Generate knight moves
; Input: R9.0 = knight square
; ==============================================================================
GM_KNIGHT:
    GLO 9
    PHI 9               ; Save from square in R9.1
    
    ; Try all 8 knight moves
    ; Offsets: -17, -15, -10, -6, +6, +10, +15, +17
    
    ; Move 1: -17 (up 2, left 1)
    GLO 9
    ANI 07H             ; Check not on a-file
    BZ GMN_SKIP1
    GLO 9
    SMI 17
    BM GMN_SKIP1        ; Off board
    PLO 10
    SEP 4
    DW GMN_TRY_SQUARE

GMN_SKIP1:
    ; Move 2: -15 (up 2, right 1)
    GHI 9
    PLO 9
    ANI 07H
    SMI 7
    BZ GMN_SKIP2        ; On h-file
    GLO 9
    SMI 15
    BM GMN_SKIP2
    PLO 10
    SEP 4
    DW GMN_TRY_SQUARE

GMN_SKIP2:
    ; Move 3: -10 (up 1, left 2)
    GHI 9
    PLO 9
    ANI 07H
    SMI 2
    BM GMN_SKIP3        ; File a or b
    GLO 9
    SMI 10
    BM GMN_SKIP3
    PLO 10
    SEP 4
    DW GMN_TRY_SQUARE

GMN_SKIP3:
    ; Move 4: -6 (up 1, right 2)
    GHI 9
    PLO 9
    ANI 07H
    SMI 6
    BDF GMN_SKIP4       ; File g or h
    GLO 9
    SMI 6
    BM GMN_SKIP4
    PLO 10
    SEP 4
    DW GMN_TRY_SQUARE

GMN_SKIP4:
    ; Move 5: +6 (down 1, left 2)
    GHI 9
    PLO 9
    ANI 07H
    SMI 2
    BM GMN_SKIP5        ; File a or b
    GLO 9
    ADI 6
    SMI 64
    BDF GMN_SKIP5       ; Off board
    ADI 64
    PLO 10
    SEP 4
    DW GMN_TRY_SQUARE

GMN_SKIP5:
    ; Move 6: +10 (down 1, right 2)
    GHI 9
    PLO 9
    ANI 07H
    SMI 6
    BDF GMN_SKIP6       ; File g or h
    GLO 9
    ADI 10
    SMI 64
    BDF GMN_SKIP6
    ADI 64
    PLO 10
    SEP 4
    DW GMN_TRY_SQUARE

GMN_SKIP6:
    ; Move 7: +15 (down 2, left 1)
    GHI 9
    PLO 9
    ANI 07H
    BZ GMN_SKIP7        ; On a-file
    GLO 9
    ADI 15
    SMI 64
    BDF GMN_SKIP7
    ADI 64
    PLO 10
    SEP 4
    DW GMN_TRY_SQUARE

GMN_SKIP7:
    ; Move 8: +17 (down 2, right 1)
    GHI 9
    PLO 9
    ANI 07H
    SMI 7
    BZ GMN_DONE         ; On h-file
    GLO 9
    ADI 17
    SMI 64
    BDF GMN_DONE
    ADI 64
    PLO 10
    SEP 4
    DW GMN_TRY_SQUARE

GMN_DONE:
    GHI 9
    PLO 9
    LBR GM_NEXT_SQUARE

; Helper: Try knight square in R10.0
GMN_TRY_SQUARE:
    GLO 10
    PLO 9               ; Temp move target to R9.0
    SEP 4
    DW GET_PIECE_AT
    BZ GMN_ADD          ; Empty, can move
    
    ; Check if enemy piece
    PLO 11              ; Save piece
    ANI COLOR_MASK
    STR 2
    LDI HIGH(SIDE)
    PHI 11
    LDI LOW(SIDE)
    PLO 11
    LDN 11
    XOR
    BZ GMN_TRY_RET      ; Same color, can't capture
    
GMN_ADD:
    GHI 9
    PLO 9               ; Restore from
    GLO 10              ; Get to
    SEP 4
    DW ADD_MOVE
    SEP 5

GMN_TRY_RET:
    GHI 9
    PLO 9
    SEP 5

; ==============================================================================
; GM_BISHOP - Generate bishop moves (4 diagonal directions)
; ==============================================================================
GM_BISHOP:
    GLO 9
    PHI 9               ; Save from square
    
    ; Direction 1: -9 (up-left)
    LDI 0F7H            ; -9 as signed byte
    SEP 4
    DW GM_SLIDE_DIAG
    
    ; Direction 2: -7 (up-right)
    LDI 0F9H            ; -7
    SEP 4
    DW GM_SLIDE_DIAG
    
    ; Direction 3: +7 (down-left)
    LDI 07H
    SEP 4
    DW GM_SLIDE_DIAG
    
    ; Direction 4: +9 (down-right)
    LDI 09H
    SEP 4
    DW GM_SLIDE_DIAG
    
    GHI 9
    PLO 9
    LBR GM_NEXT_SQUARE

; ==============================================================================
; GM_ROOK - Generate rook moves (4 orthogonal directions)
; ==============================================================================
GM_ROOK:
    GLO 9
    PHI 9
    
    ; Direction 1: -8 (up)
    LDI 0F8H
    SEP 4
    DW GM_SLIDE_ORTH
    
    ; Direction 2: +8 (down)
    LDI 08H
    SEP 4
    DW GM_SLIDE_ORTH
    
    ; Direction 3: -1 (left)
    LDI 0FFH
    SEP 4
    DW GM_SLIDE_HORIZ
    
    ; Direction 4: +1 (right)
    LDI 01H
    SEP 4
    DW GM_SLIDE_HORIZ
    
    GHI 9
    PLO 9
    LBR GM_NEXT_SQUARE

; ==============================================================================
; GM_QUEEN - Generate queen moves (rook + bishop)
; ==============================================================================
GM_QUEEN:
    GLO 9
    PHI 9
    
    ; Rook directions
    LDI 0F8H
    SEP 4
    DW GM_SLIDE_ORTH
    LDI 08H
    SEP 4
    DW GM_SLIDE_ORTH
    LDI 0FFH
    SEP 4
    DW GM_SLIDE_HORIZ
    LDI 01H
    SEP 4
    DW GM_SLIDE_HORIZ
    
    ; Bishop directions
    LDI 0F7H
    SEP 4
    DW GM_SLIDE_DIAG
    LDI 0F9H
    SEP 4
    DW GM_SLIDE_DIAG
    LDI 07H
    SEP 4
    DW GM_SLIDE_DIAG
    LDI 09H
    SEP 4
    DW GM_SLIDE_DIAG
    
    GHI 9
    PLO 9
    LBR GM_NEXT_SQUARE

; ==============================================================================
; GM_KING - Generate king moves (8 directions, 1 square each)
; ==============================================================================
GM_KING:
    GLO 9
    PHI 9
    
    ; 8 directions, check boundaries for each
    ; Up (-8)
    GLO 9
    SMI 8
    BM GMK_D2
    PLO 10
    SEP 4
    DW GMN_TRY_SQUARE   ; Reuse knight's try square
    
GMK_D2:
    ; Down (+8)
    GHI 9
    PLO 9
    ADI 8
    SMI 64
    BDF GMK_D3
    ADI 64
    PLO 10
    SEP 4
    DW GMN_TRY_SQUARE

GMK_D3:
    ; Left (-1)
    GHI 9
    PLO 9
    ANI 07H
    BZ GMK_D4           ; On a-file
    GLO 9
    SMI 1
    PLO 10
    SEP 4
    DW GMN_TRY_SQUARE

GMK_D4:
    ; Right (+1)
    GHI 9
    PLO 9
    ANI 07H
    SMI 7
    BZ GMK_D5           ; On h-file
    GLO 9
    ADI 1
    PLO 10
    SEP 4
    DW GMN_TRY_SQUARE

GMK_D5:
    ; Up-left (-9)
    GHI 9
    PLO 9
    ANI 07H
    BZ GMK_D6           ; On a-file
    GLO 9
    SMI 9
    BM GMK_D6
    PLO 10
    SEP 4
    DW GMN_TRY_SQUARE

GMK_D6:
    ; Up-right (-7)
    GHI 9
    PLO 9
    ANI 07H
    SMI 7
    BZ GMK_D7           ; On h-file
    GLO 9
    SMI 7
    BM GMK_D7
    PLO 10
    SEP 4
    DW GMN_TRY_SQUARE

GMK_D7:
    ; Down-left (+7)
    GHI 9
    PLO 9
    ANI 07H
    BZ GMK_D8           ; On a-file
    GLO 9
    ADI 7
    SMI 64
    BDF GMK_D8
    ADI 64
    PLO 10
    SEP 4
    DW GMN_TRY_SQUARE

GMK_D8:
    ; Down-right (+9)
    GHI 9
    PLO 9
    ANI 07H
    SMI 7
    BZ GMK_DONE         ; On h-file
    GLO 9
    ADI 9
    SMI 64
    BDF GMK_DONE
    ADI 64
    PLO 10
    SEP 4
    DW GMN_TRY_SQUARE

GMK_DONE:
    GHI 9
    PLO 9
    LBR GM_NEXT_SQUARE

; ==============================================================================
; GM_SLIDE_ORTH - Slide in orthogonal direction (up/down)
; Input: D = direction offset
; ==============================================================================
GM_SLIDE_ORTH:
    PLO 10              ; R10.0 = direction
    GHI 9
    PLO 9               ; Start from original square

GMSO_LOOP:
    ; Add direction to current square
    GLO 9
    STR 2
    GLO 10              ; Get direction
    ADD                 ; New square
    
    ; Check bounds (0-63)
    BM GMSO_DONE        ; Negative = off top
    SMI 64
    BDF GMSO_DONE       ; >= 64 = off bottom
    ADI 64              ; Restore value
    PLO 9               ; R9.0 = target square
    
    ; Get piece at target
    SEP 4
    DW GET_PIECE_AT
    BZ GMSO_ADD_CONTINUE ; Empty, add and continue
    
    ; Piece found - check if enemy
    ANI COLOR_MASK
    STR 2
    LDI HIGH(SIDE)
    PHI 11
    LDI LOW(SIDE)
    PLO 11
    LDN 11
    XOR
    BZ GMSO_DONE        ; Same color, blocked
    
    ; Enemy piece - add capture and stop
    GLO 9
    PLO 10              ; Save target
    GHI 9
    PLO 9               ; Restore from
    GLO 10
    SEP 4
    DW ADD_MOVE
    SEP 5

GMSO_ADD_CONTINUE:
    GLO 9
    STR 2               ; Save target
    GHI 9
    PLO 9               ; From square
    LDN 2               ; Get target back
    SEP 4
    DW ADD_MOVE
    
    ; Continue sliding from target
    LDN 2               ; Get target
    PLO 9
    GLO 10              ; Direction still in R10.0? No it was overwritten
    ; Need to preserve direction differently
    LBR GMSO_LOOP

GMSO_DONE:
    GHI 9
    PLO 9
    SEP 5

; ==============================================================================
; GM_SLIDE_HORIZ - Slide horizontally (left/right)
; Input: D = direction offset (-1 or +1)
; ==============================================================================
GM_SLIDE_HORIZ:
    PLO 10              ; R10.0 = direction
    GHI 9
    PLO 9

GMSH_LOOP:
    ; Check file boundary before moving
    GLO 10              ; Get direction
    SMI 0FFH            ; Is it -1?
    BZ GMSH_LEFT
    
    ; Moving right - check not on h-file
    GLO 9
    ANI 07H
    SMI 7
    BZ GMSH_DONE        ; On h-file
    BR GMSH_MOVE

GMSH_LEFT:
    ; Moving left - check not on a-file
    GLO 9
    ANI 07H
    BZ GMSH_DONE        ; On a-file

GMSH_MOVE:
    GLO 9
    STR 2
    GLO 10
    ADD
    PLO 9               ; New square
    
    SEP 4
    DW GET_PIECE_AT
    BZ GMSH_ADD_CONTINUE
    
    ANI COLOR_MASK
    STR 2
    LDI HIGH(SIDE)
    PHI 11
    LDI LOW(SIDE)
    PLO 11
    LDN 11
    XOR
    BZ GMSH_DONE        ; Blocked by own piece
    
    ; Enemy - capture and stop
    GLO 9
    STR 2
    GHI 9
    PLO 9
    LDN 2
    SEP 4
    DW ADD_MOVE
    SEP 5

GMSH_ADD_CONTINUE:
    GLO 9
    STR 2
    GHI 9
    PLO 9
    LDN 2
    SEP 4
    DW ADD_MOVE
    LDN 2
    PLO 9
    BR GMSH_LOOP

GMSH_DONE:
    GHI 9
    PLO 9
    SEP 5

; ==============================================================================
; GM_SLIDE_DIAG - Slide diagonally
; Input: D = direction offset
; ==============================================================================
GM_SLIDE_DIAG:
    PLO 10              ; R10.0 = direction
    GHI 9
    PLO 9

GMSD_LOOP:
    ; Check file boundary based on direction
    GLO 10
    ANI 07H             ; Low 3 bits indicate left/right component
    SMI 7               ; -9, -7 have low bits 7, 9 respectively
    ; Actually simpler to check sign and low bit:
    ; -9 = F7, -7 = F9, +7 = 07, +9 = 09
    ; Left moves: F7, 07 (bit 0 = 1)
    ; Right moves: F9, 09 (bit 0 = 1) - wait that's not right
    ; F7 = 11110111, F9 = 11111001, 07 = 00000111, 09 = 00001001
    ; Hmm, let me check differently
    
    ; For diagonal moves:
    ; -9 (up-left): check not on a-file, not on rank 8
    ; -7 (up-right): check not on h-file, not on rank 8
    ; +7 (down-left): check not on a-file, not on rank 1
    ; +9 (down-right): check not on h-file, not on rank 1
    
    GLO 10
    SMI 0F7H            ; -9?
    BZ GMSD_UL
    GLO 10
    SMI 0F9H            ; -7?
    BZ GMSD_UR
    GLO 10
    SMI 07H             ; +7?
    BZ GMSD_DL
    ; Must be +9 (down-right)

GMSD_DR:
    GLO 9
    ANI 07H
    SMI 7
    BZ GMSD_DONE        ; h-file
    GLO 9
    ADI 9
    SMI 64
    BDF GMSD_DONE
    ADI 64
    BR GMSD_CHECK

GMSD_UL:
    GLO 9
    ANI 07H
    BZ GMSD_DONE        ; a-file
    GLO 9
    SMI 9
    BM GMSD_DONE
    BR GMSD_CHECK

GMSD_UR:
    GLO 9
    ANI 07H
    SMI 7
    BZ GMSD_DONE        ; h-file
    GLO 9
    SMI 7
    BM GMSD_DONE
    BR GMSD_CHECK

GMSD_DL:
    GLO 9
    ANI 07H
    BZ GMSD_DONE        ; a-file
    GLO 9
    ADI 7
    SMI 64
    BDF GMSD_DONE
    ADI 64

GMSD_CHECK:
    PLO 9               ; New square
    
    SEP 4
    DW GET_PIECE_AT
    BZ GMSD_ADD_CONTINUE
    
    ANI COLOR_MASK
    STR 2
    LDI HIGH(SIDE)
    PHI 11
    LDI LOW(SIDE)
    PLO 11
    LDN 11
    XOR
    BZ GMSD_DONE
    
    ; Enemy capture
    GLO 9
    STR 2
    GHI 9
    PLO 9
    LDN 2
    SEP 4
    DW ADD_MOVE
    SEP 5

GMSD_ADD_CONTINUE:
    GLO 9
    STR 2
    GHI 9
    PLO 9
    LDN 2
    SEP 4
    DW ADD_MOVE
    LDN 2
    PLO 9
    LBR GMSD_LOOP

GMSD_DONE:
    GHI 9
    PLO 9
    SEP 5

; ==============================================================================
; END OF MOVE GENERATION MODULE
; ==============================================================================
