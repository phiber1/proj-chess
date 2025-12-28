# Emma02 Emulator Testing Guide

## Quick Start for VELF

### 1. Configure for Emma02
Edit `config.asm` and enable Emma02 mode:

```assembly
#define CFG_EMMA02          /* Enable Emma02 emulator mode */
#define CFG_FAST_EMU_SERIAL /* Skip timing delays (optional but recommended) */
```

### 2. Check EF Line Configuration
VELF typically uses **EF4** for serial input. Edit `config.asm`:

```assembly
/* #define CFG_USE_EF1 */
/* #define CFG_USE_EF2 */
/* #define CFG_USE_EF3 */
#define CFG_USE_EF4    /* VELF uses EF4 for serial */
```

### 3. Build
```bash
./build.sh
```

### 4. Load in Emma02

#### Option A: Load HEX file directly
1. Start Emma02
2. Select "VELF" system
3. File → Load Binary → chess-engine.hex
4. Set start address: $0000
5. Run

#### Option B: Create tape image
If VELF expects tape format:
```bash
# Convert HEX to binary (you may need srec_cat or similar tool)
srec_cat chess-engine.hex -intel -o chess-engine.bin -binary
```

### 5. Expected Output
You should see on the serial console:
```
RCA 1802/1806 Chess Engine
Initializing...
```

If you see this, the engine is working! Type `uci` and press Enter to get:
```
id name RCA-Chess-1806
id author Claude Code
uciok
```

## Troubleshooting

### No output at all
1. **Check system selection**: Make sure Emma02 is configured for VELF
2. **Verify start address**: Should be $0000
3. **Check serial console**: Make sure serial/terminal window is open
4. **Try different EF line**: VELF variants may use EF3 or EF4

### Garbage output
1. **Baud rate mismatch**: Emma02 may not need actual timing
   - Enable `CFG_FAST_EMU_SERIAL` in config.asm
2. **Wrong bit-bang delays**: Emulator timing is different from real hardware

### Program hangs
1. **Stack issue**: R2 not initialized (fixed in new main.asm)
2. **Infinite loop in serial read**: Serial input not working
3. **Missing DIS instruction**: Interrupts not disabled

## Emma02-Specific Notes

### Serial I/O in Emma02
Emma02 emulates 1802 serial I/O differently than real hardware:
- Timing delays may not be necessary
- Some systems use memory-mapped I/O instead of Q/EF
- Check Emma02 documentation for your specific system configuration

### Alternative: Memory-Mapped I/O
If bit-bang serial doesn't work, VELF might use memory-mapped console:
- Console input: Usually at a specific port address
- Console output: Usually writes to a port or memory location

Check your VELF configuration in Emma02 settings.

### Testing Without Serial
For initial testing, you can verify the code runs by:
1. Set a breakpoint at address $0000
2. Single-step through START
3. Verify INIT_BOARD is called
4. Check memory at $5000 for board initialization

## Quick Test Program

If you just want to test if the emulator runs 1802 code at all, try this minimal test:

```assembly
    ORG $0000
START:
    SEX 2          ; Set X to R2
    LDI $7F
    PHI 2
    LDI $FF
    PLO 2          ; R2 = stack

    LDI 'H'        ; Load 'H'
LOOP:
    SEQ            ; Set Q (might toggle LED)
    BR LOOP        ; Infinite loop
```

If this runs without crashing, your emulator setup is correct and the issue is with serial I/O configuration.
