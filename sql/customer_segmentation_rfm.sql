-- =====================================================================================
-- ANALYSIS: Customer Segmentation, LTV Tiers & RFM Loyalty Model
-- BUSINESS PURPOSE: Group customers into loyalty segments (Champions, At Risk, Loyal) 
--                   based on purchasing patterns, establishing lifetime value (LTV) tiers.
-- DATA SOURCE: `valid-keep-465517-q8.ecommerce.FactSales` & `DimDate`
-- TECH STACK: BigQuery (CTEs, NTILE window functions, Case Statements)
-- =====================================================================================

WITH customer_raw_metrics AS (
  -- Step 1: Extract basic Recency, Frequency, and Monetary metrics for each customer
  SELECT
    customer_key,
    -- Recency: Days since last purchase (relative to the end date of the dataset: Aug 31, 2017)
    DATE_DIFF(DATE('2017-08-31'), MAX(d.date), DAY) AS recency_days,
    -- Frequency: Number of unique orders
    COUNT(DISTINCT transaction_id) AS frequency_orders,
    -- Monetary: Total cumulative spending
    SUM(quantity_sold * item_price_usd) AS monetary_value_usd
  FROM `valid-keep-465517-q8.ecommerce.FactSales` f
  JOIN `valid-keep-465517-q8.ecommerce.DimDate` d
    ON f.date_key = d.date_key
  GROUP BY customer_key
),

rfm_scores AS (
  -- Step 2: Assign scores from 1 to 5 for Recency, Frequency, and Monetary using NTILE
  SELECT
    customer_key,
    recency_days,
    frequency_orders,
    monetary_value_usd,
    -- NTILE(5) for Recency: lower days is better, so reverse order
    NTILE(5) OVER(ORDER BY recency_days DESC) AS r_score,
    -- NTILE(5) for Frequency & Monetary: higher is better
    NTILE(5) OVER(ORDER BY frequency_orders ASC) AS f_score,
    NTILE(5) OVER(ORDER BY monetary_value_usd ASC) AS m_score
  FROM customer_raw_metrics
),

customer_segments AS (
  -- Step 3: Segment customers based on their combined RFM scores
  SELECT
    customer_key,
    recency_days,
    frequency_orders,
    monetary_value_usd,
    r_score,
    f_score,
    m_score,
    (r_score + f_score + m_score) / 3.0 AS avg_rfm_score,
    
    -- Segment logic based on averages
    CASE
      WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
      WHEN r_score >= 3 AND f_score >= 3 AND m_score >= 4 THEN 'Loyal Customers'
      WHEN r_score >= 4 AND f_score = 1 THEN 'New Customers'
      WHEN r_score = 1 AND f_score >= 3 THEN 'At Risk (Loyal, but Inactive)'
      WHEN r_score = 1 AND f_score = 1 THEN 'Lost Customers'
      ELSE 'Needs Attention (General)'
    END AS customer_segment,
    
    -- Lifetime Value (LTV) Tier segmentation
    CASE
      WHEN monetary_value_usd >= 500 THEN 'Tier 1: High LTV (>= $500)'
      WHEN monetary_value_usd >= 100 AND monetary_value_usd < 500 THEN 'Tier 2: Medium LTV ($100-$499)'
      ELSE 'Tier 3: Low LTV (< $100)'
    END AS ltv_tier
  FROM rfm_scores
)

-- Step 4: Final output displaying customer loyalty statistics
SELECT
  customer_segment,
  ltv_tier,
  COUNT(customer_key) AS customer_count,
  ROUND(AVG(recency_days), 1) AS avg_recency_days,
  ROUND(AVG(frequency_orders), 2) AS avg_orders,
  ROUND(SUM(monetary_value_usd), 2) AS total_revenue_usd,
  ROUND(AVG(monetary_value_usd), 2) AS avg_ltv_usd
FROM customer_segments
GROUP BY customer_segment, ltv_tier
ORDER BY total_revenue_usd DESC;
