# King-Safety v3 — the luft backbone (SPEC, not yet built)

Status: DESIGN. 2026-06-18. Target segment: `ORG $7B00` (256 B free, verified —
see memory/high_memory_map_authoritative.md). Replaces the queen-only storm logic of
KING_SAFETY v2; folds in / supersedes QUEEN_PROX_BONUS as the king-attack term.

## Why (the four failures this must retire)

| failure | king | escape sqs | eval error |
|---------|------|-----------|-----------|
| 2026-06-18 unsound attack (OFFENSE) | enemy Kg8 | had flight | credited a lone-queen attack +300 that could never mate -> threw pieces |
| 2026-06-17 suffocation (DEFENSE) | own Kd2 | ZERO (own Q/R/pawns) | blind; matable by 1 supported attacker, read safe |
| queen-a6 (DEFENSE) | own Kg1 | some | storm radius <=2 too tight, missed dist-3 queen |
| two-rook (DEFENSE) | own K | — | storm watched only enemy QUEEN, blind to rooks |

One ingredient is missing from all four: **the defending king's escape-square count
(luft).** A king with flight squares can't be mated by a lone piece (don't credit
attacking it); a king with none can (penalize being it). Same signal, both directions.

## Core formula (symmetric, computed per king)

    KING_DANGER(king) = ENEMY_PRESSURE(king) * LUFT_FACTOR(king)

- **ENEMY_PRESSURE** — counts ONLY ENEMY pieces bearing on / near the king zone
  (Q, R, and optionally B/N), weighted. NEVER counts friendly pieces (that misread is
  exactly what broke "attackers-minus-defenders" on the suffocation mate — the caging
  Q+R+N would have read as defenders).
- **LUFT_FACTOR** — grows as the king's safe escape squares shrink. Many flight
  squares -> ~0 (king is safe regardless of attackers). Boxed king -> max.

