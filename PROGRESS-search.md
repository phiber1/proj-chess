# RCA 1802 Chess Engine - Search Implementation Phase

> Sessions from December 18-28, 2025

**Related files:**
- `PROGRESS.md` - Current session notes
- `PROGRESS-platform.md` - Platform documentation
- `PROGRESS-movegen.md` - Move generation debugging (Dec 11-17, 2025)

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
| BNZ | LBNZ | D != 0 |
| BDF/BPZ | LBDF | DF = 1 (positive/no borrow) |
| BNF/BM | LBNF | DF = 0 (negative/borrow) |
| BQ | LBQ | Q = 1 |
| BNQ | LBNQ | Q = 0 |
| B1-B4 | LB1-LB4 | EF1-EF4 = 1 |
| BN1-BN4 | LBN1-LBN4 | EF1-EF4 = 0 |

**Short branches:** 2 bytes, can only reach targets within same 256-byte page
**Long branches:** 3 bytes, can reach any address in 64K space

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

---

## Session: December 21, 2025 (continued) - Quiescence Search

### Quiescence Search Implementation (test-step23.asm)

Added quiescence search to avoid horizon effect. At leaf nodes, instead of just evaluating, we:
1. Stand-pat evaluation (can choose not to capture)
2. Generate all moves, filter for captures only
3. For each capture: make, evaluate, unmake
4. Return best score (stand-pat or best capture)

**Results (Depth-3):**
- Best: 03-12 0384
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

---

## Session: December 21, 2025 (continued) - R14 Elimination Refactoring

### Complete R14 Removal from test-step23.asm

Per architectural guidance to "completely avoid R14 in all cases", refactored all functions that were using R14:

1. **CHECK_BEST_GE_BETA**: Removed `PLO 14` - the saved value was never used
2. **SETUP_PLY_BOUNDS**: Changed from R14.0 to memory at PARENT_OFFSET ($50E2)
3. **CLEAR_BOARD**: Changed loop counter from R14 to memory at TEMP_COUNTER ($50E3)
4. **EVALUATE_MATERIAL**: Changed square index from R14 to memory at SQ_INDEX ($50E4)

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

---

## Session: December 21, 2025 (continued) - Complete R14 Removal from movegen

### R14 Completely Eliminated from movegen-fixed.asm and movegen-helpers.asm

**Changes Made:**

1. **ADD_MOVE_ENCODED (movegen-helpers.asm):**
   - Changed to accept move flags in D register instead of R14.0
   - Stores flags to MOVE_FLAGS_TEMP memory internally before encoding
   - Callers no longer need to use PLO 14

2. **movegen-fixed.asm - All 15 PLO 14 Instances Removed**

3. **GEN_PAWN_PROMOTION (movegen-helpers.asm):**
   - Removed 4 PLO 14 instructions (queen, rook, bishop, knight promotions)

4. **GEN_CASTLING_MOVES (movegen-helpers.asm):**
   - Removed 2 PLO 14 instructions (black kingside, white kingside)

5. **DECODE_MOVE_16BIT (movegen-helpers.asm):**
   - Changed output from R14.0 to memory at DECODED_FLAGS ($50DD)

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

**Fix:** Added save/restore of UNDO_* (6 bytes) to stack in NEGAMAX.

### Key Lessons

1. **Global undo storage doesn't work with recursion** - Each ply needs its own undo state, either via stack or per-ply memory arrays.

2. **Stack balance is critical** - Every STXD needs exactly one IRX/LDXA to pop. Double-check debug code that does peek operations.

3. **Trace the full recursive flow** - Bugs may only manifest after multiple recursion levels.

---

## December 26, 2025 - Session 1: h8h8 Bug Fix

### Issues Found and Fixed

**Bug 1: MOVE_FROM/MOVE_TO not set before MAKE_MOVE**

In the main NEGAMAX loop, the 16-bit encoded move was loaded into R11 but never decoded. MAKE_MOVE reads from MOVE_FROM ($6402) and MOVE_TO ($6403) in memory, but these weren't being set.

