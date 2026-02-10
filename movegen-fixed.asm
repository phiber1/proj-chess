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
    ; Ensure X=2 for all stack/memory operations (XOR, ADD, etc.)
    SEX 2

    GLO 9
    PLO 15
    GHI 9
    PHI 15              ; F = move list start

    RLDI 10, BOARD

    ; Store scan index in memory (BIOS clobbers R14.0)
    RLDI 8, GM_SCAN_IDX
    LDI 0
    STR 8               ; scan index = 0

GEN_SCAN_BOARD:
    ; Load scan index from memory
    RLDI 8, GM_SCAN_IDX
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
    RLDI 8, GM_SCAN_IDX
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
    RLDI 8, GM_SCAN_IDX
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
; GEN_KNIGHT - UNROLLED VERSION (no stack math, no loops)
; ==============================================================================
; R11.1 has from square on entry (set before dispatch, survives CALLs)
; Uses ADI with immediate offsets - no ADD/stack operations
; Knight offsets: NNE=$21, NNW=$1F, NEE=$12, NWW=$0E
;                 SSE=$E1, SSW=$DF, SEE=$F2, SWW=$EE
; ==============================================================================
GEN_KNIGHT:
    ; --- Direction 1: NNE (+$21) ---
    GHI 11              ; From square
    ADI $21             ; target = from + $21
    PLO 11              ; R11.0 = target
    ANI $88
    LBNZ GEN_KN_DIR2
    CALL CHECK_TARGET_SQUARE
    LBZ GEN_KN_DIR2
    GHI 11
    PHI 13
    GLO 11
    PLO 13
    LDI MOVE_NORMAL
    CALL ADD_MOVE_ENCODED

GEN_KN_DIR2:
    ; --- Direction 2: NNW (+$1F) ---
    GHI 11
    ADI $1F
    PLO 11
    ANI $88
    LBNZ GEN_KN_DIR3
    CALL CHECK_TARGET_SQUARE
    LBZ GEN_KN_DIR3
    GHI 11
    PHI 13
    GLO 11
    PLO 13
    LDI MOVE_NORMAL
    CALL ADD_MOVE_ENCODED

GEN_KN_DIR3:
    ; --- Direction 3: NEE (+$12) ---
    GHI 11
    ADI $12
    PLO 11
    ANI $88
    LBNZ GEN_KN_DIR4
    CALL CHECK_TARGET_SQUARE
    LBZ GEN_KN_DIR4
    GHI 11
    PHI 13
    GLO 11
    PLO 13
    LDI MOVE_NORMAL
    CALL ADD_MOVE_ENCODED

GEN_KN_DIR4:
    ; --- Direction 4: NWW (+$0E) ---
    GHI 11
    ADI $0E
    PLO 11
    ANI $88
    LBNZ GEN_KN_DIR5
    CALL CHECK_TARGET_SQUARE
    LBZ GEN_KN_DIR5
    GHI 11
    PHI 13
    GLO 11
    PLO 13
    LDI MOVE_NORMAL
    CALL ADD_MOVE_ENCODED

GEN_KN_DIR5:
    ; --- Direction 5: SSE (+$E1 = -$1F) ---
    GHI 11
    ADI $E1
    PLO 11
    ANI $88
    LBNZ GEN_KN_DIR6
    CALL CHECK_TARGET_SQUARE
    LBZ GEN_KN_DIR6
    GHI 11
    PHI 13
    GLO 11
    PLO 13
    LDI MOVE_NORMAL
    CALL ADD_MOVE_ENCODED

GEN_KN_DIR6:
    ; --- Direction 6: SSW (+$DF = -$21) ---
    GHI 11
    ADI $DF
    PLO 11
    ANI $88
    LBNZ GEN_KN_DIR7
    CALL CHECK_TARGET_SQUARE
    LBZ GEN_KN_DIR7
    GHI 11
    PHI 13
    GLO 11
    PLO 13
    LDI MOVE_NORMAL
    CALL ADD_MOVE_ENCODED

GEN_KN_DIR7:
    ; --- Direction 7: SEE (+$F2 = -$0E) ---
    GHI 11
    ADI $F2
    PLO 11
    ANI $88
    LBNZ GEN_KN_DIR8
    CALL CHECK_TARGET_SQUARE
    LBZ GEN_KN_DIR8
    GHI 11
    PHI 13
    GLO 11
    PLO 13
    LDI MOVE_NORMAL
    CALL ADD_MOVE_ENCODED

