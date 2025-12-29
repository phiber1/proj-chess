# RCA 1802/1806 Chess Engine - Register Allocation

## System Reserved (NEVER touch)

| Reg | Name | Purpose |
|-----|------|---------|
| R0  | -    | Reserved for interrupts/DMA |
| R1  | -    | Reserved for interrupt PC |
| R2  | SP   | Stack pointer (X register) |
| R3  | PC   | Program counter (P register) |
| R4  | CALL | SCRT call routine pointer |
| R5  | RET  | SCRT return routine pointer |
| R6  | LINK | SCRT linkage - CORRUPTED BY EVERY CALL! |

## Engine Global Registers (preserve across functions)

| Reg | Name | Purpose | Notes |
|-----|------|---------|-------|
| R10 | A    | Board pointer | Set to BOARD ($6000) before search |
| R12 | C    | Side to move | 0=WHITE, 8=BLACK (matches COLOR_MASK) |

## Function-Local Registers (caller-save, may be clobbered)

| Reg | Name | NEGAMAX | GENERATE_MOVES | EVALUATE | MAKE_MOVE | SERIAL_* |
|-----|------|---------|----------------|----------|-----------|----------|
| R7  |      | Alpha/beta temp | - | - | - | - |
| R8  |      | Best score | Ptr to GM_SCAN_IDX | - | Undo ptr | String ptr |
| R9  |      | Move list ptr / return score | Move list ptr | Score accum | Ptr | Safe (fixed) |
| R11 | B    | Current move | From square (R11.1) | - | - | Shift reg (standalone) |
| R13 | D    | Temp/scratch | - | - | - | Saved by BIOS |
| R14 | E    | **R14.1 = BAUD CONST (NEVER TOUCH!)** | - | - | - | R14.0 clobbered by F_TYPE |
| R15 | F    | Temp/scratch | Move list start | - | - | F_MSG ptr / bit counter |

## R14 Special Handling (BIOS Mode)

- **R14.1:** BIOS baud rate constant - NEVER use PHI 14 or GHI 14!
- **R14.0:** Clobbered by every F_TYPE call - safe to use as scratch

## BUGS FIXED (Dec 28, 2025)

### Bug 1: SERIAL_PRINT_HEX corrupting R9
**SERIAL_PRINT_HEX was using R9.0** to save the byte being printed, but R9 is the move list pointer in NEGAMAX. Fixed by changing to R14.0 (already clobbered by F_TYPE).

### Bug 2: RESTORE_SEARCH_CONTEXT and SCRT stack interference
**RESTORE_SEARCH_CONTEXT was reading SCRT linkage as saved registers.**

When calling a function via SCRT, R6 is pushed onto the stack BELOW where R2 points. This means:
- CALL pushes R6 (2 bytes) via STXD
- Inside the called function, R2 is 2 bytes lower than expected
- RESTORE's first IRX pointed at SCRT's R6, not the saved R7.1!

**Fix:** Modified RESTORE_SEARCH_CONTEXT to:
1. First pop the SCRT linkage (R6) from stack, save to R13
2. Then read the saved context (R7-R12)
3. Manually restore R6 from R13 and return via SEP 3 (bypassing SRET)

This ensures the SCRT linkage chain is properly maintained while correctly restoring the saved register context.

### Bug 3: EVALUATE infinite loop (LBDF vs LBNF)
**EVALUATE's square counter loop used wrong branch condition.**

At the end of EVAL_NEXT_SQUARE:
```asm
    SMI 128
    LBDF EVAL_SCAN      ; WRONG: branches when counter >= 128
```

For SMI (subtract immediate):
- If D < 128: borrow occurs, DF = 0
- If D >= 128: no borrow, DF = 1

LBDF branches when DF=1, meaning it looped forever once counter hit 128!

**Fix:** Changed to `LBNF EVAL_SCAN` (branch when DF=0, i.e., counter < 128).

### Bug 4: IRX-before-CALL in NEGAMAX_NEXT_MOVE
**Move count was being peeked (LDN 2) instead of popped (LDX).**

The code did IRX to point at move_count, then LDN 2 to peek, then CALL SERIAL_PRINT_HEX. The CALL corrupted M(R2). The workaround of saving to R15.0 and restoring with STR 2; DEC 2 was fragile.

