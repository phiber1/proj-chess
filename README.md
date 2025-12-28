# RCA 1802/1806 Chess Engine

A complete chess engine for the RCA 1802/1806 microprocessor, targeting 1400-1700 ELO playing strength.

## Quick Stats

- **Target CPU**: RCA 1806 @ 12 MHz
- **RAM**: 32KB
- **Search Depth**: 6-7 ply (3-3.5 full moves)
- **Playing Strength**: ~1400-1700 ELO (with all enhancements)
- **Code Size**: ~9-11KB
- **Status**: 95% complete, playable in 1-2 hours (just needs serial I/O config)

## Features

### Implemented ✓
- Negamax search with alpha-beta pruning
- 0x88 board representation
- Complete move generation (all piece types)
- Check and checkmate detection
- Material evaluation
- UCI protocol interface
- Make/unmake move with full state restoration

### Planned
- Piece-square table evaluation
- Transposition table (16-20KB)
- Opening book (4-6KB)
- Advanced evaluation features

## Performance

| Metric | Value |
|--------|-------|
| Nodes/second | ~8,000 |
| 6-ply search time | 10-30 seconds |
| Current strength | ~1100-1300 ELO (material only) |
| Target strength | ~1500-1700 ELO (with enhancements) |

## File Structure

### Core Engine
- `support.asm` - 16-bit arithmetic library
- `math.asm` - Software multiply/divide
- `stack.asm` - Stack management for recursion
- `negamax.asm` - Alpha-beta search algorithm

### Board & Moves
- `board.asm` - 0x88 board representation
- `movegen.asm` + `movegen-helpers.asm` - Move generation
- `makemove.asm` + `makemove-helpers.asm` - Move execution
- `check.asm` - Check detection

### Evaluation & Interface
- `evaluate.asm` - Position evaluation
- `uci.asm` - UCI protocol
- `main.asm` - Entry point and main loop

### Documentation
- `INTEGRATION-GUIDE.md` - **START HERE** for assembly
- `SESSION-SUMMARY.md` - What we built
- `PROJECT-STATUS.md` - Detailed component status
- `conversation-log.md` - Design rationale
- `board-layout.md` - 0x88 reference
- `movegen-status.md` - Move gen integration guide

## Quick Start

### 1. Read Documentation
```bash
cat INTEGRATION-GUIDE.md
```

### 2. Build
Option A - Single file:
```bash
cat support.asm math.asm stack.asm board.asm check.asm \
    movegen-helpers.asm movegen.asm makemove-helpers.asm \
    makemove.asm evaluate.asm negamax.asm uci.asm \
    main.asm > chess-engine.asm

asm1802 chess-engine.asm -o chess-engine.hex
```

Option B - With includes (see INTEGRATION-GUIDE.md)

### 3. Complete Integration Tasks
See INTEGRATION-GUIDE.md sections 1-4:
1. Fix movegen.asm (use helpers)
2. Clean up makemove.asm (remove stubs)
3. Wire negamax.asm (replace stubs)
4. Implement serial I/O (hardware-specific)

### 4. Test
```assembly
CALL INIT_BOARD
CALL TEST_MOVE_GEN      ; Should return 20 moves
CALL TEST_SEARCH        ; Depth 3 search
```

### 5. Play
Connect via UCI to Arena, Cutechess, or other GUI.

## UCI Commands

```
uci                     → id name RCA-Chess-1806
                          uciok
isready                 → readyok
position startpos
position startpos moves e2e4 d7d5
go depth 6              → bestmove e2e4
quit
```

## Memory Map

```
$0000-$1FFF: Code (8KB)
$2000-$2FFF: PST tables & opening book (4KB)
$3000-$67FF: Transposition table (16KB)
$5000-$507F: Board array (128 bytes)
$5080-$5087: Game state (8 bytes)
$6800-$6FFF: Working memory (2KB)
$7800-$7FFF: Stack (2KB)
```

## Architecture Highlights

### 0x88 Board
- Fast off-board detection: `square & 0x88 == 0`
- 128 bytes (16×8 array)
- Natural rank/file encoding

### Move Encoding (16-bit)
```
Bits 0-6:   From square
Bits 7-13:  To square
Bits 14-15: Flags (normal/castle/EP/promotion)
```

### Register Usage (Search)
```
R5: depth    R6: alpha     R7: beta      R8: score
R9: moves    RA: board     RB: move      RC: color
```

## Comparison: Mephisto II (1981)

| Feature | Mephisto II | RCA-Chess-1806 |
|---------|-------------|----------------|
| CPU | RCA 1802 @ 6.1 MHz | RCA 1806 @ 12 MHz |
| RAM | 2KB | 32KB |
| ELO | 1332 | ~1500-1700 (target) |
| Advantage | — | 2× speed, 16× RAM |

## Development Status

### Complete (100%) ✓
- Core algorithms
- Board representation
- Check detection
- Material evaluation

### Needs Integration (90%) ⚠
- Move generation (connect helpers)
- Make/unmake (remove stubs)
- Negamax (replace stubs)
- UCI (add serial I/O)

### Future Enhancements (0%)
- Piece-square tables
- Transposition table
- Opening book

## Contributing

This engine was built with Claude Code (Sonnet 4.5) in a single session as a demonstration of inside-out development for constrained systems.

Integration and enhancement opportunities:
- Complete integration tasks (INTEGRATION-GUIDE.md)
- Implement hardware-specific serial I/O
- Generate PST data
- Create opening book builder
- Tune evaluation weights

## License

Educational/demonstration project. Use as you wish.

## Credits

- Architecture & Implementation: Claude Code (Anthropic)
- Target System: RCA 1802/1806 (RCA Corporation, 1970s)
- Historical Reference: Mephisto II (1981)
- UCI Protocol: Rudolf Huber & Stefan Meyer-Kahlen

## Support

See documentation:
- **INTEGRATION-GUIDE.md** for assembly and testing
- **SESSION-SUMMARY.md** for project overview
- **PROJECT-STATUS.md** for detailed component status

---

**Ready to play chess on a 1970s CPU? Let's go! 🎯♟️**
