# RCA 1802 Serial I/O and SCRT Implementation Notes

## Session: December 5, 2025
## Hardware: Membership Card, 1.75 MHz clock, 9600 baud

This document captures critical lessons learned while implementing serial I/O
for the chess engine on the Membership Card.

---

## 1. Q Pin Serial Polarity

**This is counterintuitive and caused much confusion:**

| Instruction | Q State | Serial Meaning | Used For |
|-------------|---------|----------------|----------|
| SEQ | Q OFF (low) | Space / 0 | Start bit, data 0 |
| REQ | Q ON (high) | Mark / 1 | Stop bit, idle, data 1 |

**Idle state must be REQ (Q ON = mark = high)**

---

## 2. Chuck's Working Serial Output Routine

The proven working routine is in `chuck-test.asm` and `chuck-test-string.asm`.

Key characteristics:
- Interleaved timing: output bit FIRST, then process next bit during the delay
- Separate code paths for 0-bits (QLO/QLO1) and 1-bits (QHI/QHI1)
- Uses LBNF/LBDF (3-cycle long branches) for path selection after SHRC
- R14.0 delay counter = 2 on entry, decremented to 1 for 9600 baud
- R11.0 = character to transmit (shift register)
- R15.0 = bit counter (8 bits)
- Outputs 2 stop bits

**CRITICAL: Do NOT change short branches to long branches in this routine!**
Every instruction cycle is precisely timed. Adding cycles breaks the baud rate.

---

## 3. R14.0 Baud Rate Initialization

For 9600 baud, R14.0 must equal 2 when entering B96OUT.

**Best practice:** Hardcode `LDI 02H` / `PLO 14` at the start of SERIAL_WRITE_CHAR
so external code doesn't need to manage it:

```asm
SERIAL_WRITE_CHAR:
    PLO 11              ; Save character in R11.0

B96OUT:
    LDI 02H
    PLO 14              ; R14.0 = 2 for 9600 baud (hardcoded)

    LDI 08H
    PLO 15              ; R15.0 = 8 bits
    ; ... rest of routine
```

---

## 4. SCRT Implementation (Mark Abene's Version)

The working SCRT implementation from `abene_idiot_scrt/abene_idiot.asm`:

```asm
; INITIALIZE SCRT - call with target address in R6
INITCALL:
    LDI HIGH(RET)
    PHI 5
    LDI LOW(RET)
    PLO 5
    LDI HIGH(CALL)
    PHI 4
    LDI LOW(CALL)
    PLO 4
    SEP 5               ; Transfer to user code via R6

; SCRT CALL
    SEP 3               ; <-- This instruction is at CALL-1
CALL:
    PLO 7               ; SAVE D (use R7, NOT R14!)
    GHI 6               ; SAVE LAST R6 TO STACK
    SEX 2
    STXD
    GLO 6
    STXD
    GHI 3               ; COPY R3 TO R6
    PHI 6
    GLO 3
    PLO 6
    LDA 6               ; GET SUBROUTINE ADDRESS
    PHI 3               ; AND PUT INTO R3
    LDA 6
    PLO 3
    GLO 7               ; RECOVER D
    BR CALL-1           ; TRANSFER CONTROL TO SUBROUTINE

; SCRT RET
    SEP 3               ; <-- This instruction is at RET-1
RET:
    PLO 7               ; SAVE D
    GHI 6               ; COPY R6 TO R3
    PHI 3
    GLO 6
    PLO 3
    SEX 2
    IRX                 ; POINT TO OLD R6
    LDXA
    PLO 6
    LDX
    PHI 6
    GLO 7
    BR RET-1            ; AND PERFORM RETURN TO CALLER
```

**Key points:**
- The `SEP 3` instruction BEFORE each label is critical - routines branch back to it
- `BR CALL-1` and `BR RET-1` jump to those `SEP 3` instructions
- **DO NOT use R14 for temp storage** - it conflicts with serial baud rate counter
- Use R7 (or another unused register) for saving D

---

## 5. Register Allocation

| Register | Usage |
|----------|-------|
| R2 | Stack pointer (X=2) |
| R3 | Program counter |
| R4 | SCRT CALL routine pointer |
| R5 | SCRT RET routine pointer |
| R6 | SCRT linkage register |
| R7 | SCRT temp (save/restore D) |
| R11 | Serial: character shift register |
| R13 | Serial: saved/restored by routine |
| R14.0 | Serial: baud rate delay counter (must be 2 for 9600) |
| R15 | Serial: bit counter |

---

## 6. Code Organization

**Entry point issue:** The CPU starts executing at address 0x0000. If serial
routines are placed there, you need `LBR START` at address 0 to jump past them.

**Branch range issue:** The serial routine uses short branches (2-byte) that can
only reach ±127 bytes. The routine must be placed early in the code so all
branch targets are within range.

**Recommended structure:**
```asm
    ORG $0000

    ; Entry - jump to main
    LDI HIGH(MAIN)
    PHI 6
    LDI LOW(MAIN)
    PLO 6
    LBR INITCALL

    ; Serial routines here (early, for branch range)
SERIAL_WRITE_CHAR:
    ; ...

    ; SCRT routines
INITCALL:
    ; ...
CALL:
    ; ...
RET:
    ; ...

    ; Main program
MAIN:
    ; Set up stack
    LDI $7F
    PHI 2
    LDI $FF
    PLO 2
    SEX 2

    ; Set Q to idle (mark)
    REQ

    ; Now can use SEP 4 / DW addr to call routines
```

---

## 7. EF3 Input

For serial receive, EF3 is inverted on the Membership Card:
- Idle = EF3 high (BN3 loops while idle)
- Start bit = EF3 low (B3 loops while waiting for start)
- Data 0 = EF3 high
- Data 1 = EF3 low

---

## 8. Working Test Files

- `test-q-blink.asm` - Minimal Q blink test (verified working)
- `test-serial-noscrt.asm` - Serial output without SCRT (verified working)
- `test-serial-abene.asm` - Serial output with SCRT (verified working)
- `chuck-test.asm` - Original working single char test
- `chuck-test-string.asm` - Original working string output test

---

## 9. Common Mistakes to Avoid

1. **Using SEQ for idle** - Wrong! Use REQ for idle (mark state)
2. **Using R14 in SCRT** - Conflicts with serial baud rate counter
3. **Changing short branches to long** - Breaks serial timing
4. **Forgetting LBR START at address 0** - CPU executes serial code on startup
5. **Not setting R14.0 = 2** - Baud rate will be wrong
6. **Wrong SCRT pattern** - Must have `SEP 3` before CALL/RET labels

---

## 10. Files Reference

- `serial-io-9600.asm` - Serial I/O module for chess engine
- `abene_idiot_scrt/abene_idiot.asm` - Reference SCRT implementation
- `abene_idiot_scrt/abene_idiot_doc.txt` - SCRT documentation
- `abene_idiot_scrt/hello.asm` - SCRT usage example
