# RCA 1802 Chess Engine - Progress Log

> **CLAUDE: If context was compacted, read these files before continuing:**
> 1. `docs/1802-ESSENTIALS.md` - Critical 1802 gotchas (D register, SCRT, branches, stack)
> 2. `PROGRESS-platform.md` - Register allocation, memory map, BIOS info
> 3. This file - Current status and recent sessions

**Documentation policy:** This file uses a sliding window - keep Current Status + last 2-3 sessions. When adding a new session, archive older ones to `docs/archive/sessions-WXX-WYY.md` grouped by milestone. Archives are for regression debugging, not normal operation.

---

## Current Status (February 11, 2026)

- **Opening Book:** Working but shallow — only Giuoco Piano/Italian Game (47 entries). **Expansion is top priority.**
- **CDP1806 RLDI Migration:** 401 conversions across 15 files, 799 bytes saved (5.9%)
- **Transposition Table:** Fixed (Feb 11) — depth store, R9 clobber, inline per-ply bound flags
- **Depth 3:** Only reachable after piece exchanges reduce tree; opening/middlegame stuck at depth 2
- **Depth 4:** Not viable for opening/middlegame (exceeds time budget)
- **Iterative Deepening:** SEARCH_POSITION loops d1→d2→d3, DS12887 RTC-based 120s abort
- **Time Budget:** 120s, RTC tracked on every node (fixed d1/d2 tracking gap)
- **PST Tables:** Fixed (Feb 7) — all 6 tables had inverted row order for White
- **Pawn Promotion:** Fully working — opponent promotions, search promotions, UCI output suffix
- **Evaluation:** Material + PST (pawn shield implemented but disabled — speed overhead)
- **Castling:** Fully working — rook/king moves revoke rights, rook movement + Zobrist
- **Checkmate/Stalemate:** Properly detected even when all pseudo-legal moves are illegal
- **Fifty-Move Rule:** Halfmove clock tracked in GAME_STATE, checked >= 100 in NEGAMAX
- **CuteChess Integration:** Engine plays via ELPH bridge, depth 3 matches
- **UCI Node Output:** Decimal via BIOS F_UINTOUT routine
- **UCI Buffer:** 640 bytes (supports games up to ~59 full moves)
- **Engine size:** 12,867 bytes (out of 32K available)
- **Search optimizations:** Killer moves, QS alpha-beta, capture ordering, internal TT, LMR, NMP, RFP, futility pruning
- **ELPH Bridge:** Dynamic delay scaling, echo detection, go-param stripping, timestamped logging (pyserial)

### Key Insight: Depth-2 Opening Problem
The engine hits the 120s time budget on nearly every opening move (first ~20 moves). Depth 3 is only reachable after piece exchanges reduce the search tree. This makes the engine essentially a depth-2 player in the opening/middlegame — unable to see piece safety beyond one move, castling's long-term value, or tactical sequences. **Expanding the opening book to skip the first 6-10 moves** would land the engine in simpler middlegame positions where depth 3 is achievable, for zero runtime cost.

### Match Results (Feb 11, 2026)
- **50-move Caro-Kann (7cf0491 baseline):** Real chess! Castled O-O, active piece play, ~45 min. King shuttled g1↔g2 (no repetition detection). Ended with illegal move at move 50 — UCI buffer overflow (fixed in fc0c0f5).
- **26-move match (TT depth fix + flags, 120s budget):** Castled O-O move 10. Hit 120s budget on nearly every move through move 20. Queen was aggressively placed but couldn't close (depth-2 horizon). Queen surrounded and captured, checkmate at move 26.
- **Earlier match (TT depth fix only, no flags):** Kf1 squandering castling on move 6 (depth-2 artifact). TT with wrong flags (all EXACT) caused search corruption.

### Next Up
- **Expand opening book** — deeper lines, more variations, skip depth-2 opening phase
- **LMR check guard** — lacks IS_IN_CHECK (lower priority: depth>=3 only, captures exempt)
- **Repetition detection** — engine shuffles pieces in drawn positions
- **Open-file king penalty** — lightweight king safety (replaces pawn shield approach)
- **Wider hash for TT** — 32-bit hash needed for reliable TT at scale
- **RSXD/RLXA optimization** — ~42 bytes savings, requires matched-pair conversion

