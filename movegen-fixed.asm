; ==============================================================================
; RCA 1802/1806 Chess Engine - Move Generation (INTEGRATED VERSION)
; ==============================================================================
; Generate pseudo-legal moves for all piece types
; COMPLETE VERSION with all helpers integrated
; ==============================================================================
;
; BIOS COMPATIBILITY: R14 is clobbered by BIOS calls (R14.0 used for baud).
; This version uses memory for scan index and R11.1 for from square.
;
; ==============================================================================

; NOTE: Direction offsets, KNIGHT_OFFSETS, KING_OFFSETS, and MOVE_* constants
; are now defined in board.asm to avoid duplication and make them available
; to all modules

; GM_SCAN_IDX defined in board-0x88.asm ($6807)
; All engine variables consolidated at $6800+ region

; ==============================================================================
; GENERATE_MOVES - Main entry
; ==============================================================================
; Input:  R9 = move list pointer, R12.0 = side to move
; Output: D = move count, R9 = updated past last move
; Uses:   Memory at GM_SCAN_IDX, R11.1 for from square
; ==============================================================================
GENERATE_MOVES:
    GLO 9
    PLO 15
    GHI 9
    PHI 15              ; F = move list start

    LDI HIGH(BOARD)
    PHI 10
    LDI LOW(BOARD)
    PLO 10

    ; Store scan index in memory (BIOS clobbers R14.0)
    LDI HIGH(GM_SCAN_IDX)
    PHI 8
    LDI LOW(GM_SCAN_IDX)
    PLO 8
    LDI 0
    STR 8               ; scan index = 0

GEN_SCAN_BOARD:
    ; Load scan index from memory
    LDI HIGH(GM_SCAN_IDX)
    PHI 8
    LDI LOW(GM_SCAN_IDX)
    PLO 8
    LDN 8               ; D = scan index
    ANI $88
    LBNZ GEN_SKIP_SQUARE

    LDN 10
    LBZ GEN_SKIP_SQUARE

    ; Check if piece belongs to side to move
    ANI COLOR_MASK
    STR 2
    GLO 12
    XOR               ; D = side_to_move XOR piece_color (0 if same)
    LBNZ GEN_SKIP_SQUARE  ; Skip if colors don't match

    ; Store from square in R11.1 before dispatching
    LDI HIGH(GM_SCAN_IDX)
    PHI 8
    LDI LOW(GM_SCAN_IDX)
    PLO 8
    LDN 8
    PHI 11              ; R11.1 = from square (survives CALLs)

    LDN 10
    ANI PIECE_MASK

    SMI 1
    LBZ GEN_PAWN
    SMI 1
    LBZ GEN_KNIGHT
    SMI 1
    LBZ GEN_BISHOP
    SMI 1
    LBZ GEN_ROOK
    SMI 1
    LBZ GEN_QUEEN
    SMI 1
    LBZ GEN_KING

GEN_SKIP_SQUARE:
    INC 10
    ; Increment scan index in memory
    LDI HIGH(GM_SCAN_IDX)
    PHI 8
    LDI LOW(GM_SCAN_IDX)
    PLO 8
    LDN 8
    ADI 1
    STR 8
    ANI $80             ; Check if bit 7 set (>= 128)
    LBZ GEN_SCAN_BOARD  ; Continue scanning while < 128

    ; Calculate move count
    GLO 15              ; Start pointer low byte
    STR 2               ; Store on stack
    GLO 9               ; Current pointer low byte
    SM                  ; D = current - start = bytes used
    SHR                 ; Divide by 2 for move count
    PLO 8               ; Save move count in R8.0 (temp)

    ; Return move count
    GLO 8
    RETN

; ==============================================================================
; GEN_PAWN - COMPLETE VERSION with validation
; ==============================================================================
; Uses R11.1 for from square (set before dispatch, survives CALLs)
; ==============================================================================
GEN_PAWN:
    GLO 12
    LBZ GEN_PAWN_WHITE

