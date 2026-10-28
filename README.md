# Stock Analysis of Nifty 100 Index


## Team Members of The 7th St Wolf
| Name | Sprint 1 | Sprint 2 | Sprint 3 | Sprint 4 | Sprint 5 |
|----------|----------|----------|----------|----------|----------|
| Devarsh Shroff | PM  | DE  | DS  | DE  | DS  |
| Vakeesan Moorthy  | DS  | PM  | DE  | DE  | DE |
| Rishil Nilesh Patel  | DE  | DE  | DE  | DS  | PM  |
| Jeremy Lim  | DE | DE | DS | PM  | DE |
| Aydan Kaneshiro  | DE  | DS  | PM  | DE | DE |


## Dataset Choice
The dataset chosen is the Nifty 100 1-Minute Dataset. It is composed of the top 100 stocks in India, which are part of the Nifty Index.
It is composed of around 100 CSV files, with each file being associated with one of the stocks that are part of the Nifty 100 Index.
Each CSV file is composed of stock info (DateTime, Open, Low, High, Close, Volume) for every minute from February 2015 to April 2026.

## Product Vision

Build a short-term Nifty 100 price prediction engine with confidence ratings, laying the groundwork to link market shifts with real-world news.

Our final goal is the creation of a pipeline that does the following:
* Takes in a Stock Name
* Finds the Average value of open, low, high, close and volume of each day via duckdb. Creates the feature "Price Increase" as the Target.
* Trains a XGBOOST or Neural Network at looks at a 3 Month sliding window to predict the next day.
* Returns a prediction of wheatear or not price will increase the next day along with a confidence value.

Realistically, next day prediction of stock will struggle to get more than 55-60% accuracy, with just stock data and no other information such as news. 
