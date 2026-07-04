#!/usr/bin/env python3
"""
ELPH Match Replay Script

Drives the engine through a full match's move sequence with TT state
preserved across moves (single ucinewgame at start). Used to reproduce
state-corruption bugs that only manifest after many sequential searches.

Usage:
    python3 replay-match.py <source_log> [depth] [last_move]
    python3 replay-match.py <script.uci>

  last_move: final CURRENT move number to search (1-based), inclusive.
             Move N searches the position after 2*(N-1) plies. So
             "last_move 8" stops after the engine's 8th search.

Log mode: reads <source_log> (e.g., elph-debug-illegal-g8h7.log), extracts
the full move sequence from the longest "position startpos moves ..." line,
and replays it move-by-move at a UNIFORM depth.

UCI-script mode (a path ending in .uci): plays the file's command sequence
VERBATIM — each 'position' line as written, each 'go depth N' with ITS OWN
depth (so depth-matched replays like tools/replay_crash_v3_0703_depthmatched.uci
reproduce the original match's per-search depth schedule), positions with no
'go' (book moves) sent state-only. '#' lines are comments. A bestmove timeout
is treated as the CRASH/HANG signal: the script stops immediately and sends
NOTHING further, leaving the engine untouched for ROM-monitor forensics
(first dump: NODES_SEARCHED at $6412-$6415 = the dying node).
"""
import sys
import os
import time
import serial
import re

SERIAL_PORT = '/dev/ttyUSB0'
BAUD_RATE = 19200
LOG_FILE = '/home/phiber/proj-chess/replay-debug.log'

# Timing borrowed from elph-bridge.py
CHAR_DELAY = 0.003
LINE_DELAY = 0.030
LONG_CMD_BASE_DELAY = 0.050
LONG_CMD_PER_MOVE = 0.025
LONG_CMD_THRESHOLD = 80
BESTMOVE_TIMEOUT = 200  # per-move budget (180s + overhead)


def extract_move_sequence(log_path):
    """Find the longest 'position startpos moves ...' command in the log
    and return its move list as a Python list of UCI move strings."""
    longest = ""
    with open(log_path) as f:
        for line in f:
            m = re.search(r"TX: 'position startpos moves (.+?)'", line)
            if m and len(m.group(1)) > len(longest):
                longest = m.group(1)
    return longest.split()


def send_line(ser, line, log):
    """Send a UCI line to the engine with elph-bridge-style timing."""
    log.write(f"TX: {line}\n")
    log.flush()
    line_bytes = (line + '\n').encode('latin-1')
    for b in line_bytes:
        ser.write(bytes([b]))
        if b in (0x0D, 0x0A):
            time.sleep(LINE_DELAY)
        else:
            time.sleep(CHAR_DELAY)
    ser.flush()
    if len(line) > LONG_CMD_THRESHOLD:
        move_count = 0
        ll = line.lower()
        if ' moves ' in ll:
            move_count = len(ll.split(' moves ', 1)[1].split())
        delay = LONG_CMD_BASE_DELAY + (move_count * LONG_CMD_PER_MOVE)
        time.sleep(delay)


def read_until_bestmove(ser, log, timeout):
    """Read lines from serial until 'bestmove ...' is seen.
    Returns (bestmove_line, info_lines) or (None, info_lines) on timeout.
    Each RX line is logged with a timestamp relative to search start (the
    moment this function is entered), so per-depth completion times and the
    total per-search time are visible in the log."""
    t0 = time.time()
    deadline = t0 + timeout
    buf = bytearray()
    info_lines = []
    while time.time() < deadline:
        if ser.in_waiting:
            buf.extend(ser.read(ser.in_waiting))
            while b'\n' in buf or b'\r' in buf:
                idx_n = buf.find(b'\n')
                idx_r = buf.find(b'\r')
                if idx_n == -1:
                    idx = idx_r
                elif idx_r == -1:
                    idx = idx_n
                else:
                    idx = min(idx_n, idx_r)
                line = bytes(buf[:idx]).decode('latin-1', errors='replace').strip()
                end = idx + 1
                if end < len(buf) and buf[end:end+1] in (b'\r', b'\n'):
                    end += 1
                del buf[:end]
                if not line:
                    continue
                dt = time.time() - t0
                log.write(f"[t+{dt:6.2f}s] RX: {line}\n")
                log.flush()
                if line.startswith('info '):
                    info_lines.append((dt, line))
                if line.startswith('bestmove'):
                    total = time.time() - t0
                    log.write(f"  (search time: {total:.2f}s)\n")
                    log.flush()
                    return line, info_lines
        time.sleep(0.05)
    log.write(f"  (NO bestmove after {timeout:.0f}s — search timed out)\n")
    log.flush()
    return None, info_lines