GEN_PAWN_BLACK:
    ; Single push (black pawns move towards lower ranks = DIR_N)
    GHI 11              ; From square from R11.1
    ADI DIR_N
    PLO 11              ; R11.0 = target square

    ANI $88
    LBNZ GEN_PAWN_CAPTURES_B

    ; Check if square is empty
    LDI HIGH(BOARD)
    PHI 13
    GLO 11
    PLO 13
    LDN 13
    LBNZ GEN_PAWN_CAPTURES_B  ; Not empty, skip

    ; Check for promotion (rank 0)
    GLO 11
    ANI $70
    LBZ GEN_PAWN_PROMO_B

    ; Add normal push
    GHI 11              ; from (from R11.1)
    PHI 13
    GLO 11              ; to
    PLO 13
    LDI MOVE_NORMAL
    CALL ADD_MOVE_ENCODED

    ; Check for double push from rank 6
    GHI 11              ; from square from R11.1
    ANI $70
    XRI $60
    LBNZ GEN_PAWN_CAPTURES_B

    ; Try double push - recalculate target
    GHI 11
    ADI DIR_N
    ADI DIR_N           ; from + 2*DIR_N
    PLO 11

    ; Check if empty
    LDI HIGH(BOARD)
    PHI 13
    GLO 11
    PLO 13
    LDN 13
    LBNZ GEN_PAWN_CAPTURES_B

    ; Add double push
    GHI 11              ; from (from R11.1)
    PHI 13
    GLO 11              ; to
    PLO 13
    LDI MOVE_NORMAL
    CALL ADD_MOVE_ENCODED

GEN_PAWN_CAPTURES_B:
    ; Left capture (northwest - black moves towards rank 1)
    GHI 11              ; from square from R11.1
    ADI DIR_NW
    PLO 11              ; R11.0 = target

    ANI $88
    LBNZ GEN_PAWN_RIGHT_B

    ; Check if enemy piece
    CALL CHECK_TARGET_SQUARE
    ; D = 0 (blocked), 1 (empty), 2 (capture)
    XRI 2
    LBNZ GEN_PAWN_EP_LEFT_B   ; Not a capture

    ; Add capture
    GHI 11              ; from (from R11.1)
    PHI 13
    GLO 11              ; to
    PLO 13
    LDI MOVE_NORMAL
    CALL ADD_MOVE_ENCODED

GEN_PAWN_EP_LEFT_B:
    ; Check for en passant - recalculate target
    GHI 11
    ADI DIR_NW
    PLO 11
    CALL CHECK_EN_PASSANT
    LBZ GEN_PAWN_RIGHT_B

    ; Add EP capture
    GHI 11              ; from (from R11.1)
    PHI 13
    GLO 11              ; to
    PLO 13
    LDI MOVE_EP
    CALL ADD_MOVE_ENCODED

GEN_PAWN_RIGHT_B:
    ; Right capture (northeast - black moves towards rank 1)
    GHI 11              ; from square from R11.1
    ADI DIR_NE
    PLO 11              ; R11.0 = target

    ANI $88
    LBNZ GEN_PAWN_DONE

    CALL CHECK_TARGET_SQUARE
    XRI 2
    LBNZ GEN_PAWN_EP_RIGHT_B

    GHI 11              ; from (from R11.1)
    PHI 13
    GLO 11              ; to
    PLO 13
    LDI MOVE_NORMAL
    CALL ADD_MOVE_ENCODED

GEN_PAWN_EP_RIGHT_B:
    ; Recalculate target for EP check
    GHI 11
    ADI DIR_NE
    PLO 11
    CALL CHECK_EN_PASSANT
    LBZ GEN_PAWN_DONE

    GHI 11              ; from (from R11.1)
    PHI 13
    GLO 11              ; to
    PLO 13
    LDI MOVE_EP
    CALL ADD_MOVE_ENCODED

    LBR GEN_PAWN_DONE

