# stock-earnings-buy-or-sell

## Determine if a Stock Should Be Bought or Sold After Earnings Report Release ## 

### Source Dataset ###

This project uses a Dataset from kaggle.com titled “[US Historical Stock prices with earnings data](https://www.kaggle.com/tsaustin/us-historical-stock-prices-with-earnings-data?select=stocks_latest "US Historical Stock prices with earnings data")”.

### Objectives ###

Use historic stock market data and earnings reports along with recent trends in a stock’s behavior to determine whether to buy or sell a stock after an earnings report is released. 

### Design ###

The original dataset contains four .csv files:
	
	1. dividends_latest.csv
	2. earnings_latest.csv
	3. stock_prices_latest.csv
	4. dataset_summary.csv

This project uses ‘earnings_latest.csv’, and ‘stock_prices_latest.csv’ for its raw data. The project is divided into three steps. The first step is processing and cleaning of the raw data. This step uses Weka’s processing filters. In addition to Weka, the data is cleaned and converted into nominal data types using a MySQL database. The second step is the application of a Naive Bayes model built from a cleaned dataset. Finally, the model is analyzed for effectiveness in the third step.

#### *Constraints:* ####

Earnings Reports are either released after market close, before market open, or during market hours. Due to attribute scarcity for the latter two scenarios, the training sets for this code only include tuples for Earnings Reports that are released after market close.

#### *Fields:* ####

**symbol** — Represents the stock market ticker symbol

**month** — Represents the numerical month when the Earnings Report was released. Should be converted to nominal data, as numerical metrics will be meaningless.

**recent_volatility** — This nominal value is calculated using two metrics. First, the standard deviation is calculated from the closing stock price for the two weeks immediately before the Earnings Report (std_dev_recent). Second, the standard deviation is calculated from the closing stock price for about a week after the previous Earnings Report (about 80 days prior to this Earnings Report) up to two weeks before this Earnings Report (std_dev_less_recent). If std_dev_recent is less than or equal to std_dev_less_recent, recent_volatility is set to LOW, otherwise it is set to HIGH.

**earnings_status** — Indicates whether the Earnings Report’s Earnings Per Share MISSED or MET expectations.

**two_week_trend** — This nominal value indicates whether the closing value the day before the Earnings Report is less than or greater than the closing value two weeks before the Earnings Report. If the more recent closing value is greater, two_week_trend is set to UP, otherwise it is set to DOWN.

**buy_or_sell** — Class field has possible values of BUY or SELL. The class is labeled BUY if the closing price the day after the Earnings Report is greater than the price at close the day before the Earnings Report. Otherwise, the class is labeled as SELL.

### Procedure ###

#### *Step 1: Data Processing and Cleaning* ####

1. Multiple .csv files must be processed, integrated, cleaned, and converted to nominal data types. For this we will create a MySQL database to house the raw data that will be imported in an accessible relational structure.



PHOTO <create-database>
PHOTO <create-table-earnings>
PHOTO <create-table-stock-prices>



2. In Weka, open the file ‘earnings_latest.csv’, which should can be downloaded from kaggle.com.
3.  Under **Filter**, click **Choose**.
4. Find the SubsetByExpression filter, and select it.
5. Click to the right of the **Choose** button. In the popup window, next to the box titled ‘expression’, type **(ATT1 is ‘MSFT’)**. Click **OK**. 
Note: For this example, the stock symbol for Microsoft (MSFT) is used, but any stock symbol with valid earnings reports and stock data can be used.
6. Under **Attributes**, select the dialog box for ‘symbol’.
7. Click **Apply** in **Filter**. This filters out all tuples that do not have the symbol ‘MSFT’.
8. In the top right hand corner, click **Save**. Save the file to an accessible directory titled ‘MSFT_earnings_latest.csv’.

Repeat steps 2-8 for ‘stock_prices_latest.csv’. Save the new file as ‘MSFT_stock_prices_latest.csv’ in the same directory as ‘MSFT_earnings_latest.csv’.
 
9. Load both newly created .csv files into the MySQL database.


PHOTO <load-infile-earnings>
PHOTO <load-infile-stocks>	
	

10. Create stored procedures 



PHOTO <create-procedures>	





11. Call stored procedures for stock symbol ‘MSFT’. Calling these procedures creates the tables Volatility, EarningsStatus, TwoWeekTrends, and BuyOrSell (it also deletes them if they previously exist). These tables will be populated with nominal values for each earnings report based on stock data before that earnings report and stock data after the previous earnings report. [ EarningsReport1 **StockData2 EarningsReport2** ] For more information on how these nominal fields are aggregated, see Fields section.





PHOTO <call-procedures>




12. Using a GUI SQL Editor, run the query to get processed, nominal fields. Using a GUI SQL Editor rather than a command line SQL interface for this step will make it easier to save the query results to a .csv file, which will be needed in the next step.


PHOTO <main-query>
	
	
13. Export the results of the query as a .csv file. This file will be used as the training set.
14. In Weka, Open the .csv file that contains the results of the query (the trainings set).
15. In **Filter**, select the NumericToNominal filter. 
16. In **Attributes**, check the dialog box for ‘month’. Click **Apply** in **Filter**.

The data is now processed! It is time to run the Naive Bayes Classifier.

Step 2: Naive Bayes Classifier

1. Select the Classify tab in the top left corner.
2. In Classifier, click Choose.
3. Select NaiveBayes.
4. In Test options, click the radio button for Cross-validation. Set Folds to some value greater than 0.
5. Click Start.

Step 3: Model Analysis

For the Microsoft (MSFT) stock symbol’s cleaned dataset, there were a total of 21 tuples that each correspond to nominal data for an Earnings Report. 21 tuples is not a very large number for a training set. With this in mind, cross-validation is used to rotate the test set k times (k folds). This allows each k group to be withheld from training the model, and used as the test set. 

Metrics based on the aggregate confusion matrix for MSFT:

Sensitivity: 33% — This metric describes where the tuple was classified by the model as Sell, and was correctly classified. 

Specificity: 86.6% — This metric describes where the tuple was classified by the model as Buy, and was correctly classified.

Accuracy: 71.4% — This metric describes how often the tuples were correctly classified.

Misclassification rate: 28.6% — This metric describes how often the tuples were incorrectly classified.

	Based on the sensitivity and specificity metrics, it appears that the Model is much better at predicting when to Buy after an Earnings Report than it is at predicting when to Sell. The dataset is very small, and there are only six instances in the training set where the class variable is Sell. This is a class imbalance problem, and may be solved by finding more usable data for MSFT. Another alternative is to expand the training set to not only include MSFT tuples, but also include tuples for symbols that have a high covariance with MSFT.
	For the training set, the class is labeled Buy if the closing price the day after the Earnings Report is greater than the price at close the day before the Earnings Report. Otherwise, the class is labeled as Sell. This model is based on the assumption that the price at which the stock is Bought on the day after the Earnings Report is equal to the price at which the stock closed on the previous day. In practice, this is rarely the case. Stock prices fluctuate in after hours and pre-market hours. In order to better account for this, it may be better to compare the open price on the day after the Earnings Report to the closing price for the same day. Alternatively, it may also be beneficial to compare the open price for the day after the Earnings Report to the Closing Price some days later.

References

https://www.kaggle.com/tsaustin/us-historical-stock-prices-with-earnings-data?select=stocks_latest







