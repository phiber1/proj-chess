; ==============================================================================
; RCA 1802/1806 Chess Engine - Move Generation (Clean Replacement)
; ==============================================================================
; Based on tested step11 code - proven working
; Supports both white and black via R12 (side to move)
; Simple 2-byte move format: (from, to)
; ==============================================================================
;
; REGISTER ALLOCATION MAP
; ==============================================================================
; R0  = DMA pointer (system - do not use)
; R1  = Interrupt PC (system - do not use)
; R2  = Stack pointer (X=2)
; R3  = Program counter
; R4  = SCRT CALL
; R5  = SCRT RET
; R6  = SCRT link register      *** DO NOT USE FOR TEMP STORAGE ***
; R7  = Temp board lookup pointer (piece generators)
; R8  = Offset/direction table pointer (piece generators)
; R9  = Move list pointer (input, updated on output)
; R10 = Board scan pointer (GENERATE_MOVES main loop) *** DO NOT CLOBBER ***
; R11 = Square calculation: R11.1=from square, R11.0=target square
; R12 = Side to move (0=WHITE, 8=BLACK) *** MUST PRESERVE ***
; R13 = R13.0=loop counter, R13.1=direction (sliding pieces)
; R14 = R14.0=current square index (board scan)
; R15 = R15.0=move count
;
; CRITICAL REGISTERS - DO NOT CLOBBER IN PIECE GENERATORS:
;   R6  - SCRT link register (will crash on RETN)
;   R10 - Board scan pointer (will skip squares)
;   R12 - Side to move (will generate wrong color moves)
;
; ==============================================================================
; REGISTER CONVENTIONS:
;   R2  = Stack pointer (X=2)
;   R4  = SCRT CALL
;   R5  = SCRT RET
;   R6  = SCRT link register
;   R9  = Move list pointer (preserved, updated)
;   R12 = Side to move (MUST BE PRESERVED by all functions)
;
; ==============================================================================
; FUNCTION REGISTER DOCUMENTATION
; ==============================================================================
;
; GENERATE_MOVES
;   Input:   R9 = move list pointer, R12.0 = side (0=WHITE, 8=BLACK)
;   Output:  D = move count, R9 = updated past last move
;   Clobbers: R6,R7,R8,R10,R11,R13,R14,R15
;   Preserves: R12
;
; GM_GEN_PAWN
;   Input:   R14.0 = from square, R12.0 = side, R9 = move list, R15.0 = count
;   Output:  R9 updated, R15.0 updated
;   Clobbers: R11,R13
;   Preserves: R12,R14
;
; GM_GEN_KNIGHT
;   Input:   R14.0 = from square, R12.0 = side, R9 = move list, R15.0 = count
;   Output:  R9 updated, R15.0 updated
;   Clobbers: R7,R8,R11,R13
;   Preserves: R12,R14
;
; GM_GEN_BISHOP
;   Input:   R14.0 = from square, R12.0 = side, R9 = move list, R15.0 = count
;   Output:  R9 updated, R15.0 updated
;   Clobbers: R6,R7,R8,R11,R13
;   Preserves: R12,R14
;
; GM_GEN_ROOK
;   Input:   R14.0 = from square, R12.0 = side, R9 = move list, R15.0 = count
;   Output:  R9 updated, R15.0 updated
;   Clobbers: R6,R7,R8,R11,R13
;   Preserves: R12,R14
;
; GM_GEN_QUEEN
;   Input:   R14.0 = from square, R12.0 = side, R9 = move list, R15.0 = count
;   Output:  R9 updated, R15.0 updated
;   Clobbers: R6,R7,R8,R11,R13
;   Preserves: R12,R14
;
; GM_GEN_KING
;   Input:   R14.0 = from square, R12.0 = side, R9 = move list, R15.0 = count
;   Output:  R9 updated, R15.0 updated
;   Clobbers: R7,R8,R11,R13
;   Preserves: R12,R14
;
; ==============================================================================

; ==============================================================================
; GENERATE_MOVES - Main entry point
; ==============================================================================
; Input:  R9 = move list pointer
;         R12.0 = side to move (0 = WHITE, 8 = BLACK)
; Output: D = move count
;         R9 = updated (points past last move)
; ==============================================================================
; Scan index stored in memory to avoid R14 (BIOS uses R14 for baud rate)
GM_SCAN_IDX EQU $50DF

