# FREEZE FIX — NEGAMAX move count: stack → ply-indexed memory

**Date:** 2026-06-18
**Branch:** gated-search
**Root cause file:** memory/freeze_root_cause_movecount_on_stack.md
**Live-hang dumps:** proj-chess/hang1-0618-memdump-*.log

---

## ROOT CAUSE (recap)

`NEGAMAX_MOVE_LOOP` kept the move COUNT on the STACK at a fixed offset `M(R2+1)`,
peeked every iteration via `INC 2 / LDN 2 / DEC 2`, never popped during the loop.
This required EVERY sub-call (MAKE_MOVE, recurse, UNMAKE, EVALUATE,
IS_SQUARE_ATTACKED, castling-legality, futility, LMR) to leave R2 byte-exact. A
single-byte stack imbalance on any conditional path shifts R2 → the peek reads the
WRONG byte → if nonzero, the count never reaches 0 → the loop runs PAST the end of
the move list, reading stale buffer bytes as "moves" forever = the intermittent hang.

The move POINTER was already moved off-stack to ply-indexed `LOOP_MOVE_PTR` ($64DB)
by Mark in a past session for this exact reason; the COUNT was left behind. That
leftover is the fragility. Fix = give the count the same treatment.

Mobility (bd1daa9) EXONERATED — uses `STR 2`, no STXD imbalance; hang reproduced on
pre-mobility builds.

---

## NEW EQUATE (board.asm, near LOOP_MOVE_PTR ~line 195)

```asm
; Ply-indexed save for the move COUNT during the negamax move loop.
; Was on the stack at M(R2+1), peeked every iteration — a single-byte
; stack imbalance on any sub-call path shifted R2 and the loop ran past
; the move list forever (the 2026-06-18 hang). 1 byte/ply, 8 plies.
LOOP_MOVE_CNT     EQU $64EF   ; 8 bytes - move count save per ply ($64EF-$64F6)
```

**Free-slot proof:** STACK_OVERFLOW_FLAG=$64EE (last used below); next used is
ADV_PAWN_W=$64FD. Gap $64EF-$64FC = 14 bytes free; we take 8 ($64EF-$64F6), leaving
$64F7-$64FC. MOVECOUNT_TEMP=$644A is DEAD (defined, never referenced) and the wrong
shape (1 byte, recursion-unsafe) — leave it alone.

**Why 8 bytes / ply-indexed:** board.asm:193-194 documents that LOOP_MOVE_PTR was
once 8 bytes and corrupted at plies 4-7 → the negamax loop reaches ply 7 (8 plies,
0-7). The count has the identical lifetime (must survive the recursive CALL NEGAMAX),
so it must be ply-indexed identically.

**Addressing idiom** (no SHL — 1 byte/ply; `$EF+7=$F6`, no low-byte carry, no page
cross):

```asm
RLDI 10, CURRENT_PLY
LDN 10              ; D = ply
ADI LOW(LOOP_MOVE_CNT)
PLO 10
LDI HIGH(LOOP_MOVE_CNT)
PHI 10              ; R10 = &LOOP_MOVE_CNT[ply]
```

Then `LDN 10` to read, or `STR 10` to write. Read-modify-write (decrement):
`LDN 10 / SMI 1 / STR 10` (STR leaves the decremented value in D for the following
LBZ).

---

## THE 10 SITES IN negamax.asm

| # | Line | NOW | BECOMES | R2 effect |
|---|------|-----|---------|-----------|
| PUSH | 808 | `STXD` (push count) | stash count→R11.0, addr idiom, `GLO 11/STR 10` | was P→P-1; **now no change (R2 stays P)** |
| peek | 842-844 | `INC2/LDN2/DEC2` | addr idiom + `LDN 10` (D=count) | none either way |
| peek | 857-859 | `INC2/LDN2/DEC2` | addr idiom + `LDN 10` | none |
| peek | 898-900 | `INC2/LDN2/DEC2` | addr idiom + `LDN 10` | none |
| peek | 1032-1034 | `INC2/LDN2/DEC2` | addr idiom + `LDN 10` | none |
| peek | 1044-1047 | `INC2/LDN2/DEC2` | addr idiom + `LDN 10` | none |
| decr | 2055-2060 | `INC2/LDN2/SMI1/STR2/DEC2` | addr idiom + `LDN10/SMI1/STR10` | none |
| decr+loop | 2284-2289 | `IRX/LDX/SMI1/LBZ.../STXD/LBR` | addr idiom + `LDN10/SMI1/STR10/LBZ NEGAMAX_LOOP_DONE/LBR NEGAMAX_MOVE_LOOP` | was net-0 (P on LBZ-path); **now no change** |
| DELETE | 2293 | `DEC 2` (NEGAMAX_LOOP_DONE) | *remove* | removes a P→P-1 |
| DELETE | 2319 | `IRX` (NEGAMAX_RETURN) | *remove* | removes a P-1→P |

