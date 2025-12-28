# Move Generation - Implementation Status

## Files Created

### movegen.asm - Main Move Generator
**Complete:**
- ✓ Board scanning loop (finds all pieces for current side)
- ✓ Piece type dispatch (pawn, knight, bishop, rook, queen, king)
- ✓ Knight move generation (8-offset table lookup)
- ✓ King move generation (8-offset table lookup)
- ✓ Sliding piece framework (bishop, rook, queen)
- ✓ Pawn move structure (push, double-push, captures)
- ✓ Direction offset constants and tables

**Needs Integration:**
- Move validation (using CHECK_TARGET_SQUARE from helpers)
- Proper move encoding (using ENCODE_MOVE_16BIT)
- Pawn promotions (using GEN_PAWN_PROMOTION)
- En passant (using CHECK_EN_PASSANT)
- Castling (using GEN_CASTLING_MOVES)
- Blocking/capture detection in sliding moves

### movegen-helpers.asm - Support Functions
**Implemented:**
- ✓ `CHECK_TARGET_SQUARE` - Validates move target (empty/capture/friendly)
- ✓ `ENCODE_MOVE_16BIT` / `DECODE_MOVE_16BIT` - Proper 16-bit move encoding
- ✓ `ADD_MOVE_ENCODED` - Add properly encoded move to list
- ✓ `GEN_PAWN_PROMOTION` - Generate all 4 promotion moves
- ✓ `CHECK_EN_PASSANT` - Validate en passant legality
- ✓ `GEN_CASTLING_MOVES` - Generate castling (partial)

**Stubs:**
- `IS_SQUARE_ATTACKED` - Critical for check detection (TODO)

## Move Encoding Format

```
16-bit move value:
┌──────────┬─────────────┬──────────────┐
│ Flags(2) │ To Square(7)│ From Square(7)│
└──────────┴─────────────┴──────────────┘
  bits14-15   bits 7-13      bits 0-6

Bits 0-6:   From square (0x88 format, 0-127)
Bits 7-13:  To square (0x88 format, 0-127)
Bits 14-15: Special move flags

Special flags:
  00: Normal move/capture
  01: Castling
  10: En passant
  11: Promotion (type encoded separately or in extension)
```

## Integration Needed

### 1. Update movegen.asm to use helpers

Replace simplified ADD_MOVE calls with:

```assembly
; Current (simplified):
CALL ADD_MOVE

; Should be:
CALL CHECK_TARGET_SQUARE
BNZ add_it
; ... proper validation
add_it:
    GLO RE              ; from
    PHI RD
    GLO RB              ; to
    PLO RD
    LDI MOVE_NORMAL     ; flags
    PLO RE
    CALL ADD_MOVE_ENCODED
```

### 2. Complete Sliding Move Generation

Add proper blocking/capture detection:

```assembly
GEN_SLIDE_LOOP:
    ; ... move in direction

    ; Check target square
    GLO RF
    PLO RB
    CALL CHECK_TARGET_SQUARE
    ; D = 0 (blocked), 1 (empty), 2 (capture)

    BZ GEN_SLIDE_DONE       ; Blocked by friendly

    PLO RD                  ; Save result
    CALL ADD_MOVE_ENCODED

    GLO RD
    XRI 2
    BZ GEN_SLIDE_DONE       ; Capture ends slide

    BR GEN_SLIDE_LOOP       ; Empty, continue
```

### 3. Complete Pawn Move Generation

**Promotions:**
```assembly
GEN_PAWN_PROMO_W:
    GLO RE              ; from square
    GLO RB              ; to square
    CALL GEN_PAWN_PROMOTION    ; Generates Q/R/B/N
    BR GEN_PAWN_CAPTURES_W
```

**En Passant:**
```assembly
GEN_PAWN_CAPTURES_W:
    ; ... normal capture checks

    ; Check EP
    GLO RB              ; Target square
    CALL CHECK_EN_PASSANT
    BZ skip_ep
    ; Add EP move with MOVE_EP flag
skip_ep:
```

### 4. Add Castling to King Move Generation

```assembly
GEN_KING:
    ; ... normal king moves

    ; Check for castling
    GLO RE              ; King square
    CALL GEN_CASTLING_MOVES

    BR GEN_SKIP_SQUARE
```

### 5. Implement IS_SQUARE_ATTACKED (Critical)

Needed for:
- Legal king moves (can't move into check)
- Castling validation (can't castle through check)
- Check detection (for checkmate/stalemate)

**Algorithm:**
```assembly
IS_SQUARE_ATTACKED:
    ; 1. Check pawn attacks (2 squares based on color)
    ; 2. Check knight attacks (8 squares via offset table)
    ; 3. Check king attacks (8 adjacent squares)
    ; 4. Check sliding attacks (8 directions until hit piece)
    ;    - Diagonal: enemy bishop/queen
    ;    - Orthogonal: enemy rook/queen

    ; Return D=1 if any attacker found
```

## Estimated Code Size

- movegen.asm: ~800-1000 bytes (current structure)
- movegen-helpers.asm: ~400-500 bytes
- Integration updates: ~200-300 bytes

**Total: ~1.5-2KB** (well within budget)

## Testing Strategy

Once integrated, test with:

1. **Initial position move count**: Should generate 20 moves
   - 16 pawn moves (8 single + 8 double)
   - 4 knight moves (2 knights × 2 moves each)

2. **Middle game position**: Verify captures vs quiet moves separate correctly

3. **Promotion test**: Verify 4 moves generated per pawn promotion

4. **Castling test**: Verify rights and square checking

5. **Perft testing**: Compare node counts at depths 1-4 with standard perft results

## Next Steps

1. Create integration patch for movegen.asm (use helpers)
2. Implement IS_SQUARE_ATTACKED (full version)
3. Complete castling validation
4. Add move ordering (captures first, MVV-LVA)
5. Test with perft positions

## Performance Notes

**Estimated cycles per GENERATE_MOVES call:**
- Board scan: ~200-300 cycles
- Per piece: ~50-100 cycles (non-sliding)
- Per piece: ~200-500 cycles (sliding, depends on mobility)
- Average position (~32 pieces, ~40 legal moves): ~8,000-12,000 cycles

**At 12 MHz: ~1ms per move generation** - acceptable for 6-7 ply search.
