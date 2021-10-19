CREATE DATABASE STOCKS;
USE STOCKS;

CREATE TABLE Earnings (
  id INT NOT NULL AUTO_INCREMENT,
  symbol VARCHAR(10) NOT NULL DEFAULT "NULL",
  e_date DATE NOT NULL DEFAULT "1999-12-31",
  qtr VARCHAR(10) NOT NULL DEFAULT "NULL",
  eps_est VARCHAR(255) NOT NULL DEFAULT "NULL",
  eps VARCHAR(255) NOT NULL DEFAULT "NULL",
  release_time VARCHAR(255) NOT NULL DEFAULT "NULL",
  PRIMARY KEY (id)
);

CREATE TABLE Stock_Prices (
  id INT NOT NULL AUTO_INCREMENT,
  symbol VARCHAR(10) NOT NULL DEFAULT "NULL",
  s_date DATE NOT NULL DEFAULT "1999-12-31",
  open VARCHAR(255) NOT NULL DEFAULT "NULL",
  high VARCHAR(255) NOT NULL DEFAULT "NULL",
  low VARCHAR(255) NOT NULL DEFAULT "NULL",
  close VARCHAR(255) NOT NULL DEFAULT "NULL",
  close_adjusted VARCHAR(255) NOT NULL DEFAULT "NULL",
  volume VARCHAR(255) NOT NULL DEFAULT "NULL",
  split_cofficient VARCHAR(255) NOT NULL DEFAULT "NULL",
  PRIMARY KEY (id)
);

LOAD DATA LOCAL INFILE '<path/to/stock/prices>'
INTO TABLE Stock_Prices
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
IGNORE 1 ROWS (symbol, s_date, open, high, low, close, close_adjusted, volume, split_cofficient);

LOAD DATA LOCAL INFILE '<path/to/stock/earnings>'
INTO TABLE Earnings
FIELDS TERMINATED BY ','
LINES TERMINATED BY '\n'
IGNORE 1 ROWS (symbol, e_date, qtr, eps_est, eps, release_time);

-- calculate recent volatility
drop procedure GetRecentVolatility;

DELIMITER $$

CREATE PROCEDURE GetRecentVolatility(
    IN ticker VARCHAR(10))
BEGIN
    DECLARE temp_recent_std_dev FLOAT;
    DECLARE temp_less_recent_std_dev FLOAT;
    DECLARE temp_e_date DATE;
    DECLARE recent_volatility VARCHAR(255);

    DECLARE bDone INT;
    DECLARE curs CURSOR FOR SELECT e_date FROM Earnings;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET bDone = 1;

    DROP TABLE IF EXISTS Volatility;
    CREATE TABLE IF NOT EXISTS Volatility (
      symbol VARCHAR(10) NOT NULL DEFAULT "NULL",
      e_date DATE NOT NULL DEFAULT "1999-12-31",
      volatility VARCHAR(255),
      PRIMARY KEY(symbol, e_date)
    );

    OPEN curs;

    SET bDone = 0;
    REPEAT
      FETCH curs INTO temp_e_date;

      select stddev(close)
      from Stock_Prices
      where symbol = ticker
      and s_date >= (
        select date_sub(temp_e_date, interval 14 day)
      )
      and s_date <= temp_e_date
      into temp_recent_std_dev;

      select stddev(close)
      from Stock_Prices
      where symbol = ticker
      and s_date < (
        select date_sub(temp_e_date, interval 14 day)
      )
      and s_date >= (
        select date_sub(date_sub(temp_e_date, interval 14 day), interval 66 day)
      )
      into temp_less_recent_std_dev;

      IF (temp_recent_std_dev IS NOT NULL) AND (temp_less_recent_std_dev IS NOT NULL) THEN
        -- calculate recent Volatility
        IF temp_recent_std_dev <= temp_less_recent_std_dev THEN
          SET recent_volatility = "LOW";
        ELSE
          SET recent_volatility = "HIGH";
        END IF;

        -- insert tuple into Volitlity
        INSERT INTO Volatility (symbol, e_date, volatility)
        VALUES (ticker, temp_e_date, recent_volatility);

      END IF;

    UNTIL bDone END REPEAT;

CLOSE curs;

END$$

DELIMITER ;


-- calculate earnings_status
drop procedure GetEarningsStatus;

DELIMITER $$

CREATE PROCEDURE GetEarningsStatus(
    IN ticker VARCHAR(10))
  BEGIN
    DECLARE temp_net_eps FLOAT;
    DECLARE temp_e_date DATE;

    DECLARE bDone INT;
    DECLARE curs CURSOR FOR SELECT e_date FROM Earnings where eps != "NULL" and eps_est != "NULL" and release_time != "NULL";
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET bDone = 1;

    DROP TABLE IF EXISTS EarningsStatus;
    CREATE TABLE IF NOT EXISTS EarningsStatus (
      symbol VARCHAR(10) NOT NULL DEFAULT "NULL",
      e_date DATE NOT NULL DEFAULT "1999-12-31",
      status VARCHAR(255),
      PRIMARY KEY(symbol, e_date)
    );

    OPEN curs;

    SET bDone = 0;
    REPEAT
      FETCH curs INTO temp_e_date;

      select (eps - eps_est)
      from Earnings
      where e_date = temp_e_date
      and symbol = ticker
      into temp_net_eps;

      IF temp_net_eps >= 0 THEN
        INSERT INTO EarningsStatus (symbol, e_date, status)
        VALUES (ticker, temp_e_date, "MET");
      ELSE
        INSERT INTO EarningsStatus (symbol, e_date, status)
        VALUES (ticker, temp_e_date, "MISSED");
      END IF;

    UNTIL bDone END REPEAT;

    CLOSE curs;

