# CDP1806 Extended Instruction Reference

> **For the RCA 1802/1806 Chess Engine project.**
> Supplements `1802-ESSENTIALS.md` with instructions unique to the CDP1804/1805/1806.

All extended instructions use a **68** prefix byte. Enable in a18 with:
```asm
    CPU 1805    ; Turns on 1806 extended opcodes
```

---

## High-Impact Instructions for This Engine

### RLDI Rn, imm16 — Register Load Immediate

**Opcode:** `68 CN` (4 bytes) | **Replaces:** `LDI HIGH / PHI / LDI LOW / PLO` (6 bytes)

```asm
; OLD (1802) — 6 bytes, clobbers D:
    LDI HIGH(GAME_STATE + STATE_W_KING_SQ)
    PHI 10
    LDI LOW(GAME_STATE + STATE_W_KING_SQ)
    PLO 10

; NEW (1806) — 4 bytes, D preserved:
    RLDI 10, GAME_STATE + STATE_W_KING_SQ
```

**Key advantage:** RLDI does NOT clobber D. The `LOAD` pseudo-op (which generates
the 1802 LDI/PHI/LDI/PLO sequence) destroys D. This means RLDI can set up a
pointer mid-computation without losing the accumulator value.

**RLDI clobbers T** (the register saved by MARK/SAV). We don't use T, so this
is harmless.

**Codebase impact:** ~438 occurrences across build modules = **876 bytes saved**.

### DBNZ Rn, addr — Decrement and Branch if Not Zero

**Opcode:** `68 2N` (4 bytes) | **Replaces:** memory-based loop counters (6-8 bytes)

```asm
; OLD (1802) — memory-based loop, 8+ bytes:
    LDN 13          ; Load counter from memory
    SMI 1           ; Decrement
    STR 13          ; Store back
    LBNZ LOOP       ; Branch if not zero

; NEW (1806) — 4 bytes, uses register as counter:
    DBNZ 13, LOOP   ; R13 = R13 - 1; branch if R13 != 0
```

**Note:** DBNZ decrements the full 16-bit register. For 8-bit loops, initialize
the register's high byte to 0 and low byte to the count. The branch tests the
full 16-bit value for zero.

**Codebase impact:** ~2 direct replacements in check.asm. More possible with
restructuring of register-based DEC/GLO/BNZ loops.

### RSXD Rn — Register Store via X, Decrement (16-bit Push)

**Opcode:** `68 AN` (2 bytes) | **Replaces:** `GHI Rn / STXD / GLO Rn / STXD` (4 bytes)

```asm
; OLD (1802) — 4 bytes:
    GHI 9           ; Push R9 high byte
    STXD
    GLO 9           ; Push R9 low byte
    STXD

; NEW (1806) — 2 bytes:
    RSXD 9          ; Push R9 (16-bit) to stack
```

**Byte order:** RSXD stores R(N).0 first (higher address), then R(N).1 (lower
address). This is big-endian in memory — compatible with RLXA for pop.

**Codebase impact:** ~3 occurrences in build modules = **6 bytes saved**.

### RLXA Rn — Register Load via X, Advance (16-bit Pop)

**Opcode:** `68 6N` (2 bytes) | **Replaces:** `IRX / LDXA / PHI Rn / LDX / PLO Rn` (5 bytes)

```asm
; OLD (1802) — 5 bytes:
    IRX
    LDXA            ; Pop high byte
    PHI 9
    LDX             ; Pop low byte (R2 stays at slot)
    PLO 9

; NEW (1806) — 2 bytes:
    RLXA 9          ; Pop 16-bit from stack into R9; R(X) += 2
```

**Note:** RLXA advances R(X) by 2, leaving R(X) pointing past the popped data.
This matches RSXD's decrement-by-2 behavior — they are a matched pair.

**Codebase impact:** ~12 occurrences in build modules = **36 bytes saved**.

### RNX Rn — Register N to X (16-bit Copy)

**Opcode:** `68 BN` (2 bytes) | **Replaces:** manual 16-bit register copy (4-6 bytes)

```asm
; OLD (1802) — copy R7 to R2:
    GHI 7
    PHI 2
    GLO 7
    PLO 2

; NEW (1806) — 2 bytes:
    RNX 7           ; R(X) = R7 (copies full 16-bit register)
```

**Note:** Copies R(N) into whatever register X points to (normally R2). This is
specifically R(N) → R(X), not arbitrary register-to-register.

---

## Counter/Timer Instructions

The 1806 has an on-chip 8-bit counter/timer clocked by TPA/32 (in timer mode)
or external signals on EF1/EF2 (in counter mode).

| Opcode | Mnemonic | Description |
|--------|----------|-------------|
| 68 00 | **STPC** | Stop counter, reset prescaler to 32 |
| 68 01 | **DTC** | Decrement counter by 1 |
| 68 02 | **SPM2** | Set pulse width mode 2 (EF2 input) |
| 68 03 | **SCM2** | Set counter mode 2 (count EF2 transitions) |
| 68 04 | **SPM1** | Set pulse width mode 1 (EF1 input) |
| 68 05 | **SCM1** | Set counter mode 1 (count EF1 transitions) |
| 68 06 | **LDC** | Load counter from D |
| 68 07 | **STM** | Set timer mode (counter clocked by TPA/32) |
| 68 08 | **GEC** | Get counter → D |
| 68 09 | **ETQ** | Enable toggle Q on counter underflow |