GEN_PAWN_WHITE:
    ; Single push (white pawns move towards higher ranks = DIR_S)
    GHI 11              ; from square from R11.1
    ADI DIR_S
    PLO 11              ; R11.0 = target

    ANI $88
    LBNZ GEN_PAWN_CAPTURES_W

    ; Check if empty
    LDI HIGH(BOARD)
    PHI 13
    GLO 11
    PLO 13
    LDN 13
    LBNZ GEN_PAWN_CAPTURES_W

    ; Check for promotion (rank 7)
    GLO 11
    ANI $70
    XRI $70
    LBZ GEN_PAWN_PROMO_W

    ; Add push
    GHI 11              ; from (from R11.1)
    PHI 13
    GLO 11              ; to
    PLO 13
    LDI MOVE_NORMAL
    CALL ADD_MOVE_ENCODED

    ; Double push from rank 1
    GHI 11              ; from square from R11.1
    ANI $70
    XRI $10
    LBNZ GEN_PAWN_CAPTURES_W

    ; Recalculate double push target
    GHI 11
    ADI DIR_S
    ADI DIR_S           ; from + 2*DIR_S
    PLO 11

    LDI HIGH(BOARD)
    PHI 13
    GLO 11
    PLO 13
    LDN 13
    LBNZ GEN_PAWN_CAPTURES_W

    GHI 11              ; from (from R11.1)
    PHI 13
    GLO 11              ; to
    PLO 13
    LDI MOVE_NORMAL
    CALL ADD_MOVE_ENCODED

GEN_PAWN_CAPTURES_W:
    ; Left capture (southwest - rank up, file down)
    GHI 11              ; from square from R11.1
    ADI DIR_SW
    PLO 11              ; R11.0 = target

    ANI $88
    LBNZ GEN_PAWN_RIGHT_W

    CALL CHECK_TARGET_SQUARE
    XRI 2
    LBNZ GEN_PAWN_EP_LEFT_W

    GHI 11              ; from (from R11.1)
    PHI 13
    GLO 11              ; to
    PLO 13
    LDI MOVE_NORMAL
    CALL ADD_MOVE_ENCODED

GEN_PAWN_EP_LEFT_W:
    ; Recalculate target for EP check
    GHI 11
    ADI DIR_SW
    PLO 11
    CALL CHECK_EN_PASSANT
    LBZ GEN_PAWN_RIGHT_W

    GHI 11              ; from (from R11.1)
    PHI 13
    GLO 11              ; to
    PLO 13
    LDI MOVE_EP
    CALL ADD_MOVE_ENCODED

GEN_PAWN_RIGHT_W:
    ; Right capture (southeast - rank up, file up)
    GHI 11              ; from square from R11.1
    ADI DIR_SE
    PLO 11              ; R11.0 = target

    ANI $88
    LBNZ GEN_PAWN_DONE

    CALL CHECK_TARGET_SQUARE
    XRI 2
    LBNZ GEN_PAWN_EP_RIGHT_W

    GHI 11              ; from (from R11.1)
    PHI 13
    GLO 11              ; to
    PLO 13
    LDI MOVE_NORMAL
    CALL ADD_MOVE_ENCODED

GEN_PAWN_EP_RIGHT_W:
    ; Recalculate target for EP check
    GHI 11
    ADI DIR_SE
    PLO 11
    CALL CHECK_EN_PASSANT
    LBZ GEN_PAWN_DONE

    GHI 11              ; from (from R11.1)
    PHI 13
    GLO 11              ; to
    PLO 13
    LDI MOVE_EP
    CALL ADD_MOVE_ENCODED

    LBR GEN_PAWN_DONE

GEN_PAWN_PROMO_B:
GEN_PAWN_PROMO_W:
    ; Generate 4 promotion moves
    ; R11.1 = from, R11.0 = to (set before we got here)
    CALL GEN_PAWN_PROMOTION

    ; Continue with captures based on color
    GLO 12
    LBZ GEN_PAWN_CAPTURES_W
    LBR GEN_PAWN_CAPTURES_B

