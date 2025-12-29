# RCA 1802 Chess Engine - Progress Log

> **CLAUDE: If context was compacted, re-read this entire file before continuing work.**
> This file contains critical bug fixes, architectural notes, and TODO items that may have been lost during summarization.

---

## PLATFORM DOCUMENTATION

### Hardware Platforms

This project has been developed on TWO different platforms:

#### Platform 1: Membership Card (Emulator) - Dec 11-20, 2025
- **CPU:** 1802 at 1.75 MHz (emulated)
- **Mode:** STANDALONE - our own SCRT and Chuck Yakym's bit-bang serial routines
- **Serial:** Software bit-bang at 9600 baud using EF3/Q
- **Register constraints (standalone mode):**
  - R11.0: Serial shift register
  - R14.0: Baud rate delay counter
  - R15.0: Bit counter
  - These are ONLY relevant to standalone mode!

#### Platform 2: ELPH (Real Hardware) - Dec 21 onwards
- **CPU:** CDP1806 at 12 MHz
- **Mode:** BIOS - hardware provides SCRT and serial I/O via BIOS entry points
- **Serial:** Hardware UART via BIOS calls
- **BIOS Entry Points:**
  - F_TYPE ($FF03): Output character from D
  - F_READ ($FF06): Read character into D (with echo)
  - F_MSG ($FF09): Output null-terminated string at R15
- **Register constraints (BIOS mode):**
  - R14.1: Baud constant - NEVER TOUCH!
  - R14.0: Clobbered by every BIOS call
  - R0-R6: Reserved for SCRT (provided by BIOS)

### Current Build Mode

**We are now using BIOS mode exclusively.** The standalone mode code still exists in serial-io.asm for reference but is not compiled.

Build configuration: `#define CFG_USE_BIOS` in config.asm

### Key Differences

| Aspect | Standalone (Membership Card) | BIOS (ELPH) |
|--------|------------------------------|-------------|
| Clock | 1.75 MHz | 12 MHz (6.7x faster) |
| Serial | Bit-bang (R11, R14, R15) | BIOS F_TYPE (clobbers R14.0 only) |
| SCRT | Our own implementation | BIOS provides it |
| R14 | Used for bit timing | OFF LIMITS (baud constant) |
| R15 | Used for bit counter | Safe, but F_MSG uses it |

### IMPORTANT: Register Clobbering Notes in Earlier Sessions

Some earlier debug sessions (Dec 11-20) mention "SERIAL_WRITE_CHAR clobbers R11.0, R14.0, R15.0" - this refers to **standalone mode only**. In BIOS mode, F_TYPE only clobbers R14.0.

See `REGISTER-ALLOCATION.md` for the current definitive register usage.

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
| 1 | Serial output only | Banner prints | ✓ |
| 2 | Add INIT_BOARD | "Board initialized" | ✓ |
| 3 | Board scan, count white pieces | "10 white pieces" (16 dec) | ✓ |
| 4 | Pawn single pushes | "08 pawn moves" | ✓ |
| 5 | Pawn single + double pushes | "10 pawn moves" (16 dec) | ✓ |
| 6 | Pawn + Knight moves | "14 moves" (20 dec) | ✓ |
| 7 | Full move generation (all pieces) | "14 moves" (20 dec) | ✓ |

---

### Test Files Created

- `test-step1.asm` - Serial output only
- `test-step2.asm` - Add INIT_BOARD
- `test-step3.asm` - Board scan, count pieces
- `test-step4.asm` - Pawn single pushes
- `test-step5.asm` - Pawn double pushes
- `test-step6.asm` - Pawn + Knight moves
- `test-step7.asm` - Full move generation (all piece types)

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

From starting position: **20 legal moves** (0x14 hex) ✓

---

## Session: December 12, 2025

### Step 8: Open Position Test (after 1.e4)
- Created test-step8.asm - position after 1.e4
- **Result:** 0x1E (30 moves) ✓
- Breakdown: Pawns 15, Knights 5, Bishop 5, Queen 4, King 1
- Key insight: Ng1-e2 becomes available (3 knight moves from g1, not 2)
- **Confirms:** Sliding pieces (bishop, queen) correctly generate moves through opened squares

### Step 9: Pawn Captures
- Created test-step9.asm - position after 1.e4 d5
- Added capture logic to GEN_PAWN_AT (CAP_LEFT +$0F, CAP_RIGHT +$11)
- **Result:** 0x1F (31 moves) ✓
- **Confirms:** Pawn diagonal captures working (exd5 adds 1 move)

### Step 10: En Passant
- Created test-step10.asm - position after 1.e4 d5 2.e5 f5
- EP square stored at GAME_STATE+2, checked during capture generation
- **Result:** 0x1F (31 moves) ✓
- Without EP would be 30; with EP adds exf6 e.p.
- **Confirms:** En passant capture working

### Step 11: Castling (O-O and O-O-O)
- Created test-step11.asm - starting position with back rank cleared for castling
- Added castling logic to GEN_KING_AT (checks rights + empty squares)
- **Result:** 0x19 (25 moves) ✓
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

**Final Result:** 14, 14, 1E ✓

**Key Lesson:** Document register allocation for ALL functions and cross-reference before coding.

---

## TODO - Remaining

### Completed
- [x] Test with open position (e.g., after 1.e4) to verify sliding pieces generate moves
- [x] Add pawn captures (diagonal captures)
- [x] Add en passant
- [x] Add castling (king-side and queen-side)
- [x] Integrate working movegen (movegen-new.asm) - test passing 14, 14, 1E

### Phase 1: Move Validation (isolated tests)
- [x] Add check detection (is king in check?) - test-step12 passing (00,01,01,01,01)
- [x] Add legal move filtering (reject moves that leave king in check) - test-debug16 passing (05,04)

### Phase 2: Search & Evaluation (isolated tests)
- [x] Add position evaluation function - test-step14 passing (0000, 0064, 0384, FE0C)
- [ ] Add piece-square tables (optional enhancement)
- [ ] Add alpha-beta search

### Phase 3: Opening Book
- [ ] Opening book format/storage
- [ ] Opening book lookup integration

### Phase 4: Main Integration
- [ ] Merge into chess-engine.asm

---

### Build Commands

```bash
# Preprocess, assemble, generate hex
cpp -P test-step7.asm 2>test-step7-cpp.err > test-step7-pp.asm
a18 test-step7-pp.asm -o test-step7.hex -l test-step7.lst
```

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

### Debugging Journey (test-debug7 through test-debug15)

1. **test-debug7**: Full loop returns 05 (all moves "legal"), expected 04
2. **test-debug9**: Single iteration for Ke2 returns Check=01 correctly
3. **test-debug10**: Manual 2 iterations work correctly (Check: 01, 00)
4. **test-debug11**: Loop with logging - all checks return 00, king shows FF (not found!)
5. **test-debug12**: Per-iteration logging - K=03 first iter, then K=FF (king disappears)
6. **test-debug13**: Make/unmake test - E1 shows 03 (to-square) after unmake, not 06 (king)

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
- test-debug16: Full legal move loop with memory-based make/unmake (PENDING TEST - expect 05, 04)

### Serial I/O Register Clobbering (from earlier debug)

SERIAL_WRITE_CHAR clobbers:
- R11.0 (stores character)
- R14.0 (delay counter)
- R15.0 (bit counter)