**Timer mode** runs the counter from TPA/32. With a 4 MHz clock, TPA = 8 x clock
period, so counter decrements every 8 * 32 = 256 cycles = 64 microseconds.
Full 8-bit count (255 → 0) = ~16 ms. Useful for sub-second timing if needed.

**Counter mode** counts external transitions on EF1 or EF2 pins. Could be used
for event counting (e.g., hardware move timer input).

---

## Interrupt Control

| Opcode | Mnemonic | Description |
|--------|----------|-------------|
| 68 0A | **XIE** | External interrupt enable |
| 68 0B | **XID** | External interrupt disable |
| 68 0C | **CIE** | Counter interrupt enable |
| 68 0D | **CID** | Counter interrupt disable |
| 68 3E | **BCI addr** | Branch on counter interrupt (short, 3 bytes) |
| 68 3F | **BXI addr** | Branch on external interrupt (short, 3 bytes) |

---

## Context Save

| Opcode | Mnemonic | Description |
|--------|----------|-------------|
| 68 76 | **DSAV** | Push T, D, and DF to stack (3 bytes on stack) |

DF is encoded into bit 7 of a shifted D value. Primarily for interrupt handlers.

---

## Hardware SCAL/SRET — DO NOT USE

| Opcode | Mnemonic | Description |
|--------|----------|-------------|
| 68 8N | **SCAL Rn, addr** | Hardware subroutine call (4 bytes) |
| 68 9N | **SRET Rn** | Hardware subroutine return (2 bytes) |

**WARNING:** SCAL/SRET push bytes in **opposite order** from the BIOS SCRT
(CALL/RETN via R4/R5). SCAL pushes low byte first; SCRT pushes high byte first.
They are **NOT interchangeable**. This engine uses BIOS SCRT exclusively — do
not mix in SCAL/SRET.

---

## BCD Arithmetic (Not Used)

| Opcode | Mnemonic | Description |
|--------|----------|-------------|
| 68 F4 | **DADD** | Decimal add: D + M(R(X)) → D |
| 68 FC | **DADI imm8** | Decimal add immediate |
| 68 74 | **DADC** | Decimal add with carry |
| 68 7C | **DACI imm8** | Decimal add immediate with carry |
| 68 F7 | **DSM** | Decimal subtract memory |
| 68 FF | **DSMI imm8** | Decimal subtract memory immediate |
| 68 77 | **DSMB** | Decimal subtract with borrow |
| 68 7F | **DSBI imm8** | Decimal subtract immediate with borrow |

No current use case in the chess engine. Could be useful for displaying
BCD-formatted clock times or scores if needed.

---

## Migration Impact Estimate

Current binary: **13,582 bytes**

| Optimization | Occurrences | Bytes Saved |
|--------------|------------:|------------:|
| RLDI (exact match) | 401 | 802 |
| RLDI (mismatched HIGH/LOW) | 37 | 74 |
| RSXD (16-bit push) | 3 | 6 |
| RLXA (16-bit pop) | 12 | 36 |
| DBNZ (loop counters) | 2 | 8 |
| **Total** | **455** | **926 (6.8%)** |

Estimated post-migration binary: **~12,656 bytes**

### Top Files by Savings

| File | RLDI | RSXD | RLXA | Total Bytes |
|------|-----:|-----:|-----:|------------:|
| negamax.asm | 195 | 2 | — | 394 |
| makemove.asm | 71 | — | — | 142 |
| uci.asm | 35 | 1 | — | 72 |
| transposition.asm | 24 | — | — | 48 |
| makemove-helpers.asm | 23 | — | — | 46 |
| endgame.asm | 21 | — | — | 42 |

### Speed Impact

Every RLDI replacement saves 2 machine cycles (4 cycles vs 6 cycles for the
LDI/PHI/LDI/PLO sequence). With ~401 occurrences in hot paths like negamax,
this adds up to measurable speedup across a depth-3 search with thousands of
node evaluations.

RLDI also preserves D, which can eliminate subsequent reload instructions that
are currently needed after pointer setup — a secondary speed gain that's harder
to quantify but significant in tight inner loops.

---

## a18 Assembler Notes

- Enable with `CPU 1805` directive (covers all 1804/1805/1806 instructions)
- The `LOAD Rn, addr` pseudo-op generates the old 1802 LDI/PHI/LDI/PLO sequence
  (6 bytes, clobbers D). Use `RLDI` instead for 1806 targets.
- a18 version: "1802/1805A Cross-Assembler (Portable) Ver 2.6+" by William C. Colley III
- Reference files: `A18.DOC` (assembler manual), `testa18.lst` (opcode verification)
