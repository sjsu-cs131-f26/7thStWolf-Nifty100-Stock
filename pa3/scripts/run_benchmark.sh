#!/usr/bin/env bash
set -u -o pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PA3_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"

cd -- "$PA3_DIR"

mkdir -p out logs

OUTPUT="out/benchmark.tsv"
DUCKDB="/mnt/scratch/CS131_jelenag/tools/duckdb-current/duckdb"

SHELL_LOG="logs/shell_timing.txt"
DUCK_TEXT_LOG="logs/duckdb_text_timing.txt"
DUCK_PARQUET_LOG="logs/duckdb_parquet_timing.txt"


echo '' > "$SHELL_LOG"
echo '' > "$DUCK_TEXT_LOG"
echo '' > "$DUCK_PARQUET_LOG"

printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' implementation storage_format run input_rows input_bytes real_seconds result_verified > "$OUTPUT"

TIMEFORMAT=%R


INPUT_ROWS=$(( $(wc -l < work/analysis_ready.tsv) - 1 ))
INPUT_BYTES=$(wc -c < work/analysis_ready.tsv)
PARQUET_BYTES=$(wc -c < work/analysis_ready.parquet)

ALL_OK=1

for i in 1 2 3; do
   SHELL_TIME=$( { time bash scripts/run_shell_analysis.sh work/analysis_ready.tsv >/dev/null 2>>"$SHELL_LOG"; } 2>&1 )

  DUCK_TEXT_TIME=$( { time "$DUCKDB" work/project.duckdb < sql/analysis_text.sql >/dev/null 2>>"$DUCK_TEXT_LOG"; } 2>&1 )

  DUCK_PARQUET_TIME=$( { time "$DUCKDB" work/project.duckdb < sql/analysis_parquet.sql >/dev/null 2>>"$DUCK_PARQUET_LOG"; } 2>&1 )

   if bash scripts/compare_results.sh; then
    VERIFIED="TRUE"
  else
    VERIFIED="FALSE"
    ALL_OK=0
  fi

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    shell_text      .tsv     "$i" "$INPUT_ROWS" "$INPUT_BYTES"   "$SHELL_TIME"        "$VERIFIED" >> "$OUTPUT"
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    duckdb_text     .tsv     "$i" "$INPUT_ROWS" "$INPUT_BYTES"   "$DUCK_TEXT_TIME"    "$VERIFIED" >> "$OUTPUT"
  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
    duckdb_parquet  .parquet "$i" "$INPUT_ROWS" "$PARQUET_BYTES" "$DUCK_PARQUET_TIME" "$VERIFIED" >> "$OUTPUT"
done

if [ "$ALL_OK" -eq 1 ]; then
  echo "RESULT CHECK PASSED: shell, DuckDB text, and DuckDB Parquet results all agree."
  exit 0
else
  echo "RESULT CHECK FAILED: results differ. See out/result_comparison.txt." >&2
  exit 1
fi
