-- =====================================================================================
-- ANALYSIS: Geographical Performance & Fee Friction Analysis
-- BUSINESS PURPOSE: Identify high-performing countries, isolate conversion bottlenecks,
--                   and flag fee friction (shipping & tax charges) that discourage buyers.
-- DATA SOURCE: `data-to-insights.ecommerce.all_sessions`
-- TECH STACK: BigQuery (Deduplication, CTEs, Cost Ratios, Aggregations)
-- =====================================================================================

WITH unique_orders AS (
  -- Step 1: Deduplicate transaction records to ensure metrics represent exactly one row per unique order.
  -- BigQuery's GA dataset contains multiple rows per transaction for individual item lines.
  SELECT 
    country,
    transactionId,
    -- Scale currency columns by dividing by 1,000,000 to convert micro-units to standard USD.
    MAX(totalTransactionRevenue / 1000000) AS total_revenue_usd,
    -- Fallback to totalTransactionRevenue if transactionRevenue (product cost) is null.
    MAX(COALESCE(transactionRevenue, totalTransactionRevenue) / 1000000) AS net_product_revenue_usd
  FROM `data-to-insights.ecommerce.all_sessions`
  WHERE transactionId IS NOT NULL
  GROUP BY country, transactionId
),

country_metrics AS (
  -- Step 2: Calculate aggregate metrics (AOV, shipping/tax fees, fee ratio) for each country.
  SELECT 
    country,
    COUNT(transactionId) AS true_total_orders,
    ROUND(AVG(total_revenue_usd), 2) AS clean_avg_total_cost_usd,
    ROUND(AVG(net_product_revenue_usd), 2) AS clean_avg_product_revenue_usd,
    ROUND(AVG(total_revenue_usd - net_product_revenue_usd), 2) AS clean_avg_shipping_and_tax_usd,
    ROUND(
      (SUM(total_revenue_usd - net_product_revenue_usd) / SUM(total_revenue_usd)) * 100, 2
    ) AS true_fee_percent_of_total
  FROM unique_orders
  GROUP BY country
),

traffic_counts AS (
  -- Step 3: Establish session baseline and conversion rate per country.
  SELECT 
    country,
    COUNT(DISTINCT CONCAT(fullVisitorId, '_', visitId)) AS true_session_count,
    COUNT(DISTINCT transactionId) AS confirmed_transactions,
    ROUND(
      (COUNT(DISTINCT transactionId) / COUNT(DISTINCT CONCAT(fullVisitorId, '_', visitId))) * 100, 2
    ) AS conversion_rate_pct
  FROM `data-to-insights.ecommerce.all_sessions`
  GROUP BY country
)

-- Step 4: Final combined geographical report.
-- Filters for countries with at least 5 orders to remove low-sample noise.
SELECT 
  t.country,
  t.true_session_count,
  t.confirmed_transactions,
  t.conversion_rate_pct,
  IFNULL(c.clean_avg_total_cost_usd, 0) AS average_order_value_usd,
  IFNULL(c.clean_avg_shipping_and_tax_usd, 0) AS avg_shipping_and_tax_usd,
  IFNULL(c.true_fee_percent_of_total, 0) AS fee_friction_share_pct
FROM traffic_counts t
LEFT JOIN country_metrics c 
  ON t.country = c.country
WHERE c.true_total_orders >= 5 OR t.confirmed_transactions > 0
ORDER BY t.confirmed_transactions DESC;
