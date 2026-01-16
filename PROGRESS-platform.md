# RCA 1802 Chess Engine - Platform & Register Documentation

> **CLAUDE: If context was compacted, re-read this file and PROGRESS.md before continuing work.**

This file contains platform-specific documentation and register allocation for the chess engine.

**Related files:**
- `PROGRESS.md` - Current session notes
- `PROGRESS-movegen.md` - Move generation debugging (Dec 11-17, 2025)
- `PROGRESS-search.md` - Search implementation & debugging (Dec 18-28, 2025)

---

## Hardware Platforms

This project has been developed on TWO different platforms:

### Platform 1: Membership Card (Emulator) - Dec 11-20, 2025
- **CPU:** 1802 at 1.75 MHz (emulated)
- **Mode:** STANDALONE - our own SCRT and Chuck Yakym's bit-bang serial routines
- **Serial:** Software bit-bang at 9600 baud using EF3/Q
- **Register constraints (standalone mode):**
  - R11.0: Serial shift register
  - R14.0: Baud rate delay counter
  - R15.0: Bit counter
  - These are ONLY relevant to standalone mode!

### Platform 2: ELPH (Real Hardware) - Dec 21 onwards
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

---

## Current Build Mode

**We are now using BIOS mode exclusively.** The standalone mode code still exists in serial-io.asm for reference but is not compiled.

Build configuration: `#define CFG_USE_BIOS` in config.asm

---

## Key Differences

| Aspect | Standalone (Membership Card) | BIOS (ELPH) |
|--------|------------------------------|-------------|
| Clock | 1.75 MHz | 12 MHz (6.7x faster) |
| Serial | Bit-bang (R11, R14, R15) | BIOS F_TYPE (clobbers R14.0 only) |
| SCRT | Our own implementation | BIOS provides it |
| R14 | Used for bit timing | OFF LIMITS (baud constant) |
| R15 | Used for bit counter | Safe, but F_MSG uses it |

---

## IMPORTANT: Register Clobbering Notes in Earlier Sessions

Some earlier debug sessions (Dec 11-20) mention "SERIAL_WRITE_CHAR clobbers R11.0, R14.0, R15.0" - this refers to **standalone mode only**. In BIOS mode, F_TYPE only clobbers R14.0.

---

# Register Allocation

**Last Updated:** January 15, 2026

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

## Engine Registers (All are caller-save unless noted)

| Reg | Name | Primary Use | Notes |
|-----|------|-------------|-------|
| R7  |      | Temp/scratch | Board lookup in piece generators |
| R8  |      | Temp/scratch | Direction table ptr in movegen; encoded move in negamax |
| R9  |      | Move list ptr / return value | NEGAMAX loop counter; 16-bit return values |
| R10 | A    | Memory access pointer | Used locally within functions (NOT preserved!) |
| R11 | B    | Square calculation | R11.1=from, R11.0=to in movegen |
| R12 | C    | Side to move | 0=WHITE, 8=BLACK (matches COLOR_MASK). Preserved by convention. |
| R13 | D    | Temp/scratch | Loop counters, decode results |
| R14 | E    | **R14.1 = BAUD CONST (NEVER TOUCH!)** | R14.0 safe for scratch, clobbered by F_TYPE |
| R15 | F    | F_MSG string pointer | Also move count in movegen; bit counter in standalone serial |

## Critical Register Rules

### R6 - SCRT Linkage
- **NEVER** store data in R6
- Every CALL corrupts R6 with return address
- Using R6 as temp will crash on RETN

### R10 - Memory Access Pointer (NOT Global!)
Despite older documentation, R10 is **NOT** a preserved "board pointer":
- Used locally within each function for memory access
- Each function sets R10 to whatever address it needs
- Caller must assume R10 is clobbered by any CALL
- Examples: BEST_SCORE access, UNDO_* access, ply state array access

### R12 - Side to Move
- Convention: preserved across function calls
- Set once at start of search, toggled by MAKE_MOVE/UNMAKE_MOVE
- 0 = WHITE, 8 = BLACK (matches COLOR_MASK for piece detection)

### R14 - BAUD Rate Constant (BIOS Mode)
- **R14.1:** BIOS baud rate constant - NEVER use PHI 14 or GHI 14!
- **R14.0:** Clobbered by every F_TYPE call - safe to use as scratch
- SERIAL_PRINT_HEX saves byte on stack (F_TYPE clobbers R14.0)

---

## BIOS Register Usage

| Entry | Uses | Clobbers | Notes |
|-------|------|----------|-------|
| F_TYPE ($FF03) | D=char | R14.0 | Output single character |
| F_READ ($FF06) | - | R14.0 | Read char with echo, returns in D |
| F_MSG ($FF09) | R15=string | R14.0 | Output null-terminated string |

**IMPORTANT:** BIOS calls save R13/R15 to stack on entry - R2 must point to available stack slot.
**NOTE:** BIOS SCRT only uses R4, R5, R6. Other registers (R7-R13, R15) are preserved.

---

## Function Register Usage Summary

### NEGAMAX (negamax.asm)
- R9: Move list ptr, then loop counter, then score return
- R10: Memory access (ALPHA, BETA, SCORE, BEST_*, UNDO_*, PLY)
- R11: Current move being evaluated
- R12: Side to move (preserved)
- R13: Temp/scratch

### GENERATE_MOVES (movegen-fixed.asm)
- R7: Board lookup pointer (piece generators)
- R8: Offset/direction table pointer
- R9: Move list pointer (IN: start, OUT: past end)
- R10: Board scan pointer (local to function)
- R11: R11.1=from square, R11.0=target square
- R12: Side to move (MUST preserve)
- R13: R13.0=loop counter, R13.1=direction
- R14: R14.0=current square index
- R15: R15.0=move count

