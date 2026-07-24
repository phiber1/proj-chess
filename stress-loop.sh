#!/bin/bash
# stress-loop.sh — run the pos-10 trigger repeatedly until a hang.
# On a clean run, replay-debug.log ends with "finished clean" -> loop again.
# On a hang, replay-match.py times out silently -> we STOP, ring the bell,
# and leave the hardware exactly as it is for the SC0 probe + monitor dumps.
# Usage: bash stress-loop.sh   (Ctrl-C to stop manually)

SCRIPT="${1:-tools/stress_qs_0717.uci}"   # default: FULL pass (the proven trigger context)
RUN=0
while true; do
    RUN=$((RUN+1))
    echo "=== stress run $RUN: $(date '+%H:%M:%S') ==="
    python3 replay-match.py "$SCRIPT"
    if grep -q "finished clean" replay-debug.log; then
        cp replay-debug.log "stress-runs/run-$(date '+%m%d-%H%M%S').log" 2>/dev/null
        echo "    run $RUN clean"
    else
        echo ""
        echo "############################################"
        echo "###  HANG on run $RUN  $(date '+%H:%M:%S')"
        echo "###  DO NOT RESET. SC0 probe first:"
        echo "###    pulsing = spinning ; flat = halted"
        echo "###  Then EF4, then warm reset ->"
        echo "###  dump \$7E00-\$7FFF FIRST, then \$6400-\$64FF"
        echo "############################################"
        for i in 1 2 3 4 5; do printf '\a'; sleep 1; done
        break
    fi
    sleep 2
done
