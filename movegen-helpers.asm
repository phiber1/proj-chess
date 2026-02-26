; ==============================================================================
; RCA 1802/1806 Chess Engine - Move Generation Helpers
; ==============================================================================
; Helper functions for move generation
; ==============================================================================

; ------------------------------------------------------------------------------
; CHECK_TARGET_SQUARE - Check if move to target square is valid
; ------------------------------------------------------------------------------
; Input:  B.0 = target square (0x88 format)
;         C = side to move color
; Output: D = 0 (can't move), 1 (empty square), 2 (capture)
;         DF = 1 if can move, 0 if blocked by friendly
; Uses:   Temp register
; ------------------------------------------------------------------------------
CHECK_TARGET_SQUARE:
    ; Ensure X=2 for XOR instruction
    SEX 2

    ; First check if square is valid
    GLO 11
    ANI $88
    LBNZ CHECK_TARGET_INVALID

    ; Get piece at target square (use R7, not R13 - R13 is loop counter!)
    LDI HIGH(BOARD)
    PHI 7
    GLO 11
    PLO 7               ; R7 = BOARD + target square

    LDN 7               ; Load piece at target
    LBZ CHECK_TARGET_EMPTY

    ; Square occupied - check color
    ANI COLOR_MASK
    STR 2
    GLO 12              ; Side to move
    XOR                 ; D = side XOR piece_color (0 if same color)
    LBZ CHECK_TARGET_FRIENDLY

    ; Enemy piece - capture
    LDI 1
    SHL                 ; Set DF (D becomes 2, which we want)
    RETN

CHECK_TARGET_FRIENDLY:
    ; Friendly piece - can't move here
    LDI 0               ; D = 0, DF unchanged
    RETN

CHECK_TARGET_EMPTY:
    ; Empty square - can move
    LDI 0
    SHL                 ; Set DF, D stays 0
    LDI 1               ; D = 1
    RETN

CHECK_TARGET_INVALID:
    LDI 0               ; D = 0, DF unchanged
    RETN

; MOVE_FLAGS_TEMP defined in board-0x88.asm ($6406)
; All engine variables consolidated at $6400+ region

; ------------------------------------------------------------------------------
; ENCODE_MOVE_16BIT - Properly encode move as 16-bit value
; ------------------------------------------------------------------------------
; Input:  R13.1 = from square (7 bits)
;         R13.0 = to square (7 bits)
;         MOVE_FLAGS_TEMP = special flags (2 bits) - set before CALL
; Output: R8 = encoded 16-bit move
; Uses:   D
;
; Encoding: [flags:2][to:7][from:7]
; Bits 0-6: from, Bits 7-13: to, Bits 14-15: flags
; NOTE: R14 is off-limits (BIOS uses it for serial baud rate)
; ------------------------------------------------------------------------------
ENCODE_MOVE_16BIT:
    ; Low byte = from (bits 0-6) + bit 0 of to (bit 7)
    ; NO STACK OPERATIONS - use conditional ORI instead
    GHI 13              ; From square
    ANI $7F             ; Ensure 7 bits
    PLO 8               ; 8.0 = from

    GLO 13              ; To square
    ANI $01             ; Get bit 0 of to
    LBZ ENCODE_LOW_DONE ; If to.0 = 0, R8.0 already correct
    ; to.0 = 1, need to set bit 7
    GLO 8
    ORI $80
    PLO 8               ; 8.0 = from | $80
ENCODE_LOW_DONE:

    ; High byte = bits 1-6 of to (bits 0-5) + flags (bits 6-7)
    GLO 13              ; To square
    SHR                 ; Shift right 1 (remove bit 0)
    ANI $3F             ; Mask to 6 bits
    PHI 8               ; 8.1 = to.bits[1-6]

    ; Get flags from memory - use conditional ORI (no stack!)
    RLDI 7, MOVE_FLAGS_TEMP
    LDN 7               ; D = flags
    ANI $03             ; Ensure 2 bits
    LBZ ENCODE_HI_DONE  ; flags = 0 (MOVE_NORMAL), no change needed
    SMI 1
    LBZ ENCODE_FLAG_1   ; flags = 1
    SMI 1
    LBZ ENCODE_FLAG_2   ; flags = 2
    ; flags = 3
    GHI 8
    ORI $C0
    PHI 8
    LBR ENCODE_HI_DONE
ENCODE_FLAG_2:
    GHI 8
    ORI $80
    PHI 8
    LBR ENCODE_HI_DONE
ENCODE_FLAG_1:
    GHI 8
    ORI $40
    PHI 8
ENCODE_HI_DONE:
    RETN

; DECODED_FLAGS defined in board-0x88.asm ($6405)
; All engine variables consolidated at $6400+ region

; ------------------------------------------------------------------------------
; DECODE_MOVE_16BIT - Decode 16-bit move
; ------------------------------------------------------------------------------
; Input:  8 = encoded move (R8, not R6!)
; Output: R13.1 = from square
;         R13.0 = to square
;         DECODED_FLAGS = special flags (stored in memory, not R14!)
; NOTE: R14 is off-limits (BIOS uses it for serial baud rate)
; ------------------------------------------------------------------------------
DECODE_MOVE_16BIT:
    ; NO STACK OPERATIONS - use conditional ORI instead

    ; Extract from (bits 0-6 of low byte)
    GLO 8
    ANI $7F
    PHI 13              ; R13.1 = from

    ; Extract to square (bit 7 of low byte + bits 0-5 of high byte)
    ; First get to.bits[1-6] from high byte, shifted left
    GHI 8               ; High byte
    ANI $3F             ; Bits 0-5 are to.bits[1-6]
    SHL                 ; Shift left 1
    PLO 13              ; R13.0 = to.bits[1-6] << 1

    ; Now check if bit 7 of low byte (to.bit0) is set
    GLO 8               ; Low byte
    ANI $80             ; Check bit 7
    LBZ DECODE_TO_DONE  ; If 0, R13.0 is complete
    ; to.bit0 = 1, add it
    GLO 13
    ORI $01
    PLO 13              ; R13.0 = to (full 7 bits)
DECODE_TO_DONE:

    ; Extract flags (bits 6-7 of high byte) - store to memory
    ; Set up pointer first (before extracting, since LDI clobbers D)
    RLDI 7, DECODED_FLAGS
    ; Now extract and store flags
    GHI 8
    SHR
    SHR
    SHR
    SHR
    SHR
    SHR                 ; Shift right 6
    ANI $03             ; Mask to 2 bits
    STR 7               ; Store to DECODED_FLAGS memory

    RETN

; ------------------------------------------------------------------------------
; ADD_MOVE_ENCODED - Add properly encoded move to list
; ------------------------------------------------------------------------------
; Input:  R13.1 = from square
;         R13.0 = to square
;         D = special flags (MOVE_NORMAL, MOVE_EP, etc.)
;         R9 = move list pointer (updated)
; Output: Move added to list, R9 incremented by 2
; NOTE: R14 is off-limits (BIOS uses it for serial baud rate)
; ------------------------------------------------------------------------------
ADD_MOVE_ENCODED:
    ; Ensure X=2 for stack operations
    SEX 2

    ; Save R7 (used by slider loops for current position!)
    GLO 7
    STXD
    GHI 7
    STXD

    ; Store flags from D to MOVE_FLAGS_TEMP (R14 is off-limits)
    STXD                ; Push flags to stack
    RLDI 7, MOVE_FLAGS_TEMP
    IRX
    LDX                 ; Pop flags back to D
    STR 7               ; Store to memory

    CALL ENCODE_MOVE_16BIT
    ; R8 now has encoded move

    ; Store to move list (big-endian: high byte first)
    GHI 8
    STR 9
    INC 9

    GLO 8
    STR 9
    INC 9

    ; Restore R7
    IRX
    LDXA
    PHI 7
    LDX
    PLO 7

    RETN

; ------------------------------------------------------------------------------
; GEN_PAWN_PROMOTION - Generate all 4 promotion moves
; ------------------------------------------------------------------------------
; Input:  R11.1 = from square (pawn on 7th rank)
;         R11.0 = to square (8th rank)
;         R9 = move list pointer
; Output: 4 moves added (Q, R, B, N promotions)
; ------------------------------------------------------------------------------
GEN_PAWN_PROMOTION:
    ; For now, generate 4 moves with MOVE_PROMOTION flag
    ; (All 4 use same flag; piece type could be encoded differently)
    ; NOTE: ADD_MOVE_ENCODED now takes flags in D (not R14 - BIOS uses it)

    ; Queen promotion
    GHI 11              ; From (from R11.1)
    PHI 13
    GLO 11              ; To
    PLO 13
    LDI MOVE_PROMOTION
    CALL ADD_MOVE_ENCODED

    ; Rook promotion
    GHI 11
    PHI 13
    GLO 11
    PLO 13
    LDI MOVE_PROMOTION
    CALL ADD_MOVE_ENCODED

    ; Bishop promotion
    GHI 11
    PHI 13
    GLO 11
    PLO 13
    LDI MOVE_PROMOTION
    CALL ADD_MOVE_ENCODED

    ; Knight promotion
    GHI 11
    PHI 13
    GLO 11
    PLO 13
    LDI MOVE_PROMOTION
    CALL ADD_MOVE_ENCODED

    RETN

; ------------------------------------------------------------------------------
; CHECK_EN_PASSANT - Check if en passant capture is legal
; ------------------------------------------------------------------------------
; Input:  B.0 = target square
;         C = side to move
; Output: D = 1 if legal en passant, 0 otherwise
; ------------------------------------------------------------------------------
CHECK_EN_PASSANT:
    ; Ensure X=2 for XOR instruction
    SEX 2

    ; Get en passant square from game state
    RLDI 13, GAME_STATE + STATE_EP_SQUARE

    LDN 13              ; Load EP square
    STR 2
    GLO 11              ; Target square
    XOR                 ; Compare (D = target XOR ep, 0 if match)
    BNZ CHECK_EP_NO     ; Not EP square (different)

    ; Target matches EP square
    LDI 1
    RETN

CHECK_EP_NO:
    LDI 0
    RETN

; ------------------------------------------------------------------------------
; GEN_CASTLING_MOVES - Generate castling moves if legal
; ------------------------------------------------------------------------------
; Input:  D = king square (passed in)
;         R12 = side to move
;         R9 = move list pointer
; Output: Castling moves added if legal
; ------------------------------------------------------------------------------
GEN_CASTLING_MOVES:
    ; Ensure X=2 for stack operations
    SEX 2

    ; Save king square on stack
    STXD

    ; Check castling rights
    CALL GET_CASTLING_RIGHTS
    ; D = castling rights

    ; Save castling rights on stack
    STXD

    ; Determine which castling rights to check based on color
    GLO 12
    LBZ GEN_CASTLE_WHITE

GEN_CASTLE_BLACK:
    ; Check black kingside - get rights from stack
    IRX
    LDN 2               ; D = rights
    DEC 2
    ANI CASTLE_BK
    LBZ GEN_CASTLE_BQ

    ; King on e8, rook on h8 - in 0x88: e8=$74, g8=$76
    ; Must verify f8 ($75) and g8 ($76) are empty
    LDI HIGH(BOARD)
    PHI 7
    LDI $75             ; f8
    PLO 7
    LDN 7
    LBNZ GEN_CASTLE_BQ  ; f8 occupied, can't castle

    LDI $76             ; g8
    PLO 7
    LDN 7
    LBNZ GEN_CASTLE_BQ  ; g8 occupied, can't castle

    ; Squares empty - generate castling move
    LDI $74
    PHI 13              ; From (e8)
    LDI $76
    PLO 13              ; To (g8)
    LDI MOVE_CASTLE
    CALL ADD_MOVE_ENCODED

GEN_CASTLE_BQ:
    ; Check black queenside - get rights from stack
    IRX
    LDN 2               ; D = rights
    DEC 2
    ANI CASTLE_BQ
    LBZ GEN_CASTLE_DONE

    ; TODO: Similar check for queenside
    ; For now, skip

    LBR GEN_CASTLE_DONE

GEN_CASTLE_WHITE:
    ; Check white kingside - get rights from stack
    IRX
    LDN 2               ; D = rights
    DEC 2
    ANI CASTLE_WK
    LBZ GEN_CASTLE_WQ

    ; King on e1 ($04), rook on h1 ($07) - in 0x88: e1=$04, g1=$06
    ; Must verify f1 ($05) and g1 ($06) are empty
    LDI HIGH(BOARD)
    PHI 7
    LDI $05             ; f1
    PLO 7
    LDN 7
    LBNZ GEN_CASTLE_WQ  ; f1 occupied, can't castle

    LDI $06             ; g1
    PLO 7
    LDN 7
    LBNZ GEN_CASTLE_WQ  ; g1 occupied, can't castle

    ; Squares empty - generate castling move
    LDI $04
    PHI 13              ; From (e1)
    LDI $06
    PLO 13              ; To (g1)
    LDI MOVE_CASTLE
    CALL ADD_MOVE_ENCODED

GEN_CASTLE_WQ:
    ; Check white queenside - get rights from stack
    IRX
    LDN 2
    DEC 2
    ANI CASTLE_WQ
    LBZ GEN_CASTLE_DONE

    ; TODO: Implementation for queenside

GEN_CASTLE_DONE:
    ; Pop castling rights and king square from stack
    IRX                 ; Pop rights
    IRX                 ; Pop king square
    RETN

; ------------------------------------------------------------------------------
; IS_SQUARE_ATTACKED - Implemented in check.asm
; ------------------------------------------------------------------------------
; This function is fully implemented in check.asm
; No stub needed here

; ==============================================================================
; End of Move Generation Helpers
; ==============================================================================
