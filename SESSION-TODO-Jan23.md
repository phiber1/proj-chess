# Session TODO - January 23, 2026

## Fixed Issues (Jan 22-23)

1. Castling after king moved - FIXED (clear rights when king moves)
2. R10 clobbering in MAKE_MOVE - FIXED (save/restore around CLEAR_CASTLING_RIGHT)
3. PST R15 clobbering - FIXED (save/restore in EVAL_PST)
4. PST stack order - FIXED (LIFO violation)
5. Castling without checking empty squares - FIXED (added f1/g1 and f8/g8 checks)
6. Multiple SEX 2 bugs - FIXED (added to multiple functions)
7. Ply overflow at ply 8 - FIXED (added ply limit check to NEGAMAX)

## Current Bug: h@h@ at Move 5

Position that fails:
```
position startpos moves e2e4 e7e5 g1f3 d7d6 a2a4 g8f6 a1a2 f6e4
go depth 3
```

Returns `bestmove h@h@` - BEST_MOVE is $FF $FF (never updated from initial value).

### Observations
- Happens at game move 5 (ply 10), depth 3 search
- With depth 3, max search ply should be ~3, well under limit of 8
- BEST_MOVE is initialized to $FF $FF in SEARCH_POSITION
- Updated only at root (ply 0) when score beats BEST_SCORE

### Possible Causes
1. No legal moves found (all filtered/pruned)
2. CURRENT_PLY corrupted (never == 0 at root)
3. All moves fail legality check
4. TT hit returning garbage
5. Score comparison failing

## Future Improvements

### 1. Hash-Based Opening Book Lookup (Priority: Medium)
Current book uses exact move-sequence matching, limiting transposition handling.

**Implementation:**
- Use existing Zobrist hash infrastructure
- Book format: `[hash_hi:4][hash_lo:4][from:1][to:1]` = 10 bytes per entry
- Tool: Create `tools/pgn_to_hash_book.py`
- Lookup: Compare current position hash against book entries
- Benefits: Handles transpositions, broader opening coverage

### 2. Expand Opening Book (Priority: Low)
Current book only covers Italian Game (47 entries).
- Add Sicilian, French, Caro-Kann, d4 openings
- Use larger/more diverse PGN database

