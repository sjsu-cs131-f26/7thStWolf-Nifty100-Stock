
#!/usr/bin/env bash
set -u -o pipefail


SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PA3_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
REPO_DIR="$(cd -- "$PA3_DIR/.." && pwd)"
DUCKDB="/mnt/scratch/CS131_jelenag/tools/duckdb-current/duckdb"

cd -- "$PA3_DIR"

DUCKDB=/mnt/scratch/CS131_jelenag/tools/duckdb-current/duckdb

mkdir -p logs

"$DUCKDB" < sql/build_parquet.sql > logs/build_parquet.log 2>&1

"$DUCKDB" < sql/analysis_text.sql > logs/duckdb_text.log 2>&1
 
"$DUCKDB" < sql/analysis_parquet.sql > logs/analysis_parquet.sql  2>&1

exit 0