GEN_KN_DIR8:
    ; --- Direction 8: SWW (+$EE = -$12) ---
    GHI 11
    ADI $EE
    PLO 11
    ANI $88
    LBNZ GEN_KN_DONE
    CALL CHECK_TARGET_SQUARE
    LBZ GEN_KN_DONE
    GHI 11
    PHI 13
    GLO 11
    PLO 13
    LDI MOVE_NORMAL
    CALL ADD_MOVE_ENCODED

GEN_KN_DONE:
    LBR GEN_SKIP_SQUARE

; ==============================================================================
; GEN_BISHOP, GEN_ROOK, GEN_QUEEN - Use direction-specific sliding functions
; ==============================================================================
GEN_BISHOP:
    CALL GEN_SLIDE_NE
    CALL GEN_SLIDE_NW
    CALL GEN_SLIDE_SE
    CALL GEN_SLIDE_SW
    LBR GEN_SKIP_SQUARE

GEN_ROOK:
    CALL GEN_SLIDE_N
    CALL GEN_SLIDE_S
    CALL GEN_SLIDE_E
    CALL GEN_SLIDE_W
    LBR GEN_SKIP_SQUARE

GEN_QUEEN:
    CALL GEN_SLIDE_N
    CALL GEN_SLIDE_NE
    CALL GEN_SLIDE_E
    CALL GEN_SLIDE_SE
    CALL GEN_SLIDE_S
    CALL GEN_SLIDE_SW
    CALL GEN_SLIDE_W
    CALL GEN_SLIDE_NW
    LBR GEN_SKIP_SQUARE

; ==============================================================================
; GEN_SLIDE_* - Direction-specific sliding (no stack math)
; ==============================================================================
; Each function handles one direction with hardcoded ADI
; R11.1 = from square (survives CALLs), R7.0 = current position
; Direction offsets: N=$10, NE=$11, E=$01, SE=$F1, S=$F0, SW=$EF, W=$FF, NW=$0F
; ==============================================================================

; --- GEN_SLIDE_N: North (+$10) ---
GEN_SLIDE_N:
    GHI 11
    PLO 7               ; R7.0 = current position = from
GEN_SLIDE_N_LOOP:
    GLO 7
    ADI $10             ; next = current + $10
    PLO 7               ; R7.0 = target
    ANI $88
    LBNZ GEN_SLIDE_N_RET
    GLO 7               ; Get target back (ANI destroyed D)
    PLO 11              ; R11.0 = target (for CHECK_TARGET_SQUARE)
    CALL CHECK_TARGET_SQUARE
    PLO 11              ; Save result to R11.0 (R8 clobbered by ADD_MOVE_ENCODED)
    LBZ GEN_SLIDE_N_RET
    GHI 11
    PHI 13
    GLO 7
    PLO 13
    LDI MOVE_NORMAL
    CALL ADD_MOVE_ENCODED
    GLO 11              ; Get result from R11.0
    XRI 2
    LBZ GEN_SLIDE_N_RET  ; Capture, stop
    LBR GEN_SLIDE_N_LOOP
GEN_SLIDE_N_RET:
    RETN

; --- GEN_SLIDE_NE: Northeast (+$11) ---
GEN_SLIDE_NE:
    GHI 11
    PLO 7
GEN_SLIDE_NE_LOOP:
    GLO 7
    ADI $11
    PLO 7
    ANI $88
    LBNZ GEN_SLIDE_NE_RET
    GLO 7
    PLO 11
    CALL CHECK_TARGET_SQUARE
    PLO 11              ; Save result to R11.0
    LBZ GEN_SLIDE_NE_RET
    GHI 11
    PHI 13
    GLO 7
    PLO 13
    LDI MOVE_NORMAL
    CALL ADD_MOVE_ENCODED
    GLO 11              ; Get result from R11.0
    XRI 2
    LBZ GEN_SLIDE_NE_RET
    LBR GEN_SLIDE_NE_LOOP
GEN_SLIDE_NE_RET:
    RETN

; --- GEN_SLIDE_E: East (+$01) ---
GEN_SLIDE_E:
    GHI 11
    PLO 7
GEN_SLIDE_E_LOOP:
    GLO 7
    ADI $01
    PLO 7
    ANI $88
    LBNZ GEN_SLIDE_E_RET
    GLO 7
    PLO 11
    CALL CHECK_TARGET_SQUARE
    PLO 11              ; Save result to R11.0
    LBZ GEN_SLIDE_E_RET
    GHI 11
    PHI 13
    GLO 7
    PLO 13
    LDI MOVE_NORMAL
    CALL ADD_MOVE_ENCODED
    GLO 11              ; Get result from R11.0
    XRI 2
    LBZ GEN_SLIDE_E_RET
    LBR GEN_SLIDE_E_LOOP