GENERATE_MOVES:
    LDI HIGH(BOARD)
    PHI 10
    LDI LOW(BOARD)
    PLO 10

    LDI 0
    PLO 15              ; F.0 = move count
    ; Store scan index in memory (avoid R14 - BIOS uses it)
    LDI HIGH(GM_SCAN_IDX)
    PHI 8
    LDI LOW(GM_SCAN_IDX)
    PLO 8
    LDI 0
    STR 8               ; scan index = 0

GM_SCAN_LOOP:
    ; Load scan index from memory
    LDI HIGH(GM_SCAN_IDX)
    PHI 8
    LDI LOW(GM_SCAN_IDX)
    PLO 8
    LDN 8
    ANI $88
    LBNZ GM_SCAN_SKIP   ; Invalid square in 0x88

    LDN 10
    LBZ GM_SCAN_SKIP    ; Empty square

    ; Check if piece belongs to side to move
    PLO 13              ; Save piece
    ANI COLOR_MASK
    STR 2               ; Store piece color on stack
    GLO 12              ; Side to move
    XOR                 ; 0 if colors match
    LBNZ GM_SCAN_SKIP   ; Not our piece

    ; Dispatch by piece type
    GLO 13
    ANI PIECE_MASK

    SMI 1
    LBZ GM_DO_PAWN
    SMI 1
    LBZ GM_DO_KNIGHT
    SMI 1
    LBZ GM_DO_BISHOP
    SMI 1
    LBZ GM_DO_ROOK
    SMI 1
    LBZ GM_DO_QUEEN
    SMI 1
    LBZ GM_DO_KING
    LBR GM_SCAN_SKIP

GM_DO_PAWN:
    ; Get from square from memory, save to R11.1
    LDI HIGH(GM_SCAN_IDX)
    PHI 8
    LDI LOW(GM_SCAN_IDX)
    PLO 8
    LDN 8
    PHI 11
    CALL GM_GEN_PAWN
    LBR GM_SCAN_SKIP

GM_DO_KNIGHT:
    LDI HIGH(GM_SCAN_IDX)
    PHI 8
    LDI LOW(GM_SCAN_IDX)
    PLO 8
    LDN 8
    PHI 11
    CALL GM_GEN_KNIGHT
    LBR GM_SCAN_SKIP

GM_DO_BISHOP:
    LDI HIGH(GM_SCAN_IDX)
    PHI 8
    LDI LOW(GM_SCAN_IDX)
    PLO 8
    LDN 8
    PHI 11
    CALL GM_GEN_BISHOP
    LBR GM_SCAN_SKIP

GM_DO_ROOK:
    LDI HIGH(GM_SCAN_IDX)
    PHI 8
    LDI LOW(GM_SCAN_IDX)
    PLO 8
    LDN 8
    PHI 11
    CALL GM_GEN_ROOK
    LBR GM_SCAN_SKIP

GM_DO_QUEEN:
    LDI HIGH(GM_SCAN_IDX)
    PHI 8
    LDI LOW(GM_SCAN_IDX)
    PLO 8
    LDN 8
    PHI 11
    CALL GM_GEN_QUEEN
    LBR GM_SCAN_SKIP

GM_DO_KING:
    LDI HIGH(GM_SCAN_IDX)
    PHI 8
    LDI LOW(GM_SCAN_IDX)
    PLO 8
    LDN 8
    PHI 11
    CALL GM_GEN_KING
    LBR GM_SCAN_SKIP

GM_SCAN_SKIP:
    INC 10
    ; Increment scan index in memory
    LDI HIGH(GM_SCAN_IDX)
    PHI 8
    LDI LOW(GM_SCAN_IDX)
    PLO 8
    LDN 8
    ADI 1
    STR 8
    ANI $80
    LBZ GM_SCAN_LOOP

    GLO 15              ; Return move count in D
    RETN

; ==============================================================================
; GM_GEN_PAWN - Generate pawn moves
; ==============================================================================
GM_GEN_PAWN:
    ; R11.1 = from square (set before CALL to avoid BIOS R14 clobber)
    GLO 12
    LBZ GM_PAWN_WHITE

