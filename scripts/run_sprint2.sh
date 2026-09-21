#!/usr/bin/env bash

# Resolve repo root directory dynamically relative to this script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

OUT_DIR="$REPO_ROOT/out"
mkdir -p "$OUT_DIR"

# Updated CSV location based on updated main branch structure
TARGET_FILE="$REPO_ROOT/data/samples/TMCV_minute.csv"

echo "======================================================================"
echo " Running Pipeline #1: Filter Active Price Movements"
echo " Description: Extended-regex filter for price changes, followed by count"
echo " Output: $OUT_DIR/filter_.txt"
echo "======================================================================"

CMD1="grep -E \"Increased|Decreased\" \"$TARGET_FILE\" | wc -l"
echo "Running Command: $CMD1"
eval "$CMD1" > "$OUT_DIR/filter_.txt"
cat "$OUT_DIR/filter_.txt"

echo ""
echo "======================================================================"
echo " Running Pipeline #2: Dataset Profiling"
echo " Description: Obtains file size, row count, and logs CLI commands used"
echo " Output: $OUT_DIR/profile.txt"
echo "======================================================================"

CMD2="echo \"=== FILE PROFILE ===\" && echo \"File Size: \$(ls -lh \"$TARGET_FILE\" | awk '{print \$5}')\" && echo \"Row Count: \$(wc -l < \"$TARGET_FILE\")\" && echo \"Commands Used: 'ls -lh' (for size), 'wc -l' (for row count)\""
echo "Running Command: $CMD2"
eval "$CMD2" > "$OUT_DIR/profile.txt"
cat "$OUT_DIR/profile.txt"

echo ""
echo "======================================================================"
echo " Running Pipeline #3: Top 10 Dates based on Closing price"
echo " Description: Contains dates and closing price sorted from highest to lowest"
echo " Output: $OUT_DIR/top10_date.txt"
echo "======================================================================"

CMD3="tail -n +2 \"$TARGET_FILE\" | cut -d, -f2,6 | sort -t, -k2,2nr | head -n 10"
echo "Running Command: $CMD3"
eval "$CMD3" > "$OUT_DIR/top10_date.txt"
cat "$OUT_DIR/top10_date.txt"

echo ""
echo "======================================================================"
echo " Running Pipeline #4: Skinny Table of Closing price and Volume"
echo " Description: Contains unique closing price and volume"
echo " Output: $OUT_DIR/skinny_unique.csv"
echo "======================================================================"

CMD4="tail -n +2 \"$TARGET_FILE\" | cut -d, -f6,7 | sort -u"
echo "Running Command: $CMD4"
eval "$CMD3" > "$OUT_DIR/skinny_unique.csv"
cat "$OUT_DIR/skinny_unique.csv" | head -n 10

echo ""
echo "======================================================================"
