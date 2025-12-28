# RCA 1802/1806 Chess Engine - Configuration Guide

## Quick Start

**Most users can skip detailed configuration!**

Default settings work for typical 1802 systems:
- **Serial I/O**: Bit-bang (no UART needed)
- **Console Input**: EF3 (pin 27) - industry standard
- **Console Output**: Q (pin 26) - industry standard
- **Baud Rate**: 9600
- **Clock**: 12 MHz

Just build and go:
```bash
./build.sh
```

---

## When to Configure

Configure `config.asm` if you have:
- Different EF line (EF1, EF2, EF4 instead of EF3)
- Hardware UART chip
- Different clock speed (not 12 MHz)
- Different baud rate preference
- Special emulator requirements

---

## Configuration File: config.asm

### Serial I/O Method

**Option 1: Bit-Bang (Default - Recommended)**
```assembly
#define USE_BITBANG
```
- ✓ No extra hardware needed
- ✓ Works on any system
- ✓ Well-tested
- ✗ Uses more CPU time
- ✗ Limited to ~19200 baud

**Option 2: Hardware UART**
```assembly
#define USE_UART
```
- ✓ Faster
- ✓ More reliable
- ✓ Less CPU usage
- ✗ Requires UART chip
- ✗ Hardware-specific configuration

**Choose one, not both!**

---

## EF Input Line Selection

### Default: EF3 (Most Common)

```assembly
#define USE_EF3         ; EF3 input (pin 27) - DEFAULT
```

**Why EF3?**
- Industry standard for console input
- Used by most ROM monitors
- Used by most operating systems
- COSMAC ELF, Quest Super ELF, Membership Card all use EF3

### Alternative Lines

Only change if your system uses a different line:

```assembly
; Uncomment the one your system uses:
; #define USE_EF1       ; EF1 input (pin 25)
; #define USE_EF2       ; EF2 input (pin 26)
#define USE_EF3         ; EF3 input (pin 27) - DEFAULT
; #define USE_EF4       ; EF4 input (pin 1)
```

### How to Determine Your EF Line

**Check your ROM monitor documentation:**
- COSMAC ELF: EF3
- Quest Super ELF: EF3 (configurable)
- Membership Card: EF3
- Pico/Elf: EF3
- Most others: EF3