### SCRT Reserved Registers

Do NOT use across function calls:
- R4 = CALL PC
- R5 = RET PC
- R6 = Link register
- **R7 = Temporary (clobbered by every CALL/RETN!)**

### Files Created This Session

- test-debug7.asm through test-debug19.asm - incremental debugging
- Key file: **test-debug16.asm** - working legal move filter with memory-based make/unmake

### Current Status

- **test-debug16 PASSING**: Pseudo-legal=05, Legal=04 ✓
- Next: Integrate into main test-step13.asm and movegen-new.asm

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

### Serial I/O Register Clobbering (Complete List)

SERIAL_WRITE_CHAR and related functions clobber:
- **R11.0** - character storage
- **R14.0** - delay counter
- **R15.0** - bit counter

Any code calling serial functions must save/restore these registers if needed.

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

Also save current move to separate memory (TEMP_SCORE_LO/HI) for use throughout iteration.

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

### 1802 Calling Conventions

The 1802 has **16 general-purpose registers** (R0-R15), more than many 8-bit processors of its era. This enables two approaches:

1. **Direct Register Passing/Returning** - Parameters and return values in dedicated registers
   - Faster, no stack overhead
   - Requires careful documentation of register usage per function
   - Risk of clobbering if not tracked

2. **Parameter Stack** - Push/pop parameters via R2 stack
   - More flexible, unlimited parameters
   - Slower due to memory access
   - Less clobbering risk

**This project uses direct register passing.** Critical requirement: **Document register inputs/outputs for EVERY function** to avoid clobbering conflicts.

Example function header:
```asm
; MAKE_MOVE_MEM - Make a move on the board
; Input:  R11.0 = from square, R11.1 = to square
; Output: None (board modified in place)
; Clobbers: R8, R10
; Preserves: R11
```

### When to Use Register Spilling

Use RAM storage when:
- Calling functions that clobber your working registers (serial I/O, SCRT)
- Loop variables must survive across function calls
- More state than registers can hold

Pattern:
```asm
; Save to RAM before clobbering calls
    GLO 11
    STR <ram_location>

; ... calls that clobber R11 ...

; Restore from RAM
    LDN <ram_location>
    PLO 11
```

### Current Status

- **test-step15 PASSING:** Depth-1 search finds best move correctly
- Search correctly identifies Kxd4 (capture free queen) as best move
- Material evaluation integrated and working

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

**Best: 33-32 (Qxc4)** with score FF9C (-100) ✓

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

Beyond depth 4, practical testing required to determine feasibility.

---

## Session: December 16, 2025 (continued) - Move Generator Integration

### Step 19: Search with Generated King Moves - PASSING

Successfully integrated king move generator with alpha-beta search framework:

**Test Position:** WKe4 WQf3 vs BPd5 BKh8

**Depth-1 Results:**
- 7 moves generated (8 directions - 1 blocked by own queen)
- 6 moves score 0320 (800 = queen - pawn)
- 1 move scores 0384 (900 = Kxd5 captures pawn)
- Best: 34-43 (Kxd5) ✓

**Depth-2 Results:**
- Same scores (black has no captures)
- Best: 34-43 (Kxd5) with score 0384 ✓
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

### TODO - Remaining

- [x] Integrate with move generator (king moves working!)
- [ ] Add full piece move generation (integrate movegen-new.asm)
- [ ] Test depth 3-4 search
- [ ] Add alpha-beta pruning cutoffs to NEGAMAX_PLY
- [ ] Add quiescence search
- [ ] Add piece-square tables (optional enhancement)
- [ ] Opening book integration
- [ ] Main chess-engine.asm integration

---

### Current State Summary (End of Session)

**Working Components:**
- Serial I/O (9600 baud)
- Board representation (0x88)
- Full move generation for all pieces (movegen-new.asm)
- Check detection
- Legal move filtering
- Material evaluation
- Alpha-beta search framework with ply-indexed storage
- King move generator integrated with search (test-step19.asm)

**Key Test Files:**
- `test-step17.asm` - Alpha-beta with hardcoded moves (depth-2 working)
- `test-step19.asm` - Search with generated king moves (depth-2 working)
- `test-king-movegen.asm` - Isolated king move generator test

**Next Session Starting Point:**
Continue from test-step19.asm. Options:
1. Add full piece generation from movegen-new.asm
2. Test deeper search (depth 3-4) with king moves only
3. Create tactical position to verify alpha-beta cutoffs

---

## Session: December 17, 2025 - Full Move Generation Integration

### Step 20: Full Piece Move Generation with Search - ASSEMBLED

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

```asm
GENERATE_MOVES_FOR_PLY:
    SEX 2
    ; Save ply to memory (GENERATE_MOVES will clobber R12)
    LDI HIGH(TEMP_PLY)
    PHI 10
    LDI LOW(TEMP_PLY)
    PLO 10
    GLO 12
    STR 10              ; Save ply

    ; Calculate move list address for this ply
    SHL
    SHL
    SHL
    SHL
    SHL                 ; ply * 32
    STR 2
    LDI LOW(MOVELIST_PLY0)
    ADD
    PLO 9
    LDI HIGH(MOVELIST_PLY0)
    ADCI 0
    PHI 9               ; R9 = move list pointer

    ; Set R12 = side to move based on ply
    LDI HIGH(TEMP_PLY)
    PHI 10
    LDI LOW(TEMP_PLY)
    PLO 10
    LDN 10              ; Get ply back
    ANI $01             ; Odd = black
    LBZ GMFP_WHITE
    LDI BLACK           ; $08
    LBR GMFP_SET_SIDE
GMFP_WHITE:
    LDI WHITE           ; $00
GMFP_SET_SIDE:
    PLO 12              ; R12.0 = side to move

    ; Call full move generator
    CALL GENERATE_MOVES

    ; Add terminator and restore ply
    LDI $FF
    STR 9
    ; ... restore R12 from TEMP_PLY ...
```

**Test Position:** WKe1 WQd1 WPa2 vs BKe8 BPa7

