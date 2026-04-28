# RCA 1802/1806 Chess Engine

A fully playable chess engine written in hand-crafted RCA 1802/1806 assembly language. The engine communicates via UCI protocol over serial, plays through the CuteChess GUI via a Python bridge, and has defeated Stockfish by checkmate five times.

## Quick Stats

| Stat | Value |
|------|-------|
| **CPU** | RCA CDP1806 @ 12 MHz |
| **RAM** | 32KB |
| **Code Size** | ~23.6KB (23,632 bytes) |
| **Search** | Adaptive iterative deepening, depth 2-3 (extends to 4 when time allows) |
| **Opening Book** | 478 entries, 8 openings + opponent-prep deviations, ply 14 deep |
| **Time Control** | 180 seconds per move (DS12887 RTC) |
| **Wins vs Stockfish** | 5 (Stockfish limited to Skill Level 2, 5s/move, depth 3) |

## Wins vs Stockfish

| # | Date | Opening | Result | Moves |
|---|------|---------|--------|-------|
| 1 | Feb 13, 2026 | Alekhine's Defense | Qg7# | 38 |
| 2 | Mar 2, 2026 | Alekhine's Mokele Mbembe | Qg8# | 35 |
| 3 | Mar 26, 2026 | Elephant Gambit | Rb8# | 36 |
| 4 | Apr 21, 2026 | French Advance | Rf8# | 41 |
| 5 | Apr 27, 2026 | Alekhine's Defense (Ng8 retreat) | Qxe7# | 17 |

## Features

### Search
- Negamax with alpha-beta pruning
- Adaptive iterative deepening: extends to depth 4 when depth 3 finishes fast (elapsed < 60s)
  with a hard safety cap at depth 4 (MOVE_LIST sized for 4 plies)
- Transposition table (256 entries, Zobrist hashing, mate-rejection guard for 16-bit hash collisions)
- Null move pruning (NMP)
- Late move reductions (LMR)
- Reverse futility pruning (RFP) with depth/ply/check guards
- Futility pruning at frontier nodes with sentinel guard (per-ply table sized for MAX_PLY=8)
- Check extension at search horizon (with ply guard)
- Killer move ordering
- Quiescence search with alpha-beta and capture ordering
- Checkmate detection with ply-based score adjustment (shorter mates score higher per standard convention)
- Stalemate detection
- Repetition detection (16-bit position hash history, 255 entries)
- Fifty-move rule

### Evaluation
- Material counting
- Piece-square tables (all 6 piece types)
- Bishop pair bonus
- Rook on semi-open / open file bonus
- Castling rights bonus (+20cp per side with rights remaining)
- Graduated advanced pawn bonus (+25/+50/+100/+150cp by rank 4/5/6/7, endgame-gated, 8-bit saturated)
- Passed pawn bonus (file-count detection: +25/+50/+90/+140/+200/+250cp by rank 2-7)
- Pawn-bonus 1/4 scaling in conversion phase only (own queen + opp has none) — curbs redundant-promotion bias without suppressing normal pawn play
- Queen redundancy cap (extra queens beyond first score 0cp; prevents multi-promotion shuffles)
- Queen-king proximity bonus (Chebyshev distance lookup, 60→0cp by distance 1-7)
- Drive-to-edge bonus on enemy king in winning endgame (KING_EDGE_TABLE)
- Endgame king centralization for own king (piece-count weighted)
- Check bonus (±40cp on checking moves, endgame-gated)
- Endgame detection via non-king piece count

### Board Representation
- 0x88 board format (fast off-board detection)
- Complete move generation for all piece types
- Castling legality verified in search loop (IS_SQUARE_ATTACKED on king + transit square)
- Make/unmake with full state restoration (Zobrist-incremental)
- Castling (kingside/queenside, rights revocation)
- En passant
- Pawn promotion (all piece types, in search and UCI output)

