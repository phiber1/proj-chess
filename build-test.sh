#!/bin/bash
# Build script with error checking
# Supports -DBIOS flag for BIOS mode compilation

BIOS_FLAG=""
BASE=""

# Parse arguments
for arg in "$@"; do
    case "$arg" in
        -DBIOS)
            BIOS_FLAG="-DBIOS"
            ;;
        *)
            BASE="$arg"
            ;;
    esac
done

if [ -z "$BASE" ]; then
    echo "Usage: ./build-test.sh [-DBIOS] <basename>"
    echo "Example: ./build-test.sh test-step22"
    echo "         ./build-test.sh -DBIOS test-step22"
    exit 1
fi

# Preprocess (with optional -DBIOS)
cpp -P $BIOS_FLAG "${BASE}.asm" 2>/dev/null > "${BASE}-pp.asm"

# Assemble
a18 "${BASE}-pp.asm" -l "${BASE}.lst" -o "${BASE}-raw.hex" 2>&1

# Check for branch errors (B flag) in listing
BRANCH_ERRORS=$(grep "^B" "${BASE}.lst" 2>/dev/null)
if [ -n "$BRANCH_ERRORS" ]; then
    echo ""
    echo "*** BRANCH ERRORS DETECTED ***"
    echo "$BRANCH_ERRORS"
    echo ""
    echo "Fix: Change short branches (BZ, BNZ, BNF, etc.) to long branches (LBZ, LBNZ, LBNF, etc.)"
    exit 1
fi

# Reformat hex to 24-byte records (fits in 64-char monitor input)
# -disable=exec-start-address prevents srec_cat from adding wrong start address
srec_cat "${BASE}-raw.hex" -intel -disable=exec-start-address -output "${BASE}.hex" -intel -Output_Block_Size=24
rm -f "${BASE}-raw.hex"

if [ -n "$BIOS_FLAG" ]; then
    echo "Build successful (BIOS mode), no branch errors."
else
    echo "Build successful (standalone mode), no branch errors."
fi