GEN_SLIDE_E_RET:
    RETN

; --- GEN_SLIDE_SE: Southeast (+$F1 = -$0F) ---
GEN_SLIDE_SE:
    GHI 11
    PLO 7
GEN_SLIDE_SE_LOOP:
    GLO 7
    ADI $F1
    PLO 7
    ANI $88
    LBNZ GEN_SLIDE_SE_RET
    GLO 7
    PLO 11
    CALL CHECK_TARGET_SQUARE
    PLO 11              ; Save result to R11.0
    LBZ GEN_SLIDE_SE_RET
    GHI 11
    PHI 13
    GLO 7
    PLO 13
    LDI MOVE_NORMAL
    CALL ADD_MOVE_ENCODED
    GLO 11              ; Get result from R11.0
    XRI 2
    LBZ GEN_SLIDE_SE_RET
    LBR GEN_SLIDE_SE_LOOP
GEN_SLIDE_SE_RET:
    RETN

; --- GEN_SLIDE_S: South (+$F0 = -$10) ---
GEN_SLIDE_S:
    GHI 11
    PLO 7
GEN_SLIDE_S_LOOP:
    GLO 7
    ADI $F0
    PLO 7
    ANI $88
    LBNZ GEN_SLIDE_S_RET
    GLO 7
    PLO 11
    CALL CHECK_TARGET_SQUARE
    PLO 11              ; Save result to R11.0
    LBZ GEN_SLIDE_S_RET
    GHI 11
    PHI 13
    GLO 7
    PLO 13
    LDI MOVE_NORMAL
    CALL ADD_MOVE_ENCODED
    GLO 11              ; Get result from R11.0
    XRI 2
    LBZ GEN_SLIDE_S_RET
    LBR GEN_SLIDE_S_LOOP
GEN_SLIDE_S_RET:
    RETN

; --- GEN_SLIDE_SW: Southwest (+$EF = -$11) ---
GEN_SLIDE_SW:
    GHI 11
    PLO 7
GEN_SLIDE_SW_LOOP:
    GLO 7
    ADI $EF
    PLO 7
    ANI $88
    LBNZ GEN_SLIDE_SW_RET
    GLO 7
    PLO 11
    CALL CHECK_TARGET_SQUARE
    PLO 11              ; Save result to R11.0
    LBZ GEN_SLIDE_SW_RET
    GHI 11
    PHI 13
    GLO 7
    PLO 13
    LDI MOVE_NORMAL
    CALL ADD_MOVE_ENCODED
    GLO 11              ; Get result from R11.0
    XRI 2
    LBZ GEN_SLIDE_SW_RET
    LBR GEN_SLIDE_SW_LOOP
GEN_SLIDE_SW_RET:
    RETN

; --- GEN_SLIDE_W: West (+$FF = -$01) ---
GEN_SLIDE_W:
    GHI 11
    PLO 7
GEN_SLIDE_W_LOOP:
    GLO 7
    ADI $FF
    PLO 7
    ANI $88
    LBNZ GEN_SLIDE_W_RET
    GLO 7
    PLO 11
    CALL CHECK_TARGET_SQUARE
    PLO 11              ; Save result to R11.0
    LBZ GEN_SLIDE_W_RET
    GHI 11
    PHI 13
    GLO 7
    PLO 13
    LDI MOVE_NORMAL
    CALL ADD_MOVE_ENCODED
    GLO 11              ; Get result from R11.0
    XRI 2
    LBZ GEN_SLIDE_W_RET
    LBR GEN_SLIDE_W_LOOP
GEN_SLIDE_W_RET:
    RETN

; --- GEN_SLIDE_NW: Northwest (+$0F) ---
GEN_SLIDE_NW:
    GHI 11
    PLO 7
GEN_SLIDE_NW_LOOP:
    GLO 7
    ADI $0F
    PLO 7
    ANI $88
    LBNZ GEN_SLIDE_NW_RET
    GLO 7
    PLO 11
    CALL CHECK_TARGET_SQUARE
    PLO 11              ; Save result to R11.0
    LBZ GEN_SLIDE_NW_RET
    GHI 11
    PHI 13
    GLO 7
    PLO 13
    LDI MOVE_NORMAL
    CALL ADD_MOVE_ENCODED
    GLO 11              ; Get result from R11.0
    XRI 2
    LBZ GEN_SLIDE_NW_RET
    LBR GEN_SLIDE_NW_LOOP
