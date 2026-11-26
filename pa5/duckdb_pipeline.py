# duckdb_pipeline.py
"""DuckDB version of the shared stock_combined.parquet analysis similiar in pa3/."""
import argparse
import csv
import os
import time
from pathlib import Path

# Keep timing output compatible with the PA3 workflow.
BENCHMARK_FIELDS = ["approach", "run", "input_rows", "input_bytes",
"elapsed_seconds","output_rows", "result_verified", "job_id",]

# Final result is one overall average for each calendar month.
FINAL_SQL = """
SELECT month,
       COUNT(DISTINCT symbol) AS n_stocks,
       SUM(n_days) AS n_days,
       ROUND(SUM(avg_change_pc * n_days) / NULLIF(SUM(n_days), 0), 4)
           AS avg_change_pc
FROM stock_analysis
WHERE n_days > 0
GROUP BY month
ORDER BY month
"""

# Function to create command-line parser, analysis by month, then aggregate the info as parsed value.
def parse_args():
    parser = argparse.ArgumentParser(description = "Analyze stock_combined.parquet by stock and month.")
    parser.add_argument("data_path",help = "GCS path to stock_combined.parquet")
    parser.add_argument("--threads", type = int, default=None)
    parser.add_argument("--output-dir", default = "pa5/out/duckdb")
    parser.add_argument("--benchmark-runs", type = int, default = 3)
    parser.add_argument("--benchmark-output", default = "pa5/out/benchmark_full.csv")
    parser.add_argument("--expected-result")
    parser.add_argument("--comparison-output", default = "pa5/out/comparison.txt")
    parser.add_argument("--input-bytes", type = int, default = None)
    parser.add_argument("--overwrite-benchmark", action = "store_true")
    return parser.parse_args()

# Function to safetly put a string value into a SQL string literal for DuckDB.
def quote(value):
    return "'" + value.replace("'", "''") + "'"

# Function to read the separate service account's HMAC value to load GCS support & DuckDB runtime.
def configure(con, threads):
    key_id = os.environ.get("DUCKDB_GCS_KEY_ID")
    secret = os.environ.get("DUCKDB_GCS_SECRET")
    if not key_id or not secret:
        raise ValueError("Set DUCKDB_GCS_KEY_ID and DUCKDB_GCS_SECRET first")
    # install and loads remote-file extension to connect to GCS.
    con.execute("INSTALL httpfs")
    con.execute("LOAD httpfs")
    con.execute(f"""CREATE OR REPLACE SECRET duckdb_gcs (TYPE gcs, KEY_ID {quote(key_id)}, SECRET {quote(secret)})""")
    con.execute("SET TimeZone='UTC'")
    if threads is not None:
        if threads <= 0: raise ValueError("--threads must be positive")
        con.execute(f"PRAGMA threads={int(threads)}")

# Function to read the shared minute-level Parquet
def load_minute_data(con, path):
    if not path.startswith("gs://") or not path.lower().endswith(".parquet"):
        raise ValueError("Input must be the GCS stock_combined.parquet object")

    # stock_combined.parquet's columns: name, date, open, high, low, close, volume.
    con.execute("""
        CREATE OR REPLACE TEMP TABLE minute_input AS
        SELECT
            trim(CAST(name AS VARCHAR)) AS symbol,
            try_cast(CAST(date AS VARCHAR) AS TIMESTAMP) AS ts,
            try_cast(CAST(open AS VARCHAR) AS DOUBLE) AS open,
            try_cast(CAST(high AS VARCHAR) AS DOUBLE) AS high,
            try_cast(CAST(low AS VARCHAR) AS DOUBLE) AS low,
            try_cast(CAST(close AS VARCHAR) AS DOUBLE) AS close,
            try_cast(CAST(volume AS VARCHAR) AS DOUBLE) AS volume
        FROM read_parquet(?)
        WHERE name IS NOT NULL
        """, [path])
    return int(con.execute("SELECT COUNT(*) FROM minute_input").fetchone()[0])