GEN_PAWN_DONE:
    LBR GEN_SKIP_SQUARE

; ==============================================================================
; GEN_KNIGHT - COMPLETE VERSION
; ==============================================================================
; Uses memory for loop counter and from square (globals in memory, not registers)
; R11.1 has from square on entry (set before dispatch)
; ==============================================================================
GEN_KNIGHT:
    ; Store from square in memory (survives all CALLs)
    LDI HIGH(GEN_FROM_SQ)
    PHI 7
    LDI LOW(GEN_FROM_SQ)
    PLO 7
    GHI 11              ; From square from R11.1
    STR 7

    ; Initialize loop counter in memory
    LDI HIGH(GEN_LOOP_CTR)
    PHI 7
    LDI LOW(GEN_LOOP_CTR)
    PLO 7
    LDI 8
    STR 7               ; Loop counter = 8

    ; Set up offset table pointer
    LDI HIGH(KNIGHT_OFFSETS)
    PHI 8
    LDI LOW(KNIGHT_OFFSETS)
    PLO 8

GEN_KNIGHT_LOOP:
    ; Get from square from memory
    LDI HIGH(GEN_FROM_SQ)
    PHI 7
    LDI LOW(GEN_FROM_SQ)
    PLO 7
    LDN 7               ; D = from square
    STR 2               ; Store on stack for ADD

    ; Add offset to get target
    LDN 8               ; D = offset
    ADD                 ; D = from + offset
    PLO 11              ; R11.0 = target square

    ANI $88
    LBNZ GEN_KNIGHT_NEXT

    ; Check target (uses R7, preserves R13)
    CALL CHECK_TARGET_SQUARE
    LBZ GEN_KNIGHT_NEXT   ; Blocked by friendly

    ; Add move - get from square from memory
    LDI HIGH(GEN_FROM_SQ)
    PHI 7
    LDI LOW(GEN_FROM_SQ)
    PLO 7
    LDN 7               ; D = from square
    PHI 13              ; R13.1 = from
    GLO 11              ; to
    PLO 13              ; R13.0 = to
    LDI MOVE_NORMAL
    CALL ADD_MOVE_ENCODED

GEN_KNIGHT_NEXT:
    INC 8               ; Next offset

    ; Decrement loop counter in memory
    LDI HIGH(GEN_LOOP_CTR)
    PHI 7
    LDI LOW(GEN_LOOP_CTR)
    PLO 7
    LDN 7               ; Load counter
    SMI 1               ; Decrement
    STR 7               ; Store back
    LBNZ GEN_KNIGHT_LOOP

    LBR GEN_SKIP_SQUARE

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

    LBR GEN_SKIP_SQUARE

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

    LBR GEN_SKIP_SQUARE

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

    LBR GEN_SKIP_SQUARE

; ==============================================================================
; GEN_SLIDING - COMPLETE VERSION with blocking
; ==============================================================================
; Uses R11.1 for from square (set before dispatch)
; R13.0 = direction (passed in), R7.0 = current position during slide
; ==============================================================================
GEN_SLIDING:
    ; Save R15 (holds move list start pointer)
    GLO 15
    STXD
    GHI 15
    STXD

    ; Save direction and from square
    GLO 13              ; direction
    STXD
    GHI 11              ; from square
    STXD

    ; Start from current square
    GHI 11
    PLO 7               ; R7.0 = current position

