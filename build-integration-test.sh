#!/bin/bash
# ==============================================================================
# RCA 1802/1806 Chess Engine - Build with Integration Tests
# ==============================================================================
# Builds the chess engine AND appends the integration test suite
# ==============================================================================

echo "RCA 1802/1806 Chess Engine - Integration Test Build"
echo "===================================================="
echo ""

# First, run the regular build
./build.sh

if [ $? -ne 0 ]; then
    echo "Main build failed, cannot add tests."
    exit 1
fi

echo ""
echo "Adding integration tests..."

# Output files
OUTPUT="chess-engine-test.asm"
HEXFILE="chess-engine-test.hex"

# Copy main assembly and append test module
cp chess-engine.asm "$OUTPUT"
echo "" >> "$OUTPUT"
echo "; ==== INTEGRATION TEST MODULE ====" >> "$OUTPUT"
cat integration-test.asm >> "$OUTPUT"

if command -v a18 &> /dev/null; then
    echo "Assembling with a18..."
    a18 "$OUTPUT" -o "$HEXFILE" -l chess-engine-test.lst 2>&1 | grep -v "Error(s)" || true

    if [ -f "$HEXFILE" ] && [ -s "$HEXFILE" ]; then
        echo ""
        echo "===================================================="
        echo "Integration test build complete!"
        echo "  Main engine: chess-engine.hex ($(wc -c < chess-engine.hex) bytes)"
        echo "  With tests:  $HEXFILE ($(wc -c < "$HEXFILE") bytes)"
        echo ""
        echo "To run tests on hardware:"
        echo "  1. Flash $HEXFILE to your 1802 system"
        echo "  2. Connect serial at 9600 baud (8N1)"
        echo "  3. Jump to address \$7000 to start tests"
        echo "  4. Watch output for PASS/FAIL results"
        echo ""
        echo "Expected output:"
        echo "  Test 1: Board Init... PASS"
        echo "  Test 2: Move Generation... PASS"
        echo "  Test 3: Check Detection... PASS"
        echo "  Test 4: Make/Unmake Move... PASS"
        echo "  Test 5: Evaluation... PASS"
        echo "  Test 6: Negamax (1-ply)... PASS"
        echo "  Test 7: Stack Balance... PASS"
        echo "===================================================="
    else
        echo "Integration test assembly failed!"
        exit 1
    fi
else
    echo "No assembler found - $OUTPUT ready for manual assembly"
fi
