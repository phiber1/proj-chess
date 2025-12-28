# RCA 1802 Chess Engine Design

## Target: Membership Card (32KB RAM, 1.75 MHz)

---

## 1. Board Representation

### 1.1 Square Indexing
```
     a   b   c   d   e   f   g   h
   +---+---+---+---+---+---+---+---+
 8 | 00| 01| 02| 03| 04| 05| 06| 07|  Black's back rank
   +---+---+---+---+---+---+---+---+
 7 | 08| 09| 10| 11| 12| 13| 14| 15|  Black's pawns
   +---+---+---+---+---+---+---+---+
 6 | 16| 17| 18| 19| 20| 21| 22| 23|
   +---+---+---+---+---+---+---+---+
 5 | 24| 25| 26| 27| 28| 29| 30| 31|
   +---+---+---+---+---+---+---+---+
 4 | 32| 33| 34| 35| 36| 37| 38| 39|
   +---+---+---+---+---+---+---+---+
 3 | 40| 41| 42| 43| 44| 45| 46| 47|
   +---+---+---+---+---+---+---+---+
 2 | 48| 49| 50| 51| 52| 53| 54| 55|  White's pawns
   +---+---+---+---+---+---+---+---+
 1 | 56| 57| 58| 59| 60| 61| 62| 63|  White's back rank
   +---+---+---+---+---+---+---+---+
```

- File = index AND 07H (0-7 = a-h)
- Rank = index SHR 3 (0-7 = 8-1, inverted from chess notation)
- Conversion: algebraic rank 1-8 → internal 7-0

### 1.2 Piece Encoding (1 byte per square)
```
Bit 7: Color (0 = White, 1 = Black)
Bits 0-3: Piece type

Values:
  00H = Empty
  01H = Pawn
  02H = Knight
  03H = Bishop
  04H = Rook
  05H = Queen
  06H = King

  81H = Black Pawn
  82H = Black Knight
  ... etc.

Color mask: 80H
Piece mask: 0FH
```

### 1.3 Memory Layout
```
BOARD:      DS 64      ; 64 bytes - the board
SIDE:       DS 1       ; 00H = White to move, 80H = Black to move
CASTLING:   DS 1       ; Bit flags: 01=WK, 02=WQ, 04=BK, 08=BQ
EP_SQUARE:  DS 1       ; En passant target square (FFH = none)
HALFMOVE:   DS 1       ; Halfmove clock (for 50-move rule)
KING_SQ:    DS 2       ; [0]=White king sq, [1]=Black king sq (for fast check detection)
```

---

## 2. Move Representation

### 2.1 Move Format (2 bytes)
```
Byte 0: From square (0-63)
Byte 1: To square (0-63) + flags in high bits

Flags in Byte 1:
  Bits 0-5: To square
  Bit 6: Capture flag (for move ordering)
  Bit 7: Special flag (promotion, castling, en passant)

For promotions, a third byte can specify piece type.
```

### 2.2 Move List
```
MOVE_LIST:  DS 128     ; Up to 64 moves × 2 bytes
MOVE_COUNT: DS 1       ; Number of moves in list
```

---

## 3. Negamax with Alpha-Beta

### 3.1 Algorithm (Pseudocode)
```
negamax(depth, alpha, beta):
    if depth == 0:
        return evaluate()

    best = -INFINITY
    generate_moves()

    for each move:
        make_move(move)
        score = -negamax(depth-1, -beta, -alpha)
        unmake_move(move)

        if score > best:
            best = score
        if score > alpha:
            alpha = score
        if alpha >= beta:
            break  ; Beta cutoff

    return best
```

### 3.2 Stack Frame for Recursion
Since 1802 has limited stack, we'll use an explicit search stack:

```
SEARCH_STACK:
  Per level (8 bytes):
    - alpha (2 bytes, signed 16-bit)
    - beta (2 bytes, signed 16-bit)
    - best_score (2 bytes)
    - move_index (1 byte)
    - saved state (1 byte: EP square or flags)

MAX_DEPTH = 4 (adjustable)
Stack size = 8 × MAX_DEPTH = 32 bytes
```

