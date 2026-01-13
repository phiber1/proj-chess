# RCA 1802 Chess Engine - Progress Log

> **CLAUDE: If context was compacted, re-read this file and the related documentation files before continuing work.**

This file contains current session notes. For historical sessions and reference documentation, see:

- `PROGRESS-platform.md` - Platform documentation, register allocation, memory map
- `PROGRESS-movegen.md` - Move generation phase (Dec 11-17, 2025)
- `PROGRESS-search.md` - Search implementation phase (Dec 18-28, 2025)

---

## Current Status (January 13, 2026)

- **Opening Book:** Working! Instant response for Giuoco Piano/Italian Game (47 entries)
- **Depth 2:** Working correctly, ~57 seconds when out of book
- **Transposition Table:** Full internal TT enabled at all nodes!
- **Engine is functionally correct** - search, move generation, evaluation all working
- **Engine size:** 26,938 bytes (includes TT + Zobrist + incremental hash)
- **Search optimizations:** Killer moves, QS alpha-beta, capture ordering, internal TT

### Recent Milestones
- **W15:** Internal TT enabled - TT probe/store at all nodes (~7% speedup)
- **W14:** Incremental Zobrist hash updates in MAKE_MOVE/UNMAKE_MOVE
- **W13:** Fixed critical R7 clobber bug in HASH_XOR_PIECE_SQ

### Test Results (Internal TT)
```
position startpos moves e2e4 e7e5 g1f3 b8c6 f1c4 f8c5 d2d3 g8f6
go depth 2 -> 57s, "D" + 40 internal stores, bestmove f3g5
go depth 2 -> instant, "D", bestmove f3g5 (root TT hit)

position startpos moves e2e4 e7e5 g1f3 b8c6 f1c4 f8c5 d2d3 a7a6
go depth 2 -> 57s, "O" + 40 internal stores, bestmove f3g5
go depth 2 -> instant, "O", bestmove f3g5 (root TT hit)
```

Debug output: uppercase = root hash at start, lowercase = TT_STORE at internal nodes

---

## Session: January 9, 2026 (Evening) - Incremental Hash Updates

### Summary
Added incremental Zobrist hash updates to MAKE_MOVE and UNMAKE_MOVE. Found and fixed a critical bug in HASH_XOR_PIECE_SQ that was clobbering the hash.

### Approach: Careful, Incremental Steps
After previous session's complexity caused bugs, took methodical approach:
1. **Step 1:** Add HASH_XOR_SIDE only (simplest change) - tested, committed
2. **Step 2:** Add piece-square XOR - tested, found bug, fixed, committed
3. **Step 3:** Enable internal TT (deferred to next session)

### Memory Audit
Before adding piece-square XOR, conducted thorough audit:
- Verified no duplicate/conflicting memory definitions
- Confirmed UNDO_* locations distinct from MOVE_* locations
- Separated QS_MOVE_LIST ($6F00) from UCI_BUFFER ($6500) for debugging

### Bug Found: R7 Clobber in HASH_XOR_PIECE_SQ
**Symptom:** Hash drifted during search (start "D", end "c")

**Root cause:** Line 637 stored temp value in R7.0, but R7 held the hash!
```asm
PLO 7               ; R7.0 = rank*8 (WRONG - clobbers hash!)
```

**Fix:** Use R11.0 for temp instead of R7.0

### Hash Update Logic

**MAKE_MOVE (after board modified):**
1. XOR [moving piece, from] - remove from origin
2. XOR [captured piece, to] - remove captured (skips if EMPTY)
3. XOR [moving piece, to] - add to destination
4. XOR side

**UNMAKE_MOVE (after board restored):**
1. XOR [moving piece, to] - remove from destination
2. XOR [captured piece, to] - restore captured (skips if EMPTY)
3. XOR [moving piece, from] - restore to origin
4. XOR side

### Test Results
- Same position twice: "D" start, "d" end (hash matches!), second search instant
- Different position: "O" hash, works correctly
- TT hit confirmed on repeated searches

### Debug Output (still present)
- Uppercase letter (A-P) at search start
- Lowercase letter (a-p) at TT_STORE

### Commits
- W13: Add HASH_XOR_SIDE to MAKE_MOVE/UNMAKE_MOVE
- W14: Add piece-square XOR + fix R7 clobber bug
- Also: Separate QS_MOVE_LIST from UCI_BUFFER

