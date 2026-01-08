#!/usr/bin/env python3
"""
PGN to Opening Book Converter for RCA 1802 Chess Engine

Parses PGN files and generates compact opening book in assembly format.
"""

import re
import sys
from collections import defaultdict

# Square name to 0x88 index
def square_to_0x88(sq_name):
    """Convert 'e4' to 0x88 index (0x34)"""
    file = ord(sq_name[0]) - ord('a')  # 0-7
    rank = int(sq_name[1]) - 1          # 0-7
    return rank * 16 + file

def parse_moves(movetext):
    """Extract moves from PGN movetext, stripping annotations."""
    movetext = re.sub(r'\{[^}]*\}', '', movetext)
    movetext = re.sub(r'\([^)]*\)', '', movetext)
    movetext = re.sub(r'\d+\.+', '', movetext)
    movetext = re.sub(r'(1-0|0-1|1/2-1/2|\*)', '', movetext)
    movetext = re.sub(r'\$\d+', '', movetext)
    movetext = movetext.replace('+', '').replace('#', '')
    moves = movetext.split()
    return [m.strip() for m in moves if m.strip()]

def parse_pgn(filename):
    """Parse PGN file and yield lists of moves for each game."""
    with open(filename, 'r', encoding='latin-1') as f:
        content = f.read()

    games = re.split(r'\n(?=\[Event )', content)

    for game in games:
        if not game.strip():
            continue
        match = re.search(r'\]\s*\n\s*\n?(1\..*)', game, re.DOTALL)
        if match:
            movetext = match.group(1)
            moves = parse_moves(movetext)
            if moves:
                yield moves

def move_to_squares(move, board_state):
    """
    Convert algebraic move to (from_sq, to_sq) using board state.
    Returns None for moves we can't handle.
    """
    # Handle castling
    if move == 'O-O':
        if board_state['white_to_move']:
            return (0x04, 0x06)  # e1-g1
        else:
            return (0x74, 0x76)  # e8-g8
    if move == 'O-O-O':
        if board_state['white_to_move']:
            return (0x04, 0x02)  # e1-c1
        else:
            return (0x74, 0x72)  # e8-c8

    # Pawn moves
    if re.match(r'^[a-h][1-8]$', move):
        to_file = ord(move[0]) - ord('a')
        to_rank = int(move[1]) - 1
        to_sq = to_rank * 16 + to_file

        if board_state['white_to_move']:
            # Try one square back
            from_sq = (to_rank - 1) * 16 + to_file
            if board_state['board'].get(from_sq) == 'P':
                return (from_sq, to_sq)
            # Try two squares back (from rank 2)
            from_sq = (to_rank - 2) * 16 + to_file
            if to_rank == 3 and board_state['board'].get(from_sq) == 'P':
                return (from_sq, to_sq)
        else:
            from_sq = (to_rank + 1) * 16 + to_file
            if board_state['board'].get(from_sq) == 'p':
                return (from_sq, to_sq)
            from_sq = (to_rank + 2) * 16 + to_file
            if to_rank == 4 and board_state['board'].get(from_sq) == 'p':
                return (from_sq, to_sq)
        return None

    # Pawn capture
    if re.match(r'^[a-h]x[a-h][1-8]', move):
        from_file = ord(move[0]) - ord('a')
        to_file = ord(move[2]) - ord('a')
        to_rank = int(move[3]) - 1
        to_sq = to_rank * 16 + to_file

        if board_state['white_to_move']:
            from_sq = (to_rank - 1) * 16 + from_file
        else:
            from_sq = (to_rank + 1) * 16 + from_file
        return (from_sq, to_sq)

    # Piece moves (N, B, R, Q, K)
    piece_match = re.match(r'^([NBRQK])([a-h])?([1-8])?(x)?([a-h][1-8])', move)
    if piece_match:
        piece = piece_match.group(1)
        disambig_file = piece_match.group(2)
        disambig_rank = piece_match.group(3)
        to_sq_name = piece_match.group(5)
        to_sq = square_to_0x88(to_sq_name)

        # Find the piece on the board
        search_piece = piece if board_state['white_to_move'] else piece.lower()
        candidates = []

        for sq, p in board_state['board'].items():
            if p == search_piece:
                # Check disambiguation
                sq_file = sq % 16
                sq_rank = sq // 16
                if disambig_file and sq_file != ord(disambig_file) - ord('a'):
                    continue
                if disambig_rank and sq_rank != int(disambig_rank) - 1:
                    continue
                # Basic move validation
                if can_piece_reach(piece, sq, to_sq, board_state['board']):
                    candidates.append(sq)

        if len(candidates) == 1:
            return (candidates[0], to_sq)
        elif len(candidates) > 1:
            # Multiple candidates that can reach - ambiguous, take first
            return (candidates[0], to_sq)

    return None

