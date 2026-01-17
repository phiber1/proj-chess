# RCA 1802/1806 Essential Knowledge

> **CLAUDE: Read this file when starting work on this project. It contains critical 1802-specific gotchas not in your training data.**

---

## The D Register Problem

The 1802 has a **single accumulator (D)**. ALL data operations flow through D:
- Loads: LDI, LDN, LDA, LDXA, LDX
- Stores: STR, STXD (read D to store)
- Math: ADI, SMI, ADD, SD, SHL, SHR
- Logic: ANI, ORI, XRI, AND, OR, XOR
- Register transfers: GLO, GHI, PLO, PHI

**Consequence:** There's no way to check a value without destroying D.

```asm
; WRONG - GLO clobbers D
    LDI W_PAWN          ; D = piece value
LOOP:
    STR 10
    INC 10
    DEC 13
    GLO 13              ; D = loop counter (CLOBBERS piece value!)
    BNZ LOOP

; CORRECT - reload D inside loop
LOOP:
    LDI W_PAWN          ; Reload every iteration
    STR 10
    INC 10
    DEC 13
    GLO 13
    BNZ LOOP
```

**Rule:** Always reload constants INSIDE loops after any GLO/GHI/arithmetic.

---

## SCRT (Standard Call/Return) Reserved Registers

The BIOS SCRT reserves these registers - **NEVER use for data**:

| Reg | Purpose | Notes |
|-----|---------|-------|
| R0 | DMA/Interrupt | System reserved |
| R1 | Interrupt PC | System reserved |
| R2 | Stack Pointer | X register, grows DOWN |
| R3 | Program Counter | P register |
| R4 | CALL routine | Points to SCRT call code |
| R5 | RETN routine | Points to SCRT return code |
| R6 | Linkage | Return address - **CLOBBERED BY EVERY CALL!** |

**Critical:** R6 is destroyed by every CALL. Never store data in R6 expecting it to survive a function call.

---

## BIOS Mode: R14.1 is Sacred

In BIOS mode, **R14.1 holds the baud rate constant**. If you corrupt it, serial I/O breaks.

```asm
; FORBIDDEN in BIOS mode:
    PHI 14              ; NEVER - corrupts baud rate
    GHI 14              ; NEVER - reads baud constant, not your data

; R14.0 is safe (clobbered by F_TYPE anyway):
    PLO 14              ; OK for scratch
    GLO 14              ; OK to read
```

---

## Branch Page Boundaries

Short branches (BZ, BNZ, BDF, BNF, etc.) can only reach targets within the **same 256-byte page**.

```asm
; If this code is at $05F0 and TARGET is at $0610:
    BNZ TARGET          ; FAILS! Assembler shows "B" flag

; Fix: Use long branch
    LBNZ TARGET         ; Works - can reach any address
```

**Always check assembler output for "B" flags** - they indicate branch errors.

| Short (2 bytes) | Long (3 bytes) | Condition |
|-----------------|----------------|-----------|
| BZ | LBZ | D = 0 |
| BNZ | LBNZ | D ≠ 0 |
| BDF | LBDF | DF = 1 (no borrow) |
| BNF | LBNF | DF = 0 (borrow) |
| BR | LBR | Unconditional |

---

## Stack Operations (STXD/LDXA/IRX)

The 1802 stack grows **downward**. R2 points ONE BELOW the top item.

**STXD** = Store, then Decrement: `M(R(X)) ← D; R(X) ← R(X) - 1`
**LDXA** = Load, then Increment: `D ← M(R(X)); R(X) ← R(X) + 1`
**IRX** = Increment R(X): `R(X) ← R(X) + 1` (points AT data)
**LDX** = Load via X: `D ← M(R(X))` (R(X) unchanged)

```asm
; Push sequence:
    STXD                ; Store D, then R2--

; Pop sequence:
    IRX                 ; R2++ (now points AT data)
    LDX                 ; Load D (R2 unchanged, still at slot)
    ; or
    IRX
    LDXA                ; Load D, then R2++ (past the slot)

; Peek (read without consuming):
    INC 2               ; Point at data
    LDN 2               ; Read it
    DEC 2               ; Restore stack pointer
```

**DANGER: CALL after IRX corrupts stack!**
```asm
; WRONG:
    IRX                 ; R2 points at move_count
    LDN 2               ; Peek at it
    CALL FOO            ; SCRT writes return address to M(R2)!
    LDX                 ; Gets garbage, not move_count

; CORRECT:
    IRX
    LDX                 ; Pop into D
    PLO 15              ; Save to register
    CALL FOO            ; Safe - R2 at empty slot
    GLO 15              ; Retrieve value
```

---

## STR 2 Corrupts Stack Data

