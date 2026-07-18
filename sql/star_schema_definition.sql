-- Star Schema Definition for Google Merchandise Store Analytics
-- Raw data source: data-to-insights.ecommerce.all_sessions

-- Create staging view for deduplicated transaction records
CREATE OR REPLACE VIEW `valid-keep-465517-q8.ecommerce.stg_transactions` AS
SELECT DISTINCT
  transactionId,
  fullVisitorId,
  PARSE_DATE('%Y%m%d', date) AS transaction_date,
  COALESCE(transactionRevenue, totalTransactionRevenue) / 1000000 AS revenue_usd,
  IFNULL(productRefundAmount, 0) / 1000000 AS refund_usd,
  country,
  city,
  channelGrouping
FROM `data-to-insights.ecommerce.all_sessions`
WHERE transactionId IS NOT NULL;


-- Dimension: Customers
CREATE OR REPLACE TABLE `valid-keep-465517-q8.ecommerce.DimCustomer` AS
SELECT
  FARM_FINGERPRINT(fullVisitorId) AS customer_key,
  fullVisitorId AS visitor_id,
  ARRAY_AGG(channelGrouping ORDER BY date ASC LIMIT 1)[OFFSET(0)] AS primary_channel
FROM `data-to-insights.ecommerce.all_sessions`
GROUP BY fullVisitorId;


-- Dimension: Products
CREATE OR REPLACE TABLE `valid-keep-465517-q8.ecommerce.DimProduct` AS
SELECT
  FARM_FINGERPRINT(productSKU) AS product_key,
  productSKU AS product_sku,
  v2ProductName AS product_name,
  SPLIT(v2ProductCategory, '/')[SAFE_OFFSET(0)] AS main_category,
  COALESCE(SPLIT(v2ProductCategory, '/')[SAFE_OFFSET(1)], 'N/A') AS sub_category_1,
  COALESCE(SPLIT(v2ProductCategory, '/')[SAFE_OFFSET(2)], 'N/A') AS sub_category_2
FROM `data-to-insights.ecommerce.all_sessions`
WHERE productSKU IS NOT NULL
GROUP BY productSKU, v2ProductName, v2ProductCategory;


-- Dimension: Geography / Country
CREATE OR REPLACE TABLE `valid-keep-465517-q8.ecommerce.DimCountry` AS
SELECT
  FARM_FINGERPRINT(CONCAT(IFNULL(country, 'Unknown'), '_', IFNULL(city, 'Unknown'))) AS country_key,
  country,
  city
FROM `data-to-insights.ecommerce.all_sessions`
GROUP BY country, city;


-- Dimension: Date Calendar
CREATE OR REPLACE TABLE `valid-keep-465517-q8.ecommerce.DimDate` AS
SELECT
  CAST(FORMAT_DATE('%Y%m%d', d) AS INT64) AS date_key,
  d AS date,
  EXTRACT(YEAR FROM d) AS year,
  EXTRACT(MONTH FROM d) AS month,
  FORMAT_DATE('%B', d) AS month_name,
  EXTRACT(DAY FROM d) AS day,
  EXTRACT(DAYOFWEEK FROM d) AS day_of_week,
  FORMAT_DATE('%A', d) AS day_name
FROM UNNEST(GENERATE_DATE_ARRAY('2016-08-01', '2017-08-31', INTERVAL 1 DAY)) AS d;


-- Fact Table: Sales Transactions
CREATE OR REPLACE TABLE `valid-keep-465517-q8.ecommerce.FactSales` AS
SELECT
  -- Foreign Keys linking to Dimensions
  FARM_FINGERPRINT(fullVisitorId) AS customer_key,
  FARM_FINGERPRINT(productSKU) AS product_key,
  FARM_FINGERPRINT(CONCAT(IFNULL(country, 'Unknown'), '_', IFNULL(city, 'Unknown'))) AS country_key,
  CAST(date AS INT64) AS date_key,
  
  transactionId AS transaction_id,
  
  -- Price & Revenue metrics scaled from micro-units
  productPrice / 1000000 AS item_price_usd,
  productQuantity AS quantity_sold,
  productRevenue / 1000000 AS item_revenue_usd,
  totalTransactionRevenue / 1000000 AS total_order_revenue_usd
FROM `data-to-insights.ecommerce.all_sessions`
WHERE transactionId IS NOT NULL 
  AND productSKU IS NOT NULL;
