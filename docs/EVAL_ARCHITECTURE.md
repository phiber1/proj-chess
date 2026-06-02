# ELPH Eval Architecture — Score-Affecting Reference

**Purpose:** single source of truth for *everything that touches the evaluation
score*, so phase-gating / interaction bugs become a lookup instead of a multi-day
hunt. Documents reality **as it stands today** (HEAD = `0691aa3` + the diagnostic
NEG16 trap, which is **not** an eval term). Cite by **label**, not line number.

**Maintenance rule:** any change to a score-affecting term updates this file in the
same commit. If this file and the code disagree, the code is truth and this file is
a bug.

**Audit status (2026-05-31):** pipeline + phase map + override gates + all
middlegame term magnitudes COMPLETE and verified by reading. Pending: N2
advanced-pawn-attack magnitude; EVAL_PST per-square cost. See §6.

---

## §1. Score pipeline — order of operations in `EVALUATE`

Score accumulates in **R9, white-relative signed 16-bit** (white good = positive).
Black terms subtracted; black piece values negated via `NEG16_R7`. `R6` = SCRT
linkage, never score.

| # | Stage | Label | Effect on R9 | Gate |
|---|---|---|---|---|
| 0 | Insufficient-material draw | `CHECK_INSUFFICIENT_MATERIAL` | **returns 0** | K-K / K+N-K / K+B-K / K+B-K+B(same colour) |
| 1 | Material + tracking | `EVAL_SCAN`→`EVAL_DONE` | Σ material (±) | always |
| 2 | Redundant-queen cap | `QC_W/B_LOOP` | ∓900 per queen beyond 1st | always |
| 3 | Queen→enemy-king proximity | `QP_W/B_*` | + `QUEEN_PROX[dist]` W, − B | always |
| 4 | Piece-square tables | `CALL EVAL_PST` | + PST W, − PST B | always |
| 5a | Castling-rights bonus | `EVAL_NO_W/B_CASTLE` | ±50 if side still has rights | always |
| 5b | Walked-king penalty | `EVAL_CFL_*_DONE` | ∓50 if king off home & not castled | always |
| 6 | Pawn shield | `EVAL_PS_*` | ∓60 per missing shield pawn (≤3) | always; only if castled & king on back rank |
| 7 | Doubled pawns | `EVAL_WDP/BDP_LOOP` | ∓15 × (count−1) per file | always |
| 8 | Bishop pair | `EVAL_NO_W/BBP` | ±30 | always |
| 9 | Rook open/semi file | `EVAL_WR/BR_*` | open ±20 / semi ±10 per rook | always |
| 10 | Hanging-pawn / adv-pawn attack | `CALL N2_HANGING_PAWN` | ∓25 per attacker (+adv-pawn term) | always |
| **★** | **PREEG snapshot** | `EVAL_PREEG ← R9` | captures **core = material+PST+structure+king-safety** | always |
| 11 | Mid enemy-pawn-advance penalty | (post-PREEG) | R9 −= **ADV_PAWN_B/2** | **count ≥ 12** |
| **G** | **Phase gate** | `LBDF BKS_DONE` | — | **count ≥ 12 → skip 12–18** |
| 12 | King centralization | `EG_W/B_POS` | ± `KING_CENTER[k]×4` (±120) | count < 12 |
| 13 | Advanced-pawn bonus (full) | `EG_*_ADV` | + ADV_PAWN_W (¼ in conversion phase), − ADV_PAWN_B | count < 12 |
| 14 | Passed pawns | `PP_W/B_LOOP` | + rank bonus W, − B | count < 12 |
| 15 | King-drive to edge | `EG_DRIVE_*` | + `KING_EDGE[enemy]×2` (0–120) | count < 12 **and** \|R9\|>200 |
| 16 | Check bonus | `CHECK_BONUS_*` | ±40 | **DEAD — §5** |
| 17 | Fix B keep-queen | `FIX_B_*` | ±200 | count<12; preeg≥+300&W_Q (or ≤−300&B_Q) |
| 18 | Hopeless-material amp | `HM_AMP_*` | ±2000 | count<12; §3 |
| **G** | **Item-B deficit clamp** | `BKS_DONE` | R9 = min/max(R9, preeg) + promo-survival | both phases |

