#!/usr/bin/env python3
"""
ELPH Chess Engine Bridge
Direct serial communication - no socat.
"""
import sys
import os
import select
import termios
import time
import signal

LOG_FILE = '/home/phiber/proj-chess/elph-debug.log'
SERIAL_PORT = '/dev/ttyUSB0'

def main():
    log = open(LOG_FILE, 'w')
    log.write("Bridge started (direct serial)\n")
    log.flush()

    # Ignore SIGPIPE
    signal.signal(signal.SIGPIPE, signal.SIG_IGN)

    # Open serial port
    try:
        serial_fd = os.open(SERIAL_PORT, os.O_RDWR | os.O_NOCTTY)
    except Exception as e:
        log.write(f"Failed to open serial: {e}\n")
        log.close()
        sys.exit(1)

    # Configure serial port
    try:
        attrs = termios.tcgetattr(serial_fd)
        attrs[0] = 0  # iflag
        attrs[1] = 0  # oflag
        attrs[2] = termios.CS8 | termios.CREAD | termios.CLOCAL  # cflag
        attrs[3] = 0  # lflag
        attrs[4] = termios.B19200
        attrs[5] = termios.B19200
        attrs[6][termios.VMIN] = 0
        attrs[6][termios.VTIME] = 1
        termios.tcsetattr(serial_fd, termios.TCSAFLUSH, attrs)
        termios.tcflush(serial_fd, termios.TCIOFLUSH)
        log.write("Serial configured\n")
        log.flush()
    except Exception as e:
        log.write(f"Failed to configure: {e}\n")
        log.close()
        sys.exit(1)

    # Small delay to let serial settle
    time.sleep(0.1)

    stdin_fd = sys.stdin.fileno()
    stdout_fd = sys.stdout.fileno()
    stdin_open = True

    log.write("Entering main loop\n")
    log.flush()

    try:
        while True:
            fds = [serial_fd]
            if stdin_open:
                fds.append(stdin_fd)

            readable, _, _ = select.select(fds, [], [], 0.5)

            if not readable:
                log.write("Select timeout\n")
                log.flush()

            if stdin_fd in readable:
                data = os.read(stdin_fd, 1024)
                if not data:
                    log.write("EOF on stdin\n")
                    log.flush()
                    stdin_open = False
                else:
                    log.write(f"GUI->ENGINE ({len(data)} bytes): {repr(data)}\n")
                    log.flush()
                    # Write byte-by-byte with small delay (like typing)
                    for b in data:
                        os.write(serial_fd, bytes([b]))
                        time.sleep(0.001)  # 1ms between chars

            if serial_fd in readable:
                data = os.read(serial_fd, 1024)
                if data:
                    log.write(f"ENGINE->GUI ({len(data)} bytes): {repr(data)}\n")
                    log.flush()
                    try:
                        os.write(stdout_fd, data)
                    except BrokenPipeError:
                        log.write("Broken pipe on stdout\n")
                        break

    except Exception as e:
        log.write(f"Error: {e}\n")
        log.flush()
    finally:
        os.close(serial_fd)
        log.write("Bridge closed\n")
        log.close()

if __name__ == '__main__':
    main()