### Next Steps (for future session)
1. Remove debug output
2. Enable internal TT probe/store (remove ply==0 checks)
3. Test for speedup from transposition detection

---

## Session: January 9, 2026 (Morning) - Transposition Table Fix

### Summary
Fixed TT implementation that was broken from previous session. Simplified to root-only probe/store for correctness.

### Problem Identified
Previous session added TT with incremental hash updates in MAKE_MOVE/UNMAKE_MOVE. Multiple bugs:
1. Hash updates in MAKE/UNMAKE were complex and error-prone
2. Internal TT probes were corrupting search (all nodes had same hash as root)
3. Opening book (ply 0-7) was masking the bug - "instant" responses were book hits, not TT hits

### Solution: Simplify to Root-Only TT
1. **Removed** incremental hash updates from MAKE_MOVE and UNMAKE_MOVE
2. **Added** ply check to TT_PROBE - only probe at ply 0 (root)
3. **Added** ply check to TT_STORE - only store at ply 0 (root)
4. Hash computed once via HASH_INIT at start of SEARCH_POSITION

### How It Works Now
- HASH_INIT computes Zobrist hash from current board position
- Hash stays constant during search (no incremental updates)
- TT probe/store only at root - caches root position results
- Same position searched twice = instant TT hit
- Different positions get different hashes (verified: "D" vs "O")

### Test Results
```
position startpos moves e2e4 e7e5 g1f3 b8c6 f1c4 f8c5 d2d3 g8f6
go depth 2  -> "D", 61 seconds, bestmove f3g5
go depth 2  -> "D", instant, bestmove f3g5  (TT hit!)

position startpos moves e2e4 e7e5 g1f3 b8c6 f1c4 f8c5 d2d3 a7a6
go depth 2  -> "O", 61 seconds, bestmove f3g5  (different hash)
go depth 2  -> "O", instant, bestmove f3g5  (TT hit!)
```

### Limitations
- TT only caches root positions (no internal transposition detection)
- Incremental hash updates can be added later as an optimization
- Current implementation is simple and correct - good foundation

### Files Modified
- `makemove.asm` - Removed hash update sections (~150 lines)
- `negamax.asm` - Added ply checks for TT_PROBE and TT_STORE

### Commit
- W12: Fix TT to root-only probe/store (simplified, working)

---

## Session: January 8, 2026 - Transposition Table Implementation (WIP)

### Summary
Implemented transposition table infrastructure with Zobrist hashing. TT appeared to work but was actually broken - opening book was masking the bug.

### Components Added

**1. Zobrist Key Generator (`tools/gen_zobrist.py`)**
- Generates 16-bit Zobrist keys for piece-square combinations
- Uses seed 0x1802CAFE for reproducibility
- 781 keys total: 12 pieces × 64 squares + side + 4 castling + 8 EP files

**2. Zobrist Keys (`zobrist-keys.asm`)**
- 1,562 bytes of key data
- Labels: ZOBRIST_PIECE_SQ, ZOBRIST_SIDE, ZOBRIST_CASTLE, ZOBRIST_EP

**3. TT Variables (`board-0x88.asm`)**
- HASH_HI/LO at $6601-$6602 (current position hash)
- TT_TABLE at $6700 (256 entries × 8 bytes = 2KB)
- TT entry: hash_hi, hash_lo, score_hi, score_lo, depth, flag, move_hi, move_lo

**4. TT Functions (`transposition.asm`)**
- HASH_INIT: Compute full hash from board position
- TT_CLEAR: Zero all TT entries
- TT_PROBE: Look up position, return hit/miss
- TT_STORE: Store search result in TT
- HASH_XOR_PIECE_SQ: XOR piece-square key into hash
- HASH_XOR_SIDE: Toggle side-to-move in hash

**5. Incremental Hash Updates (`makemove.asm`)**
- Added hash XOR updates in MAKE_MOVE and UNMAKE_MOVE
- XOR out piece from origin, XOR in at destination
- XOR captured piece, XOR side-to-move

### Bug Discovery
Opening book covers ply 0-7, so "instant" responses were book hits, not TT hits. At 8+ ply (out of book), TT didn't work - both searches took ~61 seconds.

