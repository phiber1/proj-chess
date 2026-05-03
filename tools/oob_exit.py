#!/usr/bin/env python3
"""oob_exit.py — pinpoint the first OOB exit in an in-progress (or completed)
elph-debug.log, and emit the position prefix + engine pick + 0x88 hex
encoding ready for opening-book.asm.

USAGE:
    python3 tools/oob_exit.py [path/to/elph-debug.log]

If no path given, defaults to /home/phiber/proj-chess/elph-debug.log.

A move is "OOB" (out of book) if the engine emitted any `info depth` line
between the position TX and the bestmove RX — i.e., it actually searched
rather than instant-playing from the book.
"""
import re, sys, os

LOG = sys.argv[1] if len(sys.argv) > 1 else "/home/phiber/proj-chess/elph-debug.log"

def uci_to_0x88(sq):
    file = ord(sq[0]) - ord('a')
    rank = int(sq[1]) - 1
    return (rank << 4) | file

def encode_move(uci):
    return uci_to_0x88(uci[:2]), uci_to_0x88(uci[2:4])

def main():
    if not os.path.exists(LOG):
        print(f"ERROR: {LOG} not found", file=sys.stderr)
        return 1

    pos_re = re.compile(r"TX: 'position startpos(?: moves (.+?))?'")
    bm_re  = re.compile(r"RX: 'bestmove (\S+)'")
    info_re = re.compile(r"RX: 'info depth")

    last_position = ""
    pending_search = False
    first_oob_position = None
    first_oob_move = None
    first_oob_search_seconds = None
    last_info_d = 0

    with open(LOG, errors='ignore') as f:
        for line in f:
            mp = pos_re.search(line)
            if mp:
                last_position = mp.group(1) or ""
                pending_search = False
                last_info_d = 0
                continue
            mi = info_re.search(line)
            if mi:
                pending_search = True
                m_d = re.search(r"info depth (\d+)", line)
                if m_d:
                    last_info_d = max(last_info_d, int(m_d.group(1)))
                continue
            mb = bm_re.search(line)
            if mb and pending_search and first_oob_position is None:
                first_oob_position = last_position
                first_oob_move = mb.group(1)
                first_oob_search_d = last_info_d
                # Get timestamp from log line for context
                m_ts = re.match(r"^\[(\d+):(\d+\.\d+)\]", line)
                if m_ts:
                    first_oob_search_seconds = int(m_ts.group(1)) * 60 + float(m_ts.group(2))

    if first_oob_position is None:
        print("No OOB exit yet — match is still in book or hasn't searched.")
        return 0

    moves = first_oob_position.split() if first_oob_position else []
    ply = len(moves)

    print(f"FIRST OOB EXIT")
    print(f"  Position prefix (ply {ply}): {first_oob_position}")
    print(f"  Engine searched and picked: {first_oob_move}")
    print(f"  Max depth reached:          d={first_oob_search_d}")
    if first_oob_search_seconds:
        print(f"  At log timestamp:           {first_oob_search_seconds:.1f}s")
    print()
    print("BOOK ENTRY (ready to paste into opening-book.asm):")
    print()
    db_bytes = [f"${ply:02X}"]
    for mv in moves:
        f, t = encode_move(mv)
        db_bytes.append(f"${f:02X}, ${t:02X}")
    f, t = encode_move(first_oob_move)
    db_bytes.append(f"${f:02X}, ${t:02X}")
    db_line = ", ".join(db_bytes)
    pos_uci = " ".join(moves)
    print(f"    ; Ply {ply}: {pos_uci} -> {first_oob_move}")
    print(f"    DB {db_line}")
    print()
    entry_size = 1 + (ply + 1) * 2
    print(f"  Entry size: {entry_size} bytes")

main()
