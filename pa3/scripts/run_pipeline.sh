#!/usr/bin/env bash
set -u -o pipefail

# Usage: bash pa3/scripts/run_pipeline.sh <input.tsv>
# Input may be repo-relative or absolute. All pipeline paths are relative to pa3/.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PA3_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
REPO_DIR="$(cd -- "$PA3_DIR/.." && pwd)"
DUCKDB="/mnt/scratch/CS131_jelenag/tools/duckdb-current/duckdb"

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <input.tsv>" >&2
  exit 2
fi

INPUT="$1"
if [[ "$INPUT" != /* ]]; then
  INPUT="$REPO_DIR/$INPUT"
fi

echo "$INPUT"
cd -- "$PA3_DIR"

mkdir -p work out logs out/partitions state/completed
: > logs/pipeline.log

log() { printf '[%s] %s\n' "$(date '+%F %T')" "$*" | tee -a logs/pipeline.log >&2; }
fail() { log "ERROR: $*"; exit 1; }

[[ -r "$INPUT" && -s "$INPUT" ]] || fail "Input is missing, unreadable, or empty: $INPUT"
[[ -x "$DUCKDB" ]] || fail "DuckDB executable not found: $DUCKDB"

log "Input: $INPUT"
log "Stage 1/5: prepare and validate analysis-ready TSV"
if ! bash scripts/prepare_analysis.sh "$INPUT" >>logs/pipeline.log 2>&1; then
  fail "Preprocessing stage failed"
fi

log "Stage 2/5: run shell analysis"
if ! bash scripts/run_shell_analysis.sh work/analysis_ready.tsv >>logs/pipeline.log 2>&1; then
  fail "Shell analysis stage failed"
fi

log "Stage 3&4/5: build Parquet and Run all both duckdb Anaylsis"
if  bash scripts/task_4_db_pipeline.sh >>logs/pipeline.log 2>&1; then
	log "DUCKDB Stage successful"
else
	fail "Duckdb stage failed"
fi

log "Stage 5/5: compare results"
if bash scripts/compare_results.sh >>logs/pipeline.log 2>&1; then
  log "All three analysis paths agree"
else
  fail "Result comparison failed; see out/result_comparison.txt"
fi

# Keep months with at least one compared row. This threshold preserves small samples.
awk -F '\t' 'BEGIN { OFS="\t" } NR==1 { print; next } $3 >= 1 { print }' \
  out/shell_result.tsv > out/final_analysis.tsv
[[ -s out/final_analysis.tsv ]] || fail "final_analysis.tsv is empty"
log "Pipeline completed successfully"