### Bugs Found (not fully fixed this session)
1. Internal TT probes corrupted BEST_MOVE (fixed: only update at ply 0)
2. MAKE_MOVE used wrong address for castling state (fixed: use GAME_STATE+STATE_CASTLING)
3. Hash updates in MAKE/UNMAKE had register clobbering issues
4. All internal nodes had same hash as root (search corruption)

### Debug Output Added
- Single character (A-P) printed before search showing hash high nibble
- Helps verify hash consistency between searches

### Files Added/Modified
- `tools/gen_zobrist.py` (new)
- `zobrist-keys.asm` (new)
- `transposition.asm` (new)
- `board-0x88.asm` (TT variables)
- `makemove.asm` (hash updates - later removed)
- `negamax.asm` (TT integration)

### Commit
- W11: Add transposition table infrastructure (WIP)

### Status
TT infrastructure in place but not working correctly. Deferred to next session.

---

## Session: January 7, 2026 - Search Optimizations

### Summary
Added multiple search optimizations to improve alpha-beta pruning efficiency. No measurable speedup at depth 2 (overhead cancels gains), but these are foundational for deeper searches.

### Optimizations Implemented

**1. Killer Move Ordering (`ORDER_KILLER_MOVES`)**
- Stores moves that caused beta cutoffs in KILLER_MOVES table
- Promotes killer1/killer2 to front of move list
- Limited to ply 0-2 to reduce overhead
- Fixed STORE_KILLER_MOVE to use CURRENT_PLY (was using SEARCH_DEPTH)

**2. Quiescence Search Alpha-Beta Pruning**
- Stand-pat beta cutoff: if stand-pat >= beta, return immediately
- Alpha update: if stand-pat > alpha, tighten the window
- Delta pruning: if stand-pat + QUEEN_VALUE < alpha, prune
- Loop beta cutoff: stop searching captures when score >= beta

**3. Capture-First Ordering (`ORDER_CAPTURES_FIRST`)**
- Scans move list, identifies captures by checking target square
- Moves all captures to front of list before quiet moves
- Foundation for full MVV-LVA (victim-attacker scoring)
- Limited to ply 0-2 to reduce overhead

### Performance Results
- Baseline (d4 from startpos): 38 seconds - unchanged
- Complex position (ply 9): ~63 seconds - unchanged
- No regression, no improvement at depth 2
- Benefits expected at depth 4+ where pruning has more impact

### Commits
- WX: Opening book support
- WY: Killer move ordering
- WZ: QS alpha-beta pruning
- W10: Capture-first ordering

---

## Session: January 7, 2026 - Opening Book Implementation

### Summary
Implemented opening book support for instant moves in the opening phase. Engine now plays the Giuoco Piano/Italian Game instantly through 7-8 moves.

### Components Added

**1. Book Data Generator (`tools/pgn_to_book.py`)**
- Parses PGN files and generates assembly book data
- Tracks board state to convert algebraic notation to 0x88 squares
- Includes `can_piece_reach()` for proper piece disambiguation
- Generated from GiuocoPiano.pgn (52,811 games)

**2. Book Data (`opening-book.asm`)**
- 47 entries, 640 bytes
- Format: `[ply] [move1_from] [move1_to] ... [response_from] [response_to]`
- Sorted by ply for efficient early-exit
- Terminated with $FF marker

**3. Book Lookup (`opening-book-lookup.asm`)**
- `BOOK_LOOKUP` function searches book for current position
- Returns D=1 if hit (response in BOOK_MOVE_FROM/TO), D=0 if miss
- Early exit when book ply exceeds game ply

**4. Game Move Tracking**
- Added `GAME_PLY` variable to track moves since start position
- UCI position parsing now records moves to `MOVE_HIST` buffer
- `INIT_MOVE_HISTORY` clears both HISTORY_PTR and GAME_PLY

**5. UCI Integration**
- `UCI_CMD_GO` calls `BOOK_LOOKUP` before search
- If book hit, returns instantly without searching
- If miss, falls back to normal search

### Files Modified
- `board-0x88.asm` - Added GAME_PLY, BOOK_MOVE_FROM/TO; updated INIT_MOVE_HISTORY
- `uci.asm` - Move recording in position parsing; book check in go command
- `build.sh` - Added opening-book-lookup.asm and opening-book.asm

