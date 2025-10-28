DROP DATABASE IF EXISTS adventureworks_dw;
CREATE DATABASE adventureworks_dw  DEFAULT CHARACTER SET utf8mb4  DEFAULT COLLATE utf8mb4_general_ci;
USE adventureworks_dw;

DROP TABLE IF EXISTS dim_date;
CREATE TABLE dim_date(
  date_key INT NOT NULL PRIMARY KEY,
  full_date DATE NULL,
  date_name CHAR(11) NOT NULL,
  date_name_us CHAR(11) NOT NULL,
  date_name_eu CHAR(11) NOT NULL,
  day_of_week TINYINT NOT NULL,
  day_name_of_week CHAR(10) NOT NULL,
  day_of_month TINYINT NOT NULL,
  day_of_year SMALLINT NOT NULL,
  weekday_weekend CHAR(10) NOT NULL,
  week_of_year TINYINT NOT NULL,
  month_name CHAR(10) NOT NULL,
  month_of_year TINYINT NOT NULL,
  is_last_day_of_month CHAR(1) NOT NULL,
  calendar_quarter TINYINT NOT NULL,
  calendar_year SMALLINT NOT NULL,
  calendar_year_month CHAR(10) NOT NULL,
  calendar_year_qtr CHAR(10) NOT NULL,
  fiscal_month_of_year TINYINT NOT NULL,
  fiscal_quarter TINYINT NOT NULL,
  fiscal_year INT NOT NULL,
  fiscal_year_month CHAR(10) NOT NULL,
  fiscal_year_qtr CHAR(10) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

DROP TABLE IF EXISTS dim_product;
CREATE TABLE dim_product (
  product_key INT AUTO_INCREMENT PRIMARY KEY,
  product_id INT NOT NULL,
  product_name VARCHAR(200),
  color VARCHAR(50),
  size VARCHAR(50),
  category_name VARCHAR(100),
  subcategory_name VARCHAR(100),
  UNIQUE KEY (product_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

DROP TABLE IF EXISTS dim_customer;
CREATE TABLE dim_customer (
  customer_key INT AUTO_INCREMENT PRIMARY KEY,
  customer_id INT NOT NULL,
  territory_id INT NULL,
  account_number VARCHAR(25) NULL,
  customer_type VARCHAR(20) NOT NULL DEFAULT 'Unknown',
  UNIQUE KEY (customer_id)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

DROP TABLE IF EXISTS fact_sales;
CREATE TABLE fact_sales (
  sales_key BIGINT AUTO_INCREMENT PRIMARY KEY,
  date_key INT NOT NULL,
  product_key INT  NOT NULL,
  customer_key INT  NOT NULL,
  sales_order_id INT  NOT NULL,
  sales_order_detail_id INT NOT NULL,
  order_qty INT  NOT NULL,
  unit_price DECIMAL(19,4) NOT NULL,
  unit_price_discount DECIMAL(19,6) NOT NULL,
  discount_amt DECIMAL(19,6) NOT NULL,
  line_total DECIMAL(19,6) NOT NULL,
  KEY (date_key),
  KEY (product_key),
  KEY (customer_key)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- 

USE adventureworks_dw;

DELIMITER //
DROP PROCEDURE IF EXISTS PopulateDateDimension //
CREATE PROCEDURE PopulateDateDimension(BeginDate DATETIME, EndDate DATETIME)
BEGIN
  DECLARE LastDayOfMon CHAR(1);
  DECLARE FiscalYearMonthsOffset INT DEFAULT 6;
  DECLARE DateCounter DATETIME;
  DECLARE FiscalCounter DATETIME;

  SET DateCounter = BeginDate;

  WHILE DateCounter <= EndDate DO
    SET FiscalCounter = DATE_ADD(DateCounter, INTERVAL FiscalYearMonthsOffset MONTH);

    IF MONTH(DateCounter) = MONTH(DATE_ADD(DateCounter, INTERVAL 1 DAY)) THEN
      SET LastDayOfMon = 'N';
    ELSE
      SET LastDayOfMon = 'Y';
    END IF;

    INSERT INTO adventureworks_dw.dim_date (
      date_key, full_date, date_name, date_name_us, date_name_eu, day_of_week,
      day_name_of_week, day_of_month, day_of_year, weekday_weekend, week_of_year,
      month_name, month_of_year, is_last_day_of_month, calendar_quarter,
      calendar_year, calendar_year_month, calendar_year_qtr,
      fiscal_month_of_year, fiscal_quarter, fiscal_year, fiscal_year_month, fiscal_year_qtr
    )
    VALUES (
      (YEAR(DateCounter)*10000)+(MONTH(DateCounter)*100)+DAY(DateCounter),
      DateCounter,
      CONCAT(CAST(YEAR(DateCounter) AS CHAR(4)),'/',DATE_FORMAT(DateCounter,'%m'),'/',DATE_FORMAT(DateCounter,'%d')),
      CONCAT(DATE_FORMAT(DateCounter,'%m'),'/',DATE_FORMAT(DateCounter,'%d'),'/',CAST(YEAR(DateCounter) AS CHAR(4))),
      CONCAT(DATE_FORMAT(DateCounter,'%d'),'/',DATE_FORMAT(DateCounter,'%m'),'/',CAST(YEAR(DateCounter) AS CHAR(4))),
      DAYOFWEEK(DateCounter),
      DAYNAME(DateCounter),
      DAYOFMONTH(DateCounter),
      DAYOFYEAR(DateCounter),
      CASE WHEN DAYNAME(DateCounter) IN ('Saturday','Sunday') THEN 'Weekend' ELSE 'Weekday' END,
      WEEKOFYEAR(DateCounter),
      MONTHNAME(DateCounter),
      MONTH(DateCounter),
      LastDayOfMon,
      QUARTER(DateCounter),
      YEAR(DateCounter),
      CONCAT(CAST(YEAR(DateCounter) AS CHAR(4)),'-',DATE_FORMAT(DateCounter,'%m')),
      CONCAT(CAST(YEAR(DateCounter) AS CHAR(4)),'Q',QUARTER(DateCounter)),
      MONTH(FiscalCounter),
      QUARTER(FiscalCounter),
      YEAR(FiscalCounter),
      CONCAT(CAST(YEAR(FiscalCounter) AS CHAR(4)),'-',DATE_FORMAT(FiscalCounter,'%m')),
      CONCAT(CAST(YEAR(FiscalCounter) AS CHAR(4)),'Q',QUARTER(FiscalCounter))
    );

    SET DateCounter = DATE_ADD(DateCounter, INTERVAL 1 DAY);
  END WHILE;
END //
DELIMITER ;

TRUNCATE TABLE adventureworks_dw.dim_date;

CALL adventureworks_dw.PopulateDateDimension('1998-01-01','2014-12-31');

SELECT COUNT(*) AS dim_rows,
       MIN(full_date) AS min_date,
       MAX(full_date) AS max_date
FROM adventureworks_dw.dim_date;


TRUNCATE TABLE dim_product;

INSERT INTO dim_product (product_id, product_name, color, size, category_name, subcategory_name)
SELECT  p.ProductID, p.Name, p.Color, p.Size, pc.Name, psc.Name
FROM adventureworks.product p
LEFT JOIN adventureworks.productsubcategory psc ON p.ProductSubcategoryID = psc.ProductSubcategoryID
LEFT JOIN adventureworks.productcategory pc ON psc.ProductCategoryID = pc.ProductCategoryID;

SELECT 'dim_product' t, COUNT(*) c FROM dim_product;

TRUNCATE TABLE dim_customer;

INSERT INTO dim_customer (customer_id, territory_id, account_number, customer_type)
SELECT c.CustomerID, c.TerritoryID, c.AccountNumber, 'Unknown'
FROM adventureworks.customer c;

SELECT 'dim_customer', COUNT(*) FROM dim_customer;

TRUNCATE TABLE fact_sales;

INSERT INTO fact_sales
  (date_key, product_key, customer_key,
   sales_order_id, sales_order_detail_id,
   order_qty, unit_price, unit_price_discount, discount_amt, line_total)
SELECT
  DATE_FORMAT(h.orderdate, '%Y%m%d') + 0 AS date_key,
  dp.product_key,
  dc.customer_key,
  d.salesorderid,
  d.salesorderdetailid,
  d.orderqty,
  d.unitprice,
  d.unitpricediscount,
  (d.unitprice * d.orderqty) * d.unitpricediscount AS discount_amt,
  (d.unitprice * d.orderqty) * (1 - d.unitpricediscount) AS line_total
FROM adventureworks.salesorderdetail d
JOIN adventureworks.salesorderheader h ON h.salesorderid = d.salesorderid
LEFT JOIN dim_product  dp ON dp.product_id  = d.productid
LEFT JOIN dim_customer dc ON dc.customer_id = h.customerid
WHERE dp.product_key IS NOT NULL
  AND dc.customer_key IS NOT NULL;

SELECT COUNT(*) AS fact_rows FROM fact_sales;

ALTER TABLE dim_date MODIFY date_key INT;
ALTER TABLE fact_sales MODIFY date_key INT;

SELECT COUNT(*) AS fact_rows,
       SUM(dd.date_key IS NULL) AS no_match_rows
FROM fact_sales f
LEFT JOIN dim_date dd ON dd.date_key = f.date_key;

SELECT MIN(dd.full_date) AS min_date, MAX(dd.full_date) AS max_date
FROM fact_sales f
JOIN dim_date dd ON dd.date_key = f.date_key;

SELECT
  dd.calendar_year AS year,
  dp.category_name,
  ROUND(SUM(f.line_total), 2) AS revenue_usd,
  COUNT(*) AS line_count
FROM fact_sales f
JOIN dim_date    dd ON dd.date_key    = f.date_key
JOIN dim_product dp ON dp.product_key = f.product_key
GROUP BY dd.calendar_year, dp.category_name
ORDER BY year, revenue_usd DESC;

SELECT * FROM dim_customer LIMIT 10;
SELECT * FROM dim_date LIMIT 10;
SELECT * FROM dim_product LIMIT 10;
SELECT * FROM fact_sales LIMIT 10;

SHOW TABLES;

SELECT product_id, color, size, tags_json 
FROM dim_product 
WHERE product_id IN (707, 708, 709);