### Recent Milestones
- **Feb 11:** Reverted to 7cf0491 baseline after bd514ee/895dcd6 regression. UCI buffer 512→640 bytes ($6000-$6FFF layout). Fixed TT_PROBE R9 clobber (dead PLO 9). Fixed TT depth store (SEARCH_DEPTH→SEARCH_DEPTH+1). Added inline per-ply TT bound flags (no CALL overhead). Fixed time budget tracking (RTC reads on every node, not just d3+). Budget 90s→120s. Engine size: 12,867 bytes.
- **Feb 10:** TT correctness fix (3 bugs: depth store, flag store, probe bounds). TT clear per-search. Futility pruning IS_IN_CHECK guard. 4 test matches, longest 40 moves/80 ply.
- **Feb 9:** CDP1806 RLDI migration — 799 bytes saved (5.9%). Depth-3: 85s → 59s. Pawn shield re-disabled (speed overhead).
- **Feb 9:** Fixed promotion handling — stale UNDO_PROMOTION, search promotions, UCI suffix.
- **Feb 7:** Fixed inverted PST tables. King PST strengthened. Engine now castles properly.
- Earlier milestones archived to `docs/archive/sessions-dec30-jan30.md`

### Depth 4 Test Results (with NMP)
```
All positions tested at depth 4, out of book:

| Position              | Time  | Bestmove | Notes                    |
|-----------------------|-------|----------|--------------------------|
| Sicilian (8 ply)      | 43s   | b1c3     | Open, tactical           |
| Ruy Lopez (10 ply)    | 36s   | b1c3     | Main line                |
| Italian Game (8 ply)  | 30s   | b1a3     | Giuoco Piano             |
| QGD (10 ply)          | 19s   | a1b1     | Closed, NMP prunes well  |
| French Defense (8 ply)| 18s   | a1b1     | Semi-closed              |

Baseline before NMP: Sicilian depth 4 = 6 min 7 sec
After NMP: 43 seconds = 8.5x speedup!
```

---

## Session: February 11, 2026 - TT Rebuild, Time Budget Fix, UCI Buffer

### Summary
Reverted to 7cf0491 baseline after bd514ee/895dcd6 regression caused terrible play quality.
Rebuilt TT fixes from scratch (inline, no CALL overhead), fixed UCI buffer overflow, fixed
time budget tracking bug, and identified depth-2 opening problem as the key strategic issue.

### Revert to 7cf0491 Baseline
Post-7cf0491 commits (bd514ee + 895dcd6) caused play regression: Kf1 on move 3, endgame
collapse (20-50 node d3 searches), rapid checkmates. Disabling TT_PROBE alone didn't help —
overhead from 6 CALL/RETN pairs per node (STORE/LOAD_NODE_FLAG) was part of the problem.
Reverted negamax.asm and board-0x88.asm to 7cf0491, confirmed with 50-move Caro-Kann match.

### UCI Buffer Overflow Fix (fc0c0f5)
Buffer was 512 bytes, overflowed at ~94 half-moves (~47 full moves). Position string at move
50 (98 half-moves = 514 chars) was truncated, corrupting the board → illegal move. Expanded
to 640 bytes. Reorganized memory to fit within $6000-$6FFF: UCI $6500-$677F, QS $6780-$67FF,
TT $6800-$6FFF.

### TT Fixes Rebuilt (40a948d)
1. **R9 clobber fix:** Removed dead `PLO 9` in TT_PROBE (saved masked index, never read back)
2. **Depth store fix:** SEARCH_DEPTH → SEARCH_DEPTH+1 (was storing high byte = 0)
3. **Inline per-ply flags:** 5 store sites + 1 load site, indexed by CURRENT_PLY into
   NODE_TT_FLAGS ($64D2, 8 bytes). No CALL/RETN overhead (~17-25 instructions per node vs
   ~120 for the bd514ee CALL approach). Flag values: entry=ALPHA, alpha update=EXACT,
   beta cutoff=BETA, checkmate=EXACT, stalemate=EXACT.