**If unsure, try EF3 first** (90% chance it's correct).

---

## Baud Rate Configuration

### Default: 9600 Baud

```assembly
BAUD_RATE   EQU 9600    ; DEFAULT
CPU_CLOCK   EQU 12      ; 12 MHz
BIT_DELAY   EQU 312     ; Calculated for above
HALF_DELAY  EQU 156
```

### Other Common Rates

**4800 baud (more reliable for long cables):**
```assembly
BAUD_RATE   EQU 4800
CPU_CLOCK   EQU 12
BIT_DELAY   EQU 625
HALF_DELAY  EQU 312
```

**19200 baud (faster, requires good clock):**
```assembly
BAUD_RATE   EQU 19200
CPU_CLOCK   EQU 12
BIT_DELAY   EQU 156
HALF_DELAY  EQU 78
```

### Different Clock Speeds

**6.1 MHz (like Mephisto II):**
```assembly
BAUD_RATE   EQU 9600
CPU_CLOCK   EQU 6
BIT_DELAY   EQU 156     ; (6 * 1,000,000) / 9600 / 4
HALF_DELAY  EQU 78
```

**3.58 MHz (NTSC colorburst crystal):**
```assembly
BAUD_RATE   EQU 9600
CPU_CLOCK   EQU 3
BIT_DELAY   EQU 78
HALF_DELAY  EQU 39
```

### Manual Calculation

Formula:
```
Cycles per bit = (CPU_CLOCK * 1,000,000) / BAUD_RATE
BIT_DELAY = Cycles per bit / 4
HALF_DELAY = BIT_DELAY / 2
```

Example for 9600 @ 12 MHz:
```
Cycles = (12 * 1,000,000) / 9600 = 1250
BIT_DELAY = 1250 / 4 = 312.5 ≈ 312
HALF_DELAY = 312 / 2 = 156
```

---

## UART Configuration

### When to Use UART

Use hardware UART if you have:
- CDP1854 UART chip
- CDP18S641 UART
- 8250/16550 compatible
- 6850 ACIA
- Any other UART hardware

### UART Settings

```assembly
#define USE_UART

; I/O port addresses (adjust for your hardware)
UART_DATA   EQU $01     ; Data register
UART_STATUS EQU $02     ; Status register

; Status bit masks (adjust for your UART)
UART_RX_RDY EQU $01     ; Receive ready bit
UART_TX_RDY EQU $02     ; Transmit ready bit
```

### Common UART Configurations

**CDP1854 (most common):**
```assembly
UART_DATA   EQU $01     ; Both data and control
UART_STATUS EQU $01     ; Same port (read=status, write=control)
UART_RX_RDY EQU $01     ; Bit 0
UART_TX_RDY EQU $02     ; Bit 1
```

**8250/16550 (PC-compatible, COM1):**
```assembly
UART_DATA   EQU $3F8    ; Base address
UART_STATUS EQU $3FD    ; Base + 5
UART_RX_RDY EQU $01     ; DR bit
UART_TX_RDY EQU $20     ; THRE bit
```

**6850 ACIA:**
```assembly
UART_DATA   EQU $??     ; System-specific
UART_STATUS EQU $??     ; System-specific
UART_RX_RDY EQU $01     ; RDRF bit
UART_TX_RDY EQU $02     ; TDRE bit
```

---

## Search Configuration

### Default Depth

```assembly
DEFAULT_DEPTH   EQU 6   ; Good balance
MAX_DEPTH       EQU 12  ; Safety limit
```

**Recommendations:**
- Beginners: DEFAULT_DEPTH 4-5 (faster games)
- Intermediate: DEFAULT_DEPTH 6 (good play)
- Advanced: DEFAULT_DEPTH 7-8 (slower but stronger)

Users can override with UCI `go depth N` command.

---

## Memory Configuration

### Default Memory Map

```assembly
CODE_START  EQU $0000   ; Program starts at 0
STACK_TOP   EQU $7FFF   ; Stack grows down from top
BOARD_BASE  EQU $5000   ; Board array
STATE_BASE  EQU $5080   ; Game state
```

**Only change if:**
- Your system has ROM at $0000 (move CODE_START)
- You have less than 32KB RAM
- You need to reserve specific memory regions

### Reduced RAM Systems

**16KB RAM ($0000-$3FFF):**
```assembly
CODE_START  EQU $0000
STACK_TOP   EQU $3FFF   ; Top of 16KB
BOARD_BASE  EQU $2000   ; Adjust addresses
STATE_BASE  EQU $2080
; Warning: Limited space for transposition table
```

**8KB RAM (minimal):**
```assembly
CODE_START  EQU $0000
STACK_TOP   EQU $1FFF
BOARD_BASE  EQU $1000
STATE_BASE  EQU $1080
; Warning: Very tight, no room for enhancements
```

---

## Debugging Options

### Enable Debug Output

```assembly
#define DEBUG_NODES       ; Show nodes searched
#define DEBUG_MOVES       ; Show move details
#define DEBUG_EVAL        ; Show evaluation
```

**Warning**: Increases code size and slows execution.

**Use for**:
- Development
- Troubleshooting
- Understanding engine behavior

**Disable for**:
- Production
- Speed testing
- Tournament play

---

## Optimization Options

### Killer Moves (Recommended)

```assembly
#define USE_KILLER_MOVES    ; 64 bytes, good speedup
```
- ✓ Small memory cost
- ✓ Significant search speedup
- ✓ Recommended for all builds

### Piece-Square Tables

```assembly
#define USE_PST             ; 384 bytes, +200 ELO
```
- Requires PST data (future)
- Improves positional play
- Worth the memory cost

### Transposition Table

```assembly
#define USE_TRANSPOSITION_TABLE   ; 16-20KB, +1 ply depth
```
- ✓ Huge search speedup
- ✓ Effectively adds 1-2 ply depth
- ✗ Requires 16-20KB RAM
- Recommended for 32KB systems

### Opening Book

```assembly
#define USE_OPENING_BOOK          ; 4-6KB, instant openings
```
- Instant opening moves
- Saves search time early game
- Requires book data (future)

---

## Emulator-Specific Settings

### General Emulator Use

```assembly
; Usually no changes needed
; Use standard bit-bang + EF3
```

### Specific Emulators

**Emu1802:**
```assembly
#define USE_BITBANG
#define USE_EF3
; Standard settings work well
```

**Emma 02:**
```assembly
#define USE_BITBANG
#define USE_EF3
; May want to adjust timing for speed
```

**Fast Emulation Mode:**
```assembly
#define FAST_EMU_SERIAL
; Skips timing delays in bit-bang
; Only use with very fast emulators
```

---

## Configuration Examples

### Example 1: Standard System (Default)

```assembly
; Typical COSMAC Elf or similar
#define USE_BITBANG
#define USE_EF3
BAUD_RATE   EQU 9600
CPU_CLOCK   EQU 12
#define USE_KILLER_MOVES
```

**Build**: `./build.sh` (works as-is)

### Example 2: System with UART

```assembly
; System with CDP1854 UART
#define USE_UART
UART_DATA   EQU $01
UART_STATUS EQU $01
UART_RX_RDY EQU $01
UART_TX_RDY EQU $02
#define USE_KILLER_MOVES
```

### Example 3: Slow Clock Speed

```assembly
; Vintage system with 3.58 MHz clock
#define USE_BITBANG
#define USE_EF3
BAUD_RATE   EQU 4800    ; Lower baud for reliability
CPU_CLOCK   EQU 3
BIT_DELAY   EQU 156
HALF_DELAY  EQU 78
```

### Example 4: Maximum Features

```assembly
; 32KB system, all features enabled
#define USE_BITBANG
#define USE_EF3
BAUD_RATE   EQU 9600
CPU_CLOCK   EQU 12
#define USE_KILLER_MOVES
#define USE_PST
#define USE_TRANSPOSITION_TABLE
#define USE_OPENING_BOOK
```

### Example 5: Minimal System

```assembly
; Bare minimum configuration
#define USE_BITBANG
#define USE_EF3
BAUD_RATE   EQU 9600
CPU_CLOCK   EQU 12
; No optional features
DEFAULT_DEPTH   EQU 4   ; Faster for limited system
```

---

## Testing Your Configuration

### Step 1: Edit config.asm

Make your changes, save file.

### Step 2: Build

```bash
./build.sh
```

Watch for errors in assembly.

### Step 3: Test Serial I/O

Load chess-engine.hex, send `uci` command.

**Expected response**:
```
id name RCA-Chess-1806
id author Claude Code
uciok
```

If no response:
1. Check EF line setting
2. Try different EF line
3. Check baud rate
4. Verify Q output working

### Step 4: Test Move Generation

Send:
```
position startpos
go depth 1
```

Should return immediately with a move.

### Step 5: Test Search

Send:
```
position startpos
go depth 3
```

Should return in 1-5 seconds.

---

## Troubleshooting Configuration

### No Serial Response

**Try this sequence:**
1. Set `#define USE_EF1`, rebuild, test
2. Set `#define USE_EF2`, rebuild, test
3. Set `#define USE_EF3`, rebuild, test (should work)
4. Set `#define USE_EF4`, rebuild, test

One should work.

### Garbled Characters

**Try**:
1. Lower baud rate (4800 instead of 9600)
2. Double-check clock speed
3. Manually calibrate BIT_DELAY

### Search Too Slow

**Reduce depth**:
```assembly
DEFAULT_DEPTH   EQU 4   ; Instead of 6
```

### Code Too Large

**Disable features**:
```assembly
; Comment out:
; #define USE_TRANSPOSITION_TABLE
; #define USE_OPENING_BOOK
; #define DEBUG_NODES
```

---

## Configuration Checklist

Before building, verify:

- [ ] Serial I/O method chosen (UART or bit-bang)
- [ ] EF line correct (usually EF3)
- [ ] Baud rate appropriate (usually 9600)
- [ ] Clock speed matches hardware
- [ ] BIT_DELAY calculated correctly (if bit-bang)
- [ ] UART ports correct (if UART)
- [ ] Memory map fits your RAM
- [ ] Optional features chosen
- [ ] No conflicting defines

---

## Summary

**For 90% of systems, default configuration works!**

**Change only if needed:**
- Different EF line → edit USE_EF* define
- Different clock → recalculate BIT_DELAY
- Hardware UART → switch to USE_UART
- Special requirements → consult this guide

**After configuring**:
1. Edit config.asm
2. Run ./build.sh
3. Load and test
4. Adjust if needed

**Good luck!** 🎯
