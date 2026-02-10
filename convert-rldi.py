#!/usr/bin/env python3
"""
Convert LDI HIGH/PHI/LDI LOW/PLO patterns to CDP1806 RLDI instructions.

Usage: python3 convert-rldi.py <filename.asm>

Finds 4-line patterns:
    LDI HIGH(expr)
    PHI Rn
    LDI LOW(expr)
    PLO Rn

And replaces with:
    RLDI Rn, expr

Handles both exact-match (same expr in HIGH and LOW) and mismatched
patterns (different expr, uses LOW's expression for RLDI).
"""

import sys
import re

def convert_file(filename):
    with open(filename, 'r') as f:
        lines = f.readlines()

    output = []
    i = 0
    exact_count = 0
    mismatch_count = 0

    # Patterns (case-insensitive for safety)
    # Match: whitespace + LDI + whitespace + HIGH( + expr + )
    re_ldi_high = re.compile(
        r'^(\s+)LDI\s+HIGH\((.+?)\)\s*(;.*)?$', re.IGNORECASE
    )
    # Match: whitespace + PHI + whitespace + register
    re_phi = re.compile(
        r'^\s+PHI\s+(\d+)\s*(;.*)?$', re.IGNORECASE
    )
    # Match: whitespace + LDI + whitespace + LOW( + expr + )
    re_ldi_low = re.compile(
        r'^\s+LDI\s+LOW\((.+?)\)\s*(;.*)?$', re.IGNORECASE
    )
    # Match: whitespace + PLO + whitespace + register
    re_plo = re.compile(
        r'^\s+PLO\s+(\d+)\s*(;.*)?$', re.IGNORECASE
    )

    while i < len(lines):
        # Check if we have 4 lines remaining
        if i + 3 < len(lines):
            m1 = re_ldi_high.match(lines[i])
            m2 = re_phi.match(lines[i + 1]) if m1 else None
            m3 = re_ldi_low.match(lines[i + 2]) if m2 else None
            m4 = re_plo.match(lines[i + 3]) if m3 else None

            if m1 and m2 and m3 and m4:
                indent = m1.group(1)
                high_expr = m1.group(2).strip()
                phi_reg = m2.group(1).strip()
                low_expr = m3.group(1).strip()
                plo_reg = m4.group(1).strip()

                # Registers must match
                if phi_reg == plo_reg:
                    # Use the LOW expression (covers both exact and mismatched)
                    expr = low_expr

                    if high_expr == low_expr:
                        exact_count += 1
                    else:
                        mismatch_count += 1

                    # Generate RLDI line
                    rldi_line = f"{indent}RLDI {phi_reg}, {expr}\n"
                    output.append(rldi_line)
                    i += 4
                    continue

        # No match — pass through
        output.append(lines[i])
        i += 1

    # Write back
    with open(filename, 'w') as f:
        f.writelines(output)

    total = exact_count + mismatch_count
    print(f"{filename}: {total} conversions ({exact_count} exact, {mismatch_count} mismatched)")
    return total

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python3 convert-rldi.py <file1.asm> [file2.asm ...]")
        sys.exit(1)

    grand_total = 0
    for fn in sys.argv[1:]:
        grand_total += convert_file(fn)

    if len(sys.argv) > 2:
        print(f"\nTotal across all files: {grand_total} conversions")
