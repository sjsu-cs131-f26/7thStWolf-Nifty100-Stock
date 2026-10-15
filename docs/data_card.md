# Overview  
* Our dataset was sourced from kaggle at: https://www.kaggle.com/datasets/debashis74017/stock-market-data-nifty-50-stocks-1-min-data.
* Our dataset is not licensed and is considered free domain
* Raw Size: 5.3GB 
* Row Count: 109,521,041
* Format: csv files
* File Organization: The Raw Data is split into 100 CSV files, with each file corresponding to a single stock. After processing, we will merge them all into 1.
* Delimiter: A comma
* Header: 
* * Before Processing: date,open,high,low,close,volume
* * After Processing: name,date,open,high,low,close,volume,price_change,volume_change 

# CMD Used
* To find Raw Size of our data we used: "du -sh raw_data"
* To find total count of all Rows we used: wc -l raw_data/*

# Data Fields Analysis
* name - string, used to find specific stocks
* date - Format of [YYYY-MM-DD HH-MM-SS] -  Data is ordered by date-time in each csv file. 
* open - float - opening price at a specific minute
* high - float - highest price at a specific minute
* low - float - lowest price at a specific minute
* volume - float - Amount of stocks at a specific minute
* price_change - String - How the price has changed from the previous minute. Contains 3 Values: None, Decreased, & Increased
* volume_change - String - How the volume has changed from the previous minute. Contains 3 Values: None, Decreased, & Increased