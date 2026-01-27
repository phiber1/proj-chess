# Debug Session Summary - January 26, 2026

## Bug: R9 Stack Corruption in Negamax Move Loop

### Symptom
Move generation produced garbage moves at ply 1 for root moves 1+ (second and later root move evaluations). First ply-1 block had valid moves, subsequent blocks had garbage with off-board squares like $78, $7F.

### Root Cause
**R9 (move list pointer) was corrupted by stack push/pop across the ~500-instruction negamax move loop.** After recursion and returning to the parent ply, R9 was restored from the stack as `$FE7A` instead of `$6280`. The engine then read garbage data from high memory ($FE7A+) and interpreted it as moves.

The move list data at $6280 was always correct (verified by `M:29B42334` raw dump). GENERATE_MOVES worked perfectly - R10 and GM_SCAN_IDX stayed in sync. The board state was correct. The problem was purely in how R9 was preserved across the recursive call.

### Debugging Trail
1. **R12 (side to move)** - ruled out, C:08 correct for all P1 blocks
2. **R9 (move list pointer)** - ruled out at function entry, L:6280 correct
3. **Ordering functions** - ruled out, disabled with no change
4. **R14 usage** - ruled out, not used in build files (docs were outdated)
5. **Board state** - ruled out, B:0C0E0C00 identical for valid and garbage blocks
6. **R10/GM_SCAN_IDX sync** - ruled out, no `!XX:YY` errors at piece dispatch
7. **Raw move list data** - M:29B42334 IDENTICAL for valid and garbage blocks
8. **R9 at move loop entry** - **FOUND IT**: `R:6280` (correct) vs `R:FE7A` (corrupt)

### Fix Applied
Replaced R9 stack push/pop with ply-indexed fixed memory save/restore.

**New variable:** `LOOP_MOVE_PTR` at `$64B0-$64B7` (8 bytes, 2 per ply)

**Files changed:**
- `board-0x88.asm` - Added LOOP_MOVE_PTR variable definition
- `negamax.asm` - 4 locations changed:
  1. R9 save (was `GLO 9 / STXD / GHI 9 / STXD`) → memory save to LOOP_MOVE_PTR[ply*2]
  2. R9 restore main path (after recursion) → memory restore
  3. R9 restore futility path → memory restore
  4. R9 restore illegal move path → memory restore
  5. Depth pop changed from `LDXA/LDXA` to `LDXA/LDX` (R9 no longer between depth and move_count on stack)
  6. Removed all debug code (L:, C:, B:, P0/P1:, M:, R:, X:, !)
  7. Re-enabled ORDER_KILLER_MOVES and ORDER_CAPTURES_FIRST
- `movegen-fixed.asm` - Removed R10/GM_SCAN_IDX sync debug code
- `PROGRESS-platform.md` - Updated GENERATE_MOVES register docs (R14→GM_SCAN_IDX), added LOOP_MOVE_PTR to memory map, added build verification section

**Also fixed:** `makemove.asm` - Changed `BNZ MM_RESET_HALFMOVE` to `LBNZ` (branch out of range from added debug code; kept as LBNZ is safer)

### Secondary Bug Found: Memory Overlap
**LOOP_MOVE_PTR was initially placed at $64A7, overlapping with:**
- `NULL_MOVE_OK` ($64A7) - null move pruning flag
- `NULL_SAVED_EP` ($64A8) - saved EP square
- `ENEMY_COLOR_TEMP` ($64A9) - used by IS_IN_CHECK

At ply 0, saving R9 ($6200) to $64A7 overwrote NULL_MOVE_OK with $62.
At ply 1, saving R9 ($6280) to $64A9 overwrote ENEMY_COLOR_TEMP with $62,
causing IS_IN_CHECK to use garbage enemy color. This caused the engine to
hang after the first root move evaluation.

**Fix:** Moved LOOP_MOVE_PTR to $64B0-$64B7 (free space).

### Status
- Build clean, no assembler errors
- Memory overlap fixed (LOOP_MOVE_PTR moved from $64A7 to $64B0)
- **Hardware test showed hang** - caused by the memory overlap, now fixed
- Debug output (ply 0/1 move+score brackets) still present in negamax.asm

### Known Issue: LMR_MOVE_INDEX is Global
`LMR_MOVE_INDEX` ($64A3) is reset to 0 at each NEGAMAX entry but is a global
variable. After a child NEGAMAX returns, LMR_MOVE_INDEX reflects the child's
final value, not the parent's count. This means LMR is applied incorrectly
after the first recursive return (move index is artificially high, so nearly
all subsequent moves qualify for LMR). This likely causes extreme slowness
at depth 3+ due to excessive LMR re-searches.

**Fix needed:** Save/restore LMR_MOVE_INDEX per ply (add to LOOP_MOVE_PTR
region or save to stack alongside LMR_REDUCED).

### TODO for Next Session
1. **Rebuild and test on hardware** - verify memory overlap fix resolves hang
2. **Add heartbeat character** - print '.' at top of ply-0 move loop to confirm engine is still running during long searches
3. **Fix LMR_MOVE_INDEX global bug** - either:
   - Save/restore to ply-indexed memory (like LOOP_MOVE_PTR), or
   - Push/pop on stack alongside LMR_REDUCED
4. **Test depth 2 first** - verify basic R9 fix works before trying depth 3
5. **Test depth 3** - if still slow, disable LMR (set LMR_REDUCED = 0 always) to isolate ordering vs LMR
6. **If all working:** Remove ply 0/1 debug brackets, run CuteChess match

### Key Lessons
1. Stack-based register save/restore is fragile across large code spans with multiple CALL/RETN pairs, alternative paths (futility, illegal move), and complex pop sequences. Ply-indexed fixed memory is more robust for values that must survive recursion in the negamax loop.
2. **Always check for memory overlaps** when adding new EQU variables. The a18 assembler does not detect overlapping EQU addresses.
