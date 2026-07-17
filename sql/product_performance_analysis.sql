-- =====================================================================================
-- ANALYSIS: Individual Product Sales & Scatter Metrics
-- BUSINESS PURPOSE: Evaluate item-level performance, prices, unit volumes, and average 
--                   order depth (avg units bought per single checkout session).
-- DATA SOURCE: `data-to-insights.ecommerce.all_sessions`
-- TECH STACK: BigQuery (Filtering, Aggregations, Ratios)
-- =====================================================================================

SELECT 
  v2ProductName AS product_name,
  -- Real product price (Google Analytics stores prices multiplied by 1,000,000 to avoid floats)
  ROUND(MAX(productPrice / 1000000), 2) AS single_item_price_usd,
  
  -- Count distinct checkouts containing this product
  COUNT(DISTINCT CONCAT(fullVisitorId, '_', visitId)) AS confirmed_order_sessions,
  
  -- Total number of units of this product purchased
  SUM(productQuantity) AS total_units_sold,
  
  -- Average product quantity purchased per order session (order depth)
  ROUND(SUM(productQuantity) / COUNT(DISTINCT CONCAT(fullVisitorId, '_', visitId)), 2) AS avg_units_per_session

FROM `data-to-insights.ecommerce.all_sessions`
WHERE eCommerceAction_type = '6' -- Focus strictly on 'Completed Purchase' actions
  AND productQuantity IS NOT NULL
GROUP BY product_name
-- Filter out low-volume items to highlight significant product trends (Scatter plot input)
HAVING confirmed_order_sessions > 10
ORDER BY confirmed_order_sessions DESC;