### Time Budget Tracking Fix (40a948d)
**Bug:** RTC reads were skipped during d1/d2 iterations (gated by CURRENT_MAX_DEPTH >= 3).
D2 search in opening takes 90+ seconds untracked. When d3 starts, SEARCH_PREV_SECS is stale,
and RTC delta wraps modulo 60 — losing whole minutes of elapsed time. This caused 180s moves
on a 120s budget.

**Fix:** RTC reads and SEARCH_ELAPSED updates now run on every node regardless of iteration
depth. Only the abort decision (SMI 120 comparison) is gated to d3+.

### Depth-2 Opening Problem Identified
Match testing revealed the engine hits the 120s budget on nearly every opening move (first
~20 moves). Depth 3 only becomes reachable after piece exchanges simplify the position.
The engine is essentially a depth-2 player in the opening/middlegame. A deeper opening book
would skip this weak phase entirely for zero runtime cost.

### Commits
- `fc0c0f5`: Revert to 7cf0491 baseline and expand UCI buffer to 640 bytes
- `40a948d`: Fix TT correctness and time budget tracking

### Files Changed
- `board-0x88.asm`: Memory layout reorganization ($6000-$6FFF), NODE_TT_FLAGS EQU
- `negamax.asm`: Inline TT flags (5 stores + 1 load), RTC tracking on all nodes, 120s budget
- `transposition.asm`: Removed dead PLO 9 in TT_PROBE
- `uci.asm`: UCI_BUFFER_LEN 511→639

### Build
12,867 bytes (.bin), clean assembly, zero errors

---

## Session: February 10, 2026 - TT Fix, TT Clear, Futility Check Guard

### Summary
Fixed three TT bugs (depth store, flag store, probe bounds), discovered TT cross-move
collision poisoning, and found futility pruning missing IS_IN_CHECK guard. Four match tests
drove iterative debugging. Time budget increased from 90s to 120s.

### TT Correctness Fix (committed bd514ee)

**Bug 1: TT Store Depth.** `RLDI 10, SEARCH_DEPTH` read high byte (always 0) instead of
`SEARCH_DEPTH + 1` (low byte). TT was completely non-functional for main search.
Fix: `RLDI 10, SEARCH_DEPTH + 1`.

**Bug 2: TT Store Flags.** All paths hardcoded TT_FLAG_EXACT. Added per-ply NODE_TT_FLAGS
array (8 bytes, CURRENT_PLY indexed) with STORE/LOAD_NODE_FLAG subroutines. 5 store points:
init=ALPHA, alpha update=EXACT, beta cutoff=BETA, checkmate=EXACT, stalemate=EXACT.

**Bug 3: TT Probe Bounds.** Implemented ALPHA/BETA/EXACT probe — first test showed engine
obliterated (hash collision false cutoffs). Rolled back to EXACT-only. Correct flags stored
for future use with larger hash.

### TT Clear Per-Search (uncommitted)
**Problem:** After TT fix, sub-second endgame moves with 35-89 nodes showed ludicrous play
(rook shuffling a1→b1→a1, queen blunders, back-rank mates). 256 entries + 16-bit hash =
stale entries from previous moves colliding with current positions.

**Fix:** Added `CALL TT_CLEAR` at start of SEARCH_POSITION before iterative deepening loop.
Preserves within-move TT (d1→d2→d3) while eliminating cross-move collision damage.

### Time Budget 90s → 120s (uncommitted)
Changed `SMI 90` to `SMI 120` at line 141. Analysis of timing data showed middlegame moves
were searching depth 3 for ~83s before hitting 90s wall. Move 9 (Qg3) in test match completed
depth 3 at 118s — would have been depth-2 fallback at 90s budget.

### Futility Pruning Check Guard (uncommitted)
**Bug discovered:** Futility pruning at depth 1 had NO IS_IN_CHECK guard. NMP checks (line
281), RFP checks (line 554), but futility setup and application did not. When in check at
depth 1, EVALUATE returns meaningless static score; all moves are forced responses.

**Impact:** Defensive moves incorrectly pruned in lines explored from non-Qxe8 root moves,
making alternatives look worse → engine chose Qxe8+ (taking protected knight, losing queen).
Indirect effect: captures exempt from futility, so they get "honest" evaluations while quiet
defensive moves are pruned based on bogus eval.

**Fix (2 parts):**
1. Setup (~line 771): Added `CALL IS_IN_CHECK` / `LBNZ NEGAMAX_SKIP_FUTILITY` after depth==1
   check. FUTILITY_OK stays 0, EVALUATE never called (meaningless in check).
