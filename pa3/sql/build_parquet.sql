COPY (
  SELECT
    CAST(symbol AS VARCHAR) AS symbol,
    CAST(timestamp AS VARCHAR) AS timestamp,
    CAST(close AS DOUBLE) AS close,
    CAST(price_change AS VARCHAR) AS price_change
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
) TO 'work/analysis_ready.parquet' (FORMAT PARQUET);

