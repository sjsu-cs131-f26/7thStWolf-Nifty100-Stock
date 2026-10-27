#!/usr/bin/env bash
set -u -o pipefail

# Usage: bash scripts/run_shell_analysis.sh work/analysis_ready.tsv
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PA3_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
cd -- "$PA3_DIR"
if [[ $# -ne 1 ]]; then
  exit 2
fi

INPUT="$1"

DUCKDB="/mnt/scratch/CS131_jelenag/tools/duckdb-current/duckdb"

FILENAME="${INPUT##*/}"
STOCK="${FILENAME%_partition.parquet}"

SQL="COPY (
  WITH compared AS (
    SELECT
      month(timestamp) AS month,
      price_change
    FROM read_parquet('${INPUT}')
    WHERE price_change IN ('Increased', 'Decreased')
  )
  SELECT
    month,
    COUNT(*) FILTER (WHERE price_change = 'Increased') AS increase_count,
    COUNT(*) AS compared_rows,
    printf('%.4f',
      CAST(COUNT(*) FILTER (WHERE price_change = 'Increased') AS DOUBLE) / COUNT(*)
    ) AS increase_ratio
  FROM compared
  GROUP BY month
  ORDER BY month ASC
) TO 'out/partitions/${STOCK}_Analysis.tsv' (HEADER, DELIMITER '\t');"

"$DUCKDB" -c "$SQL"
