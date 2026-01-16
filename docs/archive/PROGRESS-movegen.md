# RCA 1802 Chess Engine - Move Generation Phase

> Sessions from December 11-17, 2025

**Related files:**
- `PROGRESS.md` - Current session notes
- `PROGRESS-platform.md` - Platform documentation
- `PROGRESS-search.md` - Search implementation & debugging (Dec 18-28, 2025)

---

## Session: December 11, 2025

### Summary
Debugged and fixed move generation. Adopted incremental testing strategy after hours of crashes. All 7 test steps now passing.

---

### Bugs Found & Fixed

#### 1. cpp stderr pollution
- **Symptom:** Hex file started with C4 C4 C4 (NOPs), program crashed or output garbage
- **Cause:** cpp preprocessor warnings mixed into assembly output
- **Fix:** Redirect stderr to separate file: `cpp -P file.asm 2>file-cpp.err > file-pp.asm`

#### 2. INIT_BOARD clear loop writing counter values
- **Symptom:** "1B white pieces" (27) instead of "10" (16)
- **Cause:** `LDI EMPTY` before loop, but `GLO 13` (loop counter check) overwrites D
- **Fix:** Move `LDI EMPTY` inside the loop - D must be reloaded each iteration

```asm
; WRONG - GLO clobbers D
    LDI EMPTY
IB_CLEAR:
    STR 10
    INC 10
    DEC 13
    GLO 13          ; <-- This overwrites D!
    BNZ IB_CLEAR

; CORRECT - reload D each iteration
IB_CLEAR:
    LDI EMPTY       ; Reload every time
    STR 10
    INC 10
    DEC 13
    GLO 13
    BNZ IB_CLEAR
```

#### 3. Pawn init loops writing counter values
- **Symptom:** "17 white pieces" (23) instead of "10" (16) - 7 extra
- **Cause:** Same pattern - `LDI W_PAWN` before loop, GLO overwrites D
- **Fix:** Move `LDI W_PAWN` and `LDI B_PAWN` inside their respective loops

#### 4. Short branch crossing page boundary
- **Symptom:** Assembler error (B flag) on `BNZ GKA_LOOP`
- **Cause:** 1802 short branches only work within 256-byte page; target was on different page
- **Fix:** Use long branch `LBNZ` instead of `BNZ`

---

### Incremental Test Strategy

Created step-by-step test files, each adding one feature:

| Step | Test | Expected | Result |
|------|------|----------|--------|
| 1 | Serial output only | Banner prints | Pass |
| 2 | Add INIT_BOARD | "Board initialized" | Pass |
| 3 | Board scan, count white pieces | "10 white pieces" (16 dec) | Pass |
| 4 | Pawn single pushes | "08 pawn moves" | Pass |
| 5 | Pawn single + double pushes | "10 pawn moves" (16 dec) | Pass |
| 6 | Pawn + Knight moves | "14 moves" (20 dec) | Pass |
| 7 | Full move generation (all pieces) | "14 moves" (20 dec) | Pass |

---

### Key 1802 Architecture Note

The 1802 is an **accumulator-based architecture**. The D register is the sole accumulator - ALL data operations flow through it:

- **Loads/Stores:** LDI, LDN, LDA, STR, STXD
- **Logic:** ANI, ORI, XRI, AND, OR, XOR
- **Math:** ADI, SMI, ADD, SD, SHL, SHR
- **Register transfers:** GLO, GHI, PLO, PHI

**Consequence:** There's no way to check a loop counter (`GLO Rn`) without destroying whatever was in D. Constants must be reloaded inside loops, not before them.

---

### Current State

Move generator handles all piece types:
- Pawns (single + double push)
- Knights (8 L-shaped moves)
- Bishops (4 diagonal rays)
- Rooks (4 orthogonal rays)
- Queen (bishop + rook combined)
- King (8 adjacent squares)

From starting position: **20 legal moves** (0x14 hex)

---

## Session: December 12, 2025

### Step 8: Open Position Test (after 1.e4)
- Created test-step8.asm - position after 1.e4
- **Result:** 0x1E (30 moves)
- Breakdown: Pawns 15, Knights 5, Bishop 5, Queen 4, King 1
- Key insight: Ng1-e2 becomes available (3 knight moves from g1, not 2)
- **Confirms:** Sliding pieces (bishop, queen) correctly generate moves through opened squares

### Step 9: Pawn Captures
- Created test-step9.asm - position after 1.e4 d5
- Added capture logic to GEN_PAWN_AT (CAP_LEFT +$0F, CAP_RIGHT +$11)
- **Result:** 0x1F (31 moves)
- **Confirms:** Pawn diagonal captures working (exd5 adds 1 move)

