#!/usr/bin/env python3
"""
ELPH Chess Engine Bridge
Bridges stdin/stdout to serial port for UCI GUI compatibility.
"""
import sys
import os
import select
import signal
import serial
import time
import re

LOG_FILE = '/home/phiber/proj-chess/elph-debug.log'
SERIAL_PORT = '/dev/ttyUSB0'
BAUD_RATE = 19200

# Timing - need enough delay to not overwhelm BIOS echo
CHAR_DELAY = 0.003      # 3ms between characters
LINE_DELAY = 0.030      # 30ms after line ending
LONG_CMD_THRESHOLD = 80 # Commands longer than this get extra delay
LONG_CMD_BASE_DELAY = 0.050   # 50ms base extra delay
LONG_CMD_PER_MOVE = 0.025     # 25ms per move in position command (for MAKE_MOVE processing)

def filter_go_command(line):
    """Strip unsupported parameters from 'go' command."""
    if line.lower().startswith('go'):
        line = re.sub(r'\s+movetime\s+\d+', '', line, flags=re.IGNORECASE)
        line = re.sub(r'\s+wtime\s+\d+', '', line, flags=re.IGNORECASE)
        line = re.sub(r'\s+btime\s+\d+', '', line, flags=re.IGNORECASE)
        line = re.sub(r'\s+winc\s+\d+', '', line, flags=re.IGNORECASE)
        line = re.sub(r'\s+binc\s+\d+', '', line, flags=re.IGNORECASE)
        line = re.sub(r'\s+movestogo\s+\d+', '', line, flags=re.IGNORECASE)
        line = re.sub(r'\s+', ' ', line).strip()
    return line

def main():
    log = open(LOG_FILE, 'w')
    log.write("ELPH Bridge started\n")
    log.flush()

    signal.signal(signal.SIGPIPE, signal.SIG_IGN)

    try:
        ser = serial.Serial(
            port=SERIAL_PORT,
            baudrate=BAUD_RATE,
            bytesize=serial.EIGHTBITS,
            parity=serial.PARITY_NONE,
            stopbits=serial.STOPBITS_ONE,
            timeout=0.1,
            xonxoff=False,
            rtscts=False,
            dsrdtr=False
        )
        ser.reset_input_buffer()
        ser.reset_output_buffer()
        log.write(f"Serial: {ser.name} @ {ser.baudrate}\n")
        log.flush()
    except Exception as e:
        log.write(f"Serial open failed: {e}\n")
        log.close()
        sys.exit(1)

    time.sleep(0.3)

    stdin_fd = sys.stdin.fileno()
    stdout_fd = sys.stdout.fileno()

    pending_echo_lines = []
    recv_buffer = bytearray()

    log.write("Entering main loop\n")
    log.flush()

    try:
        while True:
            # Check stdin
            readable, _, _ = select.select([stdin_fd], [], [], 0.005)

            if stdin_fd in readable:
                data = os.read(stdin_fd, 1024)
                if not data:
                    log.write("EOF on stdin\n")
                    break

                text = data.decode('latin-1')
                input_lines = text.replace('\r\n', '\n').replace('\r', '\n').split('\n')

                for line in input_lines:
                    if not line:
                        continue

                    if line.strip().lower() == 'quit':
                        log.write("Quit command\n")
                        return

                    original_line = line
                    line = filter_go_command(line)

                    log.write(f"TX: {repr(line)}\n")
                    log.flush()

                    pending_echo_lines.append(line.lower())

                    # Send with delays, reading any incoming data between chars
                    line_bytes = (line + '\n').encode('latin-1')
                    for b in line_bytes:
                        ser.write(bytes([b]))
                        if b in (0x0D, 0x0A):
                            time.sleep(LINE_DELAY)
                        else:
                            time.sleep(CHAR_DELAY)
                        # Drain incoming while sending
                        while ser.in_waiting:
                            recv_buffer.extend(ser.read(ser.in_waiting))
                    ser.flush()

                    # Extra delay after long commands
                    if len(line) > LONG_CMD_THRESHOLD:
                        # Count moves in position command for scaled delay
                        # Each "xxxx " or "xxxxx " move needs MAKE_MOVE processing time
                        move_count = line.lower().count(' moves ')
                        if move_count > 0:
                            # Count individual moves after "moves" keyword
                            moves_part = line.lower().split(' moves ', 1)
                            if len(moves_part) > 1:
                                move_count = len(moves_part[1].split())
                            else:
                                move_count = 0

                        delay = LONG_CMD_BASE_DELAY + (move_count * LONG_CMD_PER_MOVE)
                        time.sleep(delay)
                        log.write(f"  (long cmd delay: {len(line)} chars, {move_count} moves, {delay*1000:.0f}ms)\n")
                        log.flush()

            # Read from serial
            while ser.in_waiting:
                recv_buffer.extend(ser.read(ser.in_waiting))

            # Process complete lines
            while b'\n' in recv_buffer or b'\r' in recv_buffer:
                idx_n = recv_buffer.find(b'\n')
                idx_r = recv_buffer.find(b'\r')

                if idx_n == -1:
                    idx = idx_r
                elif idx_r == -1:
                    idx = idx_n
                else:
                    idx = min(idx_n, idx_r)

                line = bytes(recv_buffer[:idx]).decode('latin-1', errors='replace')

                end = idx + 1
                if end < len(recv_buffer) and recv_buffer[end:end+1] in (b'\r', b'\n'):
                    end += 1
                del recv_buffer[:end]

                line_stripped = line.strip()
                if not line_stripped:
                    continue

                line_lower = line_stripped.lower()

                # Check if this is an echo
                is_echo = False
                for i, expected in enumerate(pending_echo_lines):
                    if line_lower == expected:
                        log.write(f"ECHO: {repr(line_stripped)}\n")
                        log.flush()
                        pending_echo_lines.pop(i)
                        is_echo = True
                        break
                    # Check for partial match (corrupted echo)
                    elif expected.endswith(line_lower) or line_lower.endswith(expected):
                        log.write(f"PARTIAL_ECHO: {repr(line_stripped)} (expected {repr(expected)})\n")
                        log.flush()
                        pending_echo_lines.pop(i)
                        is_echo = True
                        break

                if not is_echo:
                    output = (line_stripped + '\n').encode('latin-1')
                    log.write(f"RX: {repr(line_stripped)}\n")
                    log.flush()
                    try:
                        os.write(stdout_fd, output)
                    except (BrokenPipeError, OSError) as e:
                        log.write(f"Stdout write failed: {e}\n")
                        log.flush()
                        return

    except Exception as e:
        log.write(f"Error: {e}\n")
        log.flush()
        import traceback
        log.write(traceback.format_exc())
        log.flush()
    finally:
        try:
            ser.close()
        except:
            pass
        log.write("Bridge closed\n")
        log.flush()
        log.close()

if __name__ == '__main__':
    main()