### EVALUATE (evaluate.asm)
- R8: Piece type for table lookup
- R10: Board scan pointer (local)
- R11: Accumulator for score

### MAKE_MOVE / UNMAKE_MOVE (makemove.asm)
- R9: Clobbered (used internally)
- R10.0: Moving piece
- R10.1: Captured piece
- R13: Decoded from/to squares

### SERIAL_READ_LINE (serial-io.asm)
- R7: Buffer pointer (changed from R8)
- R9.0: Max length, R9.1: count
- R10.0: Temp character storage (during backspace)

### SAVE_PLY_STATE / RESTORE_PLY_STATE (stack.asm)
- R10: Frame address pointer (local)
- Saves/restores: R7, R8, R9, R11, R12 (10 bytes per ply)

---

## Memory-Based Globals (board-0x88.asm)

All 16-bit values use **big-endian** layout: high byte at lower address.

| Address | Name | Purpose |
|---------|------|---------|
| $6000-$607F | BOARD | 128-byte 0x88 board array |
| $6080-$608F | GAME_STATE | Game state (16 bytes) |
| $6090-$618F | MOVE_HIST | Move history for undo (256 bytes) |
| $6200-$63FF | MOVE_LIST | Ply-indexed move buffers (128 bytes/ply, 4 plies max) |
| $6400-$64FF | Engine vars | See below |
| $6500-$65FF | UCI_BUFFER | UCI input buffer (256 bytes) |
| $6400   | HISTORY_PTR | Move history pointer (2 bytes) |
| $6408   | UNDO_CAPTURED | Captured piece for unmake |
| $6409   | UNDO_FROM | From square for unmake |
| $640A   | UNDO_TO | To square for unmake |
| $640B   | UNDO_CASTLING | Castling rights for unmake |
| $640C   | UNDO_EP | EP square for unmake |
| $640D   | UNDO_HALFMOVE | Halfmove clock for unmake |
| $6410   | BEST_MOVE | Best move found (2 bytes) |
| $6442   | ALPHA_HI/LO | Alpha bound (2 bytes, big-endian) |
| $6444   | BETA_HI/LO | Beta bound (2 bytes, big-endian) |
| $6446   | SCORE_HI/LO | Current score (2 bytes, big-endian) |
| $6448   | CURRENT_PLY | Current ply depth (1 byte, 0-7) |
| $6450   | PLY_STATE_BASE | Ply-indexed state (80 bytes, 10/ply) |
| $64A0   | STATIC_EVAL_HI/LO | Cached static eval for futility (2 bytes) |
| $64A2   | FUTILITY_OK | Futility pruning enabled flag (1 byte) |
| $64A3   | LMR_MOVE_INDEX | Moves searched at current node (1 byte) |
| $64A4   | LMR_REDUCED | Flag: move searched at reduced depth (1 byte) |
| $64A5   | LMR_IS_CAPTURE | Flag: current move is a capture (1 byte) |
| $6500   | UCI_BUFFER | UCI input buffer (256 bytes) |
| $6601   | HASH_HI/LO | Current position Zobrist hash (2 bytes) |
| $6700   | TT_TABLE | Transposition table (256 entries × 8 bytes = 2KB) |
| $6F00   | QS_MOVE_LIST | Quiescence search moves (256 bytes) |

---

## Stack Usage Rules

1. Stack grows downward (STXD: store then decrement)
2. R2 points ONE BELOW the top of stack
3. After IRX, R2 points AT the data
4. CALL corrupts M(R2) before decrementing - never leave R2 pointing at important data!
5. IRX should ONLY appear immediately before a pop sequence (LDXA/LDX)
6. After LDX, R2 still points at the now-consumed slot

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
```

---

## Calling Conventions

### Parameters
- Simple values: pass in D or specific register per function docs
- Complex data: pass via memory (globals or stack)

### Return Values
- R9: 16-bit return value (score, pointer)
- D: 8-bit return value or status

### Preservation Summary
- **Caller-save (assume clobbered):** R7-R11, R13-R15
- **Preserved by convention:** R12 (side to move)
- **Never touch:** R0-R6, R14.1

---

## Historical Bugs (Reference)

### Dec 28, 2025: SERIAL_PRINT_HEX corrupting R9
- **Bug:** Used R9.0 to save byte being printed, but R9 is move list pointer
- **Fix:** Changed to R14.0 (already clobbered by F_TYPE)

### Dec 28, 2025: SAVE/RESTORE_SEARCH_CONTEXT vs SCRT
- **Bug:** Context save/restore didn't account for SCRT linkage on stack
- **Fix:** Replaced with ply-indexed state arrays (no stack manipulation)

### Dec 30, 2025: UNDO_* variables in ROM
- **Bug:** UNDO_* defined with DS (in code section = ROM), writes had no effect
- **Fix:** Changed to EQU definitions pointing to RAM at $6408+

### Jan 1, 2026: SQUARE_TO_ALGEBRAIC clobbering R13.0
- **Bug:** Used R13.0 to save square, but caller stored 'to' square there
- **Fix:** Changed to use R7.0 instead

### Jan 5, 2026: SERIAL_PRINT_HEX clobbering low nibble
- **Bug:** Stored byte in R14.0, but F_TYPE clobbers R14.0 before second nibble
- **Fix:** Changed to use stack (STXD/IRX/LDX)