**Middlegame (count ≥ 12):** R9 = core(1–10) − ADV_PAWN_B/2, then Item-B clamp.
Stages 12–18 never run.
**Endgame (count < 12):** core + endgame activity (12–15) + Fix B + hopeless-amp,
then Item-B. `count = EG_PIECE_COUNT` = non-king pieces.

---

## §2. Phase map

- **`EG_PIECE_COUNT`** (`$64EC`), threshold **12** (raised 21→12 on 2026-04-30).
  Single gate. No fullmove term yet (Task #32 proposes `pc<16 OR fullmove>50`).
- **Static vs dynamic:** PST (stage 4) always applies. "Dynamic" lives in king-safety
  state flags (5a/5b/6 via `CASTLED_FLAGS`) and the whole count<12 block (12–18).
  **King *centralization* is endgame-only**; in the middlegame the king's square
  contributes only via PST (where castled g1/b1 = +60, center = −50).

---

## §3. Override gates (most bugs live here) — all key off `EVAL_PREEG`

`EVAL_PREEG` = core score at ★ (material+PST+structure+king-safety; **excludes**
the endgame block and ADV penalties). Stays within ±~1000, so ±2000 amp dominates.

- **Fix B** (17, count<12): preeg≥+300 & W_Q → +200; preeg≤−300 & B_Q → −200.
  Inside the endgame block on purpose (out-of-place earlier → passive shuffling,
  `b33e6dd`).
- **Hopeless-amp** (18, count<12), ASYMMETRIC: losing `pc≤6 & preeg≤−300 → −2000`;
  winning `pc≤2 & preeg≥+300 & W_Q=1 & B_Q=0 → +2000` (K+Q-vs-K only). Symmetric
  version (5/27) caused depth-to-depth eval volatility & a won→shuffle-draw crash;
  winning side narrowed. **The 5/31 −450↔−2300 flicker is this amp toggling at its
  boundary** — drags out adjudication, doesn't change result.
- **Item-B clamp** (`BKS_DONE`, both phases): preeg≤−300 → `R9=min(R9,preeg)` (+½
  ADV_PAWN_W); preeg≥+300 → `R9=max(R9,preeg)` (−½ ADV_PAWN_B); else unchanged.
  **Hard ±300 step** (TODO: graduate). **CRITICAL: only fires when one side is
  materially lost by ≥300 of preeg — see §7.**
- **Mate scores** (`±$7FFE`) come from `negamax.asm`, never from EVALUATE; never reach
  the count-gated block.

---

## §4. Per-term magnitudes (✅ verified)

**Material (PIECE_VALUES):** P=100, N=320, B=330, R=500, Q=900, K=0(not counted).
Standard — material is **not** undervalued.

**Queen-cap:** ∓900 per queen beyond the first.

**Queen-prox (`QUEEN_PROX_BONUS`, by Chebyshev dist to enemy king):**
dist 1=**60**, 2=50, 3=40, 4=30, 5=20, 6=10, 7=0. White +, black −. (Queen next to
enemy king = +60.)

**PST (`EVAL_PST`, pst.asm; black flips rank via XOR $38):**
| piece | range | notable |
|---|---|---|
| Pawn | −20..+50 | rank-7 = +50 (all files); d4/e4 = +20 |
| Knight | **−50..+20** | center +20, rim/corner −50 (±70 swing) |
| Bishop | −20..+10 | long-diag +10, undeveloped c1/f1 −15 |
| Rook | −15..+10 | 7th rank +10, corner −15 |
| Queen | −30..+5 | center +5, deep raid −30 |
| King | **−50..+60** | castled g1/b1 = **+60**, e1/f1 = −20, center/advanced −40/−50 |

**King safety:** castling rights ±50; walked-king (off home & not castled) ∓50;
pawn shield ∓60 per missing pawn of 3 (only if castled & on back rank → up to ±180).

**Doubled pawns:** ∓15 × (count−1) per file. **Bishop pair:** ±30.
**Rook file:** open ±20 / semi ±10 per rook (2 rooks → up to ±40/side).
**N2 hanging pawn:** ∓25 per attacking B/Q/N. (Adv-pawn-attack sub-term: 🔲 magnitude.)

**Endgame-only:** king centralization ±120 (`KING_CENTER×4`); king-drive 0–120
(`KING_EDGE×2`, only \|R9\|>200); passed pawns r2..r7 = 25/50/90/140/200/250;
ADV pawns (accum r4..r7 = 25/60/120/200, sat 255).

---

## §5. Noted, not now (DO NOT fix mid-audit)

1. **Check bonus (stage 16) is dead code** — inside count<12 block but gated to
   count≥12. Never fires → engine has **zero check incentive in any phase**.
   Plausible contributor to aimless endgame shuffling (no reward for the checks that
   drive a king toward mate).
2. **`EVAL_ENDGAME` / `CALC_TOTAL_MATERIAL` (endgame.asm) are dead routines** — no
   caller; only the tables they sit beside are used. Reclaimable.
3. **Hopeless-amp flicker** lengthens dead-lost shuffles (5/31). Cosmetic to result.
4. **Item-B hard ±300 step** (graduate — MEMORY TODO).
5. **No real phase classifier** beyond the single count<12 gate (Task #32).

---

## §6. Coverage tracker

✅ §1 pipeline · §2 phases · §3 gates · §4 middlegame magnitudes (material,
queen-cap, queen-prox, PST, king-safety, shield, doubled, bishop-pair, rook-files)
· §4 endgame magnitudes · endgame.asm liveness · §7 matrix.
🔲 N2 advanced-pawn-attack sub-term magnitude (have hanging ∓25/attacker).
🔲 EVAL_PST per-leaf cycle cost (perf, not correctness).

---

## §7. Interaction matrix — THE shuffle-bug root cause (quantified)

**Question:** in the middlegame (count≥12) only stages 1–10 − ADV_PAWN_B/2 are
active. What can sum to +300 while ELPH drifts into material loss?

**Max white-favorable positional contribution, realistic sharp middlegame:**

| term | typical | max-ish |
|---|---|---|
| PST (castled K +60, 2 N centered +40, B's +20, pawns +40, R/Q) | +120 | +180 |
| Bishop pair | +30 | +30 |
| Rook(s) on open files | +20 | +40 |
| Queen near enemy king (prox) | +40 | +60 |
| Castling rights / castled (via K-PST) | (in PST) | — |
| **Positional sum** | **~+210** | **~+310** |

**The positional terms are uncapped and sum to ≈ a full minor piece (~320 cp).**
Material P/N/B/R/Q is standard, but nothing scales the positional block down or caps
it. Consequence:

> ELPH down a **knight (−320)** but active (+300 positional) → **net ≈ 0 → reads
> "equal."** The eval cannot distinguish *"down a piece but active"* from *"equal and
> active."* This is the documented "+180 while −200 material" bug, now quantified.

**Why the safety nets don't catch it (the killer interaction):**
- **Item-B clamp** only fires when **preeg ≤ −300** (materially lost by ≥3). In the
  "down a knight but +300 active" case, **preeg ≈ −20**, so `|preeg| < 300` → **no
  clamp.** The inflated eval stands.
- **Hopeless-amp** needs preeg ≤ −300 too → also silent.
- So the masking is **invisible to every safety net** until the material deficit
  *compounds* past the positional offset (preeg finally < −300). By then ELPH has
  played a lost position for many moves → collapse → shuffle to adjudication. This is
  exactly the 5/31 trajectory: ~30 moves at +100..+360, cliff to −500, then grind.

**Fix direction (NOT applied — for a future, deliberate, A/B-tested change):**
the positional block must not rival a minor piece. Options to evaluate, one at a
time, against the four shuffle logs: (a) global positional down-scale (e.g. PST and
the ±50/±30/±40/±60 bonuses ×½ to ×⅔); (b) a hard cap on total non-material
contribution (e.g. clamp |R9 − material| ≤ ~120 in the middlegame); (c) lower the
Item-B trigger from ±300 toward ±150 so "down a minor" is caught before it
compounds. Each is one surgical change with a clear before/after test on the logs.

> **One-line root cause:** *uncapped positional bonuses (~+300, ≈ a minor piece)
> mask a minor-piece material deficit; Item-B's ±300 trigger is too coarse to catch
> "down a piece but active," so ELPH happily plays lost positions until the deficit
> compounds.*

### Verification (2026-05-31, two shuffle-loss games via tools/matcheck)

Computed true material balance (replayed movelist) vs reported eval at every ELPH
search; positional = eval − material. ELPH = White in both.

- **Peak-eval move, both games: positional ≈ +360** — adjudication-loss mv6:
  eval +360 at material **0**; shuffle-loss mv12: eval +715 at material +350
  (**+365** positional). Two independent games land on ≈ a full minor piece of
  positional score. Confirms the §4 tally empirically.
- **3–5 "delusion" searches per game** (eval ≥ +150 while material ≤ +50), avg
  positional inflation **+274 / +320**.
- **Eval is also volatile:** shuffle-loss **+715 (mv12) → −567 (mv13)** on a −100
  material change — the "eval volatility between depths" hazard, live. Inflation +
  instability together → ELPH commits to plans that evaporate, then collapses.

**Measurement caveat:** static material vs *searched* eval is noisy at mid-exchange
positions (search sees a recapture static material misses), e.g. an early `−330`
row that is a pre-recapture transient, not a real loss. Trust the *magnitude/
persistence* of the positional component, not individual rows.

**Conclusion (SUPERSEDED — see correction below).** ~~Positional block ≈ a minor
piece, uncapped and volatile.~~ (`tools/matcheck.py` saved as regression check.)

### CORRECTION (2026-05-31 pre-check) — the positional theory was WRONG

A deterministic pre-check (feed the two peak-delusion positions to a CAP=120
build, compare eval+bestmove) **overturned the §7 hypothesis**:
- Cap fired (A +360→+220, B +715→+635) but changed **NO decisions** (bestmoves
  `d4c6`/`e5d7` unchanged), and the games' material dropped *right after* those
  moves (A 0→−100, B +350→+250).
- **Verified position A:** c6 = black knight, defended by the **b7 pawn**. After
  `Nxc6` the QSEARCH-disabled leaf counts ELPH **+320 (up a knight)** and never
  sees `b7xc6` → the +320 is **PHANTOM** (real line is an even knight trade).
- So the "+360 positional inflation" `matcheck` measured was mostly **phantom
  material from the disabled QSEARCH** (`b66f5df`), not positional bonuses. The
  cap clamps eval to `MAT ± 120`, but `MAT` is poisoned by the phantom material,
  so the cap can't fix it. **REVERTED.**

**CORRECTED root cause of the shuffle:** disabled QSEARCH → the search stops after
a capture without searching the recapture → phantom material → the engine plays
captures that *look* winning but lose material → collapse → shuffle. This is
[[qsearch_recursion_todo]] / `b66f5df`. The real fix is **recapture-aware leaf
evaluation** (recursive QSEARCH ~60–80 B, or static exchange eval), **not** eval
recalibration. Hard area: a captor≤victim filter was tried 2026-05-28 and reverted
for re-introducing phantom inflation. matcheck's static-material-vs-searched-eval
is a *symptom detector*, not a fix gate, for this class.
