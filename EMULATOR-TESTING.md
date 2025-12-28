; RCA 1802/1806 Chess Engine - Emulator Testing Guide

## Overview

Testing on emulators before hardware deployment is highly recommended. This guide covers setup and testing procedures for common RCA 1802 emulators.

---

## Supported Emulators

### 1. Emu1802 (Mike Riley)
- **Platform**: Windows, Linux (Wine)
- **Features**: Accurate timing, good serial I/O support
- **Download**: http://www.elf-emulation.com/emu1802.html
- **Best for**: Initial development and debugging

### 2. Emma 02
- **Platform**: Windows, Cross-platform
- **Features**: Multiple system emulation, debugger
- **Download**: https://www.emma02.hobby-site.com/
- **Best for**: Testing different configurations

### 3. COSMAC Elf Simulator
- **Platform**: Web-based, Cross-platform
- **Features**: Simple, accessible
- **Best for**: Quick tests, demonstrations

---

## Configuration for Emulators

### Default Emulator Settings (config.asm)

```assembly
; For most emulators, use bit-bang serial with EF3:
#define USE_BITBANG
#define USE_EF3

; Standard settings:
BAUD_RATE   EQU 9600
CPU_CLOCK   EQU 12
BIT_DELAY   EQU 312
HALF_DELAY  EQU 156
```

### Emulator-Specific Adjustments

#### Emu1802
```assembly
; Standard configuration works well
#define USE_BITBANG
#define USE_EF3
BAUD_RATE   EQU 9600

; Configure Emu1802:
; - Set Q to Serial Output
; - Set EF3 to Serial Input
; - Baud rate: 9600
; - Terminal: Enable
```

#### Emma 02
```assembly
; May need faster emulation or adjusted timing
#define USE_BITBANG
#define USE_EF3
BAUD_RATE   EQU 9600

; In Emma 02:
; - Configure EF3 as serial input
; - Q as serial output
; - Baud: 9600
; - Enable terminal window
```

#### Web-Based Emulators
```assembly
; Some may not support serial I/O
; Consider using simplified test harness
; Or running in batch mode with predefined moves
```

---

## Build for Emulator Testing

### Step 1: Configure for Emulator

Edit `config.asm`:

```assembly
; Use bit-bang serial (most compatible)
#define USE_BITBANG

; Use EF3 (standard for most systems)
#define USE_EF3

; Standard 9600 baud
BAUD_RATE   EQU 9600
CPU_CLOCK   EQU 12

; Optional: Enable debugging
#define DEBUG_NODES
```

### Step 2: Build

```bash
./build.sh
```

Output: `chess-engine.hex`

### Step 3: Load into Emulator

**Emu1802:**
1. File → Load → chess-engine.hex
2. Set start address: $0000
3. Configure serial I/O (Q and EF3)
4. Reset and run

**Emma 02:**
1. Load hex file
2. Configure I/O mappings
3. Enable terminal
4. Reset and run

---

## Testing Procedures

### Test 1: Board Initialization

**Objective**: Verify memory and board setup

**Procedure**:
1. Load and run
2. Break at known address after INIT_BOARD
3. Examine memory at $5000
4. Expected: Starting chess position

**Memory at $5000 should show**:
```
00: 04 02 03 05 06 03 02 04  ; White back rank
10: 01 01 01 01 01 01 01 01  ; White pawns
20-50: 00 (empty squares)
60: 09 09 09 09 09 09 09 09  ; Black pawns
70: 0C 0A 0B 0D 0E 0B 0A 0C  ; Black back rank
```

### Test 2: Move Generation

**Objective**: Verify move generation works

**Procedure**:
1. Set breakpoint after GENERATE_MOVES
2. Run TEST_MOVE_GEN function
3. Check D register
4. Expected: D = $14 (20 decimal)

**From starting position, should generate:**
- 8 pawn single pushes
- 8 pawn double pushes
- 2 knight moves each (4 total)
- Total: 20 moves

### Test 3: Serial I/O Echo Test