Fed into the eval symmetrically:
- `eval += KING_DANGER(black)`  (white profits from black's danger = OFFENSE credit, now luft-gated)
- `eval -= KING_DANGER(white)`  (white's own danger = DEFENSE)

This makes BOTH the product require both factors:
- OFFENSE (mode A): lone white Q near Kg8, but Kg8 has luft -> LUFT_FACTOR~0 -> credit ~0. Phantom +300 never forms.
- DEFENSE (mode B): boxed white Kd2 -> LUFT_FACTOR max; enemy Q/R present -> ENEMY_PRESSURE>0 -> big danger, seen early.
- Castled safe king (regression): LUFT low BUT ENEMY_PRESSURE~0 -> product ~0. Must NOT over-fire (the v1 "shieldless king w/o attacker" bug, evaluate.asm:21).

## LUFT computation — cheap proxy first

King's 8 neighbors (0x88: K +/- $01,$10,$0F,$11). A neighbor counts as a flight square if:
- on-board: `(sq & $88) == 0`
- CHEAP: not occupied by a FRIENDLY piece (empty or enemy = potential flight/capture)
- FULL (later): AND not attacked by any enemy piece (up to 8x IS_SQUARE_ATTACKED — cycle-heavy)

Both target failures are caught by the CHEAP proxy: the suffocated king's neighbors are
blocked by OWN pieces; the open king's neighbors are empty. Start cheap; escalate to
attack-checked luft ONLY if a future loss shows the proxy crediting an attacked-square
"flight" that's really a mating net. LUFT_FACTOR = table indexed by flight-square count
(0..8): high penalty at 0-1, ramping to 0 by ~3-4.

## DESIGN DECISIONS — LOCKED 2026-06-25 (Mark)

1. **ENEMY_PRESSURE = weighted count of enemy Q + R** bearing on/near the king zone.
   Rook-aware (fixes the two-rook loss). Weighted, not boolean (lone Q ≠ Q+R battery).
   B/N EXCLUDED for now — luft does the gating; none of the 4 failures strictly need
   B/N (missed Bh3 was a SUPPORT attacker, primary was always a Q/R). Keep the weight
   table extensible so adding B/N later is a one-line change.
2. **REPLACE STORM_PEN + QUEEN_PROX_BONUS with the luft formula; KEEP SHIELD_PEN** as a
   separate small orthogonal term (pawn cover ≠ escape squares; known-good + cheap).
   Retire the flat 0-60 QUEEN_PROX table (offense becomes luft-gated attack credit).
   Minimal blast radius.
3. **CHEAP luft proxy** — flight square = king-neighbor on-board AND not occupied by a
   FRIENDLY piece. No per-square attack scan. Escalate to attack-checked ONLY if a
   future loss shows the proxy crediting an attacked square as real flight.
4. **SHORT-CIRCUIT gate (not a phase classifier)** — compute ENEMY_PRESSURE FIRST; if 0,
   return DANGER=0 and SKIP the luft scan entirely. Exact (no heavy pieces = no danger),
   free (no classifier), and the natural ordering of the product. This IS the task-#27
   cycle gate.
5. **Magnitudes** — LUFT_FACTOR table + ENEMY_PRESSURE weights (tunable DB tables), set
   during probe tuning.

## DETAILED DESIGN (2026-06-25, grounded in current evaluate.asm)

### Data availability at the call site (QP_B_DONE ~evaluate.asm:825-871)
The board scan (EVAL_SCAN) already tracks, per side:
- **King square** — GAME_STATE+STATE_W/B_KING_SQ (0x88). ✓
- **Queen square** — W/B_QUEEN_SQ ($FF if none); W/B_QUEEN_CNT. ✓ (last-seen sq;
  redundant-queen is a rare edge, accept for v1.)
- **Rook FILE only** — EVAL_W/B_ROOK_F1/F2 (file 0-7, $FF if absent). The scan reads
  the full 0x88 square (`LDN 13`) then masks `ANI $07`. **Rook SQUARES are NOT stored.**

### >>> CRITICAL INTERACTION (found in design, would have failed a match) <<<
The CHEAP luft proxy counts a king-neighbor as blocked if occupied by a FRIENDLY piece
— **which includes the king's own shield pawns.** So a NORMALLY CASTLED king has LOW
luft: e.g. Kg1 with Pf2/Pg2/Ph2 + Rf1 → neighbors f1,f2,g2,h2 all friendly-blocked,
only h1 empty → luft = 1. By the LUFT_FACTOR table, luft=1 is near-MAX danger.

Therefore ENEMY_PRESSURE **MUST be LOCALIZED** (enemy Q/R actually near/bearing on the
king), NOT a board-level "does the enemy own a queen" count. If pressure were
board-level, a safe castled king would read as in-danger whenever the enemy has any
queen — **failing validation regression #1** (safe castled king must read ~0). With
localized pressure the model is correct: castled king + no enemy heavy piece on that
wing → pressure ~0 → danger ~0; danger only materializes when an enemy Q/R actually
arrives on the kingside — at which point low luft + real pressure = correctly flagged.
This is WHY the multiplicative model needs proximity, and it is the whole ballgame for
not over-firing.

### ENEMY_PRESSURE(king) algorithm — proximity-gated weighted Q+R
Inputs: king sq (R7.0), enemy queen sq, enemy rook sqs. For each enemy heavy piece,
add its weight IF it bears on the king zone:
- **Queen**: Chebyshev(queen, king) <= ZONE_R  → += W_QUEEN_PRESS
- **Rook (x2)**: Chebyshev(rook, king) <= ZONE_R  OR  same file  OR  same rank
  → += W_ROOK_PRESS   (same-file/rank captures back-rank/file pressure cheaply;
  back-rank mate is THE classic rook pattern → include from the start.)
- ZONE_R = 3 (TUNABLE). Must be >=3: the queen-a6 loss missed a DIST-3 queen with the
  old <=2 radius. Chebyshev(a,b) = max(|file_a-file_b|, |rank_a-rank_b|), 0x88-cheap.
- Result D = summed weight (0 = no pressure → SHORT-CIRCUIT, skip luft, return 0).

### LUFT_FACTOR(king) algorithm — cheap neighbor scan (only if pressure>0)
Count king's flight squares over the 8 offsets {±$01,±$10,±$0F,±$11}:
- on-board: (neighbor & $88) == 0
- flight if board[neighbor] is EMPTY or holds an ENEMY piece (capture-out);
  NOT a flight square if occupied by a FRIENDLY piece.
LUFT_FACTOR = LUFT_TABLE[flight_count] (index 0..8), high at 0-1, ramping to 0 by ~3-4.
DANGER = (ENEMY_PRESSURE * LUFT_FACTOR) >> SHIFT  (scale via shift, keep <=255/one byte).

### >>> NEW SUB-DECISION for Mark: source of enemy ROOK SQUARES <<<
ENEMY_PRESSURE needs rook *squares*, but the scan stores only rook *files*. Two ways:
- **(A) Extend the main scan** to store rook squares (add W/B_ROOK_SQ1/SQ2, ~8 bytes
  data + a few bytes in the existing rook-track block — store `LDN 13` unmasked
  alongside the file). Pro: reuses the one scan, no second board walk. Con: touches the
  hot EVAL_SCAN path (small blast radius); +2 vars/side.
- **(B) Mini-scan inside the pressure routine** — walk the board for enemy rooks when
  needed. Pro: zero change to EVAL_SCAN. Con: a second board walk per king per leaf =
  cycles (worse for task #27), and only runs when pressure-gated... but luft gate is
  AFTER pressure, so the rook-find always runs. (A) is cheaper overall.
- **Claude's lean: (A)** — store rook squares in the existing scan (the scan already
  has the square in hand at EVAL_NOT_ROOK_TRACK; we're just not keeping it). Keep the
  rook-FILE tracking too (open-file eval still needs it).

## ROOK-SQUARE TRACKING — SIDE-EFFECT AUDIT (Option A, 2026-06-25)

Decision: **A — extend the existing scan** (Mark approved; "if we have it in hand and
were masking it off, keep it — but watch for side-effects"). NOT an in-place unmask
(that would break consumers); instead ADD square vars alongside the untouched file vars.

**How the scan exposes the square:** R13 points to EVAL_SQ_INDEX (scan invariant,
evaluate.asm:327 "R13 must stay pointing to EVAL_SQ_INDEX"). `LDN 13` loads the current
0x88 square — exactly how QUEEN-track grabs its square (line 531). So the rook square is
available by a non-destructive `LDN 13` inside the rook-track block, no new bookkeeping.

**The change (rook-track block ~evaluate.asm:483-518):** in EACH of the 4 slot branches
(W-F1, W-F2, B-F1, B-F2), AFTER the existing `STR 11` that writes the file, append:
    RLDI 11, EVAL_x_ROOK_SQn
    LDN 13            ; D = 0x88 square (EVAL_SQ_INDEX)
    STR 11
The `ANI $07 / PHI 8 / STR` file path is UNCHANGED — files still get 0-7.

**New vars:** EVAL_W_ROOK_SQ1/SQ2, EVAL_B_ROOK_SQ1/SQ2 at **$64AB-$64AE** (VERIFIED FREE:
gap between EVAL_SKIP_PST $64AA and EVAL_W_BISHOPS $64AF; grep-confirmed no equate uses
$64AB-$64AE). Inside WORKSPACE_CLEAR ($6200-$67FF) → zeroed at startup.

**SIDE-EFFECT AUDIT (the "expanded usage" Mark flagged):**
1. **File consumers UNAFFECTED.** EVAL_*_ROOK_F1/F2 still receive the masked file 0-7.
   The ~8 consumer sites (rook open/half-open-file eval, evaluate.asm:1025-1156 &
   1400-1430) read a file and are byte-for-byte unchanged. *In-place unmask would have
   broken all 8 — this is why we ADD vars, not repurpose.*
2. **Register impact in the rook block:** the appended store clobbers R11 (immediately
   reloaded; not live after) and D (scratch). R13 is READ-only (`LDN`) — scan invariant
   preserved. R8.1 (file) untouched. R15 (color), R10 (board ptr) untouched. No new
   live-range crosses the insert. ✓
3. **Validity gating — square valid IFF file != $FF.** SQ_n is written ONLY in the same
   branch that writes F_n, so a non-$FF file guarantees a written square. The pressure
   routine MUST gate on the FILE sentinel (F_n==$FF → no rook in slot n → skip SQ_n).
   Startup-zeros SQ to $00 (= square a8, a valid-LOOKING square) — harmless ONLY if the
   routine always checks the file sentinel first. **RULE: never read SQ_n without first
   confirming F_n != $FF.** (Optional belt-and-suspenders: add the 4 SQ vars to the
   per-call $FF reset block at evaluate.asm:302-310, ~12 B; redundant if gating is
   correct, but cheap insurance. Lean: ADD the reset — matches existing pattern, removes
   the latent a8-square trap entirely.)
4. **3+ rooks (promotion) edge:** scan tracks only 2 rooks/side (pre-existing F1/F2
   limit). A 3rd rook's square is dropped → pressure UNDER-counts in a rare case.
   Benign (underestimate, never overestimate). Inherited, not introduced.
5. **Redundant-rook / last-seen:** like the queen's last-seen-square behavior, slots
   fill in scan order (a1-h8). Two rooks → SQ1=first found, SQ2=second. Deterministic. ✓

NET: blast radius = +4 data bytes + ~12 code bytes in the rook block (4 branches x
3 instr) + optional ~12 B reset. File-based features provably untouched.

## STATIC AUDIT — KING_SAFETY_V3 routine (2026-06-25, pre-code)

Mirrors v2 conventions (evaluate.asm:2005 KING_SAFETY): `SEX 2` entry, `D=danger / RETN`
exit, LEAF (no internal CALL — confirmed: v2 uses none; v3 design uses none either).

### Register contract
- **IN:**  R7.0 = king square (0x88); R7.1 = FRIENDLY color (0x00 white / 0x08 black).
  (v2 passed enemy-queen-sq in R7.1; v3 passes friendly color instead — the routine
  derives the enemy var-set from it. Caller setup at evaluate.asm:835-845 / 854-864
  changes accordingly.)
- **OUT:** D = king danger, 0..255 (positive magnitude; caller subtracts for white king,
  adds for black — same as v2 sites 846-852 / 865-871).
- **PRESERVE (MANDATORY):** R9 (EVALUATE accumulator / return) and R12 (caller
  side-to-move color). The routine must NEVER write R9/R12 — v2 is clean here; v3 must
  stay clean. (The v2 R12-clobber bug — every move→0 — is the canary; see king_safety_added.md.)
- **FREE TO CLOBBER:** R7, R8, R10, R11, R13, D, DF, and R2-as-scratch (X=2). No internal
  CALL ⇒ no SCRT R8-clobber concern; R6 untouched.
- **STACK:** leaf + scratch only via `STR 2` (X=2, no IRX/DEC past entry). Push/pop balance
  = trivially 0. R2 returns at entry position. ✓

### Memory touched
- **READS:** BOARD ($6000) for luft neighbors + (pressure) the king sq; enemy queen sq
  (B_QUEEN_SQ or W_QUEEN_SQ by R7.1); enemy rook files+sqs (EVAL_B_ROOK_F1/F2 + SQ1/SQ2,
  or white set). All reads gated on the $FF sentinel (file for rooks, sq for queen).
- **WRITES:** NONE outside its own registers + R2-scratch byte. Does not write any eval
  var. (Pure function of board + scan-tracked piece locations.) ✓ no aliasing.
- **NEW DATA:** EVAL_W/B_ROOK_SQ1/SQ2 @ $64AB-$64AE (verified free, written by the scan
  edit — audited above, separate from this routine).
- **CODE + TABLES:** new `ORG $7B00` segment, must fit $7B00-$7BFF (256 B, one page).

### >>> MULTIPLY-FREE COMBINE (1802 has no MUL) — design decision <<<
DANGER = PRESSURE × LUFT_FACTOR can't use a multiply. Resolution: a **2-D lookup table**,
no multiply, fully tunable (matches v2 "table lookups only"):
- PRESSURE clamped to 2 bits (0..3): queen weight 2, rook weight 1 → raw 0..4, clamp 3.
- LUFT count 0..8 clamped to low 3 bits (0..7; 8→7, both = maximally safe).
- index = (pressure_clamp << 3) | luft_clamp  → 0..31. `DANGER_V3_TABLE` = 32 bytes.
- Shift+OR index = NO multiply. Table encodes "low pressure OR high luft → ~0; high
  pressure AND low luft → high danger" directly; tuning = edit 32 bytes. Replaces the
  spec's earlier "LUFT_FACTOR table + multiply".

### >>> DISTANCE-THRICE structure — design decision <<<
Pressure tests up to 3 enemy pieces (Q,R1,R2). Inlining the ~40 B Chebyshev block 3×
(~120 B) blows the page budget. Resolution: **one inline distance in a LOOP body** over
the (≤3) present enemy heavy pieces. Uniform proximity test for BOTH Q and R:
  bears = (filediff<=ZONE_R AND rankdiff<=ZONE_R) OR filediff==0 OR rankdiff==0
(same-file/rank covers back-rank/file pressure for rooks AND long queen lines; Chebyshev
covers near/diagonal). Only the WEIGHT differs (Q=2,R=1). One distance code site, run ≤3×.
Keeps pressure phase ~60-80 B.

### Size budget (must fit 256 B page)
pressure loop+dist ~80 · luft 8-neighbor loop ~40 · combine/clamp/index ~25 · enemy-set
select ~12 · DANGER_V3_TABLE 32 · weights/consts ~4  →  **~190 B / 256.** ~66 B margin.
If tight: move DANGER_V3_TABLE to the $5FC0 code tail (64 B free) referenced cross-segment.

### Page-straddle
Entire routine in ONE page ($7B00-$7BFF) ⇒ every SHORT branch target is in-page → no
straddle risk *as long as it fits one page*. If it spills to a 2nd page, promote crossing
BR/Bxx → LBR/Lbxx. CALL into it from the $0000 segment = SCRT (DW addr), cross-segment-safe.
MANDATORY post-build: `grep "^[A-Z]" chess-engine.lst` (silent short-branch-out-of-page).

### Open items resolved before code
- ZONE_R = 3 (tunable). Weights Q=2/R=1 (tunable). DANGER_V3_TABLE values = probe-tuned.
- Caller-site rewrite (evaluate.asm:835-871): pass R7.1=friendly color, drop the
  pawn-code/ahead-offset setup (v3 luft uses board occupancy, not a pawn-shield scan —
  but SHIELD_PEN is KEPT per fork 2, so its own small call/inline stays; see Integration).

## SHIELD INTEGRATION + the LUFT/SHIELD/BACK-RANK interaction (2026-06-25)

**Fork-2 follow-up LOCKED (Mark): FOLD shield into KING_SAFETY_V3.** The routine already
walks the king's neighborhood for luft, so it also counts shield-missing (friendly pawns
on the 3 ahead-squares, as v2 did) — one walk, no second scan. Composition:

    DANGER(king) = (pressure == 0) ? 0
                 : SHIELD_PEN[missing] + DANGER_V3_TABLE[pressure, luft]

Both terms pressure-gated (a cracked shield with NO enemy heavy piece = not in danger).
SHIELD_PEN additive (pawn cover), luft table multiplicative-core (mating-net proxy).

**>>> CRITICAL TUNING RISK #1 (found in design — the castled-king false positive) <<<**
The cheap luft proxy counts intact SHIELD PAWNS as escape-blockers, so a SAFE castled
Kg1 (f2/g2/h2 + Rf1) has luft 0-1. If an enemy queen wanders within ZONE_R — e.g. Qd4 is
Chebyshev 3 from g1, a NORMAL central queen NOT attacking g1 — pressure fires and low-luft
→ high factor → PHANTOM danger on a safe king (fails regression probe #1).
- NOT fixable by "gate luft on shield-intact": that BREAKS the back-rank case (below).
- RESOLUTION = tuning, driven by probe #1: make LUFT_FACTOR/DANGER_V3_TABLE **STEEP** —
  only luft 0 (maybe 1) carries real weight, ramping to ~0 by luft 2; keep magnitude
  MODEST; danger is applied SYMMETRICALLY (−white, +black) so two central queens roughly
  cancel. Probe #1 (both kings castled, queens on) MUST read ~0 → tune the table until it
  does, THEN verify the boxed-king (mode B) still reads high. This is the make-or-break
  tuning loop; budget for several table iterations.

**>>> KNOWN LIMITATION, ACCEPTED FOR v1 (deferred per fork 3) <<<**
The cheap proxy MISSES back-rank mate: Kg8 + intact f7/g7/h7 (missing=0) + enemy R on the
back rank = MATE, but the proxy sees f8/h8 as "empty = flight" (luft≥1) and the intact
shield adds 0 → reads SAFE. This is EXACTLY the "attacked square counted as flight"
caveat fork 3 named; escalate to attack-checked luft ONLY if a match loss shows it. v1
does not claim back-rank detection. (Search still sees back-rank mate inside the horizon;
the eval term just doesn't pre-warn it.)

## Implementation envelope

- Location: new `ORG $7B00` code segment (256 B). Called via SCRT `CALL`.
- Register contract (MANDATORY — EVALUATE caller rules): **preserve R9 (return) and R12
  (caller side-to-move color)**; SCRT clobbers R8; free to use R7,R8,R10,R11,R13.
  (The KS v2 R12-clobber bug — every move -> 0 — must not recur; see king_safety_added.md.)
- Scratch: SEX 2 / STR 2 convention or a dedicated byte; NO STR 2 for multi-byte (use
  COMPARE_TEMP-style named scratch).
- Integration: called at QP_B_DONE (~evaluate.asm:865) where KS v2 is now, white then
  black; replaces the two CALL KING_SAFETY sites.
- Byte estimate: luft loop (~40 B) + enemy-pressure (~60-100 B depending on decision 1)
  + tables (~16 B) -> ~120-160 B, fits $7B00 with margin.

## Validation plan (probe BEFORE match, per process discipline)

1. Safe-castled-king regression (both kings castled, queens on): MUST read ~0 (no over-fire).
2. mode A: replay-to-move-17 (`Nxf7`) + move-21 (`Bxh6`) positions from the 6/18 loss —
   king-attack credit on Black must collapse toward 0 (Kg8 has luft) so the sac stops reading +.
3. mode B: the suffocation position (boxed Kd2) — own-king danger must read strongly
   negative BEFORE the mate, early enough to avoid the box.
4. queen-a6 + two-rook positions — danger must now fire (rook-aware, not queen-radius-bound).
5. Build clean (grep "^[A-Z]" chess-engine.lst), opcode-verify, THEN match-test.

All probes: UCI movelist only (no FEN). Compare at EQUAL depth (the recurring anchor bug).
