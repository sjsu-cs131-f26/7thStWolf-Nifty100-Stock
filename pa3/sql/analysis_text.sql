COPY (
  WITH compared AS (
    SELECT
      CAST(substr(timestamp, 6, 2) AS INTEGER) AS month,
      price_change AS price_change
    FROM read_csv(
      'work/analysis_ready.tsv',
      delim = '\t',
      header = true,
      columns = {
        'symbol': 'VARCHAR',
        'timestamp': 'VARCHAR',
        'close': 'DOUBLE',
        'price_change': 'VARCHAR'
      }
    )
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
) TO 'out/duckdb_text_result.tsv' (HEADER, DELIMITER '\t');