**Objective**: Verify serial communication

**Procedure**:
1. Connect emulator terminal
2. Set to 9600 baud, 8-N-1
3. Type characters
4. Expected: Characters echo back

**Simple echo test program**:
```assembly
ECHO_TEST:
    CALL SERIAL_READ_CHAR
    CALL SERIAL_WRITE_CHAR
    BR ECHO_TEST
```

### Test 4: UCI Protocol

**Objective**: Verify UCI command processing

**Terminal Session**:
```
> uci
< id name RCA-Chess-1806
< id author Claude Code
< uciok

> isready
< readyok

> position startpos
< (no response)

> go depth 3
< (thinking...)
< bestmove e2e4
```

**Expected timing**:
- depth 3: 1-3 seconds (in emulator)
- depth 4: 5-15 seconds
- depth 5: 20-60 seconds

### Test 5: Search Depth Test

**Objective**: Verify search completes at various depths

**Procedure**:
```
> position startpos
> go depth 1
< bestmove ... (immediate)

> go depth 2
< bestmove ... (~1 sec)

> go depth 3
< bestmove ... (~2-5 sec)

> go depth 4
< bestmove ... (~10-20 sec)
```

### Test 6: Move Legality Test

**Objective**: Verify only legal moves generated

**Test Positions**:

**Position 1: Fool's Mate Setup**
```
> position startpos moves f2f3 e7e6 g2g4
> go depth 3
< bestmove d8h4  ; Queen checkmate
```

**Position 2: King in Check**
```
> position startpos moves e2e4 f7f6 d2d4 g7g5 d1h5
; King in check, should generate only moves that escape check
> go depth 2
< bestmove ... (legal evasion)
```

---

## Common Emulator Issues

### Issue 1: Serial I/O Not Working

**Symptoms**: No response to UCI commands

**Solutions**:
1. Verify emulator serial I/O configuration
2. Check Q and EF3 mapping
3. Verify baud rate matches (9600)
4. Try different EF line (EF1, EF2, EF4)

**Debugging**:
```assembly
; Add test at start of SERIAL_READ_CHAR:
    SEQ         ; Toggle Q for debugging
    REQ
    ; Continue with normal code
```

### Issue 2: Timing Issues

**Symptoms**: Garbled characters, communication errors

**Solutions**:
1. Adjust BIT_DELAY in config.asm
2. Calibrate for emulator speed
3. Try lower baud rate (4800)

**Calibration**:
```assembly
; Send 'U' character (0x55 = 01010101)
; Measure bit time with emulator debugger
; Adjust BIT_DELAY accordingly
```

### Issue 3: Search Takes Too Long

**Symptoms**: Emulator very slow compared to hardware

**Solutions**:
1. Reduce default depth (depth 2-3 for testing)
2. Enable emulator "fast mode" if available
3. Test with simplified positions

**Quick Test Positions**:
```
; Endgame position (fewer pieces, faster search)
> position fen 8/8/8/4k3/8/8/4K3/4R3 w - - 0 1
> go depth 5
; Should be much faster than full board
```

### Issue 4: Memory Issues

**Symptoms**: Crashes, incorrect behavior

**Solutions**:
1. Verify memory map in emulator
2. Check RAM size (need 32KB)
3. Verify stack at $7800-$7FFF available

**Memory Test**:
```assembly
; Test stack operations
CALL INIT_STACK
GLO R2          ; Should be $FF
GHI R2          ; Should be $7F
```

---

## Performance Benchmarks

### Expected Performance in Emulators

| Emulator | Speed vs Hardware | depth 4 Time |
|----------|-------------------|--------------|
| Emu1802 (accurate) | 0.5-1× | 10-20 sec |
| Emma 02 (fast mode) | 1-2× | 5-10 sec |
| Web-based | 0.1-0.5× | 30-60 sec |

### Perft Results (Move Count Verification)

From starting position:

