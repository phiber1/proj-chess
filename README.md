# RCA 1802/1806 Chess Engine

A fully playable chess engine written in hand-crafted RCA 1802/1806 assembly language. The engine communicates via UCI protocol over serial, plays through the CuteChess GUI via a Python bridge, and has defeated Stockfish by checkmate.

## Quick Stats

| Stat | Value |
|------|-------|
| **CPU** | RCA CDP1806 @ 12 MHz |
| **RAM** | 32KB |
| **Code Size** | ~21.3KB (21,343 bytes) |
| **Search** | Iterative deepening, depth 2-3 |
| **Opening Book** | 455 entries, 8 openings, 12 ply deep |
| **Time Control** | 120 seconds per move (DS12887 RTC) |
| **Wins vs Stockfish** | 2 (Stockfish limited to 5s/move, depth 3) |

## Wins vs Stockfish

| # | Date | Opening | Result | Moves |
|---|------|---------|--------|-------|
| 1 | Feb 13, 2026 | Alekhine's Defense | Qg7# | 38 |
| 2 | Mar 2, 2026 | Alekhine's Mokele Mbembe | Qg8# | 35 |

## Features

### Search
- Negamax with alpha-beta pruning
- Iterative deepening (depth 1 through target depth)
- Transposition table (256 entries, Zobrist hashing)
- Null move pruning (NMP)
- Late move reductions (LMR)
- Reverse futility pruning (RFP) with depth/ply/check guards
- Futility pruning at frontier nodes with sentinel guard
- Check extension at search horizon (with ply guard)
- Killer move ordering
- Quiescence search with alpha-beta and capture ordering
- Checkmate and stalemate detection
- Repetition detection (16-bit position hash history, 255 entries)
- Fifty-move rule

### Evaluation
- Material counting
- Piece-square tables (all 6 piece types)
- Castling rights bonus (+20cp per side with rights remaining)
- Graduated advanced pawn bonus (+32/+64/+96cp by rank, endgame only)
- Endgame king centralization (piece-count weighted)
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
- 455 entries across 8 openings at ply 12 (6 moves per side)
- Giuoco Piano, Sicilian Rossolimo, French Advance, Caro-Kann Advance, QGD Exchange, Alekhine Modern, Scandinavian, Pirc Austrian
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
$0000-$535E  Code (~21.3KB)
$6000-$607F  Board array (128 bytes, 0x88 format)
$6080-$608F  Game state (castling, en passant, king positions, etc.)
$6090-$618F  Move history (undo stack, 256 bytes)
$6200-$63FF  Move list (512 bytes, 4 plies)
$6400-$64FF  Search workspace (killers, scores, depths, futility table, etc.)
$6500-$66FD  Position hash history (255 entries, repetition detection)
$6780-$67FF  Quiescence search workspace
$6800-$6FFF  Transposition table (2KB, 256 entries x 8 bytes)
$7000-$77FF  UCI input buffer (2KB)
$7F00-$7FFF  Stack
```

## File Structure

### Core Engine
| File | Purpose |
|------|---------|
| `negamax.asm` | Alpha-beta search, iterative deepening, all pruning |
| `evaluate.asm` | Material + PST + castling rights + pawn bonus evaluation |
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
| `opening-book.asm` | Opening book data (455 entries) |
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
| **Opening Book** | Small | 455 entries, 8 openings |
| **Wins** | N/A | 2 vs Stockfish |

## Credits

- **Engine design and implementation**: Claude Code (Anthropic) in collaboration with Mark Abene
- **Target platform**: RCA CDP1802/CDP1806 (RCA Corporation, 1976)
- **BIOS**: Elf/OS (Mike Riley)
- **UCI protocol**: Stefan Meyer-Kahlen
- **CuteChess**: Ilari Pihlajisto, Arto Jonsson

## License

Educational/hobbyist project. Use as you wish.
