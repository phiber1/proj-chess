#!/usr/bin/env python3
"""
build_test_position.py — synthesize and validate UCI test positions

Given a UCI move sequence from start position, plays it through with python-chess
to verify legality, renders the resulting board, and reports special moves
available to the side to move (promotions, capture-promotions, checks, captures).

Useful for constructing deterministic test positions where the engine should
emit a specific move (e.g., capture-promotion, mate-in-1, etc.).

USAGE
    # With a move sequence on the command line (space-separated UCI):
    python3 build_test_position.py "e2e4 e7e5 g1f3 ..."

    # Read a move sequence from stdin:
    echo "e2e4 e7e5 ..." | python3 build_test_position.py -

    # Run with the built-in default (Ranken-Boden 1851, gxf8=Q+ position):
    python3 build_test_position.py

DEPENDENCIES
    python-chess. On Linux Mint / PEP-668 systems, install in a venv:
        python3 -m venv /tmp/chess_venv
        /tmp/chess_venv/bin/pip install chess
        /tmp/chess_venv/bin/python3 tools/build_test_position.py
"""

import sys

try:
    import chess
except ModuleNotFoundError:
    print("ERROR: python-chess not installed.", file=sys.stderr)
    print("Install via venv (PEP 668):", file=sys.stderr)
    print("  python3 -m venv /tmp/chess_venv", file=sys.stderr)
    print("  /tmp/chess_venv/bin/pip install chess", file=sys.stderr)
    print("  /tmp/chess_venv/bin/python3 tools/build_test_position.py", file=sys.stderr)
    sys.exit(1)


# Built-in default: Ranken vs Boden, London 1851. Position right before
# white plays gxf8=Q+ — confirms capture-promotion handling.
DEFAULT_MOVES = (
    "e2e4 e7e5 g1f3 b8c6 f1c4 f8c5 c2c3 g8f6 d2d4 e5d4 "
    "e4e5 d7d5 c4b5 f6e4 c3d4 c5b6 c1e3 e8g8 b1c3 f7f6 "
    "d1b3 e4c3 b5c6 b7c6 b3c3 d8e8 e1g1 c8g4 e5f6 g4f3 "
    "f6g7 e8g6"
).split()


def square_to_0x88(sq):
    """Convert python-chess square (0-63) to 0x88 hex format."""
    file = chess.square_file(sq)
    rank = chess.square_rank(sq)
    return (rank << 4) | file


def play_sequence(moves_uci):
    """Play a UCI move sequence; returns (board, error) where error is None if
    successful, or (i, move, reason) if a move was illegal."""
    board = chess.Board()
    for i, m in enumerate(moves_uci):
        try:
            mv = chess.Move.from_uci(m)
        except ValueError as e:
            return board, (i, m, f"malformed UCI: {e}")
        if mv not in board.legal_moves:
            return board, (i, m, "illegal in position")
        board.push(mv)
    return board, None


def categorize_legal_moves(board):
    """Group legal moves into categories of interest."""
    cap_promos, push_promos, captures, checks, normal = [], [], [], [], []
    for m in board.legal_moves:
        is_promo = m.promotion is not None
        is_capture = board.is_capture(m)
        # Test for check: push the move and see if opponent is in check
        board.push(m)
        gives_check = board.is_check()
        is_mate = board.is_checkmate()
        board.pop()

        info = (m, gives_check, is_mate)
        if is_promo and is_capture:
            cap_promos.append(info)
        elif is_promo:
            push_promos.append(info)
        elif is_capture:
            captures.append(info)
        elif gives_check:
            checks.append(info)
        else:
            normal.append(info)
    return cap_promos, push_promos, captures, checks, normal


def fmt_move(m, gives_check, is_mate):
    suffix = "#" if is_mate else ("+" if gives_check else "")
    return f"{m.uci()}{suffix}"


def main():
    if len(sys.argv) > 1:
        if sys.argv[1] == "-":
            moves_uci = sys.stdin.read().split()
        else:
            moves_uci = " ".join(sys.argv[1:]).split()
    else:
        moves_uci = DEFAULT_MOVES
        print(f"(no input — using built-in Ranken-Boden 1851 default)")
        print()

    board, error = play_sequence(moves_uci)
    if error:
        i, m, reason = error
        print(f"FAIL: half-move {i+1} ({m}): {reason}")
        print(board)
        print()
        print("Legal moves:", [str(x) for x in list(board.legal_moves)[:24]])
        return 1

    print(f"Played {len(moves_uci)} half-moves successfully.")
    print()
    print(board)
    print()
    print(f"Side to move: {'white' if board.turn else 'black'}")
    print(f"FEN:          {board.fen()}")
    print()

    cp, pp, caps, ck, _ = categorize_legal_moves(board)

    if cp:
        print(f"Capture-promotions ({len(cp)}):")
        for m, gc, ic in cp:
            captured = board.piece_at(m.to_square)
            print(f"  {fmt_move(m, gc, ic)}"
                  f"  capt {captured.symbol() if captured else '?'}"
                  f" on {chess.square_name(m.to_square)}"
                  f" → {chess.piece_symbol(m.promotion)}"
                  f"  (0x88 from=${square_to_0x88(m.from_square):02X}"
                  f" to=${square_to_0x88(m.to_square):02X})")
        print()

    if pp:
        print(f"Push-promotions ({len(pp)}):")
        for m, gc, ic in pp:
            print(f"  {fmt_move(m, gc, ic)}  → {chess.piece_symbol(m.promotion)}")
        print()

    if ck:
        print(f"Checks ({len(ck)}):")
        for m, gc, ic in ck[:10]:
            print(f"  {fmt_move(m, gc, ic)}")
        if len(ck) > 10:
            print(f"  ... ({len(ck) - 10} more)")
        print()

    if caps:
        print(f"Captures ({len(caps)}, non-promotion):")
        for m, gc, ic in caps[:10]:
            captured = board.piece_at(m.to_square)
            print(f"  {fmt_move(m, gc, ic)}  capt {captured.symbol() if captured else '?'}")
        if len(caps) > 10:
            print(f"  ... ({len(caps) - 10} more)")
        print()

    print("UCI position string for the engine:")
    print(f"  position startpos moves {' '.join(moves_uci)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
