# RCA 1802 Chess Engine - Progress Log

> **CLAUDE: If context was compacted, read these files before continuing:**
> 1. `docs/1802-ESSENTIALS.md` - Critical 1802 gotchas (D register, SCRT, branches, stack)
> 2. `PROGRESS-platform.md` - Register allocation, memory map, BIOS info
> 3. This file - Current status and recent sessions

**Documentation policy:** This file uses a sliding window - keep Current Status + last 2-3 sessions. When adding a new session, archive older ones to `docs/archive/sessions-WXX-WYY.md` grouped by milestone. Archives are for regression debugging, not normal operation.

---

## Current Status (February 10, 2026)

- **Opening Book:** Working! Instant response for Giuoco Piano/Italian Game (47 entries)
- **CDP1806 RLDI Migration:** 401 conversions across 15 files, 799 bytes saved (5.9%)
- **Transposition Table:** Fixed (Feb 10) — depth store bug + per-ply bound flags (EXACT-only probe)
- **Depth 3:** ~59 seconds opening; late-game sub-second with TT hits (35-89 nodes)
- **Depth 4:** Playable in 18-43 seconds with Null Move Pruning
- **Iterative Deepening:** SEARCH_POSITION loops d1→d2→d3, DS12887 RTC-based 90s abort
- **PST Tables:** Fixed (Feb 7) — all 6 tables had inverted row order for White
- **Pawn Promotion:** Fully working — opponent promotions, search promotions, UCI output suffix
- **Evaluation:** Material + PST (pawn shield implemented but disabled — speed overhead)
- **Castling:** Fully working — rook/king moves revoke rights, rook movement + Zobrist
- **Checkmate/Stalemate:** Properly detected even when all pseudo-legal moves are illegal
- **Fifty-Move Rule:** Halfmove clock tracked in GAME_STATE, checked >= 100 in NEGAMAX
- **CuteChess Integration:** Engine plays via ELPH bridge, depth 3 matches — 88 plies reached
- **UCI Node Output:** Decimal via BIOS F_UINTOUT routine
- **UCI Buffer:** 512 bytes (supports games up to ~48 full moves)
- **Engine size:** 12,842 bytes (out of 32K available)
- **Search optimizations:** Killer moves, QS alpha-beta, capture ordering, internal TT, LMR, NMP, RFP, futility pruning
- **ELPH Bridge:** Dynamic delay scaling, echo detection, go-param stripping, timestamped logging (pyserial)

### Comparison to Historical Engines
- **Sargon (Z80)** defaulted to depth 2 for casual play
- This 1802/1806 engine does depth 3 routinely, depth 4 with NMP — exceeds 8-bit era expectations!

### Match Results (Feb 7-10, 2026)
- **23-move French Defense (TT fix, Feb 10):** Won the exchange via Nc6 fork + Qxa8 (rook capture). Late-game TT transformed: moves 16-23 all depth 3 in sub-second (35-89 nodes vs 2000+ normally). Opening/middlegame (moves 2-11) still depth-2 timeout. Kf1 on move 3 (depth-2 blunder, lost castling rights) led to back-rank mate by Qd1#. 21-minute match.
- **44-move Caro-Kann (post-RLDI, Feb 9):** Castled O-O on move 4, ~59-minute match. First depth-3 search completed in 59s (down from 85s pre-RLDI). Only 2 middlegame moves reached depth 3; 5 endgame moves did. Mated at move 44.
- **38-move Caro-Kann (Feb 7):** Castled O-O (move 13), developed both bishops, creative Bxf7+ sac. Lost to Black's two rooks in endgame. Promotion (a2b1b) handled correctly — no crash.
- **45-move French Defense (queenless):** Earlier match went 45 moves before hitting promotion bug (now fixed). Engine showed good positional play — Nc3, Bf4 development, accurate recaptures.

### Next Up
- **Time budget experiment** — increase 90s to 120s to convert more middlegame depth-2 → depth-3
- **TT ALPHA/BETA probe** — correct flags stored but only EXACT used (16-bit hash collision risk)
- **Open-file king penalty** — lightweight king safety (replaces pawn shield approach)
- **RSXD/RLXA optimization** — ~42 bytes savings, requires matched-pair conversion
- Consider expanding opening book beyond Italian Game