### Step 10: En Passant
- Created test-step10.asm - position after 1.e4 d5 2.e5 f5
- EP square stored at GAME_STATE+2, checked during capture generation
- **Result:** 0x1F (31 moves)
- Without EP would be 30; with EP adds exf6 e.p.
- **Confirms:** En passant capture working

### Step 11: Castling (O-O and O-O-O)
- Created test-step11.asm - starting position with back rank cleared for castling
- Added castling logic to GEN_KING_AT (checks rights + empty squares)
- **Result:** 0x19 (25 moves)
- Breakdown: Pawns 16, Rooks 5, King 4 (2 normal + 2 castling)
- **Confirms:** Both kingside and queenside castling working

---

### Integration: movegen-new.asm

Created clean replacement module `movegen-new.asm` supporting both colors via R12.

**Integration Bugs Found & Fixed:**

#### 1. R12 clobbering (side-to-move)
- **Symptom:** 02, 12, 02 moves instead of 14, 14, 1E
- **Cause:** Piece generators used R12 for offset table pointers, destroying side-to-move
- **Fix:** Changed offset table storage from R12 to R8

#### 2. R6 clobbering (SCRT link register)
- **Symptom:** Crash/hang at "White start:"
- **Cause:** Sliding piece code used R6 for board lookups
- **Fix:** Changed board lookup register from R6 to R7

#### 3. R10 clobbering (board scan pointer)
- **Symptom:** 03, 10, 05 moves (way off)
- **Cause:** Bishop/rook used R10 for board lookups, but R10 is the main scan pointer
- **Fix:** Changed board lookup register from R10 to R7

#### 4. R7 clobbering (direction storage)
- **Symptom:** 14, 14, 19 (sliding pieces broken after 1.e4)
- **Cause:** Direction stored in R7.1, but board lookup also used R7 (PHI 7 clobbered direction)
- **Fix:** Changed direction storage from R7.1 to R13.1

**Final Result:** 14, 14, 1E

**Key Lesson:** Document register allocation for ALL functions and cross-reference before coding.

---

## Session: December 12, 2025 (continued) - Legal Move Filtering Debug

### CRITICAL BUG FOUND: SCRT CALL/RETN clobbers R7!

The Mark Abene SCRT (Standard Call/Return Technique) implementation uses **R7 as a temporary register** during every CALL and RETN:

```asm
CALL:
    PLO 7           ; <-- Saves D in R7.0
    ...
    GLO 7           ; <-- Restores D from R7.0

RET:
    PLO 7           ; <-- Saves return value in R7.0
    ...
    GLO 7           ; <-- Restores return value from R7.0
```

**Consequence:** R7 CANNOT be used to pass data across function calls! Any value in R7 will be destroyed by the next CALL or RETN.

### Original Bug Symptoms

- test-step13 (legal move filter) returned 05 instead of 04 for Ke1 vs BQe8 position
- Single iteration test (test-debug9) worked correctly
- Full loop returned wrong count

### Root Cause Analysis

MAKE_MOVE stored pieces in R7:
- R7.0 = moving piece
- R7.1 = captured piece

UNMAKE_MOVE read from R7 to restore the board.

**But:** Between MAKE_MOVE and UNMAKE_MOVE, we called IS_IN_CHECK, which used CALL internally. Every CALL clobbered R7.0!

### The Fix: Use Memory Instead of R7

Created MAKE_MOVE_MEM and UNMAKE_MOVE_MEM that store pieces to fixed memory:

```asm
MOVE_PIECE  EQU $5090   ; Moving piece storage
CAPT_PIECE  EQU $5091   ; Captured piece storage
```

**Key pattern for 1802:** Always set the destination pointer BEFORE loading data into D:

```asm
; WRONG - LDI clobbers D after loading piece
    LDN 10              ; D = piece
    LDI HIGH(BOARD)     ; D = $50 (CLOBBERS PIECE!)
    PHI 8

; CORRECT - Set pointer first, then load data
    LDI HIGH(BOARD)
    PHI 8
    GLO 11
    PLO 8               ; R8 now points to destination
    LDN 10              ; D = piece (safe - next op is STR)
    STR 8               ; Store immediately
```

### Working Code: test-debug15.asm, test-debug16.asm

- test-debug15: Verified make/unmake works with memory-based approach (06, 00, 06, 00, 06)
- test-debug16: Full legal move loop with memory-based make/unmake (05, 04)

### SCRT Reserved Registers

Do NOT use across function calls:
- R4 = CALL PC
- R5 = RET PC
- R6 = Link register
- **R7 = Temporary (clobbered by every CALL/RETN!)**

---

## Session: December 13, 2025 - D Register Clobbering Bug

### Critical Bug: Return Values in D Get Clobbered

**Symptom:** Function returns correct value, but caller prints wrong value.

