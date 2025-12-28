# 0x88 Board Representation - Reference

## Memory Layout

```
$5000-$507F: Board array (128 bytes)
$5080-$5087: Game state (8 bytes)
```

## 0x88 Board Structure

### Valid Squares (0-63 mapped to 0x88 format)

```
Rank 7 (Black): 70 71 72 73 74 75 76 77   | 78-7F (off-board)
Rank 6:         60 61 62 63 64 65 66 67   | 68-6F (off-board)
Rank 5:         50 51 52 53 54 55 56 57   | 58-5F (off-board)
Rank 4:         40 41 42 43 44 45 46 47   | 48-4F (off-board)
Rank 3:         30 31 32 33 34 35 36 37   | 38-3F (off-board)
Rank 2:         20 21 22 23 24 25 26 27   | 28-2F (off-board)
Rank 1 (White): 10 11 12 13 14 15 16 17   | 18-1F (off-board)
Rank 0 (White): 00 01 02 03 04 05 06 07   | 08-0F (off-board)
                a  b  c  d  e  f  g  h
```

### Square Validation

**Fast off-board check:** `square & 0x88 == 0` means valid

Examples:
- `$24` (e2): `0010 0100 & 1000 1000 = 0000 0000` ✓ Valid
- `$28` (invalid): `0010 1000 & 1000 1000 = 0010 1000` ✗ Invalid
- `$7A` (invalid): `0111 1010 & 1000 1000 = 0000 1000` ✗ Invalid

## Piece Encoding

```
Bit:  7 6 5 4 | 3 | 2 1 0
      unused  |clr| type

Color bit (3): 0 = White, 1 = Black
Type bits (0-2): 0=empty, 1=pawn, 2=knight, 3=bishop, 4=rook, 5=queen, 6=king
```

### Piece Values

| Piece        | Value (hex) | Value (dec) | Binary    |
|--------------|-------------|-------------|-----------|
| Empty        | $00         | 0           | 0000 0000 |
| White Pawn   | $01         | 1           | 0000 0001 |
| White Knight | $02         | 2           | 0000 0010 |
| White Bishop | $03         | 3           | 0000 0011 |
| White Rook   | $04         | 4           | 0000 0100 |
| White Queen  | $05         | 5           | 0000 0101 |
| White King   | $06         | 6           | 0000 0110 |
| Black Pawn   | $09         | 9           | 0000 1001 |
| Black Knight | $0A         | 10          | 0000 1010 |
| Black Bishop | $0B         | 11          | 0000 1011 |
| Black Rook   | $0C         | 12          | 0000 1100 |
| Black Queen  | $0D         | 13          | 0000 1101 |
| Black King   | $0E         | 14          | 0000 1110 |

### Quick Operations

```assembly
; Get piece type (1-6):
LDN RA          ; Load piece
ANI $07         ; Mask bits 0-2

; Get piece color:
LDN RA          ; Load piece
ANI $08         ; Bit 3: 0=white, 8=black

; Check if enemy piece:
LDN RA          ; Load piece from square
ANI $08         ; Extract color
XOR             ; Compare with current side color
                ; Result: 0=same color, non-zero=different
```

## Game State Structure ($5080-$5087)

| Offset | Bytes | Field           | Description                    |
|--------|-------|-----------------|--------------------------------|
| +0     | 1     | Side to move    | $00=White, $08=Black          |
| +1     | 1     | Castling rights | Bit flags (see below)          |
| +2     | 1     | EP square       | En passant target ($FF=none)   |
| +3     | 1     | Halfmove clock  | Fifty-move rule counter        |
| +4     | 2     | Fullmove number | Move number (starts at 1)      |
| +6     | 1     | White king sq   | For fast check detection       |
| +7     | 1     | Black king sq   | For fast check detection       |

### Castling Rights Bits

```
Bit 0 ($01): White kingside  (O-O)
Bit 1 ($02): White queenside (O-O-O)
Bit 2 ($04): Black kingside  (O-O)
Bit 3 ($08): Black queenside (O-O-O)

Initial value: $0F (all rights available)
```

## Starting Position Layout

After `INIT_BOARD`, memory at $5000 contains:

```
$5000: 04 02 03 05 06 03 02 04   ; White back rank (Rook-King)
$5010: 01 01 01 01 01 01 01 01   ; White pawns
$5020: 00 00 00 00 00 00 00 00   ; Empty
$5030: 00 00 00 00 00 00 00 00   ; Empty
$5040: 00 00 00 00 00 00 00 00   ; Empty
$5050: 00 00 00 00 00 00 00 00   ; Empty
$5060: 09 09 09 09 09 09 09 09   ; Black pawns
$5070: 0C 0A 0B 0D 0E 0B 0A 0C   ; Black back rank
```

## Direction Offsets

For move generation:

```assembly
; Orthogonal (Rook, Queen)
DIR_N   EQU $10     ; +16 (one rank up)
DIR_S   EQU $F0     ; -16 (one rank down, as signed)
DIR_E   EQU $01     ; +1  (one file right)
DIR_W   EQU $FF     ; -1  (one file left, as signed)

; Diagonal (Bishop, Queen)
DIR_NE  EQU $11     ; +17
DIR_NW  EQU $0F     ; +15
DIR_SE  EQU $F1     ; -15 (as signed)
DIR_SW  EQU $EF     ; -17 (as signed)

; Knight moves
KN_NNE  EQU $21     ; +33
KN_NEE  EQU $12     ; +18
KN_SEE  EQU $F2     ; -14
KN_SSE  EQU $DF     ; -33
KN_SSW  EQU $DD     ; -35
KN_SWW  EQU $EE     ; -18
KN_NWW  EQU $0E     ; +14
KN_NNW  EQU $1F     ; +31
```

## Move Encoding (16-bit)

```
Bits 0-6:   From square (0x88 format, 7 bits)
Bits 7-13:  To square (0x88 format, 7 bits)
Bits 14-15: Special move flags

Special flags:
  00: Normal move
  01: Castling
  10: En passant capture
  11: Promotion (type in extra byte)
```

### Example Moves

```
e2-e4:
  From: $24 (e2)
  To:   $44 (e4)
  Encoding: $1124 (0001 0001 0010 0100)

Nf3 (g1-f3):
  From: $06 (g1)
  To:   $35 (f3)
  Encoding: $1AD5 (0001 1010 1101 0101)
```

## Usage Examples

### Get piece at e4
```assembly
LDI $44         ; e4 = $44
PLO RD
CALL GET_PIECE
; D now contains piece at e4
```

### Set white pawn on e2
```assembly
LDI $24         ; e2
PLO RD
LDI W_PAWN      ; $01
PLO RE
CALL SET_PIECE
```

### Check if square is attacked by sliding piece
```assembly
; Starting from target square, move in direction
; until hitting piece or edge

LDI $44         ; Start at e4
PLO RD

LOOP:
    GLO RD
    ADI DIR_N   ; Move north
    PLO RD

    ; Check if off board
    ANI $88
    BNZ OFF_BOARD

    ; Check square
    GLO RD
    CALL GET_PIECE
    ; ... check if enemy sliding piece

    BR LOOP
```

## Memory Efficiency

- **Board**: 128 bytes (50% utilization, but enables fast validation)
- **Game State**: 8 bytes
- **Total**: 136 bytes

Alternative mailbox (64 bytes) would save 64 bytes but require:
- Array bounds checking (4+ instructions per validation)
- Complex index arithmetic
- Slower move generation

**0x88 trades 64 bytes for ~20-30% speed improvement** - excellent tradeoff at 32KB.
