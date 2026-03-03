#!/usr/bin/env python3
"""Merge multiple opening book .asm files into a single sorted book.

Reads DB entries from each file, sorts all entries by ply (for early-exit
efficiency in the linear scan lookup), deduplicates, and writes a combined
opening-book.asm.

Usage: merge_books.py output.asm input1.asm input2.asm ...
"""

import sys
import re

def parse_book_file(filename):
    """Parse DB entries from a generated book .asm file.
    Returns list of (ply, comment, db_line) tuples."""
    entries = []
    with open(filename) as f:
        lines = f.readlines()

    i = 0
    while i < len(lines):
        line = lines[i].strip()
        # Look for comment lines followed by DB lines
        if line.startswith('; Ply '):
            comment = line
            # Next non-empty line should be the DB
            i += 1
            while i < len(lines) and not lines[i].strip():
                i += 1
            if i < len(lines):
                db_line = lines[i].strip()
                if db_line.startswith('DB '):
                    # Extract ply from the DB bytes (first byte after DB)
                    bytes_str = db_line[3:]
                    first_byte = bytes_str.split(',')[0].strip()
                    ply = int(first_byte.replace('$', '0x'), 16)
                    entries.append((ply, comment, db_line))
        i += 1

    return entries

def main():
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} output.asm input1.asm input2.asm ...")
        sys.exit(1)

    output_file = sys.argv[1]
    input_files = sys.argv[2:]

    # Collect all entries from all files
    all_entries = []
    sources = []
    for filename in input_files:
        entries = parse_book_file(filename)
        # Extract opening name from filename
        name = filename.rsplit('/', 1)[-1].replace('.asm', '')
        sources.append(f"{name}: {len(entries)} entries")
        all_entries.extend(entries)

    # Sort by ply (stable sort preserves order within same ply)
    all_entries.sort(key=lambda e: e[0])

    # Deduplicate by DB line (same position from different PGN sources)
    seen = set()
    unique_entries = []
    dupes = 0
    for ply, comment, db_line in all_entries:
        if db_line not in seen:
            seen.add(db_line)
            unique_entries.append((ply, comment, db_line))
        else:
            dupes += 1

    # Calculate total size
    total_bytes = 0
    for ply, comment, db_line in unique_entries:
        # Count DB bytes: split by comma, count entries
        bytes_str = db_line[3:]  # Remove "DB "
        byte_count = len([b.strip() for b in bytes_str.split(',')])
        total_bytes += byte_count
    total_bytes += 1  # $FF terminator

    # Write merged output
    with open(output_file, 'w') as f:
        f.write('; ==============================================================================\n')
        f.write('; Combined Opening Book Data - Merged from multiple PGN sources\n')
        f.write(f'; Total entries: {len(unique_entries)}, Total size: {total_bytes} bytes\n')
        f.write(f'; Duplicates removed: {dupes}\n')
        f.write('; Sources:\n')
        for s in sources:
            f.write(f';   {s}\n')
        f.write('; ==============================================================================\n')
        f.write('\n')
        f.write('; Book format:\n')
        f.write(';   Each entry: [ply] [move1_from] [move1_to] ... [response_from] [response_to] [$FF terminator]\n')
        f.write(';   Entries sorted by ply for efficient early-exit\n')
        f.write('\n')
        f.write('OPENING_BOOK:\n')

        current_ply = -1
        for ply, comment, db_line in unique_entries:
            if ply != current_ply:
                f.write(f'\n    ; === Ply {ply} ===\n')
                current_ply = ply
            f.write(f'    {comment}\n')
            f.write(f'    {db_line}\n')

        f.write('\n; End of book marker\n')
        f.write('    DB $FF\n')
        f.write(f'\n; Total size: {total_bytes} bytes\n')

    print(f"Merged {len(all_entries)} entries from {len(input_files)} files")
    print(f"Duplicates removed: {dupes}")
    print(f"Final entries: {len(unique_entries)}")
    print(f"Total size: {total_bytes} bytes")
    print(f"Wrote {output_file}")

if __name__ == '__main__':
    main()