; --- Black pawn (moves north, toward rank 0) ---
GM_PAWN_BLACK:
    ; Single push
    GHI 11              ; Use R11.1 instead of R14.0
    ADI DIR_N           ; -16
    PLO 11

    ANI $88
    LBNZ GM_PB_CAPTURES

    LDI HIGH(BOARD)
    PHI 13
    GLO 11
    PLO 13
    LDN 13
    LBNZ GM_PB_CAPTURES

    ; Add single push
    INC 15
    GHI 11              ; from square from R11.1
    STR 9
    INC 9
    GLO 11
    STR 9
    INC 9

    ; Double push if on rank 6 ($6x)
    GHI 11              ; from square from R11.1
    ANI $F0
    XRI $60
    LBNZ GM_PB_CAPTURES

    GLO 11
    ADI DIR_N
    PLO 11

    LDI HIGH(BOARD)
    PHI 13
    GLO 11
    PLO 13
    LDN 13
    LBNZ GM_PB_CAPTURES

    INC 15
    GHI 11              ; from square from R11.1
    STR 9
    INC 9
    GLO 11
    STR 9
    INC 9

GM_PB_CAPTURES:
    ; Capture left (NW = -17 = $EF)
    GHI 11              ; from square from R11.1
    ADI DIR_NW
    PLO 11

    ANI $88
    LBNZ GM_PB_CAP_R

    ; Check en passant
    LDI HIGH(GAME_STATE)
    PHI 13
    LDI LOW(GAME_STATE + GS_EP)
    PLO 13
    LDN 13
    STR 2
    GLO 11
    SM
    LBZ GM_PB_ADD_CAP_L

    ; Normal capture check
    LDI HIGH(BOARD)
    PHI 13
    GLO 11
    PLO 13
    LDN 13
    LBZ GM_PB_CAP_R

    ANI COLOR_MASK
    XRI BLACK
    LBNZ GM_PB_ADD_CAP_L  ; Not black = white = enemy
    LBR GM_PB_CAP_R

GM_PB_ADD_CAP_L:
    INC 15
    GHI 11              ; from square from R11.1
    STR 9
    INC 9
    GLO 11
    STR 9
    INC 9

GM_PB_CAP_R:
    ; Capture right (NE = -15 = $F1)
    GHI 11              ; from square from R11.1
    ADI DIR_NE
    PLO 11

    ANI $88
    LBNZ GM_PAWN_DONE

    ; Check en passant
    LDI HIGH(GAME_STATE)
    PHI 13
    LDI LOW(GAME_STATE + GS_EP)
    PLO 13
    LDN 13
    STR 2
    GLO 11
    SM
    LBZ GM_PB_ADD_CAP_R

    ; Normal capture
    LDI HIGH(BOARD)
    PHI 13
    GLO 11
    PLO 13
    LDN 13
    LBZ GM_PAWN_DONE

    ANI COLOR_MASK
    XRI BLACK
    LBNZ GM_PB_ADD_CAP_R
    LBR GM_PAWN_DONE

GM_PB_ADD_CAP_R:
    INC 15
    GHI 11              ; from square from R11.1
    STR 9
    INC 9
    GLO 11
    STR 9
    INC 9
    LBR GM_PAWN_DONE

; --- White pawn (moves south, toward rank 7) ---
GM_PAWN_WHITE:
    ; Single push
    GHI 11              ; from square from R11.1
    ADI DIR_S           ; +16
    PLO 11

    ANI $88
    LBNZ GM_PW_CAPTURES

    LDI HIGH(BOARD)
    PHI 13
    GLO 11
    PLO 13
    LDN 13
    LBNZ GM_PW_CAPTURES

    ; Add single push
    INC 15
    GHI 11              ; from square from R11.1
    STR 9
    INC 9
    GLO 11
    STR 9
    INC 9

    ; Double push if on rank 1 ($1x)
    GHI 11              ; from square from R11.1
    ANI $F0
    XRI $10
    LBNZ GM_PW_CAPTURES

    GLO 11
    ADI DIR_S
    PLO 11

    LDI HIGH(BOARD)
    PHI 13
    GLO 11
    PLO 13
    LDN 13
    LBNZ GM_PW_CAPTURES

    INC 15
    GHI 11              ; from square from R11.1
    STR 9
    INC 9
    GLO 11
    STR 9
    INC 9