# Function to convert every stock's minute into daily OHLCV row.
def build_daily(con):
    # SQL calculates daily OHLCV, previous close, price_change and change_pc.
    con.execute("""
        CREATE OR REPLACE TEMP TABLE daily_all AS
        WITH daily AS (
            SELECT
                symbol, CAST(ts AS DATE) AS date,
                arg_min(open, ts) AS open,
                max(high) AS high,
                min(low) AS low,
                arg_max(close, ts) AS close,
                sum(volume) AS volume,
                count(*) AS minute_rows
            FROM minute_input
            WHERE ts IS NOT NULL
            GROUP BY symbol, CAST(ts AS DATE)
        ), previous AS (
            SELECT
                daily.*,
                lag(close) OVER (
                    PARTITION BY symbol ORDER BY date
                ) AS prev_close
            FROM daily
        )
        SELECT
            symbol, date, open, high, low, close, volume, minute_rows,
            CASE
                WHEN prev_close IS NULL THEN 'None'
                WHEN close > prev_close THEN 'Increased'
                WHEN close < prev_close THEN 'Decreased'
                ELSE 'None'
            END AS price_change,
            CASE
                WHEN prev_close IS NULL OR prev_close = 0 THEN NULL::DOUBLE
                ELSE round((close - prev_close) / prev_close * 100.0, 2)
            END AS change_pc
        FROM previous
    """)


# Function to take all stock-price changes for a month and calculate the summary.
def process_month(con, month):
    # SQL below is the one stock's analysis.
    con.execute("""
        CREATE OR REPLACE TEMP TABLE month_daily AS
        SELECT *
        FROM daily_all
        WHERE EXTRACT(MONTH FROM date) = ?
        """, [month],)
    con.execute("""
        INSERT INTO stock_analysis
        SELECT
            symbol,
            CAST(? AS INTEGER) AS month,
            COUNT(change_pc) AS n_days,
            AVG(change_pc) AS avg_change_pc,
            STDDEV_SAMP(change_pc) AS std_change_pc,
            AVG(
                CASE
                    WHEN change_pc IS NOT NULL
                    THEN CAST(change_pc > 0 AS DOUBLE)
                END
            ) AS pct_up_days
        FROM month_daily
        GROUP BY symbol
        HAVING COUNT(change_pc) > 0
        """, [month],)

# Function use to load the data, loop over every stock, then aggregate all stocks.
def run_once(con, path):
    input_rows = load_minute_data(con, path)
    build_daily(con)
    # output file for one monthly analysis per stock & month.
    con.execute("""
        CREATE OR REPLACE TEMP TABLE stock_analysis ( -- Per-stock analysis.
            symbol VARCHAR, month INTEGER, n_days BIGINT,
            avg_change_pc DOUBLE, std_change_pc DOUBLE, pct_up_days DOUBLE
        )
        """)
    # find each calendar month
    months = con.execute("""
        SELECT DISTINCT CAST(EXTRACT(MONTH FROM date) AS INTEGER) AS month
        FROM daily_all
        WHERE date IS NOT NULL
        ORDER BY month
    """).fetchall()
    for (month,) in months: process_month(con, month)
    return input_rows, con.execute(FINAL_SQL).fetchall()

# Function use to write daily rows, per-stock metrics, & overall monthly result.
def write_outputs(con, output_dir):
    output_dir.mkdir(parents=True, exist_ok=True)
    con.execute(
        f"COPY (SELECT * FROM daily_all ORDER BY symbol, date) TO "
        f"{quote(str(output_dir / 'daily.parquet'))} "
        "(FORMAT PARQUET, COMPRESSION ZSTD, OVERWRITE_OR_IGNORE TRUE)"
    )
    con.execute(
        f"COPY (SELECT symbol, month, n_days, ROUND(avg_change_pc, 4) "
        f"AS avg_change_pc, ROUND(std_change_pc, 4) AS std_change_pc, "
        f"ROUND(pct_up_days, 4) AS pct_up_days "
        f"FROM stock_analysis ORDER BY symbol, month) TO "
        f"{quote(str(output_dir / 'analysis_by_stock.tsv'))} "
        "(HEADER, DELIMITER '\\t', OVERWRITE_OR_IGNORE TRUE)"
    )
    con.execute(
        f"COPY ({FINAL_SQL}) TO {quote(str(output_dir / 'analysis.tsv'))} "
        "(HEADER, DELIMITER '\\t', OVERWRITE_OR_IGNORE TRUE)"
    )