2. Application (~line 891): Changed from checking `depth==1` to checking `FUTILITY_OK`.
   Setup is now sole gatekeeper (encodes depth==1 AND not-in-check).

**Also noted:** LMR lacks IS_IN_CHECK guard but lower priority (depth>=3 only, captures exempt).

### Match Results

**Match 1 (TT fix only, 23 moves, French Defense):** Won exchange via Qxa8. Late-game
TT: 8 sub-second depth-3 moves. But Kf1 (move 3) lost castling → Qd1#. Validated TT working.

**Match 2 (TT fix, 120s budget, 33 moves, Caro-Kann):** TT clear NOT applied yet.
Rook shuffling (Rd1→Re1→Ra1 circles), queen blundered via Ba6 (Nxe2). Sub-second moves
with 35-89 nodes = stale TT entries. Identified cross-move collision poisoning.

**Match 3 (TT clear + 120s, 40 moves, Alekhine's Defense):** Longest match! 80 ply, 54 min.
Castled O-O move 6. Queen active: Qf3→Qg3→Qg5→Qd5→Qc6→Qb6. Depth 3 on moves 2, 6-9,
16-17, 29, 31-35. Knight shuttle Ne2↔Ng3 (4 moves, no repetition detection). Qxe8+ blunder
(took protected knight) lost queen. Black pawn promoted a2a1r. Mated after Rxe1. Led to
futility check guard discovery.

### Commits
- `bd514ee`: TT correctness fix (depth store, per-ply flags, EXACT-only probe)
- Uncommitted: TT clear per-search, 120s budget, futility check guard

### Files Changed
- `board-0x88.asm`: Added NODE_TT_FLAGS EQU $64D2 (8 bytes)
- `negamax.asm`: TT fix (STORE/LOAD_NODE_FLAG, 5 flag points, depth fix, EXACT probe),
  TT_CLEAR in SEARCH_POSITION, SMI 90→120, futility IS_IN_CHECK guard + FUTILITY_OK check

### Build
12,849 bytes (.bin), clean assembly, zero errors

---

## Session: February 9, 2026 - CDP1806 RLDI Migration + Pawn Shield Analysis

### Summary
Migrated entire codebase from vanilla CDP1802 instructions to use CDP1806 RLDI opcode.
401 replacements via automated Python script. Also diagnosed pawn shield performance
issue (speed, not values) and added timestamped bridge logging.

### Pawn Shield Investigation
Tested pawn shield at reduced 4cp bonus (down from 8cp). Match showed erratic play —
no castling, queen mutual annihilation. Analysis of timestamped debug log revealed the
real problem: pawn shield overhead (~200 extra instructions per EVALUATE call) pushed
depth-3 search past the 90-second time budget. Engine fell back to depth-2 for nearly
every move. Re-disabled with explanatory comment. Future: replace with lightweight
open-file king penalty (covers queen AND rook attacks on open files).

### CDP1806 RLDI Migration
- Added `CPU 1805` directive to build.sh to enable 1806 extended opcodes
- Wrote `convert-rldi.py` automation script for `LDI HIGH/PHI/LDI LOW/PLO` → `RLDI Rn, addr`
- 401 conversions (366 exact match, 35 mismatched HIGH/LOW expressions)
- One assembly fix: `BZ` → `LBZ` in movegen-helpers.asm (page boundary shifted by compression)
- Binary: 13,582 → 12,783 bytes (799 saved, 5.9%)
- RLDI preserves D register (unlike LOAD pseudo-op), eliminating follow-up reloads

### Performance Impact
- First depth-3 search (opening): 85s → 59s (30% speedup)
- 44-move Caro-Kann match (~59 minutes): castled O-O move 4, but only 2 middlegame
  moves completed depth 3, plus 5 endgame moves. Most middlegame positions still
  exhaust the 90s budget at depth 2.

### Deferred 1806 Optimizations
- **RSXD/RLXA** (16-bit push/pop): Byte order differs from manual GHI/STXD/GLO/STXD.
  RSXD stores low byte first; manual stores high byte first. Must use matched pairs.
  ~42 bytes savings. Separate careful pass needed.
- **SCAL/SRET**: Pushes bytes in OPPOSITE order from BIOS SCRT. NOT interchangeable.
- **DBNZ**: Only 2 candidates in check.asm, minimal impact.

### Bridge Timestamps
Added `log_write()` helper to elph-bridge.py with MM:SS.mmm elapsed time format.
Critical for move-time analysis — showed depth-3 completion times per move.

### Commits
- `7cf0491`: Migrate to CDP1806 RLDI instructions and add bridge timestamps

### Files Changed
- `build.sh`: Added `CPU 1805` directive
- All 15 `.asm` source files: RLDI conversions
- `movegen-helpers.asm`: BZ→LBZ page boundary fix
- `evaluate.asm`: Pawn shield re-disabled with updated comment
- `elph-bridge.py`: Timestamped logging
- `convert-rldi.py`: New automation script
- `docs/1806-ADDITIONS.md`: New CDP1806 instruction reference

### Build
12,783 bytes (.bin), clean assembly, zero errors

---

## Session: February 7-9, 2026 - PST Fix, Promotion Fix, Match Testing

### Summary
Fixed two critical bugs that transformed engine play quality: inverted PST tables and
broken promotion handling. Ran multiple CuteChess matches showing dramatically improved
positional play — engine now castles, develops pieces, and survives 38+ moves.

### Bug 1: Inverted PST Tables (pst.asm)

**Root Cause:** All 6 PST tables had row order inverted relative to the EVAL_PST code.
Code computes `index = rank*8 + file` where rank 0 = chess Rank 1 (White's back rank).
But tables stored "Rank 8" values at index 0-7 and "Rank 1" at index 56-63.

**Impact:** White's positional evaluation was completely backwards:
- King on g1 (castled) got -30 penalty instead of +40 bonus
- Pawns on rank 2 got +50 ("about to promote") instead of -20 ("starting position")
- Black was unaffected because XOR $38 flip compensated

**Fix:** Reversed all 6 table row orders. Also strengthened King PST castling squares
(b1/g1=+60, d1/e1=-20, Rank 2 flanks=+30, center=-10) and added bishop c1/f1
undevelopment penalty (-15).

### Bug 2: Promotion Handling (negamax.asm, uci.asm)

Three interrelated promotion bugs:

**2a. Stale UNDO_PROMOTION after opponent promotion:**
After UCI parser applies opponent's promotion (e.g., `f2f1q`), UNDO_PROMOTION stays set
to QUEEN_TYPE ($05). Every subsequent MAKE_MOVE during search sees this and "promotes"
every piece it moves — total board corruption, producing `h@h@` output with only 3 nodes.

**Fix:** Clear UNDO_PROMOTION = 0 in UCI_GO_SEARCH before SEARCH_POSITION.

**2b. Engine's own promotions during search:**
When engine generates promotion moves (DECODED_FLAGS = MOVE_PROMOTION), the search never
set UNDO_PROMOTION. Pawns reaching the 8th rank stayed as pawns on the board during search.

**Fix:** Before each MAKE_MOVE in negamax and QS, check DECODED_FLAGS. If MOVE_PROMOTION,
set UNDO_PROMOTION = QUEEN_TYPE. Added UNDO_PROMOTION to save/restore stack (7 bytes).

**2c. UCI bestmove promotion suffix:**
UCI_SEND_BEST_MOVE didn't append 'q' for promotion moves.

**Fix:** After outputting from/to, check if piece at from is a pawn and to is on last rank.
If so, append 'q'.

### Pawn Shield (evaluate.asm) — Implemented but Disabled

Added king safety evaluation: for each side, if king is on back rank, check 3 squares
ahead (+$10, +$0F, +$11 for White; -$10, -$0F, -$11 for Black) for friendly pawns.
Each pawn found adds/subtracts 8 centipawns. Uses ANI $88 for 0x88 validity.

Currently disabled with `LBR BKS_DONE` after `CALL EVAL_PST` to isolate PST fix effects.
Earlier testing with pawn shield enabled showed erratic play — may need re-evaluation.

### Decimal Node Output (serial-io.asm, negamax.asm, board-0x88.asm)

Replaced hex SERIAL_PRINT_HEX calls with BIOS F_UINTOUT ($FF60) for UCI-compliant
decimal node count. F_UINTOUT: R13=16-bit value, R15=buffer pointer, null-terminate
after call. UINT_BUFFER at $64CC (6 bytes).

### CuteChess Match Analysis

**Match 1 (pre-PST-fix, 31 moves):** King never castled (Kd1 instead of O-O), c1 bishop
never moved, rooks shuffled a1↔b1. Good Queen/Knight play but terrible king defense.

**Match 2 (PST-fix + pawn shield, 20 moves):** Castled early (good!) but catastrophic
material blunders (Nxe5, Qxg4). Very fast, erratic play. Pawn shield may have caused
bad evaluation swings → aggressive pruning → shallow effective search.

**Match 3 (PST-fix only, 45 moves):** French Defense, queenless middlegame. Excellent
development (Nc3, Bf4). Hit promotion bug at move 45 (a2b1b → h@h@ crash).

**Match 4 (all fixes, 38 moves):** Caro-Kann. Castled O-O move 13, both bishops developed.
Creative Bxf7+ sacrifice. Lost to Black's two rooks in endgame. Promotion (a2b1b) handled
correctly — no crash. Engine's main weakness: depth-3 tactical horizon (g4 weakening king,
letting a-pawn march to promotion).

### Commits
- `de238c7`: Use BIOS F_UINTOUT for UCI-compliant decimal node count output
- `629d54a`: Fix inverted PST tables and add pawn shield evaluation
- `7f87eec`: Fix promotion handling: clear stale flag, support search promotions, UCI output

### Files Changed
- `pst.asm`: All 6 PST tables reversed, King PST strengthened, bishop c1/f1 penalty
- `evaluate.asm`: Pawn shield code (disabled via LBR BKS_DONE)
- `negamax.asm`: UNDO_PROMOTION handling in search (set from DECODED_FLAGS, save/restore)
- `uci.asm`: Clear UNDO_PROMOTION before search, promotion suffix in bestmove output
- `serial-io.asm`: Added F_UINTOUT EQU $FF60
- `board-0x88.asm`: Added UINT_BUFFER EQU $64CC

### Build
13,582 bytes (.bin), clean assembly, zero errors

---

## Session: February 6, 2026 - Iterative Deepening + RFP

### Summary
Implemented iterative deepening with RTC-based time management and Reverse Futility
Pruning. Also fixed stale RAM bug and ran first CuteChess depth-2 matches.

### Iterative Deepening (negamax.asm)
SEARCH_POSITION loops d1→d2→d3, saving ITER_BEST after each completed depth. DS12887 RTC
reads seconds via OUT 2 ($80) / INP 3, aborts at 90s budget. Falls back to last completed
depth's bestmove on abort.

Results: Italian d3: 85s/2012 nodes (completes). Queen's Attack d3: 89s abort (falls back
to d2). Three LDI-clobbers-D bugs fixed during development.