GM_PW_CAPTURES:
    ; Capture left (SW = +15 = $0F)
    GHI 11              ; from square from R11.1
    ADI DIR_SW
    PLO 11

    ANI $88
    LBNZ GM_PW_CAP_R

    ; Check en passant
    LDI HIGH(GAME_STATE)
    PHI 13
    LDI LOW(GAME_STATE + GS_EP)
    PLO 13
    LDN 13
    STR 2
    GLO 11
    SM
    LBZ GM_PW_ADD_CAP_L

    ; Normal capture
    LDI HIGH(BOARD)
    PHI 13
    GLO 11
    PLO 13
    LDN 13
    LBZ GM_PW_CAP_R

    ANI COLOR_MASK
    LBZ GM_PW_CAP_R     ; White = friendly

GM_PW_ADD_CAP_L:
    INC 15
    GHI 11              ; from square from R11.1
    STR 9
    INC 9
    GLO 11
    STR 9
    INC 9

GM_PW_CAP_R:
    ; Capture right (SE = +17 = $11)
    GHI 11              ; from square from R11.1
    ADI DIR_SE
    PLO 11

    ANI $88
    LBNZ GM_PAWN_DONE

    ; Check en passant
    LDI HIGH(GAME_STATE)
    PHI 13
    LDI LOW(GAME_STATE + GS_EP)
    PLO 13
    LDN 13
    STR 2
    GLO 11
    SM
    LBZ GM_PW_ADD_CAP_R

    ; Normal capture
    LDI HIGH(BOARD)
    PHI 13
    GLO 11
    PLO 13
    LDN 13
    LBZ GM_PAWN_DONE

    ANI COLOR_MASK
    LBZ GM_PAWN_DONE    ; White = friendly

GM_PW_ADD_CAP_R:
    INC 15
    GHI 11              ; from square from R11.1
    STR 9
    INC 9
    GLO 11
    STR 9
    INC 9

GM_PAWN_DONE:
    RETN

; ==============================================================================
; GM_GEN_KNIGHT - Generate knight moves
; ==============================================================================
GM_GEN_KNIGHT:
    ; R11.1 = from square (set before CALL to avoid BIOS R14 clobber)

    LDI HIGH(KNIGHT_OFFSETS)
    PHI 8
    LDI LOW(KNIGHT_OFFSETS)
    PLO 8               ; R8 = offset table (not R12!)

    LDI 8
    PLO 13

GM_KN_LOOP:
    LDN 8
    STR 2
    GHI 11
    ADD
    PLO 11

    ANI $88
    LBNZ GM_KN_NEXT

    ; Check target
    LDI HIGH(BOARD)
    PHI 7
    GLO 11
    PLO 7
    LDN 7
    LBZ GM_KN_ADD       ; Empty

    ; Check if enemy
    ANI COLOR_MASK
    STR 2
    GLO 12
    XOR
    LBZ GM_KN_NEXT      ; Same color = blocked

GM_KN_ADD:
    INC 15
    GHI 11
    STR 9
    INC 9
    GLO 11
    STR 9
    INC 9

GM_KN_NEXT:
    INC 8
    DEC 13
    GLO 13
    LBNZ GM_KN_LOOP

    RETN

; ==============================================================================
; GM_GEN_BISHOP - Generate bishop moves (4 diagonal rays)
; ==============================================================================
GM_GEN_BISHOP:
    ; R11.1 = from square (set before CALL to avoid BIOS R14 clobber)

    LDI HIGH(BISHOP_DIRS)
    PHI 8
    LDI LOW(BISHOP_DIRS)
    PLO 8               ; R8 = direction table (not R12!)

    LDI 4
    PLO 13

GM_BI_DIR:
    LDN 8
    PHI 13              ; R13.1 = direction (R13.0 is loop counter)

    GHI 11
    PLO 11              ; Reset to from square