### Test Results
```
position startpos
go depth 2
→ bestmove e2e4 (instant - book hit)

position startpos moves e2e4
go depth 2
→ bestmove e7e5 (instant - book hit)

position startpos moves e2e4 e7e5
go depth 2
→ bestmove g1f3 (instant - book hit)

position startpos moves e2e4 e7e5 g1f3
go depth 2
→ bestmove b8c6 (instant - book hit)
```

### Size Impact
- Previous: 17,170 bytes
- Current: 19,250 bytes
- Added: ~2KB for book lookup code + 640 bytes book data

---

## Session: January 6, 2026 - Critical Slider Bug Fixes

### Summary
Fixed two critical bugs in slider (bishop/rook/queen) move generation that were causing memory corruption and incorrect move generation.

### Bug #1: R7 Clobbered by ADD_MOVE_ENCODED (movegen-helpers.asm)

**Symptom:** Memory corruption with repeating $03F0 pattern starting at $6346, eventually crashing into stack.

**Root Cause:** Slider loops use R7.0 to track current position along the ray. ADD_MOVE_ENCODED was clobbering R7 when storing flags to MOVE_FLAGS_TEMP:
```asm
ADD_MOVE_ENCODED:
    LDI HIGH(MOVE_FLAGS_TEMP)
    PHI 7               ; <-- Clobbers R7!
    LDI LOW(MOVE_FLAGS_TEMP)
    PLO 7               ; R7 = $6406, not slider position!
```

After ADD_MOVE_ENCODED returned, slider loop did `GLO 7; ADI direction` using garbage value, causing incorrect moves and eventual memory corruption.

**Fix:** Save/restore R7 in ADD_MOVE_ENCODED:
```asm
ADD_MOVE_ENCODED:
    ; Save R7 (used by slider loops for current position!)
    GLO 7
    STXD
    GHI 7
    STXD
    ; ... rest of function ...
    ; Restore R7
    IRX
    LDXA
    PHI 7
    LDX
    PLO 7
    RETN
```

### Bug #2: R8 Clobbered Before Capture Detection (movegen-fixed.asm)

**Symptom:** Sliders continued past enemy pieces instead of stopping on captures.

**Root Cause:** Slider loops saved CHECK_TARGET_SQUARE result to R8.0, but ENCODE_MOVE_16BIT (called by ADD_MOVE_ENCODED) uses R8 for the encoded move output. The capture detection after ADD_MOVE_ENCODED read garbage:
```asm
    CALL CHECK_TARGET_SQUARE
    PLO 8               ; Save result (0=blocked, 1=empty, 2=capture)
    ...
    CALL ADD_MOVE_ENCODED  ; <-- ENCODE_MOVE_16BIT clobbers R8!
    GLO 8               ; <-- Returns encoded move low byte, NOT result!
    XRI 2
    LBZ GEN_SLIDE_N_RET  ; Capture detection broken
```

**Fix:** Save result to R11.0 instead (target square no longer needed after setting up R13):
```asm
    CALL CHECK_TARGET_SQUARE
    PLO 11              ; Save result to R11.0 (R8 clobbered by ADD_MOVE_ENCODED)
    ...
    CALL ADD_MOVE_ENCODED
    GLO 11              ; Get result from R11.0
    XRI 2
    LBZ GEN_SLIDE_N_RET  ; Capture detection works
```

Applied to all 8 slider directions (N, NE, E, SE, S, SW, W, NW).

### Bug #3: 128-Byte Ply Buffer Calculation (negamax.asm)

**Symptom:** Move list buffer overflow when >32 moves generated.

**Root Cause:** Code used 64 bytes per ply (32 moves max), but positions can have 40+ moves. Also, the 8-bit calculation `ply × 64` was being used, but 128-byte buffers need 16-bit math since `ply × 128` overflows for ply ≥ 2.