**Bug 2: BEST_MOVE never saved during search**

Even when a better score was found, the move wasn't saved to BEST_MOVE. Additionally, we need to only save at the root level (ply 0), not at every depth.

**Fixes:**
- Added CURRENT_PLY counter (board-0x88.asm)
- Initialize PLY=0 in SEARCH_POSITION
- Increment/decrement PLY around recursive call
- Save move at root when score improves (NEGAMAX_NOT_BETTER)

---

## Session: December 26, 2025 - HISTORY_PTR Initialization Bug

### The Problem

After Dec 24 fixes, search still outputting invalid "bestmove h8h8" (later "h@h@"). Debug output showed CURRENT_PLY containing piece characters ('r', 'n', 'b', 'q', 'k', 'p') instead of ply values (0, 1, 2, 3).

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

---

## Session: December 26, 2025 (continued) - Stack Overflow & Infinite Loop

### Bug #2: Explicit Stack Initialization Needed

Added explicit R2 = $7FFF initialization in BIOS mode startup.

### Bug #3: CRITICAL - Move Loop Never Terminated!

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

---

## Session: December 27, 2025 - Move Count Corruption Debug

### Problem

Move count in NEGAMAX loop shows values jumping around (e.g., `#21, #1E, #21, #22`) instead of decrementing monotonically (`#21, #20, #1F, #1E...`). This causes infinite loop because count never reaches 0.

### Bugs Found & Fixed

#### Bug #1: STR 2 Corrupting Stack (FIXED in VI)

Using `STR 2` for scratch space corrupts the stack because it writes to M(R2) which holds important data.

**Fix:** Added `COMPARE_TEMP` at $6449 for scratch, use `SEX 10 / STR 10` pattern instead.

#### Bug #2: CALL Corrupting Move Count at IRX Position (FIXED in VJ)

When R2 points at move_count (after IRX), doing a CALL pushes R6 linkage to M(R2), corrupting the move count.

**Fix:** Save count to R15.0 before CALL, use `GLO 15` after CALL to get saved value.

---

## Session: December 28, 2025 - Register Audit & SERIAL_PRINT_HEX Bug

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

Changed SERIAL_PRINT_HEX to use R14.0 instead of R9.0. Since F_TYPE already clobbers R14.0, using it causes no additional damage.

### Comprehensive Register Audit

Created `REGISTER-ALLOCATION.md` documenting:
- System reserved registers (R0-R6)
- Engine global registers (R10, R12)
- Function-local registers with clobber notes
- BIOS vs standalone mode differences
- Calling conventions

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

The moment `PHI 3` executes, the high byte of the PC changes! The CPU immediately starts fetching instructions from a garbage address.

### Fix: Trampoline Pattern

Use a different register (R15) as temporary PC to safely modify R3.

---

## Session: December 28, 2025 (continued) - Ply-Indexed State Arrays

### Architectural Refactor Complete

Per user's suggestion, replaced stack-based recursion state with ply-indexed memory arrays. This eliminates all SCRT interference issues.

### New Memory Layout

```
PLY_STATE_BASE = $6450   ; Base address
PLY_FRAME_SIZE = 10      ; Bytes per ply (5 registers x 2 bytes)
MAX_PLY = 8              ; Maximum search depth

; Each frame stores: R7, R8, R9, R11, R12 (high byte first, big-endian)
; Ply 0: $6450-$6459
; Ply 1: $645A-$6463
; Ply 2: $6464-$646D
; ... etc
```

### Key Insight (User)

"We could avoid all this unnecessary complication by not using the system stack at all for negamax recursion state. Just reserve an area of empty memory large enough to hold number-of-values multiplied by max number of plies/iterations. Then just index into the proper set of state values per ply/iteration number."

This is the correct approach for 1802 with SCRT - keep the system stack clean for call/return linkage only.