| Depth | Nodes | Expected Count |
|-------|-------|----------------|
| 1 | 20 | 20 moves |
| 2 | 400 | 400 positions |
| 3 | 8,902 | 8,902 positions |
| 4 | 197,281 | 197,281 positions |

Use these to verify move generation accuracy.

---

## Debugging Tools

### 1. Breakpoints

Set breakpoints at key functions:
- `GENERATE_MOVES` - After each call
- `MAKE_MOVE` - Before/after
- `EVALUATE` - Check scores
- `NEGAMAX` - Watch recursion depth

### 2. Memory Watches

Monitor these addresses:
- `$5000` - Board array
- `$5080` - Game state
- `$6800` - Best move
- `$6802` - Node count
- `$7FFF` - Stack pointer

### 3. Register Watches

Critical registers during search:
- R2: Stack pointer (should be $7xxx)
- R5: Current depth
- R6: Alpha/score
- R7: Beta
- R8: Best score
- RC: Side to move

---

## Preparing for Hardware

### Final Emulator Tests Before Hardware

**Checklist**:
- [ ] UCI responds correctly
- [ ] Generates 20 moves from start
- [ ] Completes depth 4 search
- [ ] Plays reasonable moves
- [ ] Detects checkmate
- [ ] No memory errors
- [ ] Stack doesn't overflow

### Differences to Expect on Hardware

1. **Speed**: Hardware may be faster or slower
2. **Timing**: Bit-bang timing may need calibration
3. **Serial I/O**: May need different EF line
4. **Power**: Hardware can run continuously
5. **Reliability**: Hardware more reliable than emulator

### Hardware Preparation

1. **Verify clock speed**: Measure actual crystal frequency
2. **Test serial separately**: Echo test before chess
3. **Check RAM**: Verify full 32KB available
4. **Calibrate timing**: Adjust BIT_DELAY for actual speed
5. **Test incrementally**: Start with simple functions

---

## Example Test Session

### Complete Test Sequence

```bash
# 1. Build for emulator
vi config.asm  # Configure for your emulator
./build.sh

# 2. Load into emulator
# (Follow emulator-specific procedure)

# 3. Basic tests
# Run TEST_MOVE_GEN - expect 20 moves
# Run TEST_SEARCH - expect completion

# 4. UCI tests
Terminal: uci
Expected: uciok

Terminal: isready
Expected: readyok

Terminal: position startpos
Terminal: go depth 3
Expected: bestmove e2e4 (or similar, ~2-5 sec)

# 5. Game test
# Play a few moves against the engine
# Verify legal moves only
# Check reasonable play

# 6. Ready for hardware!
```

---

## Troubleshooting Reference

### Quick Diagnostic Commands

```assembly
; Test 1: Memory OK?
CALL INIT_BOARD
; Check $5000 for starting position

; Test 2: Move gen OK?
CALL TEST_MOVE_GEN
; D should = 20

; Test 3: Search OK?
CALL TEST_SEARCH
; Should complete without crash

; Test 4: Serial OK?
CALL SERIAL_READ_CHAR
CALL SERIAL_WRITE_CHAR
; Should echo character
```

### Common Error Patterns

| Symptom | Likely Cause | Fix |
|---------|--------------|-----|
| No UCI response | Serial I/O wrong | Check EF line config |
| Wrong move count | Move gen bug | Verify movegen-fixed.asm used |
| Search hangs | Stack overflow | Check depth limit |
| Garbled output | Baud rate wrong | Adjust timing |
| Illegal moves | Validation off | Check CHECK_TARGET_SQUARE |

---

## Next Steps

After successful emulator testing:

1. **Document configuration**: Note working settings
2. **Save test positions**: Record test cases
3. **Measure performance**: Note speed at each depth
4. **Prepare hardware**: Transfer working config
5. **Flash and test**: Same tests on hardware
6. **Calibrate timing**: Adjust for real clock speed
7. **Play games**: Full integration test

---

**Good luck with emulator testing!**

The emulator is your best friend for initial development. Test thoroughly before moving to hardware.
