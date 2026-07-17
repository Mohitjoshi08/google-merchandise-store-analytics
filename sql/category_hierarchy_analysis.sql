-- =====================================================================================
-- ANALYSIS: Product Category Tree and Revenue Share Analysis
-- BUSINESS PURPOSE: Understand category and subcategory revenue contribution, mapping
--                   out the catalog hierarchy (Decomposition Tree / Treemap feeds).
-- DATA SOURCE: `data-to-insights.ecommerce.all_sessions`
-- TECH STACK: BigQuery (Deduplication, Hierarchy Splits, Window Functions)
-- =====================================================================================

WITH clean_product_revenue AS (
  -- Step 1: Parse the slash-delimited category hierarchy and normalize currency values.
  SELECT 
    transactionId,
    -- Extract levels of the category hierarchy safely using BigQuery's SPLIT.
    -- Example: "Home/Office/Writing Instruments" becomes:
    --          main_category = "Home", sub_category_1 = "Office", sub_category_2 = "Writing Instruments"
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
  -- Step 2: Deduplicate category revenue at the finest detail per transaction.
  SELECT 
    main_category,
    COALESCE(sub_category_1, 'N/A') AS sub_category_1,
    COALESCE(sub_category_2, 'N/A') AS sub_category_2,
    transactionId,
    MAX(net_revenue_usd) AS transaction_revenue_usd
  FROM clean_product_revenue
  GROUP BY main_category, sub_category_1, sub_category_2, transactionId
)

-- Step 3: Run aggregate sums across the entire category hierarchy.
SELECT 
  main_category,
  sub_category_1,
  sub_category_2,
  ROUND(SUM(transaction_revenue_usd), 2) AS total_revenue_usd,
  COUNT(DISTINCT transactionId) AS total_orders,
  -- Calculate percent contribution of this specific path toward total catalog revenue.
  ROUND(
    (SUM(transaction_revenue_usd) / SUM(SUM(transaction_revenue_usd)) OVER()) * 100, 2
  ) AS total_revenue_share_pct
FROM deduped_category_revenue
GROUP BY main_category, sub_category_1, sub_category_2
ORDER BY total_revenue_usd DESC;