Never use `STR 2` for scratch - it overwrites whatever R2 points to!

```asm
; WRONG:
    GLO 7               ; D = some value
    STR 2               ; Writes to M(R2) - corrupts stack!
    LDN 10
    SM                  ; Uses corrupted value

; CORRECT: Use dedicated scratch memory
COMPARE_TEMP EQU $6449

    LDI HIGH(COMPARE_TEMP)
    PHI 10
    LDI LOW(COMPARE_TEMP)
    PLO 10
    SEX 10              ; X = R10 for memory ops
    GLO 7
    STR 10              ; Safe - writes to COMPARE_TEMP
    LDN ...
    SM
    SEX 2               ; Restore X = stack
```

---

## Big-Endian Convention

All 16-bit values use **big-endian**: high byte at LOWER address.

```asm
; Memory layout for SCORE at $6446:
;   $6446 = SCORE_HI (high byte)
;   $6447 = SCORE_LO (low byte)

; Loading 16-bit value:
    LDI HIGH(SCORE_HI)
    PHI 10
    LDI LOW(SCORE_HI)
    PLO 10
    LDA 10              ; D = high byte, R10 now at low byte
    PHI 9               ; R9.1 = high
    LDN 10              ; D = low byte
    PLO 9               ; R9 = full 16-bit value

; Storing 16-bit value from R9:
    GHI 9
    STR 10              ; Store high byte
    INC 10
    GLO 9
    STR 10              ; Store low byte
```

---

## 16-Bit Signed Arithmetic

**Negation (0 - value):**
```asm
    GLO 9               ; Low byte
    SDI 0               ; D = 0 - D (sets DF on borrow)
    PLO 9
    GHI 9               ; High byte
    SDBI 0              ; D = 0 - D - borrow
    PHI 9               ; R9 = -R9
```

**Addition with carry:**
```asm
    GLO 8
    STR 10              ; M(R10) = addend_lo
    GLO 9
    ADD                 ; D = D + M(R10), sets DF on carry
    PLO 9
    GHI 8
    STR 10
    GHI 9
    ADC                 ; D = D + M(R10) + carry
    PHI 9
```

**Subtraction with borrow:**
```asm
    GLO 8               ; subtrahend_lo
    STR 10
    GLO 9               ; minuend_lo
    SM                  ; D = D - M(R10), clears DF on borrow
    PLO 9
    GHI 8
    STR 10
    GHI 9
    SMB                 ; D = D - M(R10) - borrow
    PHI 9
```

---

## Modifying R3 While P=3 is Dangerous

When P=3, R3 is the active program counter. Modifying it changes where code executes!

```asm
; WRONG - causes immediate jump to garbage:
    GHI 6
    PHI 3               ; CPU now fetching from wrong address!
    GLO 6
    PLO 3
    SEP 3

; If you must do manual returns, use a trampoline register.
```

---

## Recursion and Global State

Global variables don't survive recursion - each depth level overwrites the same memory.

**Examples that FAIL:**
- `UNDO_CAPTURED`, `UNDO_FROM` - child calls overwrite parent's undo info
- `LMR_REDUCED` - child's move loop clears parent's flag (W18 bug)

**Solutions:**
1. **Stack-based:** Push/pop state around recursive calls
2. **Ply-indexed arrays:** `state[ply]` accessed via `PLY_STATE_BASE + (ply × frame_size)`

```asm
; Stack-based example (LMR_REDUCED fix):
    LDN 10              ; D = LMR_REDUCED
    STXD                ; Push to stack
    CALL NEGAMAX        ; Child can clobber LMR_REDUCED safely
    IRX
    LDX                 ; Pop saved value
    PLO 7               ; Save to register before LDI clobbers D
    ; ... load LMR_OUTER address ...
    GLO 7
    STR 10              ; LMR_OUTER = original LMR_REDUCED
```

This engine uses:
- Stack save/restore for `LMR_REDUCED`, `UNDO_*`, `BEST_SCORE`
- Ply-indexed arrays at $6450 for killer moves (10 bytes per ply, 8 plies max)

---

## Quick Reference: Safe Registers

| Register | Safe? | Notes |
|----------|-------|-------|
| R0-R6 | NO | System/SCRT reserved |
| R7 | YES | Temp/scratch |
| R8 | YES | Temp/scratch |
| R9 | YES | Return values, move list ptr |
| R10 | YES | Memory access pointer (local) |
| R11 | YES | Square calculations |
| R12 | YES | Side to move (0=white, 8=black) |
| R13 | YES | Temp/scratch |
| R14.0 | YES | Scratch (clobbered by BIOS anyway) |
| R14.1 | NO | Baud constant - NEVER TOUCH |
| R15 | YES | String ptr, move count |