**Root Cause:** On 1802, D is the sole accumulator. EVERY operation touches D:
- LDI, LDN, LDA (loads)
- STR, STXD (stores read D)
- ADD, ADI, SM, SMI (arithmetic)
- AND, OR, XOR, ANI, ORI, XRI (logic)
- GLO, GHI (register reads)

**Example Bug:**
```asm
    CALL MY_FUNCTION        ; Returns value in D
    LDI HIGH(STR_RESULT)    ; <-- CLOBBERS D!
    PHI 8
    CALL SERIAL_PRINT_STRING
    CALL SERIAL_PRINT_HEX   ; Prints garbage, not return value
```

**Fix:** Save return value to stack or register immediately:
```asm
    CALL MY_FUNCTION
    STXD                    ; Save D to stack immediately
    ; ... print label ...
    CALL SERIAL_PRINT_STRING
    IRX
    LDX                     ; Restore D
    CALL SERIAL_PRINT_HEX   ; Now prints correct value
```

### Best Practice for 1802

**Never use D as a parameter or return value convention.** Instead:
- Pass parameters via dedicated registers (R11, R12, etc.)
- Return values via dedicated registers (R13.0, R14.0, etc.)
- If you must return in D, caller must save it IMMEDIATELY

---

## Session: December 16, 2025 - Alpha-Beta Search Implementation

### Step 15: Depth-1 Search Test - PASSING

Created test-step15.asm with simplified alpha-beta search:

**Test Position:** White Ke4 vs Black Qd4 (undefended) + Black Kh8
- 8 hardcoded king moves from e4
- Expected: Find Kxd4 as best move (captures free queen)

**Bug Found & Fixed: Move Pointer Corruption**

- **Symptom:** First two moves correct (34-23, 34-24), then 00-00 repeating forever
- **Root Cause:** Serial I/O clobbers R11.0, which was being used as move list pointer
- **Failed Approach:** Using `DEC 11; DEC 11` to "go back" in move list after serial calls - R11.0 was already garbage

**Fix: Memory-Based Pointer Storage**

```asm
MOVE_PTR_LO     EQU $50AD   ; Move list pointer (survives serial clobbering)
MOVE_PTR_HI     EQU $50AE

; At start of loop - restore R11 from memory
SR_LOOP:
    LDI HIGH(MOVE_PTR_LO)
    PHI 10
    LDI LOW(MOVE_PTR_LO)
    PLO 10
    LDN 10
    PLO 11
    INC 10
    LDN 10
    PHI 11

; After loading move - save R11 (now pointing to next move)
    LDI HIGH(MOVE_PTR_LO)
    PHI 10
    LDI LOW(MOVE_PTR_LO)
    PLO 10
    GLO 11
    STR 10
    INC 10
    GHI 11
    STR 10
```

**Result:**
- All 8 moves evaluated correctly
- Best move: 34-33 (Kxd4) with score 0000 (material equal after capture)
- Non-capturing moves: FC7C (-900, down a queen)

### Key Pattern: Register Spilling

**Register spilling** is the practice of saving register state to RAM when:
- Registers are needed for other purposes
- Values must persist across function calls that clobber registers
- Working with more data than available registers can hold

This is what we did with MOVE_PTR_LO/HI - "spilling" the move list pointer to RAM so it survives serial I/O calls.

### Step 16: Depth-2 Search Test - PASSING

**Test Position:** White Qd4 Ke1 vs Black Qd6 Nc4 Pa5 Ke8

This position tests whether deeper search avoids tactical traps:
- Qxd6 looks great at depth-1 (+480, captures queen)
- But Nxd6 recaptures, leaving score -420

**Bug Found: Shared Move Storage Across Plies**

- **Symptom:** Wrong scores after Black's moves (e.g., -200 instead of -100)
- **Root Cause:** MAKE_MOVE_MEM uses MOVE_PIECE/CAPT_PIECE to store piece data. When making Black's move (inner ply), it overwrote White's stored pieces. Unmake then restored wrong pieces.
- **Fix:** Separate storage for each ply level:
  - WHITE_MOVE_PIECE/WHITE_CAPT_PIECE for outer ply
  - MOVE_PIECE/CAPT_PIECE for inner ply

**Results:**

| White Move | Depth-2 Score | Analysis |
|------------|---------------|----------|
| Qxd6 (33-53) | FE5C (-420) | Nxd6 recaptures |
| Qxc4 (33-32) | FF9C (-100) | No recapture |
| Qxa5 (33-40) | FEC0 (-320) | No recapture |

**Best: 33-32 (Qxc4)** with score FF9C (-100)

Depth-2 correctly avoids the "capture the queen" trap and picks the knight capture instead.

---

### Key Pattern: Per-Ply Move Storage

For multi-ply search, each level needs its own make/unmake storage:

```asm
; Outer ply (e.g., White)
WHITE_MOVE_PIECE EQU $5092
WHITE_CAPT_PIECE EQU $5093

; Inner ply (e.g., Black)
MOVE_PIECE       EQU $5090
CAPT_PIECE       EQU $5091
```

