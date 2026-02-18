# RCA 1802/1806 Chess Engine

A fully playable chess engine written in hand-crafted RCA 1802/1806 assembly language. The engine communicates via UCI protocol over serial, plays through the CuteChess GUI via a Python bridge, and has won its first match by checkmate.

## Quick Stats

| Stat | Value |
|------|-------|
| **CPU** | RCA CDP1806 @ 3.58 MHz |
| **RAM** | 32KB |
| **Code Size** | 20,845 bytes |
| **Search** | Iterative deepening, depth 2-3 (depth 4 in simplified positions) |
| **Opening Book** | 455 entries, 8 openings, 12 ply deep |
| **Time Control** | 120 seconds per move (DS12887 RTC) |
| **First Win** | Qg7# checkmate in 38 moves (Alekhine's Defense, Feb 13 2026) |

## Features

### Search
- Negamax with alpha-beta pruning
- Iterative deepening (depth 1 through target depth)
- Transposition table (256 entries, Zobrist hashing)
- Null move pruning (NMP)
- Late move reductions (LMR)
- Reverse futility pruning (RFP) with check guard
- Futility pruning at frontier nodes with check guard
- Killer move ordering
- Quiescence search with alpha-beta and capture ordering
- Checkmate and stalemate detection
- Fifty-move rule

### Evaluation
- Material counting
- Piece-square tables (all 6 piece types)
- Endgame heuristics

### Board Representation
- 0x88 board format (fast off-board detection)
- Complete move generation for all piece types
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

1. Flash `chess-engine.hex` to the target system
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
$0000-$51FF  Code (~20.8KB)
$6000-$607F  Board array (128 bytes, 0x88 format)
$6080-$60FF  Game state (castling, en passant, king positions, etc.)
$6100-$61FF  Move history (undo stack)
$6200-$64FF  Search workspace (killers, scores, depths, move pointers)
$6500-$677F  UCI input buffer (640 bytes)
$6780-$67FF  Quiescence search workspace
$6800-$6FFF  Transposition table (2KB, 256 entries x 8 bytes)
$7000-$7FFF  Stack (4KB)
```

## File Structure

### Core Engine
| File | Purpose |
|------|---------|
| `negamax.asm` | Alpha-beta search, iterative deepening, all pruning |
| `evaluate.asm` | Material + PST evaluation |
| `pst.asm` | Piece-square tables (6 piece types) |
| `endgame.asm` | Endgame heuristics |
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
| **CPU** | RCA 1802 @ 6.1 MHz | RCA 1806 @ 3.58 MHz |
| **RAM** | 2KB | 32KB |
| **Search** | Basic alpha-beta | Negamax + TT + NMP + LMR + RFP + futility |
| **Opening Book** | Small | 455 entries, 8 openings |
| **First Win** | N/A | Qg7# in 38 moves |

## Credits

- **Engine design and implementation**: Claude Code (Anthropic) in collaboration with Mark Abene
- **Target platform**: RCA CDP1802/CDP1806 (RCA Corporation, 1976)
- **BIOS**: Elf/OS (Mike Riley)
- **UCI protocol**: Stefan Meyer-Kahlen
- **CuteChess**: Ilari Pihlajisto, Arto Jonsson

## License

Educational/hobbyist project. Use as you wish.
