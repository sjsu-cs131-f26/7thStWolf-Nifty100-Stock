COPY (
  WITH compared AS (
    SELECT
      CAST(substr(timestamp, 6, 2) AS INTEGER) AS month,
      price_change AS price_change
    FROM read_parquet('work/analysis_ready.parquet')
    WHERE price_change IN ('increased', 'decreased')
  )
  SELECT
    month AS month,
    COUNT(*) FILTER (WHERE price_change = 'increased') AS increase_count,
    COUNT(*) AS compared_rows,
    printf('%.4f',
      CAST(COUNT(*) FILTER (WHERE price_change = 'increased') AS DOUBLE) / COUNT(*)
    ) AS increase_ratio
  FROM compared
  GROUP BY month
  ORDER BY month ASC
) TO 'out/duckdb_parquet_result.tsv' (HEADER, DELIMITER '\t');