For deeper search (depth 3+), this extends to arrays indexed by ply, or stack-based storage.

---

### Search Depth Goals & Performance Estimates

**Target: Depth 4** - Agreed as reasonable goal based on projections.

| Depth | What it sees | 1.75 MHz (Membership Card) | 12 MHz (1806) |
|-------|-------------|---------------------------|---------------|
| 1 | Nothing tactical | Instant | Instant |
| 2 | Simple recaptures | Fast | Fast |
| 3 | Two-move tactics | Seconds | Sub-second |
| 4 | Basic combinations | 10s-minutes | Seconds |
| 5-6 | Deeper tactics | Minutes-hours | 10s-minutes |

**Critical optimizations for depth 4:**
- **Alpha-beta pruning** - Can cut search time by 90%+ by skipping bad lines
- **Quiescence search** - Search captures until position is "quiet" to avoid horizon effects
- **Move ordering** - Try best moves first (captures, checks) to maximize pruning

---

## Session: December 16, 2025 (continued) - Move Generator Integration

### Step 19: Search with Generated King Moves - PASSING

Successfully integrated king move generator with alpha-beta search framework:

**Test Position:** WKe4 WQf3 vs BPd5 BKh8

**Depth-1 Results:**
- 7 moves generated (8 directions - 1 blocked by own queen)
- 6 moves score 0320 (800 = queen - pawn)
- 1 move scores 0384 (900 = Kxd5 captures pawn)
- Best: 34-43 (Kxd5)

**Depth-2 Results:**
- Same scores (black has no captures)
- Best: 34-43 (Kxd5) with score 0384
- Nodes: 001C (28) = 7 white + 21 black responses

**Key Implementation Details:**

1. **Per-ply move lists** at $5100, $5120, $5140, $5160 (32 bytes each)

2. **Color-aware move generation** - uses ply to determine friendly color:
   ```asm
   GLO 12              ; Get ply
   ANI $01             ; Odd = black, even = white
   SHL
   SHL
   SHL                 ; Convert to $08 for black, $00 for white
   ```

3. **King finder per side** - FIND_WHITE_KING and FIND_BLACK_KING

4. **Register allocation** - King move generator uses R8, R9, R10, R13, R14 (avoids R11/R12 conflicts)

---

## Session: December 17, 2025 - Full Move Generation Integration

### Step 20: Full Piece Move Generation with Search - PASSING

Successfully integrated movegen-new.asm with the alpha-beta search framework.

**Key Challenge: R12 Register Conflict**

- Search framework uses R12 as **ply counter** (0, 1, 2, 3...)
- movegen-new.asm uses R12 as **side-to-move** (0=WHITE, 8=BLACK)

**Solution: GENERATE_MOVES_FOR_PLY Wrapper**

Created wrapper function that:
1. Saves ply to memory (TEMP_PLY at $50D9)
2. Calculates ply-specific move list address (ply * 32 + $5100)
3. Derives side-to-move from ply parity (even=WHITE/0, odd=BLACK/8)
4. Sets R12 to side-to-move for GENERATE_MOVES call
5. Calls full move generator
6. Adds $FF terminator to move list
7. Restores R12 to ply value

**Test Results (hardware):**
- Best: 03-12 (Qc2) with score 0384
- Nodes: 00B8 (184 decimal)
- All moves correctly evaluated

### Step 21: Alpha-Beta Cutoffs - PASSING

Added actual pruning logic to NEGAMAX_PLY:

**Key Changes:**
1. `CHECK_BEST_GE_BETA` - Returns 1 if best >= beta (cutoff condition)
2. After updating best, check for cutoff and return early if triggered
3. `UPDATE_PLY_ALPHA` - Sets alpha = max(alpha, best)
4. `INC_CUTOFF_COUNT` - Tracks pruned branches

**Test Results (hardware):**
- Best: 03-12 (Qc2) with score 0384 - same as step-20
- Nodes: 00CF (207 decimal)
- Cutoffs: 0002 - pruning is working!

### Depth Performance Results

| Depth | Nodes | Cutoffs | Time @ 1.75MHz | Time @ 12MHz |
|-------|-------|---------|----------------|--------------|
| 2 | 00B3 (179) | 0002 | Fast | Fast |
| 3 | 0E73 (3699) | 001B (27) | ~1 min | 9 sec |
| 4 | 67B5 (26549) | 00A3 (163) | - | 62 sec |

---

### TODO at End of Phase

- [x] Add full piece move generation (integrate movegen-new.asm)
- [x] Add alpha-beta pruning cutoffs
- [x] Test depth-2, depth-3, depth-4 search
- [ ] Add quiescence search
- [ ] Main chess-engine.asm integration
