#!/usr/bin/env python3
"""
Opening-book legality sweep for the RCA 1806 chess engine.

Parses the COMPILED book (opening-book.asm), walks it exactly as the engine's
BL_ENTRY_LOOP does (read ply byte; $FF = end; then 2*ply move bytes + 2 response
bytes), replays each entry from the start position with python-chess, and flags
any entry whose move sequence OR recommended response is illegal.

An illegal book move is an instant forfeit, so this must come back 100% clean.

Run:  /tmp/chess_venv/bin/python3 tools/check_book_legality.py [opening-book.asm]
"""
import re, sys
import chess

def x88_to_sq(b):
    """0x88 byte -> python-chess square (or None if off-board)."""
    file = b & 0x0F
    rank = b >> 4
    if file > 7 or rank > 7:
        return None
    return chess.square(file, rank)

def load_book_bytes(path):
    """All DB $XX bytes after the OPENING_BOOK: label, in order."""
    text = open(path).read()
    # start at OPENING_BOOK: label
    m = re.search(r'^OPENING_BOOK:', text, re.M)
    if m:
        text = text[m.end():]
    bytes_out = []
    for line in text.splitlines():
        code = line.split(';', 1)[0]          # strip comments
        if 'DB' not in code:
            continue
        for hx in re.findall(r'\$([0-9A-Fa-f]{2})', code):
            bytes_out.append(int(hx, 16))
    return bytes_out

def main():
    path = sys.argv[1] if len(sys.argv) > 1 else 'opening-book.asm'
    data = load_book_bytes(path)
    i = 0
    entries = 0
    bad = []
    while i < len(data):
        ply = data[i]
        if ply == 0xFF:           # end-of-book terminator
            break
        need = 1 + 2 * ply + 2
        if i + need > len(data):
            bad.append((entries, ply, "TRUNCATED entry (runs past end of data)", None))
            break
        moves = data[i+1 : i+1+2*ply]
        resp  = data[i+1+2*ply : i+3+2*ply]
        i += need
        entries += 1

        board = chess.Board()
        seq = []
        ok = True
        # replay the ply moves
        for k in range(ply):
            f, t = moves[2*k], moves[2*k+1]
            fs, ts = x88_to_sq(f), x88_to_sq(t)
            if fs is None or ts is None:
                bad.append((entries, ply, f"move {k+1}: off-board square ${f:02X}->${t:02X}", list(seq)))
                ok = False; break
            try:
                mv = board.find_move(fs, ts)
            except Exception:
                bad.append((entries, ply,
                            f"move {k+1} ILLEGAL: {chess.square_name(fs)}{chess.square_name(ts)} "
                            f"(turn={'w' if board.turn else 'b'})", list(seq)))
                ok = False; break
            seq.append(board.san(mv))
            board.push(mv)
        if not ok:
            continue
        # check the recommended response
        rf, rt = resp
        fs, ts = x88_to_sq(rf), x88_to_sq(rt)
        if fs is None or ts is None:
            bad.append((entries, ply, f"RESPONSE off-board ${rf:02X}->${rt:02X}", list(seq)))
            continue
        try:
            mv = board.find_move(fs, ts)
        except Exception:
            occ = board.piece_at(ts)
            why = f"dest {chess.square_name(ts)} occupied by own {occ.symbol()}" if occ and occ.color == board.turn else "not a legal move"
            bad.append((entries, ply,
                        f"RESPONSE ILLEGAL: {chess.square_name(fs)}{chess.square_name(ts)} "
                        f"({why}, turn={'w' if board.turn else 'b'})", list(seq)))

    print(f"Parsed {entries} book entries from {path}")
    if not bad:
        print("RESULT: CLEAN — every move and response is legal.")
        return 0
    print(f"RESULT: {len(bad)} ILLEGAL entr{'y' if len(bad)==1 else 'ies'} found:\n")
    for n, ply, why, seq in bad:
        line = ' '.join(seq) if seq else '(start)'
        print(f"  entry #{n} (ply {ply}): {why}")
        print(f"      line: {line}")
    return 1

if __name__ == '__main__':
    sys.exit(main())