GEN_SLIDE_NW_RET:
    RETN

; ==============================================================================
; GEN_KING - UNROLLED VERSION with castling (no stack math, no loops)
; ==============================================================================
; R11.1 has from square on entry (set before dispatch, survives CALLs)
; Uses ADI with immediate offsets - no ADD/stack operations
; King offsets: N=$10, NE=$11, E=$01, SE=$F1, S=$F0, SW=$EF, W=$FF, NW=$0F
; ==============================================================================
GEN_KING:
    ; --- Direction 1: N (+$10) ---
    GHI 11
    ADI $10
    PLO 11
    ANI $88
    LBNZ GEN_KG_DIR2
    CALL CHECK_TARGET_SQUARE
    LBZ GEN_KG_DIR2
    GHI 11
    PHI 13
    GLO 11
    PLO 13
    LDI MOVE_NORMAL
    CALL ADD_MOVE_ENCODED

GEN_KG_DIR2:
    ; --- Direction 2: NE (+$11) ---
    GHI 11
    ADI $11
    PLO 11
    ANI $88
    LBNZ GEN_KG_DIR3
    CALL CHECK_TARGET_SQUARE
    LBZ GEN_KG_DIR3
    GHI 11
    PHI 13
    GLO 11
    PLO 13
    LDI MOVE_NORMAL
    CALL ADD_MOVE_ENCODED

GEN_KG_DIR3:
    ; --- Direction 3: E (+$01) ---
    GHI 11
    ADI $01
    PLO 11
    ANI $88
    LBNZ GEN_KG_DIR4
    CALL CHECK_TARGET_SQUARE
    LBZ GEN_KG_DIR4
    GHI 11
    PHI 13
    GLO 11
    PLO 13
    LDI MOVE_NORMAL
    CALL ADD_MOVE_ENCODED

GEN_KG_DIR4:
    ; --- Direction 4: SE (+$F1 = -$0F) ---
    GHI 11
    ADI $F1
    PLO 11
    ANI $88
    LBNZ GEN_KG_DIR5
    CALL CHECK_TARGET_SQUARE
    LBZ GEN_KG_DIR5
    GHI 11
    PHI 13
    GLO 11
    PLO 13
    LDI MOVE_NORMAL
    CALL ADD_MOVE_ENCODED

GEN_KG_DIR5:
    ; --- Direction 5: S (+$F0 = -$10) ---
    GHI 11
    ADI $F0
    PLO 11
    ANI $88
    LBNZ GEN_KG_DIR6
    CALL CHECK_TARGET_SQUARE
    LBZ GEN_KG_DIR6
    GHI 11
    PHI 13
    GLO 11
    PLO 13
    LDI MOVE_NORMAL
    CALL ADD_MOVE_ENCODED

GEN_KG_DIR6:
    ; --- Direction 6: SW (+$EF = -$11) ---
    GHI 11
    ADI $EF
    PLO 11
    ANI $88
    LBNZ GEN_KG_DIR7
    CALL CHECK_TARGET_SQUARE
    LBZ GEN_KG_DIR7
    GHI 11
    PHI 13
    GLO 11
    PLO 13
    LDI MOVE_NORMAL
    CALL ADD_MOVE_ENCODED

GEN_KG_DIR7:
    ; --- Direction 7: W (+$FF = -$01) ---
    GHI 11
    ADI $FF
    PLO 11
    ANI $88
    LBNZ GEN_KG_DIR8
    CALL CHECK_TARGET_SQUARE
    LBZ GEN_KG_DIR8
    GHI 11
    PHI 13
    GLO 11
    PLO 13
    LDI MOVE_NORMAL
    CALL ADD_MOVE_ENCODED

GEN_KG_DIR8:
    ; --- Direction 8: NW (+$0F) ---
    GHI 11
    ADI $0F
    PLO 11
    ANI $88
    LBNZ GEN_KG_CASTLING
    CALL CHECK_TARGET_SQUARE
    LBZ GEN_KG_CASTLING
    GHI 11
    PHI 13
    GLO 11
    PLO 13
    LDI MOVE_NORMAL
    CALL ADD_MOVE_ENCODED

GEN_KG_CASTLING:
    ; Add castling moves (R11.1 still has king square)
    GHI 11              ; D = king square for castling check
    CALL GEN_CASTLING_MOVES

    LBR GEN_SKIP_SQUARE


; ==============================================================================
; End of Move Generation (Fixed)
; ==============================================================================
