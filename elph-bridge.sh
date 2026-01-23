#!/bin/bash
# ELPH Chess Engine Bridge with logging
LOG=/home/phiber/proj-chess/elph-bridge.log
echo "=== Bridge started $(date) ===" >> $LOG

# Tee stdin/stdout through logging
exec > >(tee -a $LOG) 2>&1
exec < <(tee -a $LOG)

script -qc "socat -,raw,echo=0 /dev/ttyUSB0,b19200,raw,echo=0,crtscts=0" /dev/null