GM_BI_RAY:
    GLO 11
    STR 2
    GHI 13              ; Get direction from R13.1
    ADD
    PLO 11

    ANI $88
    LBNZ GM_BI_NEXT_DIR

    LDI HIGH(BOARD)
    PHI 7               ; Use R7 for board lookup (R10 is scan pointer!)
    GLO 11
    PLO 7
    LDN 7
    LBZ GM_BI_ADD       ; Empty - add and continue

    ; Occupied - check color
    ANI COLOR_MASK
    STR 2
    GLO 12
    XOR
    LBZ GM_BI_NEXT_DIR  ; Same color = blocked

    ; Enemy - capture then stop
    INC 15
    GHI 11
    STR 9
    INC 9
    GLO 11
    STR 9
    INC 9
    LBR GM_BI_NEXT_DIR

GM_BI_ADD:
    INC 15
    GHI 11
    STR 9
    INC 9
    GLO 11
    STR 9
    INC 9
    LBR GM_BI_RAY

GM_BI_NEXT_DIR:
    INC 8
    DEC 13
    GLO 13
    LBNZ GM_BI_DIR

    RETN

; ==============================================================================
; GM_GEN_ROOK - Generate rook moves (4 orthogonal rays)
; ==============================================================================
GM_GEN_ROOK:
    ; R11.1 = from square (set before CALL to avoid BIOS R14 clobber)

    LDI HIGH(ROOK_DIRS)
    PHI 8
    LDI LOW(ROOK_DIRS)
    PLO 8               ; R8 = direction table (not R12!)

    LDI 4
    PLO 13

GM_RK_DIR:
    LDN 8
    PHI 13              ; R13.1 = direction (R13.0 is loop counter)

    GHI 11
    PLO 11

GM_RK_RAY:
    GLO 11
    STR 2
    GHI 13              ; Get direction from R13.1
    ADD
    PLO 11

    ANI $88
    LBNZ GM_RK_NEXT_DIR

    LDI HIGH(BOARD)
    PHI 7               ; Use R7 for board lookup (R10 is scan pointer!)
    GLO 11
    PLO 7
    LDN 7
    LBZ GM_RK_ADD

    ANI COLOR_MASK
    STR 2
    GLO 12
    XOR
    LBZ GM_RK_NEXT_DIR

    INC 15
    GHI 11
    STR 9
    INC 9
    GLO 11
    STR 9
    INC 9
    LBR GM_RK_NEXT_DIR

GM_RK_ADD:
    INC 15
    GHI 11
    STR 9
    INC 9
    GLO 11
    STR 9
    INC 9
    LBR GM_RK_RAY

GM_RK_NEXT_DIR:
    INC 8
    DEC 13
    GLO 13
    LBNZ GM_RK_DIR

    RETN

; ==============================================================================
; GM_GEN_QUEEN - Generate queen moves (bishop + rook)
; ==============================================================================
GM_GEN_QUEEN:
    CALL GM_GEN_BISHOP
    CALL GM_GEN_ROOK
    RETN

; ==============================================================================
; GM_GEN_KING - Generate king moves including castling
; ==============================================================================
GM_GEN_KING:
    ; R11.1 = from square (set before CALL to avoid BIOS R14 clobber)

    ; Normal moves (8 directions)
    LDI HIGH(KING_OFFSETS)
    PHI 8
    LDI LOW(KING_OFFSETS)
    PLO 8               ; R8 = offset table (not R12!)

    LDI 8
    PLO 13

GM_KI_LOOP:
    LDN 8
    STR 2
    GHI 11
    ADD
    PLO 11

    ANI $88
    LBNZ GM_KI_NEXT

    LDI HIGH(BOARD)
    PHI 7
    GLO 11
    PLO 7
    LDN 7
    LBZ GM_KI_ADD

    ANI COLOR_MASK
    STR 2
    GLO 12
    XOR
    LBZ GM_KI_NEXT

GM_KI_ADD:
    INC 15
    GHI 11
    STR 9
    INC 9
    GLO 11
    STR 9
    INC 9

GM_KI_NEXT:
    INC 8
    DEC 13
    GLO 13
    LBNZ GM_KI_LOOP

    ; === Castling ===
    GLO 12
    LBZ GM_KI_CASTLE_W

