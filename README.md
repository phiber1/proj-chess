# RCA 1802/1806 Chess Engine

A fully playable chess engine written in hand-crafted RCA 1802/1806 assembly language. The engine communicates via UCI protocol over serial, plays through the CuteChess GUI via a Python bridge, and has defeated Stockfish by checkmate 31 times — including its first pure-technique mate (queen + knight coordination, no promotion required) in July 2026.

## Quick Stats

| Stat | Value |
|------|-------|
| **CPU** | RCA CDP1806 @ 12 MHz |
| **RAM** | 32KB |
| **Code Size** | ~24KB (24,541 bytes) |
| **Search** | Iterative deepening to depth 5, per-iteration time prediction |
| **Opening Book** | 504 entries, 8 openings + opponent-prep deviations, ply 14 deep |
| **Time Control** | 180 seconds per move (DS12887 RTC) |
| **Wins vs Stockfish** | 31 (Stockfish limited to Skill Level 2, 5s/move, depth 3) |

## Wins vs Stockfish — firsts and highlights

| # | Date | Highlight |
|---|------|-----------|
| 1 | Feb 13, 2026 | First win ever — Alekhine's Defense, Qg7# in 38 |
| 5 | Apr 27, 2026 | Fastest win — Qxe7# in 17 moves |
| 16 | May 18, 2026 | Marathon — 111 moves / 170 minutes, recovered from −395, two promotions |
| 23 | Jun 2, 2026 | Validated the current stable engine base — coherent mate-in-30 conversion |
| 30 | Jul 2, 2026 | **First pure-technique mate** — Q+N coordination, no promotion, monotonic eval start to finish |
| 31 | Jul 2, 2026 | Mating attack at near-equal material — a-pawn runner to a8=Q, then Qg8# through the defender's own rook shell |

## Features

### Search
- Negamax with alpha-beta pruning
- Iterative deepening to depth 5 with per-iteration time prediction (predicts whether the next iteration fits the remaining budget)
- Transposition table (256 entries, Zobrist hashing with XOR-fold indexing, mate-rejection guard for hash collisions)
- Null move pruning (NMP)
- Late move reductions (LMR)
- Late move pruning (LMP) at low depth
- Reverse futility pruning (RFP) with depth/ply/check guards
- Futility pruning at frontier nodes with sentinel guard
- Check extension at search horizon (with ply guard)
- Move ordering: PV move first, TT move, killer moves, victim-value capture sort
- Quiescence search with alpha-beta and capture ordering
- Checkmate detection with ply-based score adjustment (shorter mates score higher)
- Stalemate detection
- Repetition detection (16-bit position hash history, 255 entries) — holds draws by threefold from worse positions
- Fifty-move rule
- Root-move validation (regenerates and legality-checks the move at bestmove emit)
- Stack overflow guard
- Fully deterministic search (replays reproduce exactly)

### Evaluation
- Material counting
- Piece-square tables (all 6 piece types)
- Bishop pair bonus
- Rook on semi-open / open file bonus
- Queen mobility (8-direction ray count, symmetric)
- King safety: pawn-shield penalty + enemy-queen storm penalty
- Castling rights bonus
- Graduated advanced pawn bonus (endgame-gated, 8-bit saturated)
- Passed pawn bonus, rank-aware (a pawn is passed if no enemy pawn *ahead* on adjacent files)
- Racing-passer bonus, **both colors**: an advanced passer with escort ramps toward queen value (150/350/600 by rank) so promotion threats beyond the search horizon are priced in — gated on a signed piece-balance "can it actually be escorted home" test
- Outgunned passer discount (passers scale to 1/4 when the enemy has heavy pieces and we have none)
- Queen redundancy cap (extra queens beyond the first score 0; prevents multi-promotion shuffles)
- King-king proximity and drive-to-edge bonuses in winning endgames (mating-technique gradient)
- Endgame king centralization (piece-count weighted)
- Insufficient-material draw detection (K-K, KN-K, KB-K, KB-KB same-color bishops score 0)
- Hopeless-position amplifier: in a lost low-material endgame the eval is pushed past the GUI's resign threshold so decided games end instead of shuffling
- Endgame detection via non-king piece count

### Board Representation
- 0x88 board format (fast off-board detection)
- Complete move generation for all piece types
- Castling legality verified in search (IS_SQUARE_ATTACKED on king + transit square)
- Make/unmake with full state restoration (Zobrist-incremental)
- Castling, en passant, promotion to all piece types

### Opening Book
- 504 entries: 8 mainline openings (Giuoco Piano, Sicilian Rossolimo, French Advance, Caro-Kann Advance, QGD Exchange, Alekhine Modern, Scandinavian, Pirc Austrian)
- Plus opponent-prep deviations targeting Stockfish Skill-2 sidelines, extending coverage to ply 14
- Built from PGN databases with `tools/pgn_to_book.py`; every entry legality-audited with `tools/check_book_legality.py`

### Interface & Diagnostics
- UCI protocol over serial (19200 baud via BIOS)
- CuteChess integration via Python serial bridge (`elph-bridge.py`)
- RTC-based time management (DS12887 real-time clock)
- UCI `info` output with depth, score (centipawns), and node count
- Hardware break-button diagnostics: a physical button on /EF4 traps a live hang and dumps registers through the BIOS — debugging a real 1806, not an emulator