# Function to read file (CSV or TSV) to extract and return values for comparison.
def read_expected(path):
    if path is None:
        return None
    with open(path, "r", newline="", encoding="utf-8") as handle:
        first = handle.readline()
        handle.seek(0)
        rows = csv.DictReader(handle, delimiter="\t" if "\t" in first else ",")
        return [
            (
                int(row.get("month", row.get("month_num", "0"))),
                int(float(row["n_days"])) if row.get("n_days") else None,
                float(row.get("avg_change_pc", row.get("avg_change", "nan"))),
            )
            for row in rows
        ]

# Function to compare final monthly averages and available day counts.
def differences(actual, expected):
    left = {int(row[0]): row for row in actual}
    right = {int(row[0]): row for row in expected}
    count = 0
    for month in set(left) | set(right):
        if month not in left or month not in right:
            count += 1
            continue
        if right[month][1] is not None and int(left[month][2]) != right[month][1]:
            count += 1
        elif abs(float(left[month][3]) - float(right[month][2])) > 1e-4:
            count += 1
    return count

# Function use as benchmark to time results and store it localy.
def write_benchmark(path, rows, overwrite):
    path = Path(path)
    old = []
    if path.exists() and not overwrite and path.stat().st_size:
        with path.open("r", newline="", encoding="utf-8") as handle:
            old = list(csv.DictReader(handle))
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=BENCHMARK_FIELDS)
        writer.writeheader()
        for row in old + rows:
            writer.writerow({field: row.get(field, "") for field in BENCHMARK_FIELDS})

# Main Function to execute the duckdb_pipeline.
def main():
    # parse GCS path, ensure benchmark works & output locally.
    args = parse_args()
    if args.benchmark_runs < 1:
        raise ValueError("--benchmark-runs must be positive")
    if args.output_dir.startswith("gs://") or args.benchmark_output.startswith("gs://"):
        raise ValueError("DuckDB outputs must be local driver paths")

    import duckdb
    output_dir = Path(args.output_dir)
    input_bytes = args.input_bytes if args.input_bytes is not None else -1
    # first in-memory DuckDB connection.
    con = duckdb.connect(":memory:")
    try:
        configure(con, args.threads)
        input_rows, baseline = run_once(con, args.data_path)
        write_outputs(con, output_dir)
    finally:
        con.close()

    # optionally, compare the first result with an external expected result.
    expected = read_expected(args.expected_result)
    if expected is not None:
        mismatch = differences(baseline, expected)
        comparison = Path(args.comparison_output)
        comparison.parent.mkdir(parents=True, exist_ok=True)
        comparison.write_text(
            f"differing_rows={mismatch}\nresult_verified={mismatch == 0}\n",
            encoding="utf-8",
        )

    # fresh connections make the repeated timing runs independent.
    timings = []
    for run_number in range(1, args.benchmark_runs + 1):
        con = duckdb.connect(":memory:")
        try:
            configure(con, args.threads)
            started = time.perf_counter()
            _, actual = run_once(con, args.data_path)
            elapsed = time.perf_counter() - started
        finally:
            con.close()
        target = expected if expected is not None else baseline
        # store all fields just aas PA3 benchmark report.
        timings.append({
            "approach": "duckdb", "run": run_number, "input_rows": input_rows,
            "input_bytes": input_bytes, "elapsed_seconds": round(elapsed, 4),
            "output_rows": len(actual),
            "result_verified": differences(actual, target) == 0,
            "job_id": f"duckdb-run{run_number}",
        })

    write_benchmark(args.benchmark_output, timings, args.overwrite_benchmark)
    print(f"input_rows={input_rows} final_result_rows={len(baseline)}")
    for row in timings:
        print(
            f"duckdb run {row['run']}: "
            f"{row['elapsed_seconds']}s verified={row['result_verified']}"
        )
    return 0

if __name__ == "__main__":
    raise SystemExit(main())