def read_until_token(ser, log, token, timeout):
    """Read lines until one starts with `token`. Returns the line or None."""
    deadline = time.time() + timeout
    buf = bytearray()
    while time.time() < deadline:
        if ser.in_waiting:
            buf.extend(ser.read(ser.in_waiting))
            while b'\n' in buf or b'\r' in buf:
                idx = min(i for i in (buf.find(b'\n'), buf.find(b'\r')) if i != -1)
                line = bytes(buf[:idx]).decode('latin-1', errors='replace').strip()
                end = idx + 1
                if end < len(buf) and buf[end:end+1] in (b'\r', b'\n'):
                    end += 1
                del buf[:end]
                if not line:
                    continue
                log.write(f"RX: {line}\n")
                log.flush()
                if line.startswith(token):
                    return line
        time.sleep(0.05)
    return None


def replay_uci_script(path, ser, log):
    """Play a .uci command script verbatim. Each 'go' uses the depth written
    in the file; 'position' lines with no following 'go' are state-only (book
    moves). On bestmove timeout: STOP, send nothing more (monitor forensics)."""
    cmds = []
    for raw in open(path):
        line = raw.strip()
        if not line or line.startswith('#'):
            continue
        cmds.append(line)

    n_go = sum(1 for c in cmds if c.startswith('go'))
    print(f"UCI script: {path}")
    print(f"Commands: {len(cmds)} ({n_go} searches)")
    print(f"Log output: {LOG_FILE}")
    print()
    log.write(f"# UCI-script replay: {path}\n# {len(cmds)} commands, {n_go} searches\n\n")
    log.flush()

    start_time = time.time()
    search_no = 0
    i = 0
    while i < len(cmds):
        cmd = cmds[i]
        if cmd in ('uci', 'ucinewgame'):
            send_line(ser, cmd, log)
            time.sleep(1.5)
            while ser.in_waiting:            # drain id/uciok/banner
                log.write(f"RX: {ser.read(ser.in_waiting).decode('latin-1', errors='replace')}\n")
            log.flush()
        elif cmd == 'isready':
            send_line(ser, cmd, log)
            if read_until_token(ser, log, 'readyok', 10) is None:
                print("  !!! no readyok — engine unresponsive, stopping (state preserved)")
                log.write("!!! no readyok — stopped\n")
                return False
        elif cmd.startswith('position'):
            send_line(ser, cmd, log)
        elif cmd.startswith('go'):
            search_no += 1
            elapsed_min = (time.time() - start_time) / 60.0
            print(f"[{elapsed_min:5.1f}min] search {search_no}/{n_go}: {cmd}", flush=True)
            log.write(f"\n=== Search {search_no}/{n_go}: {cmd} ===\n")
            log.flush()
            send_line(ser, cmd, log)
            bestmove, infos = read_until_bestmove(ser, log, BESTMOVE_TIMEOUT)
            if bestmove is None:
                print(f"  >>> NO BESTMOVE at search {search_no} — CRASH/HANG SIGNATURE <<<")
                print(f"  >>> Engine untouched. Go to the ROM monitor and dump:")
                print(f"  >>>   $6412-$6415 (NODES_SEARCHED = dying node, cmp $CF $08)")
                print(f"  >>>   $6000-$60FF, $64A0-$64FF, $7F00-$7F9F for the diff")
                log.write(f">>> CRASH/HANG at search {search_no} — replay halted, bus quiet <<<\n")
                return False
            last_info = infos[-1][1] if infos else ""
            print(f"             {bestmove}  ({last_info})")
        else:
            send_line(ser, cmd, log)
        i += 1

    total_min = (time.time() - start_time) / 60.0
    print(f"\nScript replay complete in {total_min:.1f} minutes — all {n_go} searches returned bestmove.")
    log.write(f"\n# Script replay finished clean in {total_min:.1f} min\n")
    return True


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 replay-match.py <source_log> [depth] [last_move]")
        print("       python3 replay-match.py <script.uci>")
        print("  last_move: final CURRENT move number to search (1-based), inclusive")
        sys.exit(1)

    src_log = sys.argv[1]

    # UCI-script mode: play the file's command sequence verbatim.
    if src_log.endswith('.uci'):
        log = open(LOG_FILE, 'w')
        log.write(f"# Replay started: {time.strftime('%Y-%m-%d %H:%M:%S %Z')}\n")
        try:
            ser = serial.Serial(port=SERIAL_PORT, baudrate=BAUD_RATE,
                                bytesize=serial.EIGHTBITS, parity=serial.PARITY_NONE,
                                stopbits=serial.STOPBITS_ONE, timeout=0.1)
            ser.reset_input_buffer()
            ser.reset_output_buffer()
            print(f"Serial: {ser.name} @ {ser.baudrate}")
        except Exception as e:
            print(f"ERROR: serial open failed: {e}")
            sys.exit(1)
        time.sleep(0.3)
        clean = replay_uci_script(src_log, ser, log)
        log.close()
        ser.close()
        sys.exit(0 if clean else 2)

    depth = int(sys.argv[2]) if len(sys.argv) > 2 else 5
    # last_move is a CURRENT move number (1 = engine's first search), inclusive.
    last_move = int(sys.argv[3]) if len(sys.argv) > 3 else None

    moves = extract_move_sequence(src_log)
    if not moves:
        print(f"ERROR: no moves extracted from {src_log}")
        sys.exit(1)

    print(f"Source: {src_log}")
    print(f"Moves extracted: {len(moves)}")
    print(f"Replay depth: {depth}")
    print(f"Log output: {LOG_FILE}")
    print()

    log = open(LOG_FILE, 'w')
    log.write(f"# Replay started: {time.strftime('%Y-%m-%d %H:%M:%S %Z')}\n")
    log.write(f"# Source log: {src_log}\n")
    log.write(f"# Depth: {depth}\n")
    log.write(f"# Total moves to replay: {len(moves)}\n")
    log.write(f"# Full move sequence:\n")
    log.write(f"#   {' '.join(moves)}\n\n")
    log.flush()

    try:
        ser = serial.Serial(
            port=SERIAL_PORT,
            baudrate=BAUD_RATE,
            bytesize=serial.EIGHTBITS,
            parity=serial.PARITY_NONE,
            stopbits=serial.STOPBITS_ONE,
            timeout=0.1,
        )
        ser.reset_input_buffer()
        ser.reset_output_buffer()
        print(f"Serial: {ser.name} @ {ser.baudrate}")
    except Exception as e:
        print(f"ERROR: serial open failed: {e}")
        sys.exit(1)

    time.sleep(0.3)

    # Initial UCI handshake (drain any boot output)
    send_line(ser, 'uci', log)
    time.sleep(1.5)
    while ser.in_waiting:
        ser.read(ser.in_waiting)

    # SINGLE ucinewgame for the entire replay - this is critical.
    # All subsequent searches inherit accumulated TT state.
    send_line(ser, 'ucinewgame', log)
    time.sleep(1.5)
    while ser.in_waiting:
        ser.read(ser.in_waiting)

    # Replay each prefix in sequence.
    # IMPORTANT: original match only fed even-count prefixes to the engine
    # (positions where Stockfish had just replied — engine to move next).
    # We must replicate that exact sequence to reproduce TT state correctly.
    # So we iterate i = 0, 2, 4, ..., len(moves).
    start_time = time.time()
    illegal_detected = False
    # Iterate by CURRENT move number (1-based). Move `mv` searches the position
    # after i = 2*(mv-1) plies have been played (engine = white, to move).
    # total_moves = highest current-move number we can search given the ply list.
    total_moves = len(moves) // 2 + 1
    mv = 1
    while True:
        i = 2 * (mv - 1)          # plies played before this search
        if i > len(moves):
            break
        if last_move is not None and mv > last_move:
            break
        prefix = moves[:i]
        ends_with = prefix[-1] if prefix else "(startpos)"
        if prefix:
            pos_cmd = 'position startpos moves ' + ' '.join(prefix)
        else:
            pos_cmd = 'position startpos'

        elapsed_min = (time.time() - start_time) / 60.0
        print(f"[{elapsed_min:5.1f}min] search move {mv:3d}/{total_moves}: position ends '{ends_with}'", flush=True)

        log.write(f"\n=== Search at move {mv} (after {i} plies): position ends with '{ends_with}' ===\n")
        log.flush()

        send_line(ser, pos_cmd, log)
        send_line(ser, f'go depth {depth}', log)

        bestmove, infos = read_until_bestmove(ser, log, BESTMOVE_TIMEOUT)

        if bestmove is None:
            print(f"  !!! TIMEOUT waiting for bestmove at move {mv}")
            log.write(f"!!! TIMEOUT at move {mv}\n")
            break

        bm_parts = bestmove.split()
        engine_move = bm_parts[1] if len(bm_parts) >= 2 else "?"
        last_info = infos[-1][1] if infos else ""
        print(f"             engine says: bestmove {engine_move}  ({last_info})")

        # Heuristic illegal-move check: if next move in our list is white-to-move
        # and the engine output a bestmove that doesn't appear plausible. The
        # original bug was 'g8h7' for a position where g8 was empty. We can't
        # fully validate legality from here, but flag the well-known signature.
        if engine_move == 'g8h7':
            print(f"  >>> ILLEGAL MOVE g8h7 reproduced at move {mv} <<<")
            log.write(f">>> ILLEGAL MOVE g8h7 reproduced at move {mv} <<<\n")
            illegal_detected = True
            break

        log.flush()
        mv += 1

    total_min = (time.time() - start_time) / 60.0
    print()
    print(f"Replay complete in {total_min:.1f} minutes.")
    if illegal_detected:
        print("Illegal move REPRODUCED. See replay-debug.log for full state.")
    else:
        print("No illegal move detected.")
    log.write(f"\n# Replay finished in {total_min:.1f} min\n")
    log.close()
    ser.close()


if __name__ == '__main__':
    main()