def can_piece_reach(piece, from_sq, to_sq, board):
    """Check if piece can reach target square (basic validation)."""
    from_file = from_sq % 16
    from_rank = from_sq // 16
    to_file = to_sq % 16
    to_rank = to_sq // 16

    df = to_file - from_file
    dr = to_rank - from_rank

    if piece == 'N':
        # Knight: L-shape
        return (abs(df), abs(dr)) in [(1, 2), (2, 1)]

    elif piece == 'B':
        # Bishop: diagonal
        if abs(df) != abs(dr) or df == 0:
            return False
        # Check path is clear
        step_f = 1 if df > 0 else -1
        step_r = 1 if dr > 0 else -1
        f, r = from_file + step_f, from_rank + step_r
        while (f, r) != (to_file, to_rank):
            sq = r * 16 + f
            if sq in board:
                return False
            f += step_f
            r += step_r
        return True

    elif piece == 'R':
        # Rook: straight lines
        if df != 0 and dr != 0:
            return False
        # Check path is clear
        if df != 0:
            step = 1 if df > 0 else -1
            for f in range(from_file + step, to_file, step):
                if from_rank * 16 + f in board:
                    return False
        else:
            step = 1 if dr > 0 else -1
            for r in range(from_rank + step, to_rank, step):
                if r * 16 + from_file in board:
                    return False
        return True

    elif piece == 'Q':
        # Queen: diagonal or straight
        if df == 0 or dr == 0:
            return can_piece_reach('R', from_sq, to_sq, board)
        elif abs(df) == abs(dr):
            return can_piece_reach('B', from_sq, to_sq, board)
        return False

    elif piece == 'K':
        # King: one square any direction
        return abs(df) <= 1 and abs(dr) <= 1 and (df != 0 or dr != 0)

    return False

def init_board():
    """Initialize standard starting position."""
    board = {}
    # White pieces
    board[0x00] = 'R'; board[0x01] = 'N'; board[0x02] = 'B'; board[0x03] = 'Q'
    board[0x04] = 'K'; board[0x05] = 'B'; board[0x06] = 'N'; board[0x07] = 'R'
    for f in range(8):
        board[0x10 + f] = 'P'
    # Black pieces
    board[0x70] = 'r'; board[0x71] = 'n'; board[0x72] = 'b'; board[0x73] = 'q'
    board[0x74] = 'k'; board[0x75] = 'b'; board[0x76] = 'n'; board[0x77] = 'r'
    for f in range(8):
        board[0x60 + f] = 'p'

    return {'board': board, 'white_to_move': True}

def apply_move(state, from_sq, to_sq):
    """Apply move to board state."""
    piece = state['board'].get(from_sq)
    if piece:
        del state['board'][from_sq]
        state['board'][to_sq] = piece

        # Handle castling rook
        if piece in ['K', 'k']:
            if to_sq - from_sq == 2:  # Kingside
                rook_from = from_sq + 3
                rook_to = from_sq + 1
                rook = state['board'].get(rook_from)
                if rook:
                    del state['board'][rook_from]
                    state['board'][rook_to] = rook
            elif from_sq - to_sq == 2:  # Queenside
                rook_from = from_sq - 4
                rook_to = from_sq - 1
                rook = state['board'].get(rook_from)
                if rook:
                    del state['board'][rook_from]
                    state['board'][rook_to] = rook

    state['white_to_move'] = not state['white_to_move']

