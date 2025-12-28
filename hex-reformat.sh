#!/bin/bash
# Reformat Intel HEX file to max 26 data bytes per line (64 chars total)
# For compatibility with monitors that have 64-byte input buffers

MAX_BYTES=26

if [ -z "$1" ]; then
    echo "Usage: ./hex-reformat.sh input.hex > output.hex"
    exit 1
fi

# Process each line
while IFS= read -r line; do
    # Skip empty lines
    [ -z "$line" ] && continue

    # Check if it starts with colon
    if [[ "${line:0:1}" != ":" ]]; then
        echo "$line"
        continue
    fi

    # Parse: :LLAAAATT[DD...]CC
    count=$((16#${line:1:2}))
    addr=$((16#${line:3:4}))
    type="${line:7:2}"

    # Non-data records (type != 00) pass through unchanged
    if [ "$type" != "00" ]; then
        echo "$line"
        continue
    fi

    # Extract data bytes (everything between type and checksum)
    data="${line:9:$((count*2))}"

    # Split into chunks of MAX_BYTES
    offset=0
    while [ $offset -lt $count ]; do
        # Calculate bytes for this chunk
        remaining=$((count - offset))
        if [ $remaining -gt $MAX_BYTES ]; then
            chunk_bytes=$MAX_BYTES
        else
            chunk_bytes=$remaining
        fi

        # Extract chunk data
        chunk_data="${data:$((offset*2)):$((chunk_bytes*2))}"

        # Calculate new address
        new_addr=$((addr + offset))

        # Format: :LLAAAATT + data
        record=$(printf ":%02X%04X00%s" "$chunk_bytes" "$new_addr" "$chunk_data")

        # Calculate checksum (sum of all bytes, take two's complement)
        sum=0
        for ((i=1; i<${#record}; i+=2)); do
            byte=$((16#${record:$i:2}))
            sum=$((sum + byte))
        done
        checksum=$(( (256 - (sum & 0xFF)) & 0xFF ))

        printf "%s%02X\n" "$record" "$checksum"

        offset=$((offset + chunk_bytes))
    done
done < "$1"