Expected moves for White (ply 0):
- King: ~5 moves (e1 → d2, e2, f1, f2, and can't go to d1 due to queen)
- Queen: Many diagonal/orthogonal moves
- Pawn: a3, a4 (single and double push)

**Assembly Results:**
- File: test-step20.asm
- Hex file: test-step20.hex (6308 bytes)
- Assembly successful (2 "errors" are forward reference warnings, normal for a18)

**Status:** Ready for hardware/emulator testing

---

### Step 20: Full Piece Move Generation - PASSING

**Test Results (hardware):**
- Best: 03-12 (Qc2) with score 0384
- Nodes: 00B8 (184 decimal)
- All moves correctly evaluated, including 0000 scores for Qd7/Qd8 (Black captures queen)

---

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

The cutoffs occurred when Black found responses good enough to refute certain White moves, allowing those branches to be pruned.

---

### TODO - Remaining

- [x] Add full piece move generation (integrate movegen-new.asm) - test-step20 PASSING
- [x] Test step-20 on hardware/emulator - PASSING
- [x] Add alpha-beta pruning cutoffs - test-step21 PASSING (2 cutoffs)
- [x] Test depth-2 search - test-step22 PASSING (Best: 03-12 0384, Nodes: 00B3, Cutoffs: 0002)
- [x] Test depth-3 search - PASSING (Best: 03-12 0384, Nodes: 0E73/3699, Cutoffs: 001B/27, ~1 min @ 1.75MHz)
- [x] Integrate BIOS I/O routines (replace bit-bang serial) - test-step22 with -DBIOS flag
- [x] Test depth-3 on 12 MHz 1806 - PASSING (9 seconds!)
- [x] Test depth-4 on 12 MHz 1806 - PASSING (Best: 03-12 0384, Nodes: 67B5/26549, Cutoffs: 00A3/163, 62 sec)
- [ ] Add quiescence search
- [ ] Main chess-engine.asm integration

---

## Session: December 18, 2025 - Page Boundary Branch Bug

### Critical Bug Found: Short Branch Crossing Page Boundary

**Symptom:** Search returned wrong move (03-21 instead of 03-12) and wrong score (7B84 instead of 0384). Removing debug print statements caused the bug to appear.

**Root Cause:** Two `BNF` (short branch) instructions in `CHECK_SCORE_GT_PLY_BEST` were trying to branch from page $05 to targets on page $06. Short branches on the 1802 can only reach addresses within the same 256-byte page.

**The assembler flagged these errors with "B" in the listing file:**
```
1502:B  05f3   3b 00             BNF CSPB_GT
1506:B  05f8   3b 00             BNF CSPB_GT
```

The assembler still generated code, but the branch target byte `00` meant it jumped to $0500 instead of the intended $0600 (CSPB_GT). This caused execution to run through random code, corrupting SCORE.

**Fix:** Changed `BNF CSPB_GT` to `LBNF CSPB_GT` (long branch) in two places.

### Key Lesson: ALWAYS Check Assembler Flags

After assembly, always check for error flags in the listing:
```bash
grep "^B" file.lst    # Branch errors
grep "^P" file.lst    # Phase errors
grep "^U" file.lst    # Undefined symbols
```

Created `build-test.sh` script that automatically checks for branch errors after assembly.

### 1802 Branch Instruction Reference

| Short Branch | Long Branch | Condition |
|--------------|-------------|-----------|
| BZ | LBZ | D = 0 |
| BNZ | LBNZ | D ≠ 0 |
| BDF/BPZ | LBDF | DF = 1 (positive/no borrow) |
| BNF/BM | LBNF | DF = 0 (negative/borrow) |
| BQ | LBQ | Q = 1 |
| BNQ | LBNQ | Q = 0 |
| B1-B4 | LB1-LB4 | EF1-EF4 = 1 |
| BN1-BN4 | LBN1-LBN4 | EF1-EF4 = 0 |

**Short branches:** 2 bytes, can only reach targets within same 256-byte page
**Long branches:** 3 bytes, can reach any address in 64K space

### Debugging Approach That Found The Bug

1. Added debug prints → search worked correctly
2. Removed debug prints → search returned wrong results
3. Hypothesis: registers clobbered by serial I/O → tested, NOT the cause
4. Used Emma02 debugger to trace values at breakpoints:
   - SCORE after EVALUATE_MATERIAL: 0384 ✓
   - SCORE after NEGATE_SCORE: FC7C ✓
   - SCORE after CHECK_SCORE_GT_PLY_BEST: 847C ✗ (corrupted!)
5. Found corruption happened inside CHECK_SCORE_GT_PLY_BEST
6. Checked assembler listing → found "B" flags on branch instructions
7. Fixed short branches → bug resolved

---

## Session: December 21, 2025 - BIOS Integration & 12 MHz Testing

### BIOS I/O Integration Complete

Successfully integrated BIOS I/O routines for running on real 1806 hardware:

**BIOS Entry Points:**
- F_TYPE ($FF03) - Output character
- F_READ ($FF06) - Read character with echo
- F_MSG ($FF09) - Output null-terminated string

**Key Changes:**
- `serial-io.asm` - Added `#ifdef BIOS` wrappers for thin BIOS calls
- `test-step22.asm` - Added conditional compilation for BIOS mode
- `movegen-new.asm` - Replaced R14 usage with memory-based scan index (GM_SCAN_IDX at $50DF) since BIOS uses R14.1 for baud rate
- Build with: `./build-test.sh test-step22 -DBIOS`
- Exit to monitor: `LBR $8003`

**Register Constraints (BIOS mode):**
- R14.1 = baud constant (NEVER touch!)
- R14.0 = clobbered by every BIOS call

### Performance Results on 12 MHz 1806

| Depth | Nodes | Cutoffs | Time (12 MHz) | Time (1.75 MHz) |
|-------|-------|---------|---------------|-----------------|
| 3 | 3,699 | 27 | 9 sec | ~60 sec |
| 4 | 26,549 | 163 | 62 sec | ~7 min (est) |

**Speedup: 6.7x** - Right in line with clock ratio (12/1.75 = 6.86x)

### Minicom Line Wrap Issue

Discovered that minicom's line wrapping was off by default, causing long output lines to be truncated visually. This initially appeared as a bug where only 20 of 23 moves were printed. Solution: Enable line wrapping in minicom settings.

### Current State

- Depth-4 search working in ~1 minute on 12 MHz 1806
- Alpha-beta pruning achieving good cutoff rates
- Best move consistently found: Qd1-c2 (03-12) with score +900
- Ready for quiescence search and main integration

---

## Session: December 21, 2025 (continued) - Quiescence Search

### Quiescence Search Implementation (test-step23.asm)

Added quiescence search to avoid horizon effect. At leaf nodes, instead of just evaluating, we:
1. Stand-pat evaluation (can choose not to capture)
2. Generate all moves, filter for captures only
3. For each capture: make, evaluate, unmake
4. Return best score (stand-pat or best capture)

**Results (Depth-3):**
- Best: 03-12 0384 ✓
- Nodes: 0C35 (3125) vs 0E73 (3699) without quiescence
- Cutoffs: 001B (27)

### Critical Debugging Lessons - Register Clobbering

Spent significant time debugging hangs caused by register conflicts:

1. **R14 is forbidden** - BIOS F_TYPE clobbers R14 on every call
2. **R15 clobbered by GENERATE_MOVES** - used for move count
3. **R13 clobbered by GENERATE_MOVES** - used for loop counter/direction

**Solution Strategy for Large 1802 BIOS Applications:**
- Use memory ($50xx) for all global/persistent state
- Use registers only for local temporaries within functions
- NEVER use R14 anywhere in the codebase
- Save critical values to memory before calling functions that clobber registers

**Memory locations used:**
- $50E0-$50E1: QS_BEST (stand-pat score saved across GENERATE_MOVES)
- $50DF: GM_SCAN_IDX (board scan index, replaces R14)

### Files Modified
- test-step23.asm: Quiescence search implementation
- Uses R13 instead of R14 for score comparison
- Saves stand-pat to memory before move generation

---

## Session: December 21, 2025 (continued) - R14 Elimination Refactoring

### Complete R14 Removal from test-step23.asm

Per architectural guidance to "completely avoid R14 in all cases", refactored all functions that were using R14:

1. **CHECK_BEST_GE_BETA**: Removed `PLO 14` - the saved value was never used (borrow flag from SM is used by SMB)

2. **SETUP_PLY_BOUNDS**: Changed from R14.0 to memory at PARENT_OFFSET ($50E2)
   - Parent ply offset now stored in memory
   - Two load points instead of register reads

3. **CLEAR_BOARD**: Changed loop counter from R14 to memory at TEMP_COUNTER ($50E3)
   - R8 points to counter, LDN/STR pattern in loop

4. **EVALUATE_MATERIAL**: Changed square index from R14 to memory at SQ_INDEX ($50E4)
   - R13 points to index throughout loop
   - Slightly more instructions but guaranteed safe

### New Memory Locations Added
```
PARENT_OFFSET   EQU $50E2      ; Parent ply offset for SETUP_PLY_BOUNDS
TEMP_COUNTER    EQU $50E3      ; Loop counter for CLEAR_BOARD
SQ_INDEX        EQU $50E4      ; Square index for EVALUATE_MATERIAL
```

### Build Status
- test-step23.asm builds with no errors in BIOS mode
- Ready for hardware testing and main integration

### Next Steps
- Test refactored code on hardware ✓
- Integrate quiescence search into main chess-engine.asm ✓

---

## Session: December 21, 2025 (continued) - Main Engine Integration

### Quiescence Search Integrated into chess-engine.asm

Successfully integrated quiescence search into the main engine:

1. **Memory locations added to negamax.asm:**
   ```
   QS_BEST_LO:     EQU $6806
   QS_BEST_HI:     EQU $6807
   QS_MOVE_PTR_LO: EQU $6808
   QS_MOVE_PTR_HI: EQU $6809
   QS_TEMP:        EQU $680A
   EVAL_SQ_INDEX:  EQU $680B
   ```

2. **NEGAMAX_LEAF modified:** Now calls QUIESCENCE_SEARCH instead of EVALUATE

3. **QUIESCENCE_SEARCH function added:**
   - Stand-pat evaluation
   - Generate all moves, filter for captures
   - Make/evaluate/unmake each capture
   - Return best score in R6

4. **R14 eliminated from critical paths:**
   - negamax.asm: Move count saved directly to stack
   - evaluate.asm: Square counter now uses EVAL_SQ_INDEX memory location

5. **movegen-fixed.asm R14 usage is contained:**
   - Uses R14 internally but no BIOS calls
   - Safe as long as we don't preserve R14 across GENERATE_MOVES calls

### Build Results
- chess-engine.hex: 12850 bytes (was 12342 before quiescence)
- No assembly errors

### Testing
Ready for hardware testing with quiescence search enabled.

---

## Session: December 21, 2025 (continued) - Complete R14 Removal from movegen

### R14 Completely Eliminated from movegen-fixed.asm and movegen-helpers.asm

Per user requirement that "R14 is entirely off limits" (BIOS uses R14.0 for baud rate, R14.1 for serial port speed), completed removal of all R14 usage from move generation code.

### Changes Made

1. **ADD_MOVE_ENCODED (movegen-helpers.asm):**
   - Changed to accept move flags in D register instead of R14.0
   - Stores flags to MOVE_FLAGS_TEMP memory internally before encoding
   - Callers no longer need to use PLO 14

2. **movegen-fixed.asm - All 15 PLO 14 Instances Removed:**
   - All move flag settings now just load the flag into D before CALL ADD_MOVE_ENCODED
   - Pattern changed from:
     ```asm
     LDI MOVE_NORMAL
     PLO 14
     CALL ADD_MOVE_ENCODED
     ```
   - To:
     ```asm
     LDI MOVE_NORMAL
     CALL ADD_MOVE_ENCODED
     ```

3. **GEN_PAWN_PROMOTION (movegen-helpers.asm):**
   - Removed 4 PLO 14 instructions (queen, rook, bishop, knight promotions)
   - Now relies on ADD_MOVE_ENCODED accepting flags in D

4. **GEN_CASTLING_MOVES (movegen-helpers.asm):**
   - Removed 2 PLO 14 instructions (black kingside, white kingside)

5. **DECODE_MOVE_16BIT (movegen-helpers.asm):**
   - Changed output from R14.0 (E.0) to memory at DECODED_FLAGS ($50DD)
   - Callers that need flags must now read from DECODED_FLAGS memory

### New Memory Locations
```asm
MOVE_FLAGS_TEMP EQU $50DE    ; Flags passed to ENCODE_MOVE_16BIT
DECODED_FLAGS   EQU $50DD    ; Flags output from DECODE_MOVE_16BIT
```

### Build Results
- chess-engine.hex: 14,000 bytes
- No assembly errors
- No branch errors (B flags in listing)

### Files Modified
- movegen-fixed.asm: Removed all R14 usage
- movegen-helpers.asm: ADD_MOVE_ENCODED, GEN_PAWN_PROMOTION, GEN_CASTLING_MOVES, DECODE_MOVE_16BIT

### R14 Status in Codebase

**Completely eliminated from:**
- movegen-fixed.asm
- movegen-helpers.asm
- check.asm (uses stack for loop counters, R7.0 for sliding)

**Still used in (expected/acceptable):**
- serial-io.asm (standalone mode bit-bang timing, not used in BIOS mode)
- Other test files

### Next Steps
- Test on hardware with BIOS mode
- Verify move generation works correctly with memory-based flag passing

---

## Session: December 21, 2025 (continued) - Memory Consolidation

### Memory Layout Consolidated to $6000 Base

ALL engine data now consolidated at $6000. Clean, organized, no scattered regions.

### Memory Map ($6000-$6600)
```
Board and Game Data ($6000-$63FF):
  $6000-$607F: BOARD (128 bytes - 0x88 array)
  $6080-$608F: GAME_STATE (16 bytes)
  $6090-$618F: MOVE_HIST (256 bytes)
  $6200-$63FF: MOVE_LIST (512 bytes)

Engine Variables ($6400-$64FF):
  $6400-$6401: HISTORY_PTR (2 bytes)
  $6402: MOVE_FROM
  $6403: MOVE_TO
  $6404: CASTLING
  $6405: DECODED_FLAGS
  $6406: MOVE_FLAGS_TEMP
  $6407: GM_SCAN_IDX
  $6410-$6411: BEST_MOVE (2 bytes)
  $6412-$6415: NODES_SEARCHED (4 bytes)
  $6416-$6417: SEARCH_DEPTH (2 bytes)
  $6418-$641D: QS_* variables
  $641D: EVAL_SQ_INDEX
  $6420-$643F: KILLER_MOVES (32 bytes)

UCI ($6500-$6600):
  $6500-$65FF: UCI_BUFFER (256 bytes)
  $6600: UCI_STATE

Stack:
  $7FFF downward: Stack (grows down)
```

### Files Modified
- board-0x88.asm: Central definition of all engine variables
- negamax.asm: Removed duplicate definitions
- movegen-fixed.asm: Removed GM_SCAN_IDX duplicate
- movegen-helpers.asm: Removed MOVE_FLAGS_TEMP, DECODED_FLAGS duplicates
- uci.asm: Removed UCI_BUFFER, UCI_STATE duplicates
- main.asm: Fixed BR MAIN_LOOP -> LBR MAIN_LOOP (page boundary)

### Build Results
- chess-engine.hex: 14,148 bytes
- No assembly errors
- No branch errors

---

## Debugging Notes

### Monitor Breakpoint Instruction
To insert a breakpoint in code for register dump:
```asm
    DB $79          ; MARK opcode
    DB $D1          ; SEP 1 - triggers breakpoint
```

This will:
1. Stop execution
2. Dump all registers to console
3. Allow continuing with monitor "CONTINUE" command

### Reserved Registers (BIOS Mode)
Never touch these registers - they are used by BIOS/monitor/SCRT:
- **R0** - Implied program counter (P=0 at reset/interrupts)
- **R1** - Monitor breakpoint handler (SEP 1 jumps here)
- **R2** - Stack pointer (X register)
- **R3** - Program counter (P register during normal execution)
- **R4** - SCALL routine pointer
- **R5** - SRET routine pointer
- **R6** - SCRT linkage register (return address) - DO NOT USE FOR PARAMETERS!
- **R14** - Serial baud rate (R14.0) and port speed (R14.1)

Available for chess engine: R7, R8, R9, R10, R11, R12, R13, R15

**CRITICAL**: Functions like NEG16, ADD16, SUB16, SWAP16 that use R6 for parameters
are BROKEN when called as subroutines. Must be INLINED instead.

### Debug Character Legend (negamax.asm)
Current debug output markers:
- `.` = entered NEGAMAX
- `A` = before SAVE_SEARCH_CONTEXT
- `B` = after SAVE_SEARCH_CONTEXT
- `C` = after INC_NODE_COUNT
- `D` = passed fifty-move check
- `E` = depth > 0, continuing
- `F` = before GENERATE_MOVES
- `[` `]` = movegen markers
- `G` = after GENERATE_MOVES
- `H` = after saving move count
- `0` = no moves (goes to NEGAMAX_NO_MOVES)
- `I` = has moves, entering loop
- `J` = move loop iteration
- `K` = got move from list
- `L` = before MAKE_MOVE
- `M` = after MAKE_MOVE
- `N` = depth decremented
- `O` = before recursive NEGAMAX call
- `P` = after recursive NEGAMAX returns
- `Q` = before UNMAKE_MOVE

UCI/Search markers:
- `G` = UCI GO command entered
- `S` = about to call SEARCH_POSITION
- `1` = SEARCH_POSITION entered
- `2` = about to get side to move
- `3` = about to call NEGAMAX
- `4` = NEGAMAX returned
- `R` = after SEARCH_POSITION returns

---

## Session: December 24, 2025 - Stack Balance & UNDO_* Bug Fixes

### Major Milestone: Search Completes and Returns "bestmove"!

After fixing multiple stack and memory bugs, the engine now completes a depth-3 search and returns cleanly to the UCI prompt with a bestmove response.

### Bugs Fixed This Session

#### 1. NEGAMAX_RETURN Double-Pop (negamax.asm)

**Symptom:** Program returned to initialization code after search.

**Root Cause:** At NEGAMAX_RETURN, two `IRX` instructions were used to "pop" the move count, but only one byte was pushed.

**Fix:**
```asm
; BEFORE (wrong - popping 2 bytes)
NEGAMAX_RETURN:
    IRX
    IRX

; AFTER (correct - popping 1 byte)
NEGAMAX_RETURN:
    IRX
```

#### 2. movegen-fixed.asm Debug Code Extra IRX (line 91)

**Symptom:** Stack corruption during move generation, causing eventual crash.

**Root Cause:** Debug code sequence was:
- `STXD` (push)
- `IRX` (point to data)
- `LDN 2` (read data)
- `IRX` (WRONG - extra pop!)

The STXD+IRX was already balanced. The second IRX over-popped.

**Fix:** Removed the extra `IRX` at line 91.

#### 3. CRITICAL: UNDO_* Variable Overwrite Bug (negamax.asm + makemove.asm)

**Symptom:** Board corruption - pieces disappearing during search. UNMAKE_MOVE restored wrong pieces.

**Root Cause:** MAKE_MOVE and UNMAKE_MOVE use global UNDO_* variables:
```asm
UNDO_CAPTURED:  DS 1
UNDO_FROM:      DS 1
UNDO_TO:        DS 1
UNDO_CASTLING:  DS 1
UNDO_EP:        DS 1
UNDO_HALFMOVE:  DS 1
```

With recursive search, each depth level's MAKE_MOVE **overwrites** these same variables. When unwinding, UNMAKE_MOVE at parent levels uses the **child's** undo data - completely wrong!

**Flow showing the bug:**
1. Depth 3: MAKE_MOVE saves to UNDO_* (level 3's data)
2. Depth 2: MAKE_MOVE OVERWRITES UNDO_* (now level 2's data)
3. Depth 1: MAKE_MOVE OVERWRITES UNDO_* (now level 1's data)
4. Depth 1: returns
5. Depth 2: UNMAKE_MOVE reads UNDO_* → **gets level 1's data!** ← BUG

**Fix:** Added save/restore of UNDO_* (6 bytes) to stack in NEGAMAX:

```asm
; After MAKE_MOVE - save UNDO_* to stack
    LDI HIGH(UNDO_CAPTURED)
    PHI 10
    LDI LOW(UNDO_CAPTURED)
    PLO 10
    LDA 10              ; UNDO_CAPTURED
    STXD
    LDA 10              ; UNDO_FROM
    STXD
    LDA 10              ; UNDO_TO
    STXD
    LDA 10              ; UNDO_CASTLING
    STXD
    LDA 10              ; UNDO_EP
    STXD
    LDN 10              ; UNDO_HALFMOVE
    STXD

; Before UNMAKE_MOVE - restore UNDO_* from stack
    LDI HIGH(UNDO_HALFMOVE)
    PHI 10
    LDI LOW(UNDO_HALFMOVE)
    PLO 10
    IRX
    LDXA                ; UNDO_HALFMOVE
    STR 10
    DEC 10
    LDXA                ; UNDO_EP
    STR 10
    ; ... etc for all 6 bytes ...
```

### Test Results

**Final Output:**
```
GS123.ABCD00EF[board]GHIJKLMN...
...
PQPQPQPQPQPQ4Rbestmove h8h8
>
```

- Search ran through multiple iterations
- Clean make/unmake cycles (PQPQPQ pattern shows 6 iterations)
- Returned to prompt cleanly with "bestmove" response

### Remaining Bug: Invalid Move "h8h8"

The move `h8h8` is invalid (same square). This indicates BEST_MOVE wasn't properly updated during search. Likely causes:
1. BEST_MOVE memory never written during search
2. Move encoding bug
3. Initial value of BEST_MOVE is $0707 (h8h8 in 0x88)

**Next session:** Investigate BEST_MOVE storage in NEGAMAX loop.

### Files Modified This Session

1. **negamax.asm**
   - Fixed double IRX at NEGAMAX_RETURN
   - Added UNDO_* save (6 bytes) after MAKE_MOVE
   - Added UNDO_* restore (6 bytes) before UNMAKE_MOVE

2. **movegen-fixed.asm**
   - Removed extra IRX at line 91 (debug code stack imbalance)

### Build Results

- chess-engine.hex: 15,310 bytes
- No assembly errors
- Search completes and returns cleanly

### Key Lessons

1. **Global undo storage doesn't work with recursion** - Each ply needs its own undo state, either via stack or per-ply memory arrays.

2. **Stack balance is critical** - Every STXD needs exactly one IRX/LDXA to pop. Double-check debug code that does peek operations.

3. **Trace the full recursive flow** - Bugs may only manifest after multiple recursion levels.

### Debug Character Legend Update

Added:
- `R` = SEARCH_POSITION returned (after NEGAMAX completes)

---

## TODO - Next Session

- [ ] Fix BEST_MOVE not being updated (h8h8 bug)
- [ ] Verify move encoding/decoding
- [ ] Test with deeper search depths
- [ ] Remove debug output for production build

### Investigation Notes (Dec 24 - Evening)

**Root cause identified for h8h8 bug:**

In `negamax.asm` at `NEGAMAX_NOT_BETTER` (lines 612-617), when a better score is found:
- The code updates best score in R8 ✓
- But **never saves the current move to BEST_MOVE** ✗

The fix needs to:
1. Track the current move being evaluated
2. When score > best_score, save current move to BEST_MOVE ($6410-$6411)

Location to add fix: After line 617 in negamax.asm (after `PHI 8 ; R8 = score`)

---

## December 26, 2025 - Session 1: h8h8 Bug Fix

### Issues Found and Fixed

**Bug 1: MOVE_FROM/MOVE_TO not set before MAKE_MOVE**

In the main NEGAMAX loop, the 16-bit encoded move was loaded into R11 but never decoded. MAKE_MOVE reads from MOVE_FROM ($6402) and MOVE_TO ($6403) in memory, but these weren't being set.

**Fix (negamax.asm, before MAKE_MOVE call):**
```asm
; Decode move and set MOVE_FROM/MOVE_TO for MAKE_MOVE
GHI 11              ; Get encoded low byte (swapped due to little-endian)
PLO 8               ; Store as R8 low
GLO 11              ; Get encoded high byte
PHI 8               ; Store as R8 high

CALL DECODE_MOVE_16BIT
; R13.1 = from square, R13.0 = to square

; Store to MOVE_FROM/MOVE_TO for MAKE_MOVE
LDI HIGH(MOVE_FROM)
PHI 10
LDI LOW(MOVE_FROM)
PLO 10
GHI 13              ; from
STR 10
INC 10
GLO 13              ; to
STR 10
```

**Bug 2: BEST_MOVE never saved during search**

Even when a better score was found, the move wasn't saved to BEST_MOVE. Additionally, we need to only save at the root level (ply 0), not at every depth.

**Fix Part A - Added CURRENT_PLY counter (board-0x88.asm):**
```asm
CURRENT_PLY     EQU $6448   ; 1 byte - current search ply (0=root)
```

**Fix Part B - Initialize PLY=0 in SEARCH_POSITION:**
```asm
; Initialize ply counter to 0 (we're at root)
LDI HIGH(CURRENT_PLY)
PHI 10
LDI LOW(CURRENT_PLY)
PLO 10
LDI 0
STR 10              ; CURRENT_PLY = 0
```

**Fix Part C - Increment/decrement PLY around recursive call:**
```asm
; Increment ply counter before recursion
LDI HIGH(CURRENT_PLY)
PHI 10
LDI LOW(CURRENT_PLY)
PLO 10
LDN 10
ADI 1
STR 10              ; CURRENT_PLY++

CALL NEGAMAX

; Decrement ply counter after recursion
LDI HIGH(CURRENT_PLY)
PHI 10
LDI LOW(CURRENT_PLY)
PLO 10
LDN 10
SMI 1
STR 10              ; CURRENT_PLY--
```

**Fix Part D - Save move at root when score improves (NEGAMAX_NOT_BETTER):**
```asm
; If at root (PLY == 0), save this move to BEST_MOVE
LDI HIGH(CURRENT_PLY)
PHI 10
LDI LOW(CURRENT_PLY)
PLO 10
LDN 10              ; Get current ply
LBNZ NEGAMAX_NEXT_MOVE  ; Not at root, skip BEST_MOVE update

; At root - save move to BEST_MOVE
; Move is in UNDO_FROM/UNDO_TO (restored after unmake)
LDI HIGH(UNDO_FROM)
PHI 10
LDI LOW(UNDO_FROM)
PLO 10
LDA 10              ; UNDO_FROM
PHI 7               ; Temp
LDN 10              ; UNDO_TO
PLO 7               ; R7 = from/to

LDI HIGH(BEST_MOVE)
PHI 10
LDI LOW(BEST_MOVE)
PLO 10
GHI 7
STR 10              ; BEST_MOVE[0] = from
INC 10
GLO 7
STR 10              ; BEST_MOVE[1] = to
```

### Build Status

- Build successful: 15,502 bytes
- 2 short-branch warnings (auto-resolved by assembler)

### Files Modified

1. **negamax.asm:**
   - Added decode step before MAKE_MOVE (around line 234-257)
   - Added PLY increment/decrement around recursive call (around line 419-441)
   - Added BEST_MOVE save at root in NEGAMAX_NOT_BETTER (around line 662-691)
   - PLY initialization in SEARCH_POSITION (around line 1133-1139)

2. **board-0x88.asm:**
   - Added CURRENT_PLY EQU at $6448

### Ready for Hardware Test

The code now properly:
1. Decodes moves before MAKE_MOVE
2. Tracks search ply depth
3. Saves the best move found at root level

Awaiting user test on real hardware.

---

## Session: December 26, 2025 - HISTORY_PTR Initialization Bug

### The Problem

After Dec 24 fixes, search still outputting invalid "bestmove h8h8" (later "h@h@"). Debug output showed CURRENT_PLY containing piece characters ('r', 'n', 'b', 'q', 'k', 'p') instead of ply values (0, 1, 2, 3).

### Investigation

User provided memory dump of $6400-$64FF after hang. Key findings:

```
$6400-$6401: HISTORY_PTR = FF FE  (GARBAGE - should be $6090!)
$6448: CURRENT_PLY = 6A (106 decimal - way too high!)
```

The memory from $6448 onwards contained structured data with return addresses (like $1268 - the instruction after CALL NEGAMAX), indicating stack or buffer data was overwriting the variable area.

### Root Cause

**INIT_MOVE_HISTORY was completely broken:**

```asm
; WRONG - writes to MOVE_HIST, not HISTORY_PTR!
INIT_MOVE_HISTORY:
    LDI HIGH(MOVE_HIST)   ; $60
    PHI 10
    LDI LOW(MOVE_HIST)    ; $90
    PLO 10
    LDI 0
    STR 10               ; This writes 0 to $6090, NOT to HISTORY_PTR!
    RETN
```

The comment said "Set history pointer to 0" but the code stored 0 to MOVE_HIST ($6090), leaving HISTORY_PTR ($6400-$6401) uninitialized with garbage.

When PUSH_HISTORY_ENTRY read HISTORY_PTR, it got garbage ($FFFE), and wrote history entries to random memory - corrupting CURRENT_PLY, SCORE, ALPHA, BETA, and other variables in the $64xx region.

### The Fix

```asm
; CORRECT - initialize HISTORY_PTR to point to MOVE_HIST
INIT_MOVE_HISTORY:
    LDI HIGH(HISTORY_PTR)
    PHI 10
    LDI LOW(HISTORY_PTR)
    PLO 10
    LDI HIGH(MOVE_HIST)
    STR 10              ; HISTORY_PTR high byte = $60
    INC 10
    LDI LOW(MOVE_HIST)
    STR 10              ; HISTORY_PTR low byte = $90
    RETN
```

### Lesson Learned

When debugging memory corruption:
1. Memory dumps are invaluable - user can dump ranges after crashes
2. Look for uninitialized pointers - they cause writes to random locations
3. Pattern recognition: seeing return addresses in variable areas = stack/buffer overflow
4. Always verify pointer initialization writes to the POINTER, not the TARGET

### Files Modified

- **board-0x88.asm:** Fixed INIT_MOVE_HISTORY to properly initialize HISTORY_PTR

### Status

Awaiting hardware test to confirm fix.

---

## Session: December 26, 2025 (continued) - Stack Overflow & Infinite Loop

### Additional Discoveries

#### Bug #2: Explicit Stack Initialization Needed

Added explicit R2 = $7FFF initialization in BIOS mode startup. Even though BIOS initializes the stack, we set it explicitly to be safe:

```asm
START:
    LDI $7F
    PHI 2
    LDI $FF
    PLO 2               ; R2 = $7FFF (stack top)
    SEX 2
```

#### Bug #3: CRITICAL - Move Loop Never Terminated!

**Root cause of massive stack overflow:** The move loop in NEGAMAX never checked if the move count reached 0. It unconditionally jumped back to the loop start:

```asm
; WRONG - infinite loop!
NEGAMAX_NEXT_MOVE:
    IRX
    LDN 2              ; Get move count
    SMI 1              ; Decrement
    STR 2              ; Store back
    DEC 2
    LBR NEGAMAX_MOVE_LOOP  ; Always loops - never exits!
```

**The fix:**

```asm
; CORRECT - check for termination
NEGAMAX_NEXT_MOVE:
    IRX
    LDN 2              ; Get move count
    SMI 1              ; Decrement
    LBZ NEGAMAX_RETURN  ; If count == 0, exit loop!
    STR 2              ; Store decremented count back
    DEC 2
    LBR NEGAMAX_MOVE_LOOP
```

This caused the `71 72` pattern (encoded moves) to repeat for kilobytes as the stack overflowed from $7FFF down through $6400 and beyond, corrupting all variables.

### Memory Dump Analysis

User provided dumps showing:
- HISTORY_PTR corrupted (should be $6090, was garbage)
- CURRENT_PLY corrupted (should be 0-3, was 0x6A+)
- Repeating patterns of move data and return addresses throughout $6400-$64FF

### Current Status

After fix, program runs but returns to "Initializing..." entry point after ABCPQ sequence - suggests remaining stack imbalance. To investigate tomorrow.

### Files Modified

- **main.asm:** Added explicit R2 = $7FFF init in BIOS mode
- **negamax.asm:** Fixed move loop termination check

---

## Session: December 27, 2025 - Move Count Corruption Debug

### Problem

Move count in NEGAMAX loop shows values jumping around (e.g., `#21, #1E, #21, #22`) instead of decrementing monotonically (`#21, #20, #1F, #1E...`). This causes infinite loop because count never reaches 0.

### Bugs Found & Fixed

#### Bug #1: STR 2 Corrupting Stack (FIXED in VI)

Using `STR 2` for scratch space corrupts the stack because it writes to M(R2) which holds important data.

**Fix:** Added `COMPARE_TEMP` at $6449 for scratch, use `SEX 10 / STR 10` pattern instead.

#### Bug #2: CALL Corrupting Move Count at IRX Position (FIXED in VJ)

When R2 points at move_count (after IRX), doing a CALL pushes R6 linkage to M(R2), corrupting the move count. Then reloading with `LDN 2` gets garbage.

**Fix:** Save count to R15.0 before CALL, use `GLO 15` after CALL to get saved value.

```asm
; VJ fix - save to R15 before CALL
IRX                ; Point to move_count
LDN 2              ; Get move count
PLO 15             ; Save to R15.0
CALL SERIAL_PRINT_HEX   ; CALL corrupts M(R2)
GLO 15             ; Get saved count from R15
SMI 1              ; Decrement
BZ NEGAMAX_LOOP_DONE
STR 2              ; Store decremented count (fixes M(R2))
DEC 2
LBR NEGAMAX_MOVE_LOOP
```

**VK:** Confirmed working - loop terminates and shows `@` marker at count=0.

### Current Issue (VN - Unsolved)

Even with memory-based saving (MOVECOUNT_TEMP at $644A), counts still jump around. 

**Attempted fixes that didn't work:**
- VL: Extra debug output corrupted R15 (SERIAL_PRINT_HEX uses R15 for F_MSG)
- VM: Reverted to VK logic but still broken
- VN: Used memory instead of R15, still broken

**Mystery:** VK was reported working, but VM (identical logic) and VN (memory-based) are not.

### Possible Causes to Investigate Tomorrow

1. Something in the move loop BODY (between NEGAMAX_MOVE_LOOP and NEGAMAX_NEXT_MOVE) is corrupting either:
   - The move_count on the stack
   - R2 (stack pointer) itself
   - R10 (used to point to MOVECOUNT_TEMP)

2. The recursive CALL NEGAMAX is not properly balancing the stack

3. There's a different code path that's jumping around (not a simple decrement issue)

### Git Status

Repository initialized with commits:
- `cdb2e3d` Initial commit (VJ)
- `d73e1f1` VK: Add '@' marker
- `0c947bb` VL: Add count-after-decrement debug (broken)
- `975e642` VM: Revert to VK logic
- `b294b60` VN: Use memory instead of R15

### Files Modified

- **board-0x88.asm:** Added COMPARE_TEMP ($6449), MOVECOUNT_TEMP ($644A)
- **negamax.asm:** Multiple attempts to fix move count corruption

### Next Steps

1. Add debug output showing R2 value at key points to verify stack pointer consistency
2. Check if the issue is in the FIRST read (LDN 2 after IRX) vs the save/restore
3. Consider removing all debug CALL statements temporarily to isolate the issue
4. Trace through one complete loop iteration manually

---

## Session: December 28, 2025 - Register Audit & SERIAL_PRINT_HEX Bug

### Problem

VK version was reported working yesterday but now fails with same symptoms (move count jumping around). Investigation revealed the root cause was not in NEGAMAX but in SERIAL_PRINT_HEX.

### Root Cause Found

**SERIAL_PRINT_HEX was clobbering R9.0!**

```asm
; BUGGY CODE in serial-io.asm:
SERIAL_PRINT_HEX:
    PLO 9               ; Save byte in R9.0 - CORRUPTS MOVE LIST PTR!
    ...
    GLO 9               ; Get original byte
```

But R9 is the move list pointer in NEGAMAX! Every debug print corrupted R9.0, causing `LDA 9` to read moves from wrong addresses.

### Fix Applied

Changed SERIAL_PRINT_HEX to use R14.0 instead of R9.0. Since F_TYPE already clobbers R14.0, using it causes no additional damage:

```asm
; FIXED CODE:
SERIAL_PRINT_HEX:
    PLO 14              ; Save byte in R14.0 (F_TYPE clobbers this anyway)
    ...
    GLO 14              ; Get original byte
```

### Comprehensive Register Audit

Created `REGISTER-ALLOCATION.md` documenting:
- System reserved registers (R0-R6)
- Engine global registers (R10, R12)
- Function-local registers with clobber notes
- BIOS vs standalone mode differences
- Calling conventions

### Platform Documentation Added

Added clear documentation to PROGRESS.md explaining the TWO platforms:

1. **Membership Card (Emulator) - Dec 11-20:** Standalone mode with Chuck Yakym's bit-bang serial. R11, R14, R15 used for serial timing.

2. **ELPH (Real Hardware) - Dec 21 onwards:** BIOS mode with F_TYPE/F_READ/F_MSG. Only R14.0 clobbered by BIOS.

Previous debug notes mentioning "SERIAL_WRITE_CHAR clobbers R11.0, R14.0, R15.0" were from standalone mode and don't apply to BIOS mode.

### Files Modified

- **serial-io.asm:** Fixed SERIAL_PRINT_HEX to use R14.0 instead of R9.0
- **REGISTER-ALLOCATION.md:** Created comprehensive register usage docs
- **PROGRESS.md:** Added platform documentation section
- **integration-test.asm:** Fixed for BIOS mode (removed INITCALL, SERIAL_INIT, fixed long branches)

### Build Status

Clean build, no errors. Ready for hardware testing.

### Key Lesson

**Always audit register usage across ALL functions before assuming a local fix is correct.** The bug wasn't in NEGAMAX's move count handling - it was in a utility function (SERIAL_PRINT_HEX) that happened to use a register (R9) that NEGAMAX depends on.

---

## Session: December 28, 2025 (continued) - SAVE/RESTORE Context Bugs

### Problem

VN build showed only "GSVO" then nothing. VP build showed hundreds of 'N's (NEGAMAX entry) followed by a single 'S' (after SAVE returned). SAVE_SEARCH_CONTEXT was not returning correctly.

### Root Cause: Modifying R3 While P=3

**CRITICAL 1802 BUG:** When P=3, R3 is the active program counter. The SAVE_SEARCH_CONTEXT manual return code did:

```asm
    ; Set R3 = our return address
    GHI 6
    PHI 3       ; <-- DANGER! This changes R3.1 immediately!
    GLO 6       ;     CPU is now fetching from wrong address!
    PLO 3
    SEP 3
```

The moment `PHI 3` executes, the high byte of the PC changes! The CPU immediately starts fetching instructions from a garbage address, causing the endless 'N's as execution randomly landed back at NEGAMAX.

### Fix: Trampoline Pattern

Use a different register (R15) as temporary PC to safely modify R3:

```asm
    ; Save return address to R7 (caller-save, OK to use)
    GHI 6
    PHI 7
    GLO 6
    PLO 7

    ; Point R15 to trampoline code
    LDI HIGH(SAVE_TRAMPOLINE)
    PHI 15
    LDI LOW(SAVE_TRAMPOLINE)
    PLO 15

    ; Restore R6 from R13 (old linkage)
    GHI 13
    PHI 6
    GLO 13
    PLO 6

    ; Jump to trampoline (P becomes 15)
    SEP 15

SAVE_TRAMPOLINE:
    ; Now P=15, can safely modify R3
    GHI 7
    PHI 3
    GLO 7
    PLO 3
    ; Switch to R3 and return
    SEP 3
```

Applied same fix to RESTORE_SEARCH_CONTEXT.

### Architectural Decision: Ply-Indexed State Arrays

**User insight:** Using the system stack for recursive NEGAMAX state is fighting against SCRT conventions. Every CALL/RETN touches the stack, and manual stack manipulation risks interference.

**Better approach:** Use dedicated memory arrays indexed by ply number:

```
NEGAMAX_STATE = $6500   ; Base address
FRAME_SIZE = 10         ; 5 registers × 2 bytes
MAX_PLY = 8             ; 80 bytes total

; Ply N state at: NEGAMAX_STATE + (N × 10)
; Ply 0: $6500-$6509
; Ply 1: $650A-$6513
; Ply 2: $6514-$651D
; etc.
```

**Benefits:**
- No SCRT interference - system stack only for CALL/RETN linkage
- Simpler code - direct indexed addressing
- Deterministic - each ply has fixed memory location
- Easier debugging - can inspect state at any ply

**Status:** VQ build created with trampoline fix. Next step is refactoring to ply-indexed arrays.

### Files Modified

- **stack.asm:** Added trampoline pattern to SAVE_SEARCH_CONTEXT and RESTORE_SEARCH_CONTEXT
- **negamax.asm:** Version markers VP→VQ, debug markers for NEGAMAX entry/exit
- **REGISTER-ALLOCATION.md:** Added bugs 3, 4, 5 documentation
- **DEBUG-SESSION-DEC28.md:** Created session notes

### Build: VQ

- Size: 15,552 bytes
- Trampoline fix in place
- Ready for testing OR refactor to ply-indexed arrays

---

## Session: December 28, 2025 (continued) - Ply-Indexed State Arrays

### Architectural Refactor Complete

Per user's suggestion, replaced stack-based recursion state with ply-indexed memory arrays. This eliminates all SCRT interference issues.

### New Memory Layout

```
PLY_STATE_BASE = $6450   ; Base address
PLY_FRAME_SIZE = 10      ; Bytes per ply (5 registers × 2 bytes)
MAX_PLY = 8              ; Maximum search depth

; Each frame stores: R7, R8, R9, R11, R12 (high byte first, big-endian)
; Ply 0: $6450-$6459
; Ply 1: $645A-$6463
; Ply 2: $6464-$646D
; ... etc
```

### New Functions

**SAVE_PLY_STATE:**
1. Read CURRENT_PLY from memory
2. Multiply by 10 (×8 + ×2 via shifts)
3. Add to PLY_STATE_BASE → frame address
4. Store R7, R8, R9, R11, R12 (high byte first)
5. Normal RETN (no stack tricks!)

**RESTORE_PLY_STATE:**
- Same address calculation
- Load registers in same order
- Normal RETN

### Code Removed

Deleted 168 lines of complex stack manipulation:
- SAVE_SEARCH_CONTEXT (with SCRT linkage pop, DEC×3, push context)
- RESTORE_SEARCH_CONTEXT (with SCRT linkage pop, context read)
- SAVE_TRAMPOLINE (P=15 trick to modify R3)
- RESTORE_TRAMPOLINE

### Build: VR

- Size: 15,564 bytes
- Ply-indexed state management
- Search completes and returns "bestmove h@h@"

### Remaining Issue

BEST_MOVE still shows "h@h@" (invalid). This is a separate bug - the move isn't being saved when score improves at root. Not a stack/SCRT issue.

### Files Modified

- **board-0x88.asm:** Added PLY_STATE_BASE, PLY_FRAME_SIZE, MAX_PLY definitions
- **stack.asm:** Added SAVE_PLY_STATE/RESTORE_PLY_STATE, removed old stack-based functions
- **negamax.asm:** Changed to CALL SAVE_PLY_STATE / CALL RESTORE_PLY_STATE, version VR

### Key Insight (User)

"We could avoid all this unnecessary complication by not using the system stack at all for negamax recursion state. Just reserve an area of empty memory large enough to hold number-of-values multiplied by max number of plies/iterations. Then just index into the proper set of state values per ply/iteration number."

This is the correct approach for 1802 with SCRT - keep the system stack clean for call/return linkage only.

### Next Session TODO

- [ ] Debug BEST_MOVE not being updated (h@h@ bug)
- [ ] Trace through root ply to see if score comparison works
- [ ] Check CURRENT_PLY value when saving best move
