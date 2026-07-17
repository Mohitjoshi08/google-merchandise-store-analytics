-- =====================================================================================
-- ARCHITECTURE: Data Warehouse Layers & Star Schema Definition
-- BUSINESS PURPOSE: Transition raw clickstream logs into an optimized, high-performance
--                   dimensional model (Star Schema) to support clean business reporting.
-- DATA WAREHOUSE LAYERS: 
--   1. RAW LAYER      : `data-to-insights.ecommerce.all_sessions` (Ingested GA Event stream)
--   2. STAGING LAYER  : Deduplicated & normalized session/transaction views
--   3. ANALYTICS LAYER: FactSales & Dimension Tables (Star Schema)
-- =====================================================================================

-- =====================================================================================
-- STEP 1: STAGING LAYER (Normalizing & Deduplicating Events)
-- =====================================================================================

-- Creating Staging Transactions to isolate pure purchase records
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


-- =====================================================================================
-- STEP 2: ANALYTICS LAYER - DIMENSION TABLES
-- =====================================================================================

-- DimCustomer: Stores visitor attributes and initial traffic sources
CREATE OR REPLACE TABLE `valid-keep-465517-q8.ecommerce.DimCustomer` AS
SELECT
  -- Generate unique surrogate key for customers
  FARM_FINGERPRINT(fullVisitorId) AS customer_key,
  fullVisitorId AS visitor_id,
  -- Capture primary acquisition channel
  ARRAY_AGG(channelGrouping ORDER BY date ASC LIMIT 1)[OFFSET(0)] AS primary_channel
FROM `data-to-insights.ecommerce.all_sessions`
GROUP BY fullVisitorId;


-- DimProduct: Stores product catalog attributes and hierarchies
CREATE OR REPLACE TABLE `valid-keep-465517-q8.ecommerce.DimProduct` AS
SELECT
  -- Generate unique surrogate key for products
  FARM_FINGERPRINT(productSKU) AS product_key,
  productSKU AS product_sku,
  v2ProductName AS product_name,
  -- Parse category hierarchy
  SPLIT(v2ProductCategory, '/')[SAFE_OFFSET(0)] AS main_category,
  COALESCE(SPLIT(v2ProductCategory, '/')[SAFE_OFFSET(1)], 'N/A') AS sub_category_1,
  COALESCE(SPLIT(v2ProductCategory, '/')[SAFE_OFFSET(2)], 'N/A') AS sub_category_2
FROM `data-to-insights.ecommerce.all_sessions`
WHERE productSKU IS NOT NULL
GROUP BY productSKU, v2ProductName, v2ProductCategory;


-- DimCountry: Stores regional locations to prevent string duplication in FactSales
CREATE OR REPLACE TABLE `valid-keep-465517-q8.ecommerce.DimCountry` AS
SELECT
  -- Generate unique surrogate key for regions
  FARM_FINGERPRINT(CONCAT(IFNULL(country, 'Unknown'), '_', IFNULL(city, 'Unknown'))) AS country_key,
  country,
  city
FROM `data-to-insights.ecommerce.all_sessions`
GROUP BY country, city;


-- DimDate: Time-dimension to support calendar and time-intelligence analyses
CREATE OR REPLACE TABLE `valid-keep-465517-q8.ecommerce.DimDate` AS
SELECT
  -- Date surrogate key
  CAST(FORMAT_DATE('%Y%m%d', d) AS INT64) AS date_key,
  d AS date,
  EXTRACT(YEAR FROM d) AS year,
  EXTRACT(MONTH FROM d) AS month,
  FORMAT_DATE('%B', d) AS month_name,
  EXTRACT(DAY FROM d) AS day,
  EXTRACT(DAYOFWEEK FROM d) AS day_of_week,
  FORMAT_DATE('%A', d) AS day_name
FROM UNNEST(GENERATE_DATE_ARRAY('2016-08-01', '2017-08-31', INTERVAL 1 DAY)) AS d;


-- =====================================================================================
-- STEP 3: ANALYTICS LAYER - FACT SALES TABLE
-- =====================================================================================

-- FactSales: The core transaction table holding numeric measures and key associations
CREATE OR REPLACE TABLE `valid-keep-465517-q8.ecommerce.FactSales` AS
SELECT
  -- Surrogate Foreign Keys linking to Dimensions
  FARM_FINGERPRINT(fullVisitorId) AS customer_key,
  FARM_FINGERPRINT(productSKU) AS product_key,
  FARM_FINGERPRINT(CONCAT(IFNULL(country, 'Unknown'), '_', IFNULL(city, 'Unknown'))) AS country_key,
  CAST(date AS INT64) AS date_key,
  
  -- Business Keys
  transactionId AS transaction_id,
  
  -- Measures
  productPrice / 1000000 AS item_price_usd,
  productQuantity AS quantity_sold,
  productRevenue / 1000000 AS item_revenue_usd,
  
  -- Overall order overheads (Deduplicated using safe ratio division per item line)
  totalTransactionRevenue / 1000000 AS total_order_revenue_usd
FROM `data-to-insights.ecommerce.all_sessions`
WHERE transactionId IS NOT NULL 
  AND productSKU IS NOT NULL;
