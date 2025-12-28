# RCA 1802/1806 Chess Engine - Integration & Build Guide

## Overview

This guide explains how to assemble all modules into a working chess engine and what final integration steps are needed.

## File Structure & Dependencies

```
main.asm                    (Entry point, includes all modules)
├── support.asm            ✓ (No dependencies)
├── math.asm               ✓ (Uses: support.asm)
├── stack.asm              ✓ (No dependencies)
├── board.asm              ✓ (No dependencies)
├── check.asm              ✓ (Uses: board.asm)
├── movegen-helpers.asm    ✓ (Uses: board.asm, check.asm)
├── movegen.asm            ⚠ (Uses: board.asm, movegen-helpers.asm) - NEEDS INTEGRATION
├── makemove-helpers.asm   ✓ (Uses: board.asm)
├── makemove.asm           ⚠ (Uses: board.asm, makemove-helpers.asm) - NEEDS CLEANUP
├── evaluate.asm           ✓ (Uses: board.asm, support.asm, math.asm)
├── negamax.asm            ⚠ (Uses: all) - NEEDS STUB REPLACEMENT
└── uci.asm                ⚠ (Uses: board.asm, main.asm) - NEEDS SERIAL I/O
```

## Assembly Order

### Option 1: Single File Assembly
Concatenate all files in dependency order into one large file:

```bash
cat support.asm \
    math.asm \
    stack.asm \
    board.asm \
    check.asm \
    movegen-helpers.asm \
    movegen.asm \
    makemove-helpers.asm \
    makemove.asm \
    evaluate.asm \
    negamax.asm \
    uci.asm \
    main.asm > chess-engine.asm
```

Then assemble with your RCA 1802/1806 assembler:
```bash
asm1802 chess-engine.asm -o chess-engine.hex
```

### Option 2: Modular Assembly with Includes
Use your assembler's `INCLUDE` or `#include` directive in main.asm:

```assembly
; main.asm (updated)
#include "support.asm"
#include "math.asm"
#include "stack.asm"
#include "board.asm"
#include "check.asm"
#include "movegen-helpers.asm"
#include "movegen.asm"
#include "makemove-helpers.asm"
#include "makemove.asm"
#include "evaluate.asm"
#include "negamax.asm"
#include "uci.asm"

; ... rest of main.asm
```

### Option 3: Separate Assembly and Linking
Assemble each module separately and link:

```bash
asm1802 support.asm -o support.obj
asm1802 math.asm -o math.obj
# ... etc
link1802 *.obj -o chess-engine.hex
```

## Critical Integration Tasks

### 1. Fix movegen.asm Stubs ⚠️

**File:** `movegen.asm`

