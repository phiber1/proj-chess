; ==============================================================================
; RCA 1802/1806 Chess Engine - Check Detection (FIXED)
; ==============================================================================
; Detect if a square is attacked or if king is in check
; Critical for legal move generation and mate detection
;
; FIXES:
; - Enemy color now pushed to stack and accessed properly
; - Removed erroneous LDN 2 after XOR that overwrote comparison results
; ==============================================================================

; ------------------------------------------------------------------------------
; IS_IN_CHECK - Determine if current side's king is in check
; ------------------------------------------------------------------------------
; Input:  C = side to check (WHITE or BLACK)
;         A = board pointer (BOARD)
; Output: D = 1 if in check, 0 if safe
; Uses:   Multiple registers
; ------------------------------------------------------------------------------
IS_IN_CHECK:
    ; Get king position from game state
    GLO 12
    BZ IS_CHECK_WHITE

IS_CHECK_BLACK:
    ; Get black king position
    LDI HIGH(GAME_STATE)
    PHI 13
    LDI LOW(GAME_STATE + STATE_B_KING_SQ)
    PLO 13
    LDN 13
    PLO 11              ; B.0 = black king square
    LBR IS_CHECK_TEST

IS_CHECK_WHITE:
    ; Get white king position
    LDI HIGH(GAME_STATE)
    PHI 13
    LDI LOW(GAME_STATE + STATE_W_KING_SQ)
    PLO 13
    LDN 13
    PLO 11              ; B.0 = white king square

IS_CHECK_TEST:
    ; Check if king square is attacked by enemy
    ; C already has side being checked
    CALL IS_SQUARE_ATTACKED
    ; D = 1 if attacked, 0 if safe
    RETN

; ------------------------------------------------------------------------------
; IS_SQUARE_ATTACKED - Check if square is attacked by enemy
; ------------------------------------------------------------------------------
; Input:  B.0 = square to check (0x88 format)
;         C = side being attacked (WHITE or BLACK)
; Output: D = 1 if square is attacked by enemy, 0 if safe
; Uses:   Most registers, stack
;
; Strategy:
;   1. Check for pawn attacks (2 squares)
;   2. Check for knight attacks (8 squares)
;   3. Check for king attacks (8 squares - for king vs king)
;   4. Check for sliding attacks (8 directions)
;      - Bishop/Queen on diagonals
;      - Rook/Queen on orthogonals
;
; Stack layout after prologue:
;   M[R2+1] = C (our color)
;   M[R2+2] = B.0 (target square)
;   ENEMY_COLOR_TEMP = enemy color (in memory, not stack)
; ------------------------------------------------------------------------------
IS_SQUARE_ATTACKED:
    ; Ensure X=2 for all stack operations in this function
    SEX 2

    ; Save context
    GLO 11
    STXD
    GLO 12
    STXD

    ; Calculate enemy color and store in memory (NOT stack!)
    ; This avoids complex stack offset calculations in nested calls
    LDI HIGH(ENEMY_COLOR_TEMP)
    PHI 10
    LDI LOW(ENEMY_COLOR_TEMP)
    PLO 10
    GLO 12
    XRI BLACK           ; Flip color (0 -> 8, 8 -> 0)
    STR 10              ; Store enemy color at ENEMY_COLOR_TEMP

    ; -----------------------------------------------
    ; 1. Check for enemy pawn attacks
    ; -----------------------------------------------
    ; Pawns attack diagonally
    ; White pawns attack NE and NW from their position
    ; Black pawns attack SE and SW from their position
    ; So from target square, check opposite directions

    GLO 12
    LBZ ATTACK_CHECK_W_PAWNS

ATTACK_CHECK_B_PAWNS:
    ; We're checking if black king is attacked by white pawns
    ; White pawns would attack from SE and SW of our square
    ; So check NW and NE for white pawns
    GLO 11              ; Target square
    ADI DIR_NW
    PLO 13

    ANI $88
    LBNZ ATTACK_PAWN_2

    ; Valid square, check for white pawn
    LDI HIGH(BOARD)
    PHI 10
    GLO 13
    PLO 10
    LDN 10
    XRI W_PAWN
    LBZ ATTACK_FOUND    ; White pawn attacks this square!

