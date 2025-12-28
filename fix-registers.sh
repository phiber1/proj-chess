#!/bin/bash
# Convert R0-RF register syntax to 0-F for a18 assembler

for file in *.asm; do
    echo "Fixing $file..."
    sed -i.bak \
        -e 's/\bR0\b/0/g' \
        -e 's/\bR1\b/1/g' \
        -e 's/\bR2\b/2/g' \
        -e 's/\bR3\b/3/g' \
        -e 's/\bR4\b/4/g' \
        -e 's/\bR5\b/5/g' \
        -e 's/\bR6\b/6/g' \
        -e 's/\bR7\b/7/g' \
        -e 's/\bR8\b/8/g' \
        -e 's/\bR9\b/9/g' \
        -e 's/\bRA\b/A/g' \
        -e 's/\bRB\b/B/g' \
        -e 's/\bRC\b/C/g' \
        -e 's/\bRD\b/D/g' \
        -e 's/\bRE\b/E/g' \
        -e 's/\bRF\b/F/g' \
        "$file"
done
echo "Done! Backup files saved with .bak extension"