## Building

```bash
bash build.sh
```

This preprocesses `config.asm`, concatenates all modules in dependency order, and assembles with the A18 cross-assembler. Output: `chess-engine.hex` (Intel HEX) and `chess-engine.bin`.

### Configuration

Edit `config.asm` to select between:
- **BIOS mode** (default): Uses Elf/OS BIOS for serial I/O and SCRT
- **Standalone mode**: Bit-bang serial for bare hardware

## Playing

1. Load `chess-engine.bin` into RAM at $0000 via xmodem, or load `chess-engine.hex` via the ROM monitor
2. Connect serial at 19200 baud
3. Run the CuteChess bridge:
   ```bash
   python3 elph-bridge.py
   ```
4. Configure CuteChess with the bridge as an engine

The engine responds to standard UCI commands:
```
uci              -> id name RCA-Chess-1806 / uciok
isready          -> readyok
position startpos moves e2e4 d7d5
go depth 5       -> bestmove ...
```

## Memory Map

```
$0000-$5FDD  Code + tables (~24KB)
$6000-$607F  Board array (128 bytes, 0x88 format)
$6080-$608F  Game state (castling, en passant, king positions, etc.)
$6090-$618F  Move history (undo stack)
$6200-$67FF  Search/eval workspace (killers, scores, counters, hash history,
             per-ply tables) — zeroed at every ucinewgame
$6800-$6FFF  Transposition table (2KB, 256 entries x 8 bytes)
$7000-$77FF  UCI input buffer (2KB)
$7800-$7AFF  Move list (depth-5 search)
$7B00-$7BFF  Reserved (future subroutine page)
$7C00-$7CFF  XMODEM loader (resident)
$7D00-$7FFF  Stack (overflow guard at $7D00)
```

## File Structure

### Core Engine
| File | Purpose |
|------|---------|
| `negamax.asm` | Alpha-beta search, iterative deepening, all pruning |
| `evaluate.asm` | Material + PST + pawn structure + king safety + mobility + endgame heuristics |
| `pst.asm` | Piece-square tables (6 piece types) |
| `endgame.asm` | Endgame king centralization heuristics |
| `transposition.asm` | TT probe/store, Zobrist hash update |
| `zobrist-keys.asm` | Zobrist hash key tables |

### Board & Moves
| File | Purpose |
|------|---------|
| `board.asm` | Board representation, constants, memory layout |
| `movegen.asm` | Complete move generation (all pieces) |
| `movegen-helpers.asm` | Move generation support routines |
| `makemove.asm` | Move execution with full undo support |
| `check.asm` | Check and attack detection |

### Interface & Support
| File | Purpose |
|------|---------|
| `uci.asm` | UCI protocol parser and response |
| `serial-io.asm` | Serial I/O (BIOS or standalone) |
| `opening-book.asm` | Opening book data (504 entries) |
| `opening-book-lookup.asm` | Book position matching |
| `main.asm` | Entry point, initialization |
| `config.asm` | Build configuration |
| `support.asm` | 16-bit arithmetic library |
| `scrt.asm` | Standard call/return technique (subroutine linkage) |
| `stack.asm` | Stack management for recursion |

### Tools
| File | Purpose |
|------|---------|
| `tools/pgn_to_book.py` | Convert PGN files to opening book ASM |
| `tools/merge_books.py` | Merge and deduplicate opening books |
| `tools/check_book_legality.py` | Replay-audit every book entry for legality |
| `tools/gen_zobrist.py` | Generate Zobrist hash key tables |
| `tools/analyze_loss.py` | Ground engine evals against replayed material (match forensics) |
| `tools/analyze_endgame_mechanism.py` | Endgame/adjudication mechanism analysis over match logs |
| `elph-bridge.py` | CuteChess serial bridge (Python/pyserial) |
| `build.sh` | Build script (preprocess, concat, assemble) |

## Historical Context

The RCA 1802 was the first CMOS microprocessor (1976), used in the COSMAC VIP, space probes (Voyager, Galileo), and early hobbyist computers. The Mephisto II (1981) was a commercial chess computer built on the 1802.

| | Mephisto II (1981) | This Engine |
|--|-------------------|-------------|
| **CPU** | RCA 1802 @ 6.1 MHz | RCA 1806 @ 12 MHz |
| **RAM** | 2KB | 32KB |
| **Search** | Basic alpha-beta | Negamax + TT + NMP + LMR + LMP + RFP + futility + check ext, depth 5 |
| **Opening Book** | Small | 504 entries, 8 openings + opponent-prep |
| **Wins** | N/A | 31 vs Stockfish |

## Credits

- **Engine design and implementation**: Claude Code (Anthropic) in collaboration with Mark Abene
- **Target platform**: RCA CDP1802/CDP1806 (RCA Corporation, 1976)
- **A18 cross-assembler**: William C. Colley, III / Herb Johnson
- **BIOS**: Elf/OS (Mike Riley)
- **UCI protocol**: Stefan Meyer-Kahlen
- **CuteChess**: Ilari Pihlajisto, Arto Jonsson

## License

Educational/hobbyist project. Use as you wish.