; --- Black castling ---
GM_KI_CASTLE_B:
    GHI 11
    SMI SQ_E8
    LBNZ GM_KI_DONE     ; King not on e8

    LDI HIGH(GAME_STATE)
    PHI 13
    LDI LOW(GAME_STATE + GS_CASTLE)
    PLO 13
    LDN 13
    PLO 11              ; Temp store rights in R11.0

    ; Kingside O-O
    GLO 11
    ANI CASTLE_BK
    LBZ GM_KI_BQ

    LDI HIGH(BOARD)
    PHI 13
    LDI SQ_F8
    PLO 13
    LDN 13
    LBNZ GM_KI_BQ

    LDI SQ_G8
    PLO 13
    LDN 13
    LBNZ GM_KI_BQ

    INC 15
    LDI SQ_E8
    STR 9
    INC 9
    LDI SQ_G8
    STR 9
    INC 9

GM_KI_BQ:
    ; Queenside O-O-O
    GLO 11
    ANI CASTLE_BQ
    LBZ GM_KI_DONE

    LDI HIGH(BOARD)
    PHI 13
    LDI SQ_D8
    PLO 13
    LDN 13
    LBNZ GM_KI_DONE

    LDI SQ_C8
    PLO 13
    LDN 13
    LBNZ GM_KI_DONE

    LDI SQ_B8
    PLO 13
    LDN 13
    LBNZ GM_KI_DONE

    INC 15
    LDI SQ_E8
    STR 9
    INC 9
    LDI SQ_C8
    STR 9
    INC 9
    LBR GM_KI_DONE

; --- White castling ---
GM_KI_CASTLE_W:
    GHI 11
    SMI SQ_E1
    LBNZ GM_KI_DONE

    LDI HIGH(GAME_STATE)
    PHI 13
    LDI LOW(GAME_STATE + GS_CASTLE)
    PLO 13
    LDN 13
    PLO 11              ; Temp store rights in R11.0

    ; Kingside O-O
    GLO 11
    ANI CASTLE_WK
    LBZ GM_KI_WQ

    LDI HIGH(BOARD)
    PHI 13
    LDI SQ_F1
    PLO 13
    LDN 13
    LBNZ GM_KI_WQ

    LDI SQ_G1
    PLO 13
    LDN 13
    LBNZ GM_KI_WQ

    INC 15
    LDI SQ_E1
    STR 9
    INC 9
    LDI SQ_G1
    STR 9
    INC 9

GM_KI_WQ:
    ; Queenside O-O-O
    GLO 11
    ANI CASTLE_WQ
    LBZ GM_KI_DONE

    LDI HIGH(BOARD)
    PHI 13
    LDI SQ_D1
    PLO 13
    LDN 13
    LBNZ GM_KI_DONE

    LDI SQ_C1
    PLO 13
    LDN 13
    LBNZ GM_KI_DONE

    LDI SQ_B1
    PLO 13
    LDN 13
    LBNZ GM_KI_DONE

    INC 15
    LDI SQ_E1
    STR 9
    INC 9
    LDI SQ_C1
    STR 9
    INC 9

GM_KI_DONE:
    RETN

; ==============================================================================
; Data Tables
; ==============================================================================

; Knight offsets (8 L-shaped moves)
KNIGHT_OFFSETS:
    DB $DF      ; -33: up 2, left 1
    DB $E1      ; -31: up 2, right 1
    DB $EE      ; -18: up 1, left 2
    DB $F2      ; -14: up 1, right 2
    DB $0E      ; +14: down 1, left 2
    DB $12      ; +18: down 1, right 2
    DB $1F      ; +31: down 2, left 1
    DB $21      ; +33: down 2, right 1

; King offsets (8 directions)
KING_OFFSETS:
    DB $EF      ; NW (-17)
    DB $F0      ; N  (-16)
    DB $F1      ; NE (-15)
    DB $FF      ; W  (-1)
    DB $01      ; E  (+1)
    DB $0F      ; SW (+15)
    DB $10      ; S  (+16)
    DB $11      ; SE (+17)

; Bishop directions (4 diagonals)
BISHOP_DIRS:
    DB $EF      ; NW (-17)
    DB $F1      ; NE (-15)
    DB $0F      ; SW (+15)
    DB $11      ; SE (+17)

; Rook directions (4 orthogonals)
ROOK_DIRS:
    DB $F0      ; N  (-16)
    DB $10      ; S  (+16)
    DB $FF      ; W  (-1)
    DB $01      ; E  (+1)

; ==============================================================================
; End of Move Generation
; ==============================================================================
