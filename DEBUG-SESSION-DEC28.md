# Debug Session - December 28, 2025

## Current Build: VN (16138 bytes)

## Bugs Fixed This Session

### Bug 1: EVALUATE infinite loop (evaluate.asm:145)
- **Problem**: `LBDF EVAL_SCAN` branched when counter >= 128 (DF=1), causing infinite loop
- **Fix**: Changed to `LBNF EVAL_SCAN` (branch when DF=0, counter < 128)
- **Status**: FIXED in source

### Bug 2: IRX-before-CALL in NEGAMAX_NEXT_MOVE (negamax.asm:816-824)
- **Problem**: `LDN 2` peeked at data without consuming, then CALL corrupted M(R2)
- **Fix**: Changed to `LDX` (pop) and `STXD` (atomic push)
- **Status**: FIXED in source

## Outstanding Issue: Infinite `eval~` in Quiescence Search

### Symptoms (from engine-log2.out)
- 91 occurrences of `eval~` pattern
- Appears to loop infinitely in QS_LOOP
- Each `eval~` = one complete EVALUATE call (not stuck inside EVALUATE)

### Debug Markers Added in VL
```
&XX  - Move count (hex) from GENERATE_MOVES in QS (after line 976)
*    - Capture found, about to call EVALUATE (before line 1090)
%    - QS_RETURN reached, loop exiting normally (at line 1172)
```

### Key Code Paths to Trace

**QUIESCENCE_SEARCH flow:**
1. Stand-pat: CALL EVALUATE (prints `eval~`)
2. Print `!`
3. CALL GENERATE_MOVES (prints `[...board...]`)
4. Save move count to R15.0, R15.1 = 0
5. QS_LOOP: check GLO 15, exit if zero
6. For each move: DEC 15, check if capture
7. If capture: push R15.0, MAKE_MOVE, EVALUATE, UNMAKE_MOVE, pop R15.0
8. Loop back to QS_LOOP

**Suspected Issues:**
1. Move count could be corrupted (very high value)
2. R15 might not be decrementing properly
3. Too many moves treated as "captures" due to board corruption

### Stack Discipline Rules (from REGISTER-ALLOCATION.md)
1. Stack grows downward (STXD: store then decrement)
2. R2 points ONE BELOW the top of stack
3. After IRX, R2 points AT the data
4. **IRX should ONLY appear immediately before a pop sequence (LDXA/LDX)**
5. After LDX (without A), R2 still points at now-consumed slot = "empty" slot
6. BIOS routines (F_TYPE, F_READ, F_MSG) save R13/R15 to stack on entry

### SCRT Conventions
- R4 = CALL routine, R5 = RET routine, R6 = linkage (corrupted by every CALL)
- CALL pushes R6 (2 bytes) via STXD before jumping to target
- RETN (SEP 5) pops R6 and returns to caller
- Never use R6 for application data!

### BIOS Notes
- F_TYPE ($FF03): Clobbers R14.0, saves R13/R15 on entry
- F_READ ($FF06): Clobbers R14.0
- F_MSG ($FF09): Uses R15 as string pointer, clobbers R14.0
- R14.1 = baud constant - NEVER touch!

## Files Modified This Session
1. **negamax.asm** - IRX fix, debug markers, version VN
2. **evaluate.asm** - LBNF fix for loop termination
3. **stack.asm** - SAVE_SEARCH_CONTEXT fix (NEW!), RESTORE_SEARCH_CONTEXT fix
4. **REGISTER-ALLOCATION.md** - Added bugs 3 & 4, stack rules

### Bug 5: SAVE_SEARCH_CONTEXT corrupting R6 on return (stack.asm)
- **Problem**: SAVE pushed 10 bytes of context, then did RETN. But RETN
  pops from R2+1, which pointed at the saved context (R7.hi/R7.lo), NOT
  the SCRT linkage that was pushed by CALL. R6 got corrupted with R7 values!
- **Root Cause**: After CALL SAVE, stack had [SCRT linkage][context], but
  RETN tried to pop from top of stack (context) not bottom (linkage).
- **Fix**: Changed SAVE to match RESTORE's pattern:
  1. Pop SCRT linkage first into R13
  2. Adjust R2 back to entry position (3 DECs)
  3. Push context
  4. Manually return via SEP 3 (not RETN)
- **Status**: FIXED in VN build

## Next Steps
1. Flash VN build
2. Capture output to engine-log4.out
3. Check for:
   - `VN` at start (confirms new build with SAVE fix)
   - `(` after QS returns (before RESTORE)
   - `)` after RESTORE returns
   - Normal return to engine loop (no hang/crash)

## Key Memory Addresses
- BOARD: $6000
- MOVE_LIST: $6500
- SEARCH_DEPTH: $6406
- ALPHA_LO/HI: $6400
- BETA_LO/HI: $6402
- QS_BEST_LO: memory location for QS best score
- QS_MOVE_PTR_LO: memory location for QS move pointer
- GM_SCAN_IDX: $6807
- EVAL_SQ_INDEX: $641D

## Register Allocation Summary
- R2: Stack pointer (X register)
- R3: Program counter (P register)
- R4/R5/R6: SCRT (CALL/RET/linkage)
- R7-R9, R11, R13-R15: Caller-save (may be clobbered)
- R10 (A): Board pointer
- R12 (C): Side to move (0=white, 8=black)
- R14.1: BIOS baud constant - NEVER TOUCH
