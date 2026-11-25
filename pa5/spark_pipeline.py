import argparse
import re
import sys
import time

from pyspark.sql import SparkSession
from pyspark.sql import functions as F
from pyspark.sql.window import Window

# Command-line arguments
def parse_args():
    parser = argparse.ArgumentParser(
    description="PA5 full-dataset PySpark stock analysis"
)

    parser.add_argument(
        "--input",
        required=True,
        help="GCS folder containing the stock CSV files"
    )

    parser.add_argument(
        "--output",
        required=True,
        help="GCS folder for prepared data and analysis results"
    )

    parser.add_argument(
        "--shuffle-partitions",
        type=int,
        default=32,
        help="Number of Spark shuffle partitions"
    )

    return parser.parse_args()

# Spark session
def create_spark_session(shuffle_partitions):
    spark = (
        SparkSession.builder
        .appName("PA5-Nifty100-Stock-Analysis")
        .config("spark.sql.shuffle.partitions", str(shuffle_partitions))
        .config("spark.sql.session.timeZone", "UTC")
        .getOrCreate()
    
    )

    return spark

def load_minute_data(spark, input_path):

    print(f"Reading Parquet dataset: {input_path}")

    df = spark.read.parquet(input_path)

    # Check if all required columns exist
    required_columns = ["date", "open", "high", "low", "close", "volume"]

    missing = [
        column for column in required_columns
        if column not in df.columns
    ]

    missing = [c for c in required_columns if c not in df.columns]

    if missing:
        raise ValueError(f"Missing required columns: {missing}")

    return df.select(*required_columns)

# Convert one stock's minute-level records into daily open, high, low, close, volume data
# Calculate price change (change_pc) using the previous trading day's close
def convert_stock_to_daily(stock_data):

    # Convert timestamps and numeric columns
    stock_data = (
        stock_data
        .withColumn("ts", F.to_timestamp("date"))
        .withColumn("day", F.to_date("ts"))
        .withColumn("open", F.col("open").cast("double"))
        .withColumn("high", F.col("high").cast("double"))
        .withColumn("low", F.col("low").cast("double"))
        .withColumn("close", F.col("close").cast("double"))
        .withColumn("volume", F.col("volume").cast("double"))
    )

    # Convert minute records into one daily record
    daily = (
        stock_data
        .groupBy("name", "day")
        .agg(
            F.min_by("open", "ts").alias("open"),
            F.max("high").alias("high"),
            F.min("low").alias("low"),
            F.max_by("close", "ts").alias("close"),
            F.sum("volume").alias("volume"),
            F.count("*").alias("minute_rows")
        )
        .withColumnRenamed("day", "date")
    )

    # Calculate percentage change from previous trading day
    window = Window.partitionBy("name").orderBy("date")

    daily = daily.withColumn(
        "prev_close",
        F.lag("close").over(window)
    )

    daily = (
        daily
        .withColumn(
            "price_change",
            F.when(F.col("prev_close").isNull(), "None")
            .when(F.col("close") > F.col("prev_close"), "Increased")
            .when(F.col("close") < F.col("prev_close"), "Decreased")
            .otherwise("None")
        )
        .withColumn(
            "change_pc",
            F.when(
                F.col("prev_close").isNull() |
                (F.col("prev_close") == 0),
                None
            ).otherwise(
                F.round(
                    (F.col("close") - F.col("prev_close"))
                    / F.col("prev_close") * 100,
                    2
                )
            )
        )    
        .drop("prev_close", "ts")
    )
    return daily

# Analyze one stock's daily percentage changes by calendar month
def analyze_stock(daily_data):

    monthly = (
        daily_data
        .withColumn("month_num", F.month("date"))
        .groupBy("name", "month_num")
        .agg(
            F.count("change_pc").alias("n_days"),
            F.round(F.avg("change_pc"), 4).alias("avg_change_pc"),
            F.round(F.stddev("change_pc"), 4).alias("std_change_pc"),
            F.round(
                F.avg(
                    F.when(
                        F.col("change_pc").isNotNull(),
                        (F.col("change_pc") > 0).cast("double")
                    )
                ),
                4
            ).alias("pct_up_days")
        )
        .orderBy("name", "month_num")
    )

    return monthly

# Main function
def main():
    args = parse_args()
    spark = create_spark_session(args.shuffle_partitions)

    print("PA5 Spark pipeline started!")
    print("Input:", args.input)
    print("Output:", args.output)
    print("Shuffle partitions:", args.shuffle_partitions)

    try:
        # Load all minute-level stock records
        minute_data = load_minute_data(spark, args.input)

        print("Raw minute-level data loaded.")
        minute_data.printSchema()

        total_minute_records = minute_data.count()
        print("total minute records:", total_minute_records)

        # Partition data by stock name
        minute_data = minute_data.repartition(args.shuffle_partitions, "name")

        # Get the list of stock names
        stock_names = [
            row["name"]
            for row in minute_data.select("name").distinct().collect()
        ]

        print("Number of stocks:", len(stock_names))

        # Process each stock individually
        daily_results = []
        analysis_results = []

        for stock_name in stock_names:
            print("Processing stock:", stock_name)

            # Get minute records for current stock
            one_stock = minute_data.filter(
                F.col("name") == stock_name
            )

            # Convert minute records into daily records
            daily_stock = convert_stock_to_daily(one_stock)

            # Analyze daily percentage changes
            monthly_stock = analyze_stock(daily_stock)

            # Save the results for combining after the loop
            daily_results.append(daily_stock)
            analysis_results.append(monthly_stock)

        # Combine results from all stocks
        if daily_results:
            all_daily_data = daily_results[0]

            for result in daily_results[1:]:
                all_daily_data = all_daily_data.unionByName(result)

            all_daily_data = all_daily_data.orderBy("name", "date")

            print("Combined daily data:")
            all_daily_data.show(10, truncate=False)

             # Save daily level prepared data to GCS
            daily_output_path = args.output.rstrip("/") + "/daily_data"
            all_daily_data.write \
                .mode("overwrite") \
                .parquet(daily_output_path)

        if analysis_results:
            final_analysis = analysis_results[0]

            for result in analysis_results[1:]:
                final_analysis = final_analysis.unionByName(result)

            final_analysis = final_analysis.orderBy("name", "month_num")

            print("Final monthly analysis:")
            final_analysis.show(30, truncate=False)

            print("Total monthly analysis rows:", final_analysis.count())

            # Save final monthly analysis as CSV
            analysis_output_path = args.output.rstrip("/") + "/monthly_analysis"
            final_analysis.coalesce(1).write \
                .option("header", True) \
                .mode("overwrite") \
                .csv(analysis_output_path)

    finally:
        spark.stop()


if __name__ == "__main__":
    main()