### Recent Milestones
- **Feb 10:** TT correctness fix — three bugs: store depth read wrong byte (high=0, TT completely non-functional), all flags hardcoded EXACT, probe only accepted EXACT. Fixed with per-ply NODE_TT_FLAGS array, correct ALPHA/BETA/EXACT at 5 store paths, depth byte fix. ALPHA/BETA probe tested but rolled back (16-bit hash collisions caused false cutoffs). EXACT-only probe validated: 8 consecutive sub-second depth-3 moves in late game. Engine size: 12,842 bytes.
- **Feb 9:** CDP1806 RLDI migration — 401 conversions across 15 files via automated script. Binary: 13,582 → 12,783 bytes (799 saved, 5.9%). First depth-3 search: 85s → 59s (30% speedup). Pawn shield tested at 4cp bonus — confirmed speed overhead (not values) causes depth-2 fallback; re-disabled. Bridge timestamps added.
- **Feb 9:** Fixed promotion handling — three bugs: stale UNDO_PROMOTION corrupting search after opponent promotion, engine's own promotions during search not setting UNDO_PROMOTION from DECODED_FLAGS, UCI bestmove output missing 'q' suffix. UNDO_PROMOTION now saved/restored in search stack (7 bytes). Engine size: 13,582 bytes.
- **Feb 7:** Fixed inverted PST tables — all 6 tables had rows in wrong order for White. King PST strengthened (b1/g1=+60, d1/e1=-20), bishop c1/f1 penalty (-15). Pawn shield code added but disabled. Engine now castles and develops bishops properly.
- **Feb 7:** Added decimal node count output via BIOS F_UINTOUT ($FF60). UCI "info depth N nodes NNNNN" now outputs decimal instead of hex.
- **Feb 6 (late):** Iterative deepening with RTC-based time management. DS12887 RTC reads seconds via OUT 2/INP 3, aborts at 90s. Three LDI-clobbers-D bugs fixed.
- **Feb 6 (eve):** RFP implemented (15% speedup on quiet positions). Tested and reverted extended futility and razoring (EVALUATE overhead > benefit on 1802).
- **Feb 6:** Fixed stale RAM bug — added WORKSPACE_CLEAR ($6200-$64FF) at startup and ucinewgame.
- **Feb 4:** Fixed queen blindness (TT depth bug), futility pruning, h@h@, rook castling rights, and added pawn promotion support for UCI opponent moves.
- **Jan 30 (eve):** Four CuteChess match fixes: alpha-beta re-enabled (11x speedup), TT root skip, UCI buffer 256→512, castling rook movement + Zobrist.
- Earlier sessions archived to `docs/archive/sessions-dec30-jan30.md`

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

## Session: February 10, 2026 - TT Correctness Fix (Three Bugs)

### Summary
Fixed three TT bugs that together rendered the transposition table completely non-functional
for the main search. The store depth bug (reading high byte = always 0) was the most critical —
identical bug class to the Feb 4 probe-side fix, but on the store side. Also implemented
per-ply bound flags and tested full ALPHA/BETA probe logic (rolled back due to 16-bit hash
collision risk).

### Bug 1: TT Store Depth (negamax.asm)
`RLDI 10, SEARCH_DEPTH` read the high byte (always 0) instead of `SEARCH_DEPTH + 1` (low byte).
Every TT entry stored depth=0. The probe (fixed Feb 4) correctly read the low byte, so the
depth check (`entry_depth >= required_depth`) failed for ALL probes at depth >= 1. **The TT
was completely non-functional for the main search.**

Fix: `RLDI 10, SEARCH_DEPTH + 1` — one-line fix, biggest impact.

### Bug 2: TT Store Flags (negamax.asm)
All paths through NEGAMAX_RETURN hardcoded `LDI TT_FLAG_EXACT`. Added per-ply NODE_TT_FLAGS
array (8 bytes, indexed by CURRENT_PLY) with STORE_NODE_FLAG/LOAD_NODE_FLAG subroutines.
Flags set at 5 locations: init=ALPHA, alpha update=EXACT, beta cutoff=BETA,
checkmate=EXACT, stalemate=EXACT.

### Bug 3: TT Probe Bounds (negamax.asm)
Implemented full ALPHA/BETA/EXACT probe with signed 16-bit comparisons. First test match
showed engine "obliterated" — suspiciously low depth-1 node counts (5 nodes in positions
with 30+ legal moves) suggested hash collision false cutoffs. **Rolled back to EXACT-only
probe.** Correct flags are stored for future use with a larger hash.

### Match Result (EXACT-only probe)
23-move French Defense, 21-minute match:
- Moves 2-11 (opening): All depth-2 timeout (~90s each). Kf1 on move 3 lost castling rights.
- Move 12 (Qf3): First middlegame depth 3 — 2158 nodes, 84s
- Move 15 (Qxa8): Depth 3 — 1534 nodes, 63s. Won the exchange (rook capture via Nc6 fork).
- Moves 16-23: ALL depth 3 in sub-second! 35-89 nodes. TT EXACT hits cutting huge branches.
- Lost to Qd1# (back-rank mate, consequence of early Kf1 blunder).

### Commits
- TT correctness fix (this commit)

### Files Changed
- `board-0x88.asm`: Added NODE_TT_FLAGS EQU $64D2 (8 bytes)
- `negamax.asm`: STORE_NODE_FLAG/LOAD_NODE_FLAG subroutines, 5 flag store points,
  depth fix (SEARCH_DEPTH → SEARCH_DEPTH + 1), EXACT-only probe with explanatory comment

### Build
12,842 bytes (.bin), clean assembly, zero errors

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
