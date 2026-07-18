-- Product Sales Performance and Order Depth Analysis

SELECT 
  v2ProductName AS product_name,
  -- Scale product price from micro-units to USD
  ROUND(MAX(productPrice / 1000000), 2) AS single_item_price_usd,
  
  -- Count distinct completed checkout sessions containing this product
  COUNT(DISTINCT CONCAT(fullVisitorId, '_', visitId)) AS confirmed_order_sessions,
  
  -- Total number of units purchased
  SUM(productQuantity) AS total_units_sold,
  
  -- Average quantity purchased per order session
  ROUND(SUM(productQuantity) / COUNT(DISTINCT CONCAT(fullVisitorId, '_', visitId)), 2) AS avg_units_per_session

FROM `data-to-insights.ecommerce.all_sessions`
WHERE eCommerceAction_type = '6' -- Completed Purchase
  AND productQuantity IS NOT NULL
GROUP BY product_name
HAVING confirmed_order_sessions > 10
ORDER BY confirmed_order_sessions DESC;
