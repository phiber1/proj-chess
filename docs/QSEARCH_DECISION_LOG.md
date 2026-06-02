# QSEARCH / Quiescence / Phantom-Material — Definitive Decision Log

**Why this file exists:** we have re-litigated QSEARCH/SEE several times
(on/off, filters, "too slow", "doesn't help"). This consolidates git log,
commit bodies, the `qsearch-recursion-todo` memory, and the 2026-05-31
pre-check into ONE record so it is never re-argued from scratch. Sources are
authoritative (commit messages with hardware test numbers).

## Timeline (what was actually tried, and the measured result)

| date | commit | change | result |
|---|---|---|---|
| 2026-01-07 | 39bb8b5 | QSEARCH α-β pruning (stand-pat cutoff, delta prune) | "no measurable speedup at d2" |
| 2026-02-05 | b45e13e | QS capture limit = 8/node (R11.1) | **"depth 3 QS impractical — 1802 CPU speed"** |
| 2026-02-05 | b76b83a | QS per-capture delta prune + material-only leaf eval | 30–33% faster QS |
| 2026-05-13 | f197daf | QSEARCH **defender pre-filter** (skip captor>victim & defended) | fixed Bxg6/Nxf7 phantom sacs; Win #11. *Only* catches that one class |
| 2026-05-22 | **b66f5df** | **DISABLE QSEARCH captures** (`LBR QS_RETURN`, stand-pat only) | test_472: d4 **+472→−194**. Also fixed opening passivity (was blamed on N3) |
| 2026-05-28 | ef2e153 | QSEARCH-A: re-enable with **captor≤victim filter** | **REVERTED** — test_472 +233 inflation back; queen-sac not prevented; promo-survival d5 −748 (worse). "filter alone can't handle the bug class" |

**Current state:** stand-pat only (`LBR QS_RETURN`). Capture loop + defender
pre-filter still in the binary but **unreached** (dead).

## The key insight that ends the circling

**Neither QSEARCH-on (non-recursive) nor QSEARCH-off eliminates phantom
material. Both have it; off is just the lesser evil.**

- *QSEARCH-on, non-recursive:* the capture loop evaluates each capture via
  `CALL EVALUATE` on the post-capture position, never searching the recapture →
  loop phantom (+472), **on top of** the main-search horizon phantom.
- *QSEARCH-off (current):* no loop phantom, BUT the **main search still reaches
  non-quiet leaves** — any capture played at the deepest ply is stand-pat-scored
  with the captured piece counted and the recapture unseen. **Horizon phantom
  remains.**

**Confirmed 2026-05-31:** on the *current* (QSEARCH-off) engine, position A's
`Nxc6` scores ELPH **+320 "up a knight"** — but c6 is a knight defended by the
**b7 pawn**, so the real line is an even trade. The QSEARCH-off engine is still
hallucinating material at horizon captures. This is the shuffle's driver:
ELPH commits to lines ending in a "winning" capture that is actually recaptured,
then the eval craters the next move (+715 → −567), and it collapses → shuffle.

So toggling QSEARCH on/off has been **moving phantom material around, never
removing it.** That's the circle.

## What actually fixes it (and the real blocker)

The ONLY fix is **resolving recaptures at the horizon**:
- **(1) Recursive QSEARCH** — replace `CALL EVALUATE` in the capture loop with
  `CALL QUIESCENCE_SEARCH` + ~60–80 B state mgmt (save/restore QS_BEST & α/β,
  toggle R12, negate; 9 steps in `qsearch-recursion-todo`). Textbook. **Standing
  TODO since b66f5df.**
- **(2) Static Exchange Evaluation (SEE)** — compute a capture sequence's net
  material on a square *statically*, no recursion. **NEVER IMPLEMENTED.** Our
  "SEE doesn't help" was a *prediction in discussion, not a tested result.*
- **(3) Narrow recapture check** — at a leaf, search only the immediate
  recapture on the just-captured square (one ply). Cheap; catches `Nxc6/bxc6`;
  misses deep chains. Never tried.

