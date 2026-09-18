#!/usr/bin/env bash

# ==============================================================================
# Sprint 2 Data Pipelines
# Sample File: data/processed_data/TMCV_minute.csv (Selected from 100 stocks)
# ==============================================================================

# Dynamically resolve relative path to data directory regardless of where script is executed
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
TARGET_FILE="$REPO_ROOT/data/processed_data/TMCV_minute.csv"

echo "======================================================================"
echo " Pipeline #1: Filter Active Price Movements & Count Records"
echo " Description: Uses extended regex (-E) to capture all trading minutes"
echo "              where price_change was either 'Increased' or 'Decreased'."
echo "======================================================================"

CMD1="grep -E \"Increased|Decreased\" \"$TARGET_FILE\" | wc -l"
echo "Running Command: $CMD1"
echo "----------------------------------------------------------------------"
eval "$CMD1"

echo ""
echo "======================================================================"
echo " Pipeline #2: File Profile & Metadata Extraction"
echo " Description: Obtains file size, row count, and logs the CLI commands"
echo "              used to retrieve those metrics."
echo "======================================================================"

CMD2="echo \"File Size: \$(ls -lh \"$TARGET_FILE\" | awk '{print \$5}')\" && echo \"Row Count: \$(wc -l < \"$TARGET_FILE\")\" && echo \"Commands Used: 'ls -lh' (for size), 'wc -l' (for row count)\""
echo "Running Command: $CMD2"
echo "----------------------------------------------------------------------"
eval "$CMD2"
echo "======================================================================"