END$$

DELIMITER ;


-- calculate two week trends before earnings report
drop procedure GetTwoWeekTrends;

DELIMITER $$

CREATE PROCEDURE GetTwoWeekTrends(
    IN ticker VARCHAR(10))
  BEGIN
    DECLARE temp_prev_day_close FLOAT;
    DECLARE temp_two_weeks_ago_close FLOAT;
    DECLARE temp_close_diff FLOAT;
    DECLARE temp_e_date DATE;

    DECLARE bDone INT;
    DECLARE curs CURSOR FOR SELECT e_date FROM Earnings where eps != "NULL" and eps_est != "NULL" and release_time = "post";
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET bDone = 1;

    DROP TABLE IF EXISTS TwoWeekTrends;
    CREATE TABLE IF NOT EXISTS TwoWeekTrends (
      symbol VARCHAR(10) NOT NULL DEFAULT "NULL",
      e_date DATE NOT NULL DEFAULT "1999-12-31",
      trend VARCHAR(255),
      PRIMARY KEY(symbol, e_date)
    );

    OPEN curs;

    SET bDone = 0;
    REPEAT
      FETCH curs INTO temp_e_date;

      select close
      from Stock_Prices
      where symbol = ticker
      and s_date >= (
        select date_sub(temp_e_date, interval 14 day)
      )
      and s_date <= temp_e_date
      order by s_date
      limit 1
      into temp_two_weeks_ago_close;

      select close
      from Stock_Prices
      where symbol = ticker
      and s_date = temp_e_date
      into temp_prev_day_close;

      SET temp_close_diff = temp_prev_day_close - temp_two_weeks_ago_close;

      IF temp_close_diff >= 0 THEN
        INSERT INTO TwoWeekTrends (symbol, e_date, trend)
        VALUES (ticker, temp_e_date, "UP");
      ELSE
        INSERT INTO TwoWeekTrends (symbol, e_date, trend)
        VALUES (ticker, temp_e_date, "DOWN");
      END IF;

    UNTIL bDone END REPEAT;

    CLOSE curs;

END$$

DELIMITER ;

-- calculate whether stock went up or down the day after earnings report
-- if stock went up, label "BUY", else label "SELL"
drop procedure GetClassBuyOrSell;

DELIMITER $$

CREATE PROCEDURE GetClassBuyOrSell(
    IN ticker VARCHAR(10))
  BEGIN
    DECLARE temp_prev_day_close FLOAT;
    DECLARE temp_next_day_close FLOAT;
    DECLARE temp_close_diff FLOAT;
    DECLARE temp_e_date DATE;

    DECLARE bDone INT;
    DECLARE curs CURSOR FOR SELECT e_date FROM Earnings where eps != "NULL" and eps_est != "NULL" and release_time = "post";
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET bDone = 1;

    DROP TABLE IF EXISTS BuyOrSell;
    CREATE TABLE IF NOT EXISTS BuyOrSell (
      symbol VARCHAR(10) NOT NULL DEFAULT "NULL",
      e_date DATE NOT NULL DEFAULT "1999-12-31",
      outcome VARCHAR(255),
      PRIMARY KEY(symbol, e_date)
    );

    OPEN curs;

    SET bDone = 0;
    REPEAT
      FETCH curs INTO temp_e_date;

      SET temp_next_day_close = NULL;

      select close
      from Stock_Prices
      where symbol = ticker
      and s_date > temp_e_date
      order by s_date
      limit 1
      into temp_next_day_close;

      SET temp_prev_day_close = NULL;

      select close
      from Stock_Prices
      where symbol = ticker
      and s_date = temp_e_date
      into temp_prev_day_close;

      SET temp_close_diff = temp_next_day_close - temp_prev_day_close;

      IF (temp_close_diff is not NULL) THEN
        IF temp_close_diff > 0 THEN
          INSERT INTO BuyOrSell (symbol, e_date, outcome)
          VALUES (ticker, temp_e_date, "BUY");
        ELSE
          INSERT INTO BuyOrSell (symbol, e_date, outcome)
          VALUES (ticker, temp_e_date, "SELL");
        END IF;
      END IF;

    UNTIL bDone END REPEAT;

    CLOSE curs;

END$$

DELIMITER ;

-- populate new tables
call GetRecentVolatility("MSFT");
call GetEarningsStatus("MSFT");
call GetTwoWeekTrends("MSFT");
call GetClassBuyOrSell("MSFT");

-- main query
select Earnings.symbol, month(Earnings.e_date) as month, volatility as recent_volatility,
(EarningsStatus.status) as earnings_status, trend as two_week_trend, outcome as buy_or_sell
from Earnings, Volatility, EarningsStatus, TwoWeekTrends, BuyOrSell
where Earnings.e_date = Volatility.e_date
and Earnings.e_date = EarningsStatus.e_date
and Earnings.e_date = TwoWeekTrends.e_date
and Earnings.e_date = BuyOrSell.e_date
and Earnings.symbol = Volatility.symbol
and Earnings.symbol = EarningsStatus.symbol
and Earnings.symbol = TwoWeekTrends.symbol
and Earnings.symbol = BuyOrSell.symbol
and Earnings.symbol = "MSFT";