**Fix:** Changed to proper pop pattern:
- `LDX` instead of `LDN 2` (marks slot as empty)
- `STXD` instead of `STR 2; DEC 2` (atomic push)

### Bug 5: SAVE_SEARCH_CONTEXT corrupting R6 on return
**SAVE pushed 10 bytes of context, then did RETN. RETN popped from wrong location!**

When CALL SAVE executes, SCRT pushes R6 linkage (2 bytes). Then SAVE pushes 10 bytes of context. At RETN, the stack looks like:
```
[SCRT linkage (2 bytes)]  ← what RETN should pop
[context (10 bytes)]      ← what RETN actually pops from (R2+1)
R2 points here
```

RETN tried to pop from R2+1, which pointed at context (R7.hi/R7.lo), NOT the SCRT linkage. R6 got corrupted with R7 values! This broke the return chain for all subsequent CALLs.

**Fix:** Changed SAVE to match RESTORE's pattern:
1. Pop SCRT linkage first into R13
2. Adjust R2 back to entry position (3 DECs after IRX + 2 LDXAs)
3. Push context at same positions as original design
4. Manually return via SEP 3 (bypassing RETN)

## BIOS Register Usage

- **F_TYPE ($FF03):** Clobbers R14.0 only
- **F_READ ($FF06):** Clobbers R14.0 only
- **F_MSG ($FF09):** Uses R15 as string pointer, also clobbers R14.0

**CRITICAL:** Only use R14.0 (via PLO/GLO). NEVER touch R14.1 (via PHI/GHI) - it holds the BIOS baud rate constant!

```asm
; BEFORE (buggy):
SERIAL_PRINT_HEX:
    PLO 9               ; Save byte in R9.0 - CORRUPTS MOVE LIST PTR!
    ...
    GLO 9               ; Get original byte

; AFTER (fixed):
SERIAL_PRINT_HEX:
    PLO 14              ; Save byte in R14.0 - already clobbered by F_TYPE
    ...                 ; R14.1 (baud constant) is UNTOUCHED
    GLO 14              ; Get original byte
```

## Memory-Based Globals (defined in board-0x88.asm)

| Address | Name | Purpose |
|---------|------|---------|
| $6400   | ALPHA_LO/HI | Alpha bound (2 bytes) |
| $6402   | BETA_LO/HI | Beta bound (2 bytes) |
| $6404   | SCORE_LO/HI | Current score (2 bytes) |
| $6406   | SEARCH_DEPTH | Search depth (2 bytes) |
| $6449   | COMPARE_TEMP | Scratch for comparisons |
| $644A   | MOVECOUNT_TEMP | Scratch for move count |
| $6807   | GM_SCAN_IDX | Move gen scan index |

## Stack Usage Rules

1. Stack grows downward (STXD: store then decrement)
2. R2 points ONE BELOW the top of stack
3. After IRX, R2 points AT the data
4. CALL corrupts M(R2) before decrementing - never leave R2 pointing at important data during CALL!
5. **IRX should ONLY appear immediately before a pop sequence (LDXA/LDX)**
6. After LDX (without A), R2 still points at the now-consumed slot - this is the "empty" slot
7. BIOS routines (F_TYPE, F_READ, F_MSG) save R13/R15 to stack on entry - R2 must point to available slot

### Safe Pop-then-CALL Pattern
```asm
; WRONG: IRX before CALL corrupts data
    IRX             ; R2 at data
    LDN 2           ; Peek (R2 unchanged, data still there)
    CALL FOO        ; SCRT overwrites M(R2)!
    LDX             ; Gets garbage

; RIGHT: Pop completely, then CALL
    IRX             ; R2 at data
    LDX             ; Pop data into D (R2 at empty slot)
    PLO 15          ; Save to register
    CALL FOO        ; SCRT uses empty slot (safe)
    GLO 15          ; Retrieve saved value
    STXD            ; Push new value back
```

## Calling Conventions

### Parameters
- Pass via memory (globals) for complex data
- Pass via registers for simple values (D, or specific register per function docs)

### Return Values
- R9 = 16-bit return value (score, pointer, etc.)
- D = 8-bit return value or status

### Preservation
- Caller-save: R7-R9, R11, R13-R15 (assume clobbered by any CALL)
- Callee-save: R10, R12 (must be preserved or explicitly documented as clobbered)