GEN_SLIDE_LOOP:
    ; Move in direction - peek at direction from stack
    IRX                 ; Point to from square
    IRX                 ; Point to direction
    LDN 2               ; D = direction
    DEC 2
    DEC 2               ; Restore stack pointer

    GLO 7
    ADD
    PLO 7               ; R7.0 = new position

    ; Check if off board
    ANI $88
    LBNZ GEN_SLIDE_DONE

    ; Check target square
    GLO 7
    PLO 11              ; R11.0 = target for CHECK_TARGET_SQUARE
    CALL CHECK_TARGET_SQUARE
    ; D = 0 (blocked), 1 (empty), 2 (capture)

    PLO 8               ; Save result in R8.0

    LBZ GEN_SLIDE_DONE   ; Blocked by friendly

    ; Add move - get from square from stack
    IRX
    LDN 2               ; D = from square
    DEC 2
    PHI 13              ; R13.1 = from
    GLO 7               ; to
    PLO 13              ; R13.0 = to
    LDI MOVE_NORMAL
    CALL ADD_MOVE_ENCODED

    ; Check if we should continue sliding
    GLO 8               ; Get saved result
    XRI 2               ; Was it a capture?
    LBZ GEN_SLIDE_DONE   ; Yes, stop sliding

    LBR GEN_SLIDE_LOOP  ; Empty, continue

GEN_SLIDE_DONE:
    IRX                 ; Point to from square
    IRX                 ; Point to direction
    IRX                 ; Point to R15.1
    ; Restore R15 (move list start pointer)
    LDXA                ; Load R15.1, advance to R15.0
    PHI 15
    LDX                 ; Load R15.0
    PLO 15
    RETN

; ==============================================================================
; GEN_KING - COMPLETE VERSION with castling
; ==============================================================================
; Uses memory for loop counter and from square (globals in memory, not registers)
; R11.1 has from square on entry (set before dispatch)
; ==============================================================================
GEN_KING:
    ; Store from square in memory (survives all CALLs)
    LDI HIGH(GEN_FROM_SQ)
    PHI 7
    LDI LOW(GEN_FROM_SQ)
    PLO 7
    GHI 11              ; From square from R11.1
    STR 7

    ; Initialize loop counter in memory
    LDI HIGH(GEN_LOOP_CTR)
    PHI 7
    LDI LOW(GEN_LOOP_CTR)
    PLO 7
    LDI 8
    STR 7               ; Loop counter = 8

    ; Set up offset table pointer
    LDI HIGH(KING_OFFSETS)
    PHI 8
    LDI LOW(KING_OFFSETS)
    PLO 8

GEN_KING_LOOP:
    ; Get from square from memory
    LDI HIGH(GEN_FROM_SQ)
    PHI 7
    LDI LOW(GEN_FROM_SQ)
    PLO 7
    LDN 7               ; D = from square
    STR 2               ; Store on stack for ADD

    ; Add offset to get target
    LDN 8               ; D = offset
    ADD                 ; D = from + offset
    PLO 11              ; R11.0 = target square

    ANI $88
    LBNZ GEN_KING_NEXT

    ; Check target (uses R7, preserves R13)
    CALL CHECK_TARGET_SQUARE
    LBZ GEN_KING_NEXT

    ; Add move - get from square from memory
    LDI HIGH(GEN_FROM_SQ)
    PHI 7
    LDI LOW(GEN_FROM_SQ)
    PLO 7
    LDN 7               ; D = from square
    PHI 13              ; R13.1 = from
    GLO 11              ; to
    PLO 13              ; R13.0 = to
    LDI MOVE_NORMAL
    CALL ADD_MOVE_ENCODED

GEN_KING_NEXT:
    INC 8               ; Next offset

    ; Decrement loop counter in memory
    LDI HIGH(GEN_LOOP_CTR)
    PHI 7
    LDI LOW(GEN_LOOP_CTR)
    PLO 7
    LDN 7               ; Load counter
    SMI 1               ; Decrement
    STR 7               ; Store back
    LBNZ GEN_KING_LOOP

    ; Get from square from memory for castling
    LDI HIGH(GEN_FROM_SQ)
    PHI 7
    LDI LOW(GEN_FROM_SQ)
    PLO 7
    LDN 7               ; D = from square (king position)

    ; Add castling moves
    CALL GEN_CASTLING_MOVES

    LBR GEN_SKIP_SQUARE

; ==============================================================================
; End of Move Generation (Fixed)
; ==============================================================================
