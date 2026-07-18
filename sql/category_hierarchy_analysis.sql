-- Product Category Tree and Revenue Contribution Analysis

WITH clean_product_revenue AS (
  -- Parse the slash-delimited category hierarchy and scale micro-unit currency
  SELECT 
    transactionId,
    SPLIT(v2ProductCategory, '/')[SAFE_OFFSET(0)] AS main_category,
    SPLIT(v2ProductCategory, '/')[SAFE_OFFSET(1)] AS sub_category_1,
    SPLIT(v2ProductCategory, '/')[SAFE_OFFSET(2)] AS sub_category_2,
    COALESCE(transactionRevenue, totalTransactionRevenue) / 1000000 AS net_revenue_usd
  FROM `data-to-insights.ecommerce.all_sessions`
  WHERE v2ProductCategory IS NOT NULL 
    AND v2ProductCategory NOT IN ('(not set)', '${escCatTitle}')
    AND (transactionRevenue IS NOT NULL OR totalTransactionRevenue IS NOT NULL)
),

deduped_category_revenue AS (
  -- Deduplicate categories at transaction level
  SELECT 
    main_category,
    COALESCE(sub_category_1, 'N/A') AS sub_category_1,
    COALESCE(sub_category_2, 'N/A') AS sub_category_2,
    transactionId,
    MAX(net_revenue_usd) AS transaction_revenue_usd
  FROM clean_product_revenue
  GROUP BY main_category, sub_category_1, sub_category_2, transactionId
)

-- Aggregate revenue sums and shares across categories
SELECT 
  main_category,
  sub_category_1,
  sub_category_2,
  ROUND(SUM(transaction_revenue_usd), 2) AS total_revenue_usd,
  COUNT(DISTINCT transactionId) AS total_orders,
  ROUND(
    (SUM(transaction_revenue_usd) / SUM(SUM(transaction_revenue_usd)) OVER()) * 100, 2
  ) AS total_revenue_share_pct
FROM deduped_category_revenue
GROUP BY main_category, sub_category_1, sub_category_2
ORDER BY total_revenue_usd DESC;