def build_book_tree(pgn_file, max_ply=10):
    """Build a tree of positions with converted square notation."""
    tree = defaultdict(lambda: defaultdict(int))

    game_count = 0
    error_count = 0

    for moves in parse_pgn(pgn_file):
        game_count += 1
        state = init_board()
        move_sequence = []

        for i, alg_move in enumerate(moves[:max_ply + 1]):
            squares = move_to_squares(alg_move, state)
            if squares is None:
                error_count += 1
                break

            from_sq, to_sq = squares

            if i < max_ply:
                # Record position -> next move
                position = tuple(move_sequence)
                tree[position][(from_sq, to_sq)] += 1

            move_sequence.append((from_sq, to_sq))
            apply_move(state, from_sq, to_sq)

    print(f"Parsed {game_count} games ({error_count} parse errors)", file=sys.stderr)
    return tree

def generate_asm_book(tree, min_frequency=10, output_file=None):
    """Generate assembly code for the opening book."""

    entries = []

    for position, responses in tree.items():
        best_response = max(responses.items(), key=lambda x: x[1])
        move, count = best_response

        if count >= min_frequency:
            entries.append({
                'position': list(position),
                'response': move,
                'count': count,
                'ply': len(position)
            })

    # Sort by ply, then by position
    entries.sort(key=lambda e: (e['ply'], e['position']))

    lines = []
    lines.append("; ==============================================================================")
    lines.append("; Opening Book Data - Auto-generated from PGN")
    lines.append(f"; Entries: {len(entries)}, Min frequency: {min_frequency}")
    lines.append("; ==============================================================================")
    lines.append("")
    lines.append("; Book format:")
    lines.append(";   Each entry: [ply] [move1_from] [move1_to] ... [response_from] [response_to] [$FF terminator]")
    lines.append(";   Entries sorted by ply for efficient early-exit")
    lines.append("")
    lines.append("OPENING_BOOK:")

    total_bytes = 0

    for e in entries:
        ply = e['ply']
        pos = e['position']
        resp = e['response']

        # Comment showing the line
        pos_str = ' '.join([f"{m[0]:02X}-{m[1]:02X}" for m in pos])
        lines.append(f"    ; Ply {ply}: {pos_str} -> {resp[0]:02X}-{resp[1]:02X} ({e['count']}x)")

        # Data bytes
        data = [f"${ply:02X}"]  # Ply count
        for from_sq, to_sq in pos:
            data.append(f"${from_sq:02X}")
            data.append(f"${to_sq:02X}")
        data.append(f"${resp[0]:02X}")  # Response from
        data.append(f"${resp[1]:02X}")  # Response to

        lines.append(f"    DB {', '.join(data)}")
        total_bytes += len(data)

    lines.append("")
    lines.append("; End of book marker")
    lines.append("    DB $FF")
    total_bytes += 1

    lines.append("")
    lines.append(f"; Total size: {total_bytes} bytes")

    output = '\n'.join(lines)

    if output_file:
        with open(output_file, 'w') as f:
            f.write(output)
        print(f"Wrote {output_file} ({total_bytes} bytes)", file=sys.stderr)
    else:
        print(output)

    return entries, total_bytes

def main():
    if len(sys.argv) < 2:
        print("Usage: pgn_to_book.py <pgn_file> [max_ply] [min_frequency] [output.asm]")
        sys.exit(1)

    pgn_file = sys.argv[1]
    max_ply = int(sys.argv[2]) if len(sys.argv) > 2 else 10
    min_freq = int(sys.argv[3]) if len(sys.argv) > 3 else 10
    output_file = sys.argv[4] if len(sys.argv) > 4 else None

    print(f"Processing {pgn_file} (max_ply={max_ply}, min_freq={min_freq})", file=sys.stderr)

    tree = build_book_tree(pgn_file, max_ply)
    entries, size = generate_asm_book(tree, min_freq, output_file)

    print(f"\nBook Statistics:", file=sys.stderr)
    print(f"  Total entries: {len(entries)}", file=sys.stderr)
    print(f"  Total size: {size} bytes", file=sys.stderr)

if __name__ == '__main__':
    main()
