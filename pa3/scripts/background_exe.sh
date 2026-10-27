#!/usr/bin/env bash
set -u -o pipefail
set -m   #

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PA3_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
cd -- "$PA3_DIR"
mkdir -p logs out

CMD='scripts/run_pipeline.sh pa3/data/sample/sample.tsv'
LOG='logs/background_run.log'
OUT='out/background_run_proof.txt'

rm -f logs/exit_code.txt

nohup bash -c "$CMD; echo \$? > logs/exit_code.txt" > "$LOG" 2>&1 &
PID=$!
JOB=$(jobs -l | head -1)

sleep 1   

{
  echo "# Launched Command"
  echo "nohup bash -c \"$CMD; echo \\\$? > logs/exit_code.txt\" > \"$LOG\" 2>&1 &"
  echo
  echo "## PID & JOB"
  echo "PID: $PID"
  echo "Job: $JOB"
  echo
  echo "## PS Snapshot"
  ps -p "$PID" -o pid,ppid,stat,etime,cmd || echo "(process already finished)"
} > "$OUT"

wait "$PID"
STATUS=$?

{
  echo
  echo "## Log tail"
  tail -n 10 "$LOG"
  echo
  echo "## Completion Evidence"
  echo "Exit Status: $STATUS"
  echo "Exit file:   $(cat logs/exit_code.txt 2>/dev/null || echo unknown)"
} >> "$OUT"