### 3.3 Iterative Implementation
To avoid deep recursion on the hardware stack, implement negamax iteratively with explicit state management.

---

## 4. Position Evaluation

### 4.1 Material Values
```
Pawn   = 100
Knight = 320
Bishop = 330
Rook   = 500
Queen  = 900
King   = 20000 (effectively infinite)
```

Using centipawns (100 = 1 pawn) gives good resolution in a 16-bit signed value.

### 4.2 Simple Evaluation
```
evaluate():
    score = 0
    for each square:
        piece = board[square]
        if piece != EMPTY:
            value = piece_value[piece & 0FH]
            if piece & 80H:  ; Black
                score -= value
            else:            ; White
                score += value

    ; Return from side-to-move perspective
    if SIDE == BLACK:
        return -score
    return score
```

### 4.3 Future Enhancements
- Piece-square tables (positional bonuses)
- Pawn structure (doubled, isolated, passed)
- King safety
- Mobility

---

## 5. Move Generation

### 5.1 Piece Movement Patterns

**Pawn**: Direction depends on color
- White: -8 (forward), -16 (double from rank 2)
- Black: +8 (forward), +16 (double from rank 7)
- Captures: ±7, ±9 (diagonal)

**Knight**: Offsets (8 possible)
- ±6, ±10, ±15, ±17
- Must check board boundaries!

**Bishop**: Sliding diagonal (±7, ±9)
**Rook**: Sliding orthogonal (±1, ±8)
**Queen**: Rook + Bishop combined
**King**: Single step in all 8 directions

### 5.2 Sliding Piece Generation
```
For each direction:
    target = square + direction
    while target is on board:
        if board[target] == EMPTY:
            add_move(square, target)
        else if enemy_piece(target):
            add_move(square, target)  ; Capture
            break
        else:
            break  ; Own piece blocks
        target += direction
```

### 5.3 Boundary Checking
Use file/rank extraction to detect wrapping:
- Moving left: if (sq & 7) == 0, can't go further left
- Moving right: if (sq & 7) == 7, can't go further right
- Moving up: if sq < 8, can't go further up
- Moving down: if sq > 55, can't go further down

---

## 6. Implementation Order

1. **Board setup and display** - Initialize starting position, print board
2. **Move input** - Parse and validate human moves
3. **Move generation** - Generate pseudo-legal moves
4. **Make/unmake move** - Apply and reverse moves
5. **Check detection** - Is the king attacked?
6. **Legal move filter** - Remove moves that leave king in check
7. **Evaluation** - Score positions (material only first)
8. **Negamax search** - The AI core
9. **Iterative deepening** - Search deeper with time control
10. **Enhancements** - Move ordering, quiescence, etc.

---

## 7. Memory Budget (Estimated)

```
Code:           ~4 KB
Board + State:  ~80 bytes
Move list:      ~130 bytes
Search stack:   ~32 bytes
SCRT + Serial:  ~300 bytes
Working RAM:    ~500 bytes
-----------------------
Total:          ~5 KB

Available:      32 KB (plenty of room)
```

---

## 8. Register Allocation (Tentative)

```
R2:  Stack pointer (SCRT)
R3:  Program counter
R4:  SCRT CALL
R5:  SCRT RET
R6:  SCRT linkage
R7:  SCRT temp (D save)
R8:  General pointer (strings, board access)
R9:  General temp / loop counter
R10: General temp
R11: Serial shift register
R12: Search depth / move index
R13: Serial saved register
R14: Serial baud rate counter
R15: Serial bit counter
```

---

## 9. Files Structure

```
chess.asm          - Main program, game loop
serial-io.asm      - Serial I/O module (done)
board.asm          - Board representation, display
movegen.asm        - Move generation
search.asm         - Negamax search
eval.asm           - Position evaluation
```
