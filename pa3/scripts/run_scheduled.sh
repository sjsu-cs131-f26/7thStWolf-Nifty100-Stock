#!/usr/bin/env bash
set -u -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PA3_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
REPO_DIR="$(cd -- "$PA3_DIR/.." && pwd)"

cd "$PA3_DIR"
LAST_CHECKED=$(<state/last_checked_partition.txt)
ID=$((LAST_CHECKED + 1))

mkdir -p logs state

LOG="logs/cron.log"

STATE="state/partition_manifest.tsv"
FILE_PATH="$(awk -F '\t' -v id="$ID" '$1 == id { print $2; exit }' "$STATE")"


if [[ -z "$FILE_PATH" ]]; then
    printf '[%s] All partitions have been completed. Exiting.\n' \
        "$(date '+%Y-%m-%d %H:%M:%S')" >> "$LOG"
    exit 0
fi


printf '[%s] Scheduled Analysis of Partition %s for stock %s has begun\n' \
  "$(date '+%Y-%m-%d %H:%M:%S')" \
  "$ID" \
  "$FILE_PATH" >> "$LOG"


bash scripts/run_partition.sh "$FILE_PATH"


printf '[%s] Scheduled Analysis of Partition %s for stock %s has ended\n' \
  "$(date '+%Y-%m-%d %H:%M:%S')" \
  "$ID" \
  "$FILE_PATH" >> "$LOG"

echo "$ID" > state/last_checked_partition.txt

printf '[%s] Partition %s for stock %s completed\n' \
  "$(date '+%Y-%m-%d %H:%M:%S')" "$ID" "$FILE_PATH" >> state/completed.txt
exit 0