Line numbers are pre-edit (against 56ba972); they shift as edits are applied — match
on the surrounding code, not the number.

---

## WHOLE-FRAME PROOF (why deleting 2293 + 2319 is correct)

**Old invariant:** STXD@808 lowered R2 by 1 (P→P-1); the body ran at P-1 with the
count at M(P). EVERY exit funnels to `NEGAMAX_RETURN`, whose `IRX`@2319 raised R2 back
to P for RESTORE/RETN. `NEGAMAX_LOOP_DONE`'s `DEC 2`@2293 existed only to re-sync the
LBZ-taken path (which left R2 at P after IRX@2284) back to the body's P-1.
`NEGAMAX_NO_MOVES`/`NEGAMAX_STALEMATE` keep no count of their own — they
`LBR NEGAMAX_RETURN` and rely on its IRX.

**New invariant:** the count is NEVER pushed, so **R2 = P everywhere**, entry through
return. RESTORE already expects P. Therefore BOTH the IRX@2319 and the compensating
DEC 2@2293 must go — leaving either corrupts R2 by ±1.

**All RETURN entry paths verified uniform at P-1→(no IRX)→P... actually at P:**
- 1048 `LBZ NEGAMAX_RETURN` (loop head, count 0)
- 2092 `LBR NEGAMAX_RETURN` (beta cutoff; 2055 decrement is now memory, R2 untouched)
- 2303/2306 `LBNZ NEGAMAX_RETURN` (from LOOP_DONE; 2293 DEC 2 deleted)
- fallthrough from NEGAMAX_NO_MOVES / NEGAMAX_STALEMATE (both `LBR NEGAMAX_RETURN`)
- 1037 `LBR NEGAMAX_NO_MOVES` (early no-moves)
- 2310 `LBR NEGAMAX_NO_MOVES` (sentinel no-improve)

With the count off the stack, R2 = P at all of these. No re-sync needed.

---

## REGISTER AUDIT

New idiom clobbers **R10** (all sites) and **R11.0** (PUSH only). Per-site liveness:

- All 5 peeks + both decrements are each immediately preceded by a `RLDI 10,...` in
  the current code → R10 is already dead scratch there. The count result is consumed
  in D (CALL arg / LBZ / LBNZ) before any reload. SAFE.
- PUSH@808 runs right after `CALL GENERATE_MOVES`, whose only output is D=count; R11
  is movegen scratch (dead on return). Stash count→R11.0, build address, store. SAFE.
- R8/R9/R12/R13 untouched by the idiom. R9 (move pointer) and R12 (color) preserved.

---

## SIZE / HEADROOM

Grows code ~+55-70 B (+~8 B/peek ×5, push, 2 decrements; minus 2 deletes). Applied on
a **mobility-reverted base** (revert bd1daa9, keep book fix 56ba972) → ~128 B headroom
under the $6000 wall. Mandatory `grep "^[A-Z]" chess-engine.lst` after build (size
change can trigger silent short-branch-out-of-page; promote BR/BNZ→LBR/LBNZ if so).

---

## SECONDARY (after this fix)

Still hunt the actual R2 stack imbalance. Moving the count to memory fixes the HANG
robustly, but if a real imbalance exists, drifting R2 can still corrupt the SCRT
return chain elsewhere (the balanced STXD/IRX clusters at 1394-1888 = MAKE/UNMAKE/LMR
sub-frames are the place to look). Belt-and-suspenders.
