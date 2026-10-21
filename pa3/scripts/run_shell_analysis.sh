#!/usr/bin/env bash
set -u -o pipefail

# Usage: bash scripts/run_shell_analysis.sh work/analysis_ready.tsv
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PA3_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
cd -- "$PA3_DIR"

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <analysis_ready.tsv>" >&2
  exit 2
fi

INPUT="$1"
[[ -r "$INPUT" && -s "$INPUT" ]] || {
  echo "ERROR: Input missing, unreadable, or empty: $INPUT" >&2
  exit 1
}

EXPECTED=$'symbol\ttimestamp\tclose\tprice_change'
ACTUAL="$(head -n 1 "$INPUT")"

if [[ "$ACTUAL" != "$EXPECTED" ]]; then
  echo "ERROR: expected analysis-ready four-column TSV header" >&2
  exit 1
fi

BAD_STRUCTURE="$(awk -F '\t' 'NR > 1 && NF != 4 { n++ } END { print n+0 }' "$INPUT")"
if [[ "$BAD_STRUCTURE" -gt 0 ]]; then
  echo "ERROR: $BAD_STRUCTURE data row(s) do not have exactly 4 fields" >&2
  exit 1
fi

mkdir -p out

# Analyze only increased/decreased rows, grouped by calendar month.
awk -F '\t' -v OFS='\t' '
NR == 1 { next }
$4 == "increased" || $4 == "decreased" {
  m = substr($2, 6, 2) + 0
  compared[m]++
  if ($4 == "increased") increases[m]++
}
END {
  print "month", "increase_count", "compared_rows", "increase_ratio"
  for (m = 1; m <= 12; m++) {
    if (compared[m] > 0)
      printf "%d\t%d\t%d\t%.4f\n", m, increases[m]+0, compared[m], (increases[m]+0)/compared[m]
  }
}' "$INPUT" > out/shell_result.tsv

[[ -s out/shell_result.tsv ]] || {
  echo "ERROR: shell analysis produced no result" >&2
  exit 1
}

