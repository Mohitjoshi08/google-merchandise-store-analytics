-- Geographical Conversion Performance and Fee Friction (Shipping/Tax) Analysis

WITH unique_orders AS (
  -- Deduplicate transactions to get correct transaction totals
  SELECT 
    country,
    transactionId,
    MAX(totalTransactionRevenue / 1000000) AS total_revenue_usd,
    MAX(COALESCE(transactionRevenue, totalTransactionRevenue) / 1000000) AS net_product_revenue_usd
  FROM `data-to-insights.ecommerce.all_sessions`
  WHERE transactionId IS NOT NULL
  GROUP BY country, transactionId
),

country_metrics AS (
  -- Calculate average order values, shipping/tax fees, and share percentages
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
  -- Base session and transaction counts per country
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

-- Combined geographical performance report (filter for countries with orders to reduce noise)
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