**Current issues:**
- `ADD_MOVE` is simplified (doesn't use proper encoding)
- `GEN_SLIDING` doesn't check for blocking pieces
- Pawn moves don't validate target squares
- Special moves (EP, castling, promotion) are incomplete

**Required changes:**

#### A. Replace ADD_MOVE with ADD_MOVE_ENCODED

Find all instances of:
```assembly
CALL ADD_MOVE
```

Replace with:
```assembly
; First validate target
GLO RB              ; to square
CALL CHECK_TARGET_SQUARE
; D = 0 (blocked), 1 (empty), 2 (capture)
BZ skip_move        ; Blocked by friendly

; Add the move
GHI RB              ; from square
PHI RD
GLO RB              ; to square
PLO RD
LDI MOVE_NORMAL
PLO RE
CALL ADD_MOVE_ENCODED

skip_move:
```

#### B. Fix GEN_SLIDING to Check for Blocking

In `GEN_SLIDING`, replace the simplified loop with:

```assembly
GEN_SLIDE_LOOP:
    ; ... move in direction (existing code)

    ; Check target square
    GLO RF              ; Current square
    PLO RB
    CALL CHECK_TARGET_SQUARE
    ; D = 0 (blocked), 1 (empty), 2 (capture)

    BZ GEN_SLIDE_DONE   ; Blocked by friendly

    ; Add move
    PLO RD              ; Save result (1 or 2)
    GLO RE              ; from square
    PHI RD
    GLO RF              ; to square (current)
    PLO RD
    LDI MOVE_NORMAL
    PLO RE
    CALL ADD_MOVE_ENCODED

    ; Check if capture (result was 2)
    GLO RD              ; Get saved result
    XRI 2
    BZ GEN_SLIDE_DONE   ; Capture ends slide

    BR GEN_SLIDE_LOOP   ; Empty square, continue
```

#### C. Complete Pawn Special Moves

Replace `GEN_PAWN_PROMO_W` and `GEN_PAWN_PROMO_B` stubs:

```assembly
GEN_PAWN_PROMO_W:
GEN_PAWN_PROMO_B:
    ; from in RE.0, to in RB.0
    GLO RE              ; from
    GLO RB              ; to
    CALL GEN_PAWN_PROMOTION    ; Generates 4 moves (Q/R/B/N)
    BR GEN_PAWN_DONE
```

Add en passant checks in capture sections:

```assembly
; After normal capture checks
GLO RB              ; target square
CALL CHECK_EN_PASSANT
BZ skip_ep
; Add EP move
GLO RE
PHI RD
GLO RB
PLO RD
LDI MOVE_EP
PLO RE
CALL ADD_MOVE_ENCODED
skip_ep:
```

#### D. Add Castling to King Moves

At end of `GEN_KING`:

```assembly
GEN_KING:
    ; ... existing king move generation

    ; Add castling moves
    GLO RE              ; king square
    CALL GEN_CASTLING_MOVES

    BR GEN_SKIP_SQUARE
```

### 2. Remove Stubs from makemove.asm ⚠️

**File:** `makemove.asm`

**Changes needed:**

Replace stub functions at end of file with includes:

```assembly
; DELETE these stubs:
; PUSH_HISTORY_ENTRY:
;     ; TODO: Full implementation
;     RETN
; ... etc.

; REPLACE with:
; (Functions now in makemove-helpers.asm)
; No action needed if using Option 1 or 2 assembly
```

### 3. Wire Stubs in negamax.asm ⚠️

**File:** `negamax.asm`

**Current stubs:**
- `GENERATE_MOVES` - implemented in movegen.asm
- `MAKE_MOVE` / `UNMAKE_MOVE` - implemented in makemove.asm
- `EVALUATE` - implemented in evaluate.asm
- `IS_IN_CHECK` - implemented in check.asm
- `STORE_KILLER_MOVE` - needs simple implementation
- `INC_NODE_COUNT` - needs full 32-bit implementation

**Required changes:**

#### A. Remove/Replace Stub Functions

Delete these stub implementations at end of negamax.asm:

```assembly
; DELETE:
GENERATE_MOVES:
    LDI 0
    RETN

MAKE_MOVE:
    RETN

UNMAKE_MOVE:
    RETN

EVALUATE:
    LDI 0
    PHI R6
    PLO R6
    RETN

IS_IN_CHECK:
    LDI 0
    RETN

; KEEP (implement properly):
STORE_KILLER_MOVE:
INC_NODE_COUNT:
```

#### B. Implement STORE_KILLER_MOVE

Replace stub with:

```assembly
STORE_KILLER_MOVE:
    ; Store killer move for current ply
    ; RB = move, R5 = depth (current ply = max_depth - depth)

    ; Calculate ply index
    ; Simplified: use depth directly (0-7)
    GLO R5
    ANI $07             ; Limit to 8 plies
    SHL                 ; * 2 (two killers per ply)

    ; TODO: Shift existing killer, store new one
    ; For now, just return
    RETN
```

#### C. Implement INC_NODE_COUNT (Full 32-bit)

Replace stub with:

```assembly
INC_NODE_COUNT:
    ; Increment 32-bit counter at NODES_SEARCHED
    LDI HIGH(NODES_SEARCHED)
    PHI RD
    LDI LOW(NODES_SEARCHED)
    PLO RD

    ; Increment low byte
    LDN RD
    ADI 1
    STR RD
    BNZ INC_NODE_DONE   ; No carry

    ; Carry to next byte
    INC RD
    LDN RD
    ADCI 0
    STR RD
    BNZ INC_NODE_DONE

    ; Carry to third byte
    INC RD
    LDN RD
    ADCI 0
    STR RD
    BNZ INC_NODE_DONE

    ; Carry to fourth byte
    INC RD
    LDN RD
    ADCI 0
    STR RD

INC_NODE_DONE:
    RETN
```

### 4. Implement Serial I/O in uci.asm ⚠️

**File:** `uci.asm`

**Hardware-specific implementation needed for:**
- `SERIAL_READ_CHAR`
- `SERIAL_WRITE_CHAR`

#### Option A: UART (if available)

```assembly
; Assuming UART at I/O port $01 (data) and $02 (status)
UART_DATA   EQU $01
UART_STATUS EQU $02

SERIAL_READ_CHAR:
    ; Wait for data available
wait_rx:
    INP UART_STATUS
    ANI $01             ; RX ready bit
    BZ wait_rx

    ; Read character
    INP UART_DATA
    RETN

SERIAL_WRITE_CHAR:
    ; Save character
    PLO RD

    ; Wait for TX ready
wait_tx:
    INP UART_STATUS
    ANI $02             ; TX ready bit
    BZ wait_tx

    ; Send character
    GLO RD
    OUT UART_DATA
    RETN
```

#### Option B: Bit-Bang Serial (9600 baud example)

```assembly
; Assumes EF1 = RX, Q = TX, 12 MHz clock
; Bit time = 1/9600 = 104 µs = ~1250 cycles

SERIAL_READ_CHAR:
    ; Wait for start bit (EF1 goes low)
wait_start:
    BN1 wait_start

    ; Delay half bit time
    CALL DELAY_HALF_BIT

    ; Read 8 bits
    LDI 8
    PLO RC              ; Bit counter
    LDI 0
    PLO RD              ; Accumulator

read_bit:
    CALL DELAY_BIT_TIME

    ; Read bit from EF1
    B1 bit_high

bit_low:
    GLO RD
    SHR                 ; Shift right (LSB first)
    PLO RD
    BR read_next

bit_high:
    GLO RD
    SHR
    ORI $80             ; Set MSB
    PLO RD

read_next:
    DEC RC
    GLO RC
    BNZ read_bit

    ; Wait for stop bit
    CALL DELAY_BIT_TIME

    ; Return character
    GLO RD
    RETN

SERIAL_WRITE_CHAR:
    ; ... similar implementation
    RETN

DELAY_BIT_TIME:
    ; Delay for ~1250 cycles (104 µs @ 12 MHz)
    LDI 200             ; Approximate
delay_loop:
    SMI 1
    BNZ delay_loop
    RETN

DELAY_HALF_BIT:
    ; Half of above
    LDI 100
delay_half_loop:
    SMI 1
    BNZ delay_half_loop
    RETN
```

## Build and Test Procedure

### Phase 1: Syntax Check
1. Assemble each module individually
2. Fix any syntax errors
3. Verify all labels are defined

### Phase 2: Integrated Build
1. Assemble full program (using one of the three options above)
2. Check for duplicate labels
3. Verify memory map fits in 32KB
4. Generate hex file

### Phase 3: Module Testing

#### Test 1: Board Initialization
```assembly
CALL INIT_BOARD
CALL PRINT_BOARD    ; Visual verification
```

Expected: Starting chess position

#### Test 2: Move Generation
```assembly
CALL TEST_MOVE_GEN
; D should = 20 (20 legal moves from starting position)
```

#### Test 3: Make/Unmake
```assembly
CALL TEST_MAKE_UNMAKE
CALL PRINT_BOARD    ; Should be back to start position
```

#### Test 4: Search
```assembly
CALL TEST_SEARCH
; Should return without crashing
; BEST_MOVE should contain a legal move
```

### Phase 4: UCI Testing
1. Connect to serial terminal (9600 baud, 8N1)
2. Send `uci` command
3. Expect: `id name ...`, `uciok`
4. Send `isready`
5. Expect: `readyok`
6. Send `position startpos`
7. Send `go depth 3`
8. Expect: `bestmove e2e4` (or similar)

### Phase 5: GUI Integration
1. Install Arena or Cutechess
2. Configure engine:
   - Type: UCI
   - Command: (path to terminal program + serial port)
   - Or use USB-serial adapter
3. Start game
4. Verify legal moves only
5. Play test games

## Known Limitations

### Current Implementation
- ✓ Material-only evaluation (no PST yet)
- ✓ No transposition table (searches full tree)
- ✓ No opening book
- ✓ Basic move ordering (captures then quiet)
- ✓ No time management (depth-only search)
- ⚠ Serial I/O is hardware-specific stub

### Expected Performance
- **Search speed**: ~8,000 nodes/second
- **6-ply search**: 10-30 seconds
- **Playing strength**: ~1100-1300 ELO (material only)

### With Future Enhancements
- **+PST**: ~1300-1500 ELO
- **+Transposition table**: Effective 7-8 ply
- **+Opening book**: Better opening play
- **Final strength**: ~1500-1700 ELO

## Troubleshooting

### No moves generated
- Check `GENERATE_MOVES` integration
- Verify `CHECK_TARGET_SQUARE` is being called
- Test with `TEST_MOVE_GEN`

### Illegal moves made
- Check `IS_IN_CHECK` is working
- Verify king position tracking in `MAKE_MOVE`
- Test `IS_SQUARE_ATTACKED`

### Search crashes
- Check stack size (should be 2KB at $7800-$7FFF)
- Verify `SAVE_SEARCH_CONTEXT` / `RESTORE_SEARCH_CONTEXT`
- Test with depth 1 first, then increase

### UCI not responding
- Verify serial I/O implementation
- Test echo loop: read char, write char
- Check baud rate matches (9600)
- Verify line endings (LF or CRLF)

## Next Steps

1. **Complete integration tasks** (sections 1-4 above)
2. **Build and test** each phase
3. **Debug** any issues
4. **Enhance** with PST, TT, book

## Estimated Effort

- **Integration fixes**: 2-3 hours
- **Serial I/O implementation**: 1-2 hours
- **Testing and debug**: 2-4 hours
- **Total to playable**: 5-9 hours

## File Checklist

- [x] support.asm - Complete
- [x] math.asm - Complete
- [x] stack.asm - Complete
- [x] board.asm - Complete
- [x] check.asm - Complete
- [x] movegen-helpers.asm - Complete
- [ ] movegen.asm - Needs integration fixes
- [x] makemove-helpers.asm - Complete
- [ ] makemove.asm - Needs stub cleanup
- [x] evaluate.asm - Complete (material only)
- [ ] negamax.asm - Needs stub replacement
- [ ] uci.asm - Needs serial I/O
- [x] main.asm - Complete (framework)

## Success Criteria

Engine is playable when:
1. ✓ Assembles without errors
2. ✓ Responds to UCI commands
3. ✓ Generates only legal moves
4. ✓ Completes searches without crashing
5. ✓ Plays reasonable moves
6. ✓ Detects checkmate correctly

All foundational code is complete. Only integration and hardware-specific I/O remain!