### Opening Book
- 473 entries: 8 mainline openings (Giuoco Piano, Sicilian Rossolimo, French Advance, Caro-Kann Advance, QGD Exchange, Alekhine Modern, Scandinavian, Pirc Austrian)
- Plus opponent-prep deviations targeting Stockfish Skill-2 sidelines (Krejcik-sacrifice and Krejcik-retreat after Alekhine's Defense, extending coverage to ply 14)
- Built from PGN databases with `tools/pgn_to_book.py`

### Interface
- UCI protocol over serial (19200 baud via BIOS)
- CuteChess integration via Python serial bridge (`elph-bridge.py`)
- RTC-based time management (DS12887 real-time clock)
- UCI `info` output with depth, score (centipawns), and node count

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
go depth 3       -> bestmove e2e4
```

## Memory Map

```
$0000-$5B7F  Code (~23.4KB)
$6000-$607F  Board array (128 bytes, 0x88 format)
$6080-$608F  Game state (castling, en passant, king positions, etc.)
$6090-$618F  Move history (undo stack, 256 bytes)
$6200-$63FF  Move list (512 bytes, 4 plies)
$6400-$64FF  Search workspace (killers, scores, undo state, queen counters, etc.)
$6500-$66FD  Position hash history (255 entries, repetition detection)
$6700-$670F  Per-ply best-move table (8 plies × 2 bytes)
$6710-$671F  Pawn file counts (eval transients, white + black)
$6720-$6721  Queen square trackers (eval transients)
$6722-$6741  Futility pruning table (8 plies × 4 bytes)
$6800-$6FFF  Transposition table (2KB, 256 entries × 8 bytes)
$7000-$77FF  UCI input buffer (2KB)
$7F00-$7FFF  Stack
```

Workspace area `$6200-$67FF` is zeroed at every `ucinewgame` to prevent stale state between games.

## File Structure

### Core Engine
| File | Purpose |
|------|---------|
| `negamax.asm` | Alpha-beta search, iterative deepening, all pruning |
| `evaluate.asm` | Material + PST + pawn structure + queen-cap + queen-king proximity + endgame heuristics |
| `pst.asm` | Piece-square tables (6 piece types) |
| `endgame.asm` | Endgame king centralization heuristics |
| `transposition.asm` | TT probe/store, Zobrist hash update |
| `zobrist-keys.asm` | Zobrist hash key tables |

### Board & Moves
| File | Purpose |
|------|---------|
| `board-0x88.asm` | Board representation, constants, memory layout |
| `movegen-fixed.asm` | Complete move generation (all pieces) |
| `movegen-helpers.asm` | Move generation support routines |
| `makemove.asm` | Move execution with full undo support |
| `makemove-helpers.asm` | Castling, en passant, promotion handling |
| `check.asm` | Check and attack detection |

### Interface & Support
| File | Purpose |
|------|---------|
| `uci.asm` | UCI protocol parser and response |
| `serial-io.asm` | Serial I/O (BIOS or standalone) |
| `opening-book.asm` | Opening book data (473 entries) |
| `opening-book-lookup.asm` | Book position matching |
| `main.asm` | Entry point, initialization |
| `config.asm` | Build configuration |
| `support.asm` | 16-bit arithmetic library |
| `math.asm` | Multiply/divide routines |
| `stack.asm` | Stack management for recursion |

### Tools
| File | Purpose |
|------|---------|
| `tools/pgn_to_book.py` | Convert PGN files to opening book ASM |
| `tools/merge_books.py` | Merge and deduplicate opening books |
| `tools/gen_zobrist.py` | Generate Zobrist hash key tables |
| `elph-bridge.py` | CuteChess serial bridge (Python/pyserial) |
| `build.sh` | Build script (preprocess, concat, assemble) |

## Historical Context

The RCA 1802 was the first CMOS microprocessor (1976), used in the COSMAC VIP, space probes (Voyager, Galileo), and early hobbyist computers. The Mephisto II (1981) was a commercial chess computer built on the 1802.

| | Mephisto II (1981) | This Engine |
|--|-------------------|-------------|
| **CPU** | RCA 1802 @ 6.1 MHz | RCA 1806 @ 12 MHz |
| **RAM** | 2KB | 32KB |
| **Search** | Basic alpha-beta | Negamax + TT + NMP + LMR + RFP + futility + check ext |
| **Opening Book** | Small | 478 entries, 8 openings + opponent-prep |
| **Wins** | N/A | 5 vs Stockfish |

## Credits

- **Engine design and implementation**: Claude Code (Anthropic) in collaboration with Mark Abene
- **Target platform**: RCA CDP1802/CDP1806 (RCA Corporation, 1976)
- **BIOS**: Elf/OS (Mike Riley)
- **UCI protocol**: Stefan Meyer-Kahlen
- **CuteChess**: Ilari Pihlajisto, Arto Jonsson

## License

Educational/hobbyist project. Use as you wish.