**The real blocker is cycle cost, not lack of a known fix:**
- d=3 QS was already "impractical" on the 1802 (b45e13e, 2026-02-05).
- Per-leaf eval is already heavy (shield + N2 + state-conditional; Task #27).
- Engine is hard-capped at d=5 ([[search_depth_hard_cap_5]]). Recursive QSEARCH
  adds unbounded per-leaf capture chains → risks dropping d=5 completions.
- That is *why* b66f5df chose disable + "fix eval first" rather than recursion.

## The honest status

- "Fix eval first" (b66f5df rationale) has been pursued for months (Phase 2–4
  audits). The shuffle persists because its dominant cause is **search-horizon
  phantom material, not eval calibration** — confirmed 2026-05-31. We were
  treating the wrong layer.
- Recapture resolution is a *known* fix that was *deferred for cycle cost*, not a
  fix that was *tried and failed*. The only thing actually tried-and-failed is the
  **captor≤victim filter** (ef2e153) — and it failed because it's not recapture
  resolution, just a crude skip.
- **SEE and the narrow-recapture check (3) have never been built or measured.**

## The decision (for a human, deliberately)

1. **Commit to recapture resolution**, accepting the cycle-cost engineering:
   start with **(3) narrow recapture** as a cheap probe (does resolving just the
   immediate recapture kill the pre-check phantom and survive d=5 timing?), and
   only escalate to **(1) recursive QSEARCH** if (3)'s coverage is insufficient.
   SEE **(2)** is the alternative if recursion's cycle cost proves fatal.
2. **Accept phantom material as a permanent limitation** and instead damp its
   *match impact* (e.g., contempt/again- st speculative captures at the root) —
   weaker, but no cycle-budget risk.

Recommendation: **option 1, starting with the narrow recapture probe (3)** — it
directly tests "does recapture resolution stop the phantom" at minimal cycle cost
and minimal code, using `tools/test_eval_inflation_472.uci` + the pre-check
positions A/B as the gate, before any large recursive-QSEARCH investment.

## Probe (3) — implementation plan (CHOSEN 2026-05-31; not yet built)

**No new state needed.** `UNDO_TO` (= square the move-into-the-leaf landed on,
i.e. the recapture square) and `UNDO_CAPTURED` (= piece taken, or EMPTY) are
already valid at the QSEARCH leaf — verified: `N2_HANGING_PAWN` (called from
EVALUATE at that same leaf) already depends on `UNDO_FROM`/`UNDO_TO` being the
last move, and nothing between the parent `MAKE_MOVE` (negamax.asm:1367) and the
leaf writes them.

Change is confined to `QUIESCENCE_SEARCH` (negamax.asm), reusing the existing
dead capture loop:
1. Replace the unconditional `LBR QS_RETURN` (the b66f5df disable, ~line 2764)
   with: **if `UNDO_CAPTURED == EMPTY` → `LBR QS_RETURN`** (stand-pat only, exactly
   today's behaviour for quiet leaves). Else fall into the capture loop.
2. In `QS_LOOP`, after `DECODE_MOVE_16BIT` (R13.0 = to-square), add a filter:
   **skip (continue loop) unless to-square == `UNDO_TO`.** This restricts the loop
   to *recaptures on the just-captured square* — never opens new speculative
   captures (which is what made the old full loop hallucinate +472).
3. Keep it **1-ply** (the loop's existing `CALL EVALUATE`, no recursion) and
   **bypass the f197daf defender pre-filter** for these recaptures (we want to
   search the recapture even when the recapturing piece is larger).
4. Limitation (accepted for a probe): resolves ONE recapture level. A 3rd-level
   re-recapture is still horizon-phantom, but the estimate moves from grossly
   wrong (+320 phantom) to approximately right (even trade). Multi-level
   exchanges need full recursive QSEARCH (option 1) or SEE.

**Gate before any match:** feed `tools/test_eval_inflation_472.uci` (expect it to
stay ≈ −194, NOT jump to +233/+472) and pre-check positions A/B (expect `Nxc6`'s
+320 to collapse toward the even-trade value). Also confirm d=5 still completes
in time (cycle-cost check — the whole reason this was deferred).

**Pre-implementation read still required:** the dead `QS_LOOP` body
(negamax.asm ~2979–3180: make/eval/unmake/best-tracking) must be read in full to
confirm it's intact (not half-edited stale code) before re-enabling it.

### RESULT (2026-05-31): probe (3) BUILT, TESTED, FAILED — reverted

Implemented exactly as planned (gate on `UNDO_CAPTURED` + `to==UNDO_TO` filter,
reusing the dead loop; clean build). Gate test 1: **`test_eval_inflation_472`
→ d5 = +233** (honest QSEARCH-off baseline is −194). That is the *same +233*
QSEARCH-A (ef2e153) produced. 1-level recapture resolution is insufficient:
test_472's exchange is **multi-level** (capture→recapture→re-recapture); resolving
only the first recapture creates a fresh phantom at the next level (the
recapturing piece is itself recapturable, unseen by the 1-ply leaf eval). Net
loss — fixes single-recapture horizon cases (A/B) but *breaks* multi-level cases
QSEARCH-off was already honest about. **REVERTED to clean HEAD.**

**CONFIRMED RULE (now tested twice):** *partial* capture resolution — whether
`captor≤victim` (ef2e153) or 1-level recapture (this) — both land on +233. **Only
FULL exchange resolution removes phantom material.** The field is now narrowed to
exactly two options, both static-honest at test_472 by construction:
- **(1) recursive QSEARCH** — resolves the full exchange via recursion. Thorough;
  **unbounded cycle cost** (the historical blocker — risks dropping d=5).
- **(2) SEE (static exchange eval)** — computes the full exchange's net material
  *statically*, no recursion → **bounded cycle cost**. Fiddly (attacker/defender
  enumeration by ascending value). Never built here.

Probe (3) and the captor≤victim filter are now permanently ruled out — do not
retry partial resolution.

## SEE BUILT (2026-06-01, branch see-exchange-eval) — and the test_472 gate was STALE

**SEE implemented** in `negamax.asm` (replaces the dead QSEARCH capture loop in
place; ~725 B). Static swap algorithm, no recursion, x-ray-aware (consumed
attacker squares are transparent to slider scans). /4-scaled byte values. Hooked
at the QS leaf via `SEE_CORRECT_STANDPAT`: if the move into the leaf was a
capture, it resolves the FULL exchange on `UNDO_TO` and adds the side-to-move's
net recapture recovery to R9. Scratch RAM $674A-$6775 (reclaimed from the dead
`QS_MOVE_LIST`). Headroom regained by also deleting dead `EVAL_ENDGAME`/
`CALC_TOTAL_MATERIAL` (endgame.asm). Tail $5F11, 239 B free.

**Bug found + fixed via `tools/see_model.py`** (a faithful Python port of the asm
— now a standing reference): the pawn-attacker directions were INVERTED. Authoritative
`check.asm:IS_SQUARE_ATTACKED` has WHITE pawns attacking the target from
`T+NW`/`T+NE` and BLACK from `T+SE`/`T+SW`; SEE had them swapped, so it never
found pawn recapturers. Fixed in both model and asm.

**The test_472 gate (-194) is STALE — do not use it for SEE.** Measured 2026-06-01:
- SEE-enabled build: d5 = **+233**, bestmove b2c3.
- **No-op SEE build (SEE disabled, all other changes intact): d5 = +233 too.**
So +233 is the PRE-EXISTING HEAD baseline, NOT a SEE artifact. The -194 dates to
b66f5df (May 22); dozens of eval commits since moved HEAD to +233. The d2-d4
scores DID differ between the two builds → SEE is alive and computing corrections;
it just can't change test_472's d5 because the refutation is **`Qxb1` on a
DIFFERENT square** than the `bxc3` recapture. SEE resolves one square's exchange;
it structurally cannot see a follow-up tactic elsewhere. test_472 is a horizon/
deeper-search problem, not a SEE-fixable one.

**New deterministic SEE gate:** `tools/test_see_nxe5.uci` — after `1.e4 e5 2.Nf3
Nc6`, `go depth 1`. Nxe5 (f3e5) wins a pawn but loses the knight to Nc6 (net -220).
SEE must veto it: no-op/HEAD → bestmove f3e5 (~+100 phantom); SEE → bestmove NOT
f3e5 (Nxe5 reads ~-220). Model-confirmed R=320 recovery. Ultimate validation is
still a live match (does the shuffle stop). No-op build saved /tmp/chess-engine-SEE-noop.hex.

## SEE VALIDATED END-TO-END (2026-06-01)

`tools/test_see_nxe5.uci` (1.e4 e5 2.Nf3 Nc6 a3 a6 h3 h6, go depth 1):
- broken/no-op SEE: **bestmove f1a6 / +138** (grabs b7-defended a6 pawn — phantom)
- corrected SEE:    **bestmove f1c4 / +63**  (rejects Bxa6, develops) ✓

SEE now correctly resolves the recapture and vetoes the losing capture. The
real-vs-crude check matched: a crude "+2000 on any capture leaf" debug build
ALSO gave f1c4/63, confirming the swap computation reproduces the right verdict
(not just any perturbation).

### The bug that cost an afternoon: wrong board module's constants
SEE was first written against `board.asm`'s convention (`BLACK=$80`,
`PIECE_MASK=$0F`). The build actually concatenates `board-0x88.asm`:
**`BLACK=$08`, `COLOR_MASK=$08`, `PIECE_MASK=$07`, `B_PAWN=$09`**. So SEE's
pawn pass compared b7 against `$81` (never matched → FIND_LVA returned
not-found → R=0 → no effect), type extraction used `$0F` (left the color bit in
for black pieces → garbage SEE_PVAL index), and the slider color / side-flip
used `$80`. Fixed to COLOR_MASK/PIECE_MASK/B_PAWN. Diagnosed via a fixed-+2000
plumbing build (isolated plumbing from computation) then a FIND_LVA-only build
(isolated the pawn pass). Lesson: `board.asm` was a stale `$80`-convention
lookalike — now archived; the live module renamed `board.asm` (was board-0x88).

### Remaining gates
- d=5 timing (SEE now fires real work per capture leaf — confirm d5 still
  completes in budget; test_472 d5 already completed, but it now does more work).
- Live match: does the wins-then-shuffle pattern stop. THE real gate.

## CYCLE COST SOLVED via endgame phase gate (2026-06-01)

Full SEE on every capture leaf was too slow (d4 wouldn't complete) — the same
cycle wall that shelved recursive QSEARCH. Fix (Mark's idea): **run SEE ONLY in
the endgame** (`EG_PIECE_COUNT < SEE_ENDGAME_PIECES`, default 12). Cost and need
are aligned — SEE's cost scales with piece count, and conversion-shuffle losses
happen when few pieces remain, so SEE is cheap exactly where it's needed. Full
SEE correctness is preserved (no approximation). Opening/middlegame: SEE off.

Two-part implementation:
1. Phase gate on EG_PIECE_COUNT (set by the EVALUATE at QS entry).
2. **Gate is INLINE in QS before the CALL** — the unconditional
   `CALL SEE_CORRECT_STANDPAT` at every QS leaf was itself the killer: SCRT
   call/return x100Ks of leaves cost a whole depth even when SEE skipped
   internally. Now a quiet leaf costs ~3 instructions; only endgame capture
   leaves pay the call.

**Confirmed:** gated-SEE build gives byte-identical nodes/scores/bestmove to a
pre-SEE backup on a full-material opening position (which tops out at d4 for both
— position is too wide for d5, unrelated to SEE). So opening/middlegame timing is
provably unchanged. `SEE_ENDGAME_PIECES` (board.asm) is a one-line tune if an
endgame d5 ever runs long. Endgame SEE behavior is validated by live match.

## ENDGAME SEE VALIDATED ON HARDWARE (2026-06-01)

tools/test_see_endgame.uci (KQK-shuffle game @ ply 158; White/ELPH to move, 11
pieces; Rf1xf4 grabs a pawn but loses the rook -> SEE -400):
- go depth 1: **bestmove g1f2 (+35), NOT f1f4** -> SEE fired and vetoed the
  phantom. (Without SEE, f1f4=+100 would dominate a +35 king move; a quiet move
  winning proves f1f4 was devalued below +35 — i.e. SEE knocked it to ~-400.)
- go depth 5: **completes, g1h2 (-100)** -> endgame search with SEE active hits
  d5 in budget. Timing holds where SEE runs.

So: SEE fires + is correct in the endgame; opening/middlegame is provably
unchanged (phase gate); endgame d5 timing OK. Remaining gate: a live match
(does the wins-then-shuffle pattern stop). NOTE from the log mining: ml_adj and
ml_shuf had NO legal White phantom captures in their endgames — those losses
were pure eval-driven king shuffles, so SEE alone may not fix every shuffle
class. Watch matches for eval-shuffle vs phantom-capture failure modes.

Tooling: tools/find_see_test.py (movelist applier + phantom scanner, now filters
illegal king-into-check captures) — reusable to mine SEE test positions.