### Reverse Futility Pruning (negamax.asm)
At non-root nodes with depth <= 2, if static_eval - margin >= beta, return static_eval
(position too good, opponent won't allow it). Margin: 100cp at depth 1, 300cp at depth 2.
15% speedup on quiet positions. Extended futility and razoring tested but reverted
(EVALUATE overhead > benefit on 1802).

### Stale RAM Fix (board-0x88.asm)
Added WORKSPACE_CLEAR zeroing $6200-$64FF at startup and ucinewgame. Prevents stale
variable bugs between games. Note: TT at $6700-$6EFF is NOT cleared by WORKSPACE_CLEAR
(cleared separately by TT_CLEAR in ucinewgame).

### CuteChess Depth-2 Matches
Two matches confirmed poor play quality at depth 2 — engine couldn't see basic tactics.
Depth 3 with iterative deepening is the target for competitive play.

### Commits
- `5c959e9`: Fix stale RAM bug: clear workspace $6200-$64FF on startup and ucinewgame
- `4bebfb2`: Add RFP, PST tuning, delta pruning, and restore elph-bridge
- `19e1c0d`: Add iterative deepening with RTC-based time management
- `936ed83`: Update PROGRESS.md with iterative deepening results

### Build
13,192 bytes (.bin), clean

---

> **Older sessions archived to:** `docs/archive/sessions-dec30-jan30.md`
