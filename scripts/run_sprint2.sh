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
echo " Description: Extended-regex filter for price changes, followed by count of total movements in price"
echo " Output: $OUT_DIR/filter_price_movements.txt"
echo "======================================================================"

CMD1="grep -E \"Increased|Decreased\" \"$TARGET_FILE\" | wc -l"
{ time ( eval "$CMD1" > "$OUT_DIR/filter_price_movements.txt" ); } 2>> "$OUT_DIR/timing.txt"
echo "Total Price Movements:"
cat "$OUT_DIR/filter_price_movements.txt"

echo ""
echo "======================================================================"
echo " Running Pipeline #2: Dataset Profiling"
echo " Description: Obtains file size, row count, and logs CLI commands used"
echo " Output: $OUT_DIR/profile.txt"
echo "======================================================================"

CMD2="echo \"=== FILE PROFILE ===\" && echo \"File Size: \$(ls -lh \"$TARGET_FILE\" | awk '{print \$5}')\" && echo \"Row Count: \$(wc -l < \"$TARGET_FILE\")\" && echo \"Commands Used: 'ls -lh' (for size), 'wc -l' (for row count)\""
{ time (eval "$CMD2" > "$OUT_DIR/profile.txt"); } 2>> "$OUT_DIR/timing.txt"
cat "$OUT_DIR/profile.txt"

echo ""
echo "======================================================================"
echo " Running Pipeline #3: Top 10 Dates based on Closing price"
echo " Description: Contains dates and closing price sorted from highest to lowest"
echo " Output: $OUT_DIR/top10_date.txt"
echo "======================================================================"

CMD3="tail -n +2 \"$TARGET_FILE\" | cut -d, -f2,6 | sort -t, -k2,2nr | head -n 10"
{ time ( eval "$CMD3" > "$OUT_DIR/top10_date.txt" ); } 2>> "$OUT_DIR/timing.txt"
cat "$OUT_DIR/top10_date.txt"

echo ""
echo "======================================================================"
echo " Running Pipeline #4: Skinny Table of Closing price and Volume"
echo " Description: Contains unique closing price and volume"
echo " Output: $OUT_DIR/skinny_unique.csv"
echo "======================================================================"

CMD4="tail -n +2 \"$TARGET_FILE\" | cut -d, -f6,7 | sort -u"
{ time ( eval "$CMD4" > "$OUT_DIR/skinny_unique.csv" ); } 2>> "$OUT_DIR/timing.txt"
cat "$OUT_DIR/skinny_unique.csv" | head -n 10

echo ""
echo "======================================================================"
echo "Running Pipeline #5: Frequency of Price Changes"
{ time (tail -n +2 "$TARGET_FILE" | cut -d, -f8 | sort | uniq -c | sort -nr | tee "$OUT_DIR/freq_price_change.txt"); } 2>> "$OUT_DIR/timing.txt"
echo "Running Pipeline #6: Frequency of Price Increases by Month"
{ time (tail -n +2 "$TARGET_FILE" | cut -d, -f2,8 | grep -E ",Increased$" | cut -c6-7 | sort | uniq -c| sort -rn | tee "$OUT_DIR/freq_price_increases_by_month.txt"); } 2>> "$OUT_DIR/timing.txt"