**Fix:** Use 128 bytes per ply with proper 16-bit calculation:
```asm
    ; offset_hi = ply >> 1, offset_lo = (ply & 1) << 7
    LDN 10              ; D = current ply (0-3)
    SHR                 ; D = ply >> 1 (0 or 1)
    ADI HIGH(MOVE_LIST) ; D = $62 + (ply >> 1)
    PHI 9
    LDN 10              ; D = ply (reload)
    ANI $01
    BZ NEGAMAX_PLY_EVEN
    LDI $80             ; Odd ply: low byte = $80
    BR NEGAMAX_PLY_DONE
NEGAMAX_PLY_EVEN:
    LDI $00
NEGAMAX_PLY_DONE:
    PLO 9               ; R9 = ply-indexed move list
```

Buffer layout: Ply 0=$6200, Ply 1=$6280, Ply 2=$6300, Ply 3=$6380

### Other Fixes
- **uci.asm:** Changed short branches (BM, BDF, BZ) to long branches (LBNF, LBDF, LBZ) for UCI_GO_SET_DEPTH target
- **negamax.asm:** Fixed STORE_KILLER_MOVE pointer calculation (was using clobbered R13.0)

### Verification
Memory dump (engine-memdump2.out) confirmed correct operation:
- Move buffers contain valid encoded moves (no $03F0 corruption)
- NODES_SEARCHED = 15,659 for interrupted depth 3 search
- Engine returned valid `bestmove b1c3` at depth 2

### Files Modified
- `movegen-helpers.asm` - R7 save/restore in ADD_MOVE_ENCODED
- `movegen-fixed.asm` - R8→R11 for capture detection in all 8 slider directions
- `negamax.asm` - 128-byte ply buffers, STORE_KILLER_MOVE fix, QS bypass for testing
- `uci.asm` - Long branch fixes

---

## Session: December 30, 2025 - Multiple Critical Bug Fixes

### Summary

Continued debugging the "bestmove h@h@" bug. Found and fixed multiple issues, narrowed down to DECODE_MOVE_16BIT extracting wrong values.

### Bugs Found & Fixed

#### Bug #1: PIECE_VALUES Lookup (evaluate.asm)

**Symptom:** All evaluations returned $90F0 (constant score for all moves).

**Root Cause:** Address calculation for piece value table was wrong:
```asm
; BUGGY - GLO/PLO 11 is a no-op!
    GLO 8               ; Piece type
    SHL                 ; x2 for table offset
    PLO 11              ; R11.0 = offset
    LDI HIGH(PIECE_VALUES)
    PHI 11
    GLO 11              ; Load offset back
    PLO 11              ; Store it again - NO-OP!
```

**Fix:**
```asm
    GLO 8               ; Piece type
    SHL                 ; x2 for table offset
    STR 2               ; Save offset to stack
    LDI LOW(PIECE_VALUES)
    ADD                 ; D = LOW(PIECE_VALUES) + offset
    PLO 11
    LDI HIGH(PIECE_VALUES)
    ADCI 0              ; Add carry
    PHI 11              ; R11 = PIECE_VALUES + offset
```

#### Bug #2: QS_MOVE_LIST Clobbering Parent's Moves (negamax.asm)

**Symptom:** After first move, subsequent moves decoded as garbage ({70:00}, {00:70}).

**Root Cause:** QUIESCENCE_SEARCH used same MOVE_LIST buffer ($6200) as parent NEGAMAX. When QS generated moves, it overwrote the parent's move list.

**Fix:** Added separate QS_MOVE_LIST at $6300.

#### Bug #3: R9 Not Reset After GENERATE_MOVES (negamax.asm)

**Symptom:** First move from garbage address, not from $6200.

**Root Cause:** GENERATE_MOVES advances R9 as it writes moves. After returning, R9 points PAST the end of the move list, not to the start.

**Fix:** Reset R9 to START of move list after GENERATE_MOVES.

#### Bug #4: UNDO_* in ROM Instead of RAM (makemove.asm, board-0x88.asm)

**Symptom:** UNDO_FROM showed invalid value $7F in memory dumps.

**Root Cause:** UNDO_* variables were defined with DS (Define Storage) in the code section, placing them in ROM. Writes had no effect.

**Fix:** Changed to EQU definitions in RAM.

### Files Modified

- **evaluate.asm:** Fixed PIECE_VALUES lookup
- **board-0x88.asm:** Added QS_MOVE_LIST, UNDO_* EQUs in RAM
- **negamax.asm:** Added R9 reset after GENERATE_MOVES, QS uses QS_MOVE_LIST
- **makemove.asm:** Removed UNDO_* DS definitions

