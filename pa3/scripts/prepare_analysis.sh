#!/usr/bin/env bash
set -u -o pipefail

# Produces work/analysis_ready.tsv and out/shell_result.tsv.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PA3_DIR="$(cd -- "$SCRIPT_DIR/.." && pwd)"
cd -- "$PA3_DIR"

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <input.tsv>" >&2
  exit 2
fi
INPUT="$1"
[[ -r "$INPUT" && -s "$INPUT" ]] || { echo "Input missing/unreadable/empty: $INPUT" >&2; exit 1; }

mkdir -p work out logs
: > logs/rejected_rows.log
TMP="work/analysis_ready.tmp.tsv"
RAW_HEADER="$(head -n 1 "$INPUT")"
EXPECTED=$'name\tdate\topen\thigh\tlow\tclose\tvolume\tprice_change\tvolume_change'
if [[ "$RAW_HEADER" != "$EXPECTED" ]]; then
  echo "ERROR: unexpected header or delimiter; expected nine tab-separated columns" >&2
  printf 'Expected: %s\nActual:   %s\n' "$EXPECTED" "$RAW_HEADER" >> logs/validation.log
  exit 1
fi

# Structural violations abort the run rather than silently corrupting columns.
BAD_STRUCTURE="$(awk -F '\t' 'NR > 1 && NF != 9 { n++ } END { print n+0 }' "$INPUT")"
if [[ "$BAD_STRUCTURE" -gt 0 ]]; then
  echo "ERROR: $BAD_STRUCTURE row(s) have a field count other than 9" >&2
  awk -F '\t' 'NR > 1 && NF != 9 { print "line " NR ": expected 9 fields, found " NF }' "$INPUT" \
    | head -n 10 >> logs/validation.log
  exit 1
fi

# Normalize price_change to lowercase, validate, and retain only the four required fields.
# Bad data rows are dropped and recorded (up to 10 examples); structural errors abort above.
awk -F '\t' -v OFS='\t' '
function isnum(x) { return x ~ /^[-+]?[0-9]+([.][0-9]+)?([eE][-+]?[0-9]+)?$/ }
NR == 1 { print "symbol", "timestamp", "close", "price_change"; next }
{
  label=$8
  reason=""
  if ($2 !~ /^[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9] [0-9][0-9]:[0-9][0-9]:[0-9][0-9]$/) reason="bad_timestamp"
  else {
    month=substr($2,6,2)+0
    if (month < 1 || month > 12) reason="bad_month"
  }
  if (reason=="") {
    if (!isnum($6) || ($6+0) <= 0) reason="bad_close"
    else if (!isnum($4) || !isnum($5) || ($4+0) < ($5+0)) reason="bad_high_low"
    else if (label != "increased" && label != "decreased" && label != "none") reason="bad_price_change"
  }
  if (reason != "") {
    rejected++
    if (rejected <= 10) print "line " NR "\t" reason "\t" $0 > "/dev/stderr"
    next
  }
  print $1, $2, $6, label
}
END { print "Rejected data rows: " rejected+0 > "/dev/stderr" }
' < <(sed -E '2,$s/^(([^	]*	){7})([^	]*)/\1\L\3\E/' "$INPUT") \
  2> work/validation_stderr.log > "$TMP"

# Keep a small, capped rejected-row log; diagnostics never go to stdout.
grep -E '^(line |Rejected data rows:)' work/validation_stderr.log > logs/rejected_rows.log || true
mv "$TMP" work/analysis_ready.tsv

OUT_BAD="$(awk -F '\t' 'NF != 4 { n++ } END { print n+0 }' work/analysis_ready.tsv)"
OUT_ROWS="$(awk 'END { print NR+0 }' work/analysis_ready.tsv)"
INPUT_ROWS="$(awk 'END { print NR-1 }' "$INPUT")"
REJECTED="$(awk -F '\t' '/^Rejected data rows:/ {print $4}' logs/rejected_rows.log | tail -n 1)"
[[ -n "$REJECTED" ]] || REJECTED=0
if [[ "$OUT_BAD" -ne 0 || "$OUT_ROWS" -le 1 ]]; then
  echo "ERROR: output invariant failed (bad_fields=$OUT_BAD, output_lines=$OUT_ROWS)" >&2
  exit 1
fi
VALID_ROWS=$((OUT_ROWS - 1))
if [[ $((VALID_ROWS + REJECTED)) -ne "$INPUT_ROWS" ]]; then
  echo "ERROR: row arithmetic failed: valid=$VALID_ROWS rejected=$REJECTED input=$INPUT_ROWS" >&2
  exit 1
fi
{
  echo "Input data rows: $INPUT_ROWS"
  echo "Rejected data rows: $REJECTED"
  echo "Output data rows: $VALID_ROWS"
  echo "Arithmetic check: $VALID_ROWS + $REJECTED = $INPUT_ROWS"
  echo "Output fields per row: 4"
} > logs/validation.log
