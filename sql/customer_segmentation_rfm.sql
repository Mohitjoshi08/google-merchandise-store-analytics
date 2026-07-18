-- RFM (Recency, Frequency, Monetary) Customer Segmentation & LTV Analysis

WITH customer_raw_metrics AS (
  -- Calculate base metrics relative to dataset end date (Aug 31, 2017)
  SELECT
    customer_key,
    DATE_DIFF(DATE('2017-08-31'), MAX(d.date), DAY) AS recency_days,
    COUNT(DISTINCT transaction_id) AS frequency_orders,
    SUM(quantity_sold * item_price_usd) AS monetary_value_usd
  FROM `valid-keep-465517-q8.ecommerce.FactSales` f
  JOIN `valid-keep-465517-q8.ecommerce.DimDate` d
    ON f.date_key = d.date_key
  GROUP BY customer_key
),

rfm_scores AS (
  -- Assign scores (1 to 5) using quintiles
  SELECT
    customer_key,
    recency_days,
    frequency_orders,
    monetary_value_usd,
    -- Recency: lower days is better (highest score for most recent)
    NTILE(5) OVER(ORDER BY recency_days DESC) AS r_score,
    -- Frequency & Monetary: higher is better
    NTILE(5) OVER(ORDER BY frequency_orders ASC) AS f_score,
    NTILE(5) OVER(ORDER BY monetary_value_usd ASC) AS m_score
  FROM customer_raw_metrics
),

customer_segments AS (
  -- Define loyalty segments and LTV tiers
  SELECT
    customer_key,
    recency_days,
    frequency_orders,
    monetary_value_usd,
    r_score,
    f_score,
    m_score,
    (r_score + f_score + m_score) / 3.0 AS avg_rfm_score,
    
    CASE
      WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
      WHEN r_score >= 3 AND f_score >= 3 AND m_score >= 4 THEN 'Loyal Customers'
      WHEN r_score >= 4 AND f_score = 1 THEN 'New Customers'
      WHEN r_score = 1 AND f_score >= 3 THEN 'At Risk (Loyal, but Inactive)'
      WHEN r_score = 1 AND f_score = 1 THEN 'Lost Customers'
      ELSE 'Needs Attention (General)'
    END AS customer_segment,
    
    CASE
      WHEN monetary_value_usd >= 500 THEN 'Tier 1: High LTV (>= $500)'
      WHEN monetary_value_usd >= 100 AND monetary_value_usd < 500 THEN 'Tier 2: Medium LTV ($100-$499)'
      ELSE 'Tier 3: Low LTV (< $100)'
    END AS ltv_tier
  FROM rfm_scores
)

-- Summary statistics of the customer segments
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