---

## Session: January 1, 2026

### Summary

Major refactoring to eliminate stack-based math operations. User pointed out design decision: never touch the stack for math, always use ADI/SMI/ORI/etc with immediate values, and X should always = R2.

### Key Design Principle (from user)

> "We agreed not to touch the stack, and always leave X = R2. All the back-and-forth stack operations, prone to error, would be replaced with index table lookups in memory. Every math and logical operation has an immediate mode. This together with register INC and DEC instructions provides everything we need to index through tables in memory."

The largest chess move offset is $21 (knight NNE), which fits in ADI's immediate byte.

### Refactoring Completed

#### 1. ENCODE_MOVE_16BIT (movegen-helpers.asm)
- **Before:** Used `STR 2` / `OR` pattern (stack-based OR)
- **After:** Uses conditional `ORI` with immediate values

#### 2. DECODE_MOVE_16BIT (movegen-helpers.asm)
- **Before:** Used `STR 2` / `OR` and `STXD`/`IRX`/`LDX` patterns
- **After:** Uses conditional `ORI $01` for to.bit0, direct memory store for flags

#### 3. GEN_KNIGHT (movegen-fixed.asm)
- **Before:** Loop with offset table, `STR 2` / `ADD` pattern
- **After:** Unrolled 8 directions with hardcoded ADI:
  - NNE: `ADI $21`, NNW: `ADI $1F`, NEE: `ADI $12`, NWW: `ADI $0E`
  - SSE: `ADI $E1`, SSW: `ADI $DF`, SEE: `ADI $F2`, SWW: `ADI $EE`

#### 4. GEN_KING (movegen-fixed.asm)
- **Before:** Loop with offset table
- **After:** Unrolled 8 directions with hardcoded ADI

#### 5. GEN_SLIDING -> 8 Direction-Specific Functions
- **Before:** Single parameterized `GEN_SLIDING` with stack-based direction storage
- **After:** 8 separate functions: `GEN_SLIDE_N`, `GEN_SLIDE_NE`, etc.

### Bug Fix: GEN_SLIDE_* Target Register (WM)

**Symptom:** Crash at first move, encoded move showing from=$00

**Root Cause:** After `ANI $88` (board bounds check), D was destroyed. Then `PLO 11` stored the wrong value.

**Fix:** Reload target from R7 before PLO 11.

### Files Modified

- **movegen-helpers.asm:** ENCODE/DECODE use conditional ORI
- **movegen-fixed.asm:** Unrolled GEN_KNIGHT/GEN_KING, 8 GEN_SLIDE_* functions
- **serial-io.asm:** SERIAL_READ_LINE uses R7 instead of R8

---

## Session: January 1, 2026 (continued) - SQUARE_TO_ALGEBRAIC Bug Fix

### Summary

Found and fixed the real cause of "bestmove b1b1" output. Debug prints during search were a red herring - the actual bug was in UCI output formatting.

### The Real Bug: SQUARE_TO_ALGEBRAIC (uci.asm)

```asm
SQUARE_TO_ALGEBRAIC:
    PLO 13              ; Save square <- CLOBBERS R13.0!
    ANI $07
    ADI 'a'
    CALL SERIAL_WRITE_CHAR
    GLO 13              ; Get square back
    ...
```

UCI_SEND_BEST_MOVE loads:
- R13.1 = from square (e.g., $01 = b1)
- R13.0 = to square (e.g., $22 = c3)

Then calls SQUARE_TO_ALGEBRAIC with `GHI 13` (from), which does `PLO 13` - **overwriting the 'to' square!**

### The Fix

Changed SQUARE_TO_ALGEBRAIC to use R7.0 instead of R13.0.

### Lesson Learned

**Debug output can be misleading.** When prints show stale/intermediate values during a complex search, they may not reflect the final state. Memory dumps after execution reveal the truth.

### Final Build

- **Size:** 16,436 bytes
- **Output:** `bestmove b1c3` (valid knight move!)

---

## Session: January 5, 2026 - Depth 2 Working, Depth 3 Investigation

### Summary

Fixed multiple bugs to get depth 2 search working correctly. Identified and implemented fix for depth 3 crash. Depth 3 now hangs rather than crashing - investigation ongoing.

### Bugs Found & Fixed