ATTACK_PAWN_2:
    GLO 11
    ADI DIR_NE
    PLO 13

    ANI $88
    LBNZ ATTACK_CHECK_KNIGHTS

    LDI HIGH(BOARD)
    PHI 10
    GLO 13
    PLO 10
    LDN 10
    XRI W_PAWN
    LBZ ATTACK_FOUND

    LBR ATTACK_CHECK_KNIGHTS

ATTACK_CHECK_W_PAWNS:
    ; Check if white king attacked by black pawns
    ; Black pawns attack from NE and NW of their position
    ; So check SE and SW for black pawns
    GLO 11
    ADI DIR_SE
    PLO 13

    ANI $88
    LBNZ ATTACK_PAWN_W2

    LDI HIGH(BOARD)
    PHI 10
    GLO 13
    PLO 10
    LDN 10
    XRI B_PAWN
    LBZ ATTACK_FOUND

ATTACK_PAWN_W2:
    GLO 11
    ADI DIR_SW
    PLO 13

    ANI $88
    LBNZ ATTACK_CHECK_KNIGHTS

    LDI HIGH(BOARD)
    PHI 10
    GLO 13
    PLO 10
    LDN 10
    XRI B_PAWN
    LBZ ATTACK_FOUND

    ; -----------------------------------------------
    ; 2. Check for enemy knight attacks
    ; -----------------------------------------------
ATTACK_CHECK_KNIGHTS:
    ; Use knight offset table
    LDI HIGH(KNIGHT_OFFSETS)
    PHI 13
    LDI LOW(KNIGHT_OFFSETS)
    PLO 13              ; D = knight offset table

    LDI 8
    STXD                ; Push loop counter to stack (R14 is off-limits)

