#!/usr/bin/env bash
set -u -o pipefail
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PA3_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
cd -- "$PA3_DIR"

REPORT="out/result_comparison.txt"
: > "$REPORT"
status1=0
status2=0
{
  echo "Comparison 1: shell vs DuckDB text"
  diff -u out/shell_result.tsv out/duckdb_text_result.tsv
} >> "$REPORT" 2>&1 || status1=$?
{
  echo "Comparison 2: DuckDB text vs DuckDB Parquet"
  diff -u out/duckdb_text_result.tsv out/duckdb_parquet_result.tsv
} >> "$REPORT" 2>&1 || status2=$?

# diff status 1 means different; status >1 means diff itself failed.
if [[ "$status1" -eq 0 && "$status2" -eq 0 ]]; then
  echo "RESULT: all three analysis paths agree" | tee -a "$REPORT"
  exit 0
fi
echo "RESULT: mismatch or comparison error (shell/text=$status1, text/parquet=$status2)" | tee -a "$REPORT"
exit 1