#### 1. SERIAL_PRINT_HEX Clobbering Low Nibble

- **Symptom:** Debug output showed `{00:20}` instead of `{00:23}` - low nibble always 0
- **Cause:** Original code stored byte in R14.0, but F_TYPE clobbers R14.0 during first nibble print
- **Fix:** Changed to use stack instead of R14.0

```asm
; BEFORE (broken):
SERIAL_PRINT_HEX:
    PLO 14              ; Save byte in R14.0 (clobbered by F_TYPE!)
    ...
    GLO 14              ; Gets garbage

; AFTER (fixed):
SERIAL_PRINT_HEX:
    STXD                ; Save byte on stack
    ...
    IRX
    LDX                 ; Pop original byte from stack
```

#### 2. PLY Check Using Clobbered D

- **Symptom:** PLY==0 check never triggered at root
- **Cause:** After `CALL SERIAL_PRINT_HEX`, D register was garbage
- **Fix:** Reload CURRENT_PLY before the LBNZ check

#### 3. R9 Clobbered by UNMAKE_MOVE in QS

- **Symptom:** Scores corrupted after captures in quiescence search
- **Cause:** QS stored score in R9, but UNMAKE_MOVE clobbers R9
- **Fix:** Push/pop R9 around UNMAKE_MOVE call in QS

```asm
QS_NO_NEG:
    ; Save score (R9) before UNMAKE_MOVE clobbers it
    GHI 9
    STXD
    GLO 9
    STXD
    CALL UNMAKE_MOVE
    ; Restore score (R9)
    IRX
    LDXA
    PLO 9
    LDX
    PHI 9
```

#### 4. Beta Comparison Inverted (SD vs SM)

- **Symptom:** Alpha-beta pruning not working correctly
- **Cause:** SD does M(X) - D, not D - M(X). Was computing beta - score instead of score - beta.
- **Fix:** Changed to SM/SMB for correct score - beta calculation

```asm
; BEFORE (wrong):
    GLO 13              ; D = score_lo
    SD                  ; D = M(X) - D = beta - score (WRONG!)

; AFTER (correct):
    GLO 13              ; D = score_lo
    SM                  ; D = D - M(X) = score - beta (CORRECT!)
```

#### 5. Move List Overwrite During Recursion (Depth 3 Crash)

- **Symptom:** Depth 3 crashed after ~40 seconds, RAM filled with "03 83" pattern from $6206 to stack
- **Cause:** Every NEGAMAX call wrote moves to same MOVE_LIST address ($6200). Child recursion overwrites parent's move list.
- **Fix:** Implemented ply-indexed move lists. Each ply gets 64 bytes (32 moves).

```asm
; Calculate move list base as MOVE_LIST + (CURRENT_PLY x 64)
    LDI HIGH(CURRENT_PLY)
    PHI 10
    LDI LOW(CURRENT_PLY)
    PLO 10
    LDN 10              ; D = current ply (0-7)
    ; Multiply by 64: shift left 6 times
    SHL                 ; x2
    SHL                 ; x4
    SHL                 ; x8
    SHL                 ; x16
    SHL                 ; x32
    SHL                 ; x64
    ; Add to MOVE_LIST base
    ADI LOW(MOVE_LIST)
    PLO 9
    LDI HIGH(MOVE_LIST)
    ADCI 0              ; Add carry
    PHI 9               ; R9 = ply-indexed move list
```

### Other Changes

- **uci.asm:** Added 'quit' command (LBR $8003 for BIOS warm start)
- **uci.asm:** Fixed branch error - changed `BM` to `LBNF` (1802 has no long BM instruction)

### Current Status

- **Depth 2:** Working correctly, produces `bestmove b1c3`
- **Depth 3:** No longer crashes with "03 83" pattern, but hangs indefinitely

### Next Steps

1. Add minimal debug to check if search is progressing or stuck in loop
2. Investigate if infinite loop in move generation or recursion
3. Consider timeout/move limit for debugging

### Files Modified

- **negamax.asm:** QS R9 save/restore, beta comparison fix (SD->SM), ply-indexed move lists
- **serial-io.asm:** SERIAL_PRINT_HEX uses stack instead of R14.0
- **uci.asm:** Added quit command, fixed BM->LBNF branch error