ATTACK_KNIGHT_LOOP:
    ; Save table pointer
    GLO 13
    STXD
    GHI 13
    STXD

    ; Get offset from table
    LDN 13              ; Load offset (don't increment, we saved pointer)
    STR 2              ; Save offset to stack top temporarily

    ; Calculate target square
    GLO 11              ; Target square
    ADD                 ; Add offset (from M[R2])
    PLO 15              ; F.0 = test square

    ; Validate square
    ANI $88
    LBNZ ATTACK_KNIGHT_NEXT

    ; Check for piece at square
    LDI HIGH(BOARD)
    PHI 10
    GLO 15
    PLO 10
    LDN 10              ; Load piece
    LBZ ATTACK_KNIGHT_NEXT

    ; Check if it's a knight
    PLO 15              ; Save piece in F.0
    ANI PIECE_MASK
    XRI KNIGHT_TYPE    ; Is it a knight?
    LBNZ ATTACK_KNIGHT_NEXT

    ; It's a knight - check if enemy color
    GLO 15              ; Get piece back
    ANI COLOR_MASK     ; D = piece color
    STR 2              ; Store piece color at M[R2]

    ; Get enemy color from memory (simple and reliable!)
    LDI HIGH(ENEMY_COLOR_TEMP)
    PHI 10
    LDI LOW(ENEMY_COLOR_TEMP)
    PLO 10
    LDN 10              ; D = enemy color

    ; Now D = enemy color, M[R2] = piece color
    SEX 2               ; Ensure X=2 for XOR
    XOR                 ; D = enemy_color XOR piece_color
    LBZ ATTACK_FOUND_POP3 ; If equal (XOR=0), it's an enemy knight!

ATTACK_KNIGHT_NEXT:
    ; Restore table pointer and advance
    IRX
    LDXA
    PHI 13
    LDX
    PLO 13
    INC 13              ; Advance to next offset

    ; Decrement counter (on stack)
    IRX                 ; Point to counter
    LDN 2               ; Load counter
    SMI 1
    STR 2               ; Store decremented counter
    DEC 2               ; Restore stack pointer
    LBNZ ATTACK_KNIGHT_LOOP

    ; Pop counter from stack
    IRX

    ; -----------------------------------------------
    ; 3. Check for enemy king attacks (king vs king)
    ; -----------------------------------------------
ATTACK_CHECK_KING:
    LDI HIGH(KING_OFFSETS)
    PHI 13
    LDI LOW(KING_OFFSETS)
    PLO 13

    LDI 8
    STXD                ; Push loop counter to stack (R14 is off-limits)

ATTACK_KING_LOOP:
    ; Save table pointer
    GLO 13
    STXD
    GHI 13
    STXD

    LDN 13              ; Get offset
    STR 2

    GLO 11
    ADD
    PLO 15

    ANI $88
    LBNZ ATTACK_KING_NEXT

    LDI HIGH(BOARD)
    PHI 10
    GLO 15
    PLO 10
    LDN 10
    LBZ ATTACK_KING_NEXT

    PLO 15
    ANI PIECE_MASK
    XRI KING_TYPE      ; Is it a king?
    LBNZ ATTACK_KING_NEXT

    ; It's a king - check color
    GLO 15
    ANI COLOR_MASK     ; D = piece color
    STR 2              ; Store piece color at M[R2]

    ; Get enemy color from memory (simple and reliable!)
    LDI HIGH(ENEMY_COLOR_TEMP)
    PHI 10
    LDI LOW(ENEMY_COLOR_TEMP)
    PLO 10
    LDN 10              ; D = enemy color

    SEX 2               ; Ensure X=2 for XOR
    XOR
    LBZ ATTACK_FOUND_POP3

ATTACK_KING_NEXT:
    IRX
    LDXA
    PHI 13
    LDX
    PLO 13
    INC 13

    ; Decrement counter (on stack)
    IRX                 ; Point to counter
    LDN 2               ; Load counter
    SMI 1
    STR 2               ; Store decremented counter
    DEC 2               ; Restore stack pointer
    LBNZ ATTACK_KING_LOOP

    ; Pop counter from stack
    IRX

    ; -----------------------------------------------
    ; 4. Check for sliding piece attacks
    ; -----------------------------------------------
    ; Check diagonals for bishops and queens
    LDI DIR_NE
    CALL ATTACK_CHECK_SLIDING
    LBNZ ATTACK_FOUND

    LDI DIR_NW
    CALL ATTACK_CHECK_SLIDING
    LBNZ ATTACK_FOUND

    LDI DIR_SE
    CALL ATTACK_CHECK_SLIDING
    LBNZ ATTACK_FOUND

    LDI DIR_SW
    CALL ATTACK_CHECK_SLIDING
    LBNZ ATTACK_FOUND

    ; Check orthogonals for rooks and queens
    LDI DIR_N
    CALL ATTACK_CHECK_SLIDING
    LBNZ ATTACK_FOUND

    LDI DIR_S
    CALL ATTACK_CHECK_SLIDING
    LBNZ ATTACK_FOUND

    LDI DIR_E
    CALL ATTACK_CHECK_SLIDING
    LBNZ ATTACK_FOUND

    LDI DIR_W
    CALL ATTACK_CHECK_SLIDING
    LBNZ ATTACK_FOUND

    ; No attackers found
    LDI 0
    LBR ATTACK_RESTORE

ATTACK_FOUND_POP3:
    ; Pop counter + 2 bytes for table pointer
    IRX
    IRX
    IRX
    LBR ATTACK_FOUND

ATTACK_FOUND_POP2:
    ; Pop the saved D pointer before going to ATTACK_FOUND
    IRX
    IRX

ATTACK_FOUND:
    ; Attack found!
    LDI 1

ATTACK_RESTORE:
    ; Save result
    PLO 15

    ; Restore context (pop C, B - enemy_color now in memory, not stack)
    IRX
    LDXA               ; Pop C
    PLO 12
    LDX                ; Pop B (leave R2 pointing here)
    PLO 11

    ; Return result
    GLO 15
    RETN

; ------------------------------------------------------------------------------
; ATTACK_CHECK_SLIDING - Check for sliding piece attack in one direction
; ------------------------------------------------------------------------------
; Input:  D = direction offset
;         B.0 = target square
;         Stack has enemy color at known offset
; Output: D = 1 if attack found, 0 if not
; Uses:   A, R7, F (R14 is off-limits - BIOS uses it)
; ------------------------------------------------------------------------------
ATTACK_CHECK_SLIDING:
    ; Ensure X=2 for stack address calculations
    SEX 2

    ; Save direction
    PLO 15              ; F.0 = direction

    ; Start from target square
    GLO 11
    PLO 7               ; R7.0 = current square (not R14!)

ATTACK_SLIDE_LOOP:
    ; Move in direction
    GLO 7
    STR 2
    GLO 15              ; Direction
    ADD                 ; New square
    PLO 7

    ; Check if off board
    ANI $88
    LBNZ ATTACK_SLIDE_NONE

    ; Check what's on square
    LDI HIGH(BOARD)
    PHI 10
    GLO 7
    PLO 10
    LDN 10              ; Load piece
    LBZ ATTACK_SLIDE_LOOP ; Empty, continue sliding

    ; Piece found - save it
    PHI 15              ; F.1 = piece (F.0 still has direction)

    ; Check if enemy color
    ANI COLOR_MASK     ; D = piece color
    STR 2              ; Save piece color at M[R2]

    ; Get enemy color from memory (simple and reliable!)
    LDI HIGH(ENEMY_COLOR_TEMP)
    PHI 10
    LDI LOW(ENEMY_COLOR_TEMP)
    PLO 10
    LDN 10              ; D = enemy color

    ; Compare: D = enemy_color, M[R2] = piece_color
    SEX 2               ; Ensure X=2 for XOR instruction
    XOR                 ; D = enemy_color XOR piece_color
    LBNZ ATTACK_SLIDE_NONE ; Wrong color, blocked by friendly

    ; Right color - check piece type
    GHI 15              ; Get piece back
    ANI PIECE_MASK     ; Get type
    PLO 10              ; Save type in A.0 temporarily

    ; Check based on direction (diagonal vs orthogonal)
    GLO 15              ; Get direction
    ANI $0F            ; Low nibble
    ; Diagonal directions: NE=$F1, NW=$EF, SE=$11, SW=$0F
    ; Orthogonal: N=$F0, S=$10, E=$01, W=$FF
    ; Diagonal low nibbles: 1, F (15), 1, F
    ; Orthogonal low nibbles: 0, 0, 1, F
    ; Hmm, this doesn't cleanly separate them...

    ; Simpler: check if piece is bishop, rook, or queen
    GLO 10              ; piece type
    XRI QUEEN_TYPE
    LBZ ATTACK_SLIDE_YES ; Queen attacks in all directions

    GLO 10
    XRI BISHOP_TYPE
    LBZ ATTACK_SLIDE_CHECK_DIAG

    GLO 10
    XRI ROOK_TYPE
    LBZ ATTACK_SLIDE_CHECK_ORTH

    ; Not a sliding piece, blocked
    LBR ATTACK_SLIDE_NONE

ATTACK_SLIDE_CHECK_DIAG:
    ; Bishop - only attacks on diagonals
    ; Check if direction is diagonal (NE, NW, SE, SW)
    GLO 15
    XRI DIR_NE
    BZ ATTACK_SLIDE_YES
    GLO 15
    XRI DIR_NW
    BZ ATTACK_SLIDE_YES
    GLO 15
    XRI DIR_SE
    BZ ATTACK_SLIDE_YES
    GLO 15
    XRI DIR_SW
    BZ ATTACK_SLIDE_YES
    BR ATTACK_SLIDE_NONE

ATTACK_SLIDE_CHECK_ORTH:
    ; Rook - only attacks on orthogonals
    GLO 15
    XRI DIR_N
    BZ ATTACK_SLIDE_YES
    GLO 15
    XRI DIR_S
    BZ ATTACK_SLIDE_YES
    GLO 15
    XRI DIR_E
    BZ ATTACK_SLIDE_YES
    GLO 15
    XRI DIR_W
    BZ ATTACK_SLIDE_YES
    ; Fall through to none

ATTACK_SLIDE_NONE:
    LDI 0
    RETN

ATTACK_SLIDE_YES:
    LDI 1
    RETN

; ==============================================================================
; End of Check Detection
; ==============================================================================
