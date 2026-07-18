-- Page Exit Share Analysis (Identify high drop-off pages)

SELECT 
  pagePathLevel1 AS exit_page_path,
  -- Count unique visitor sessions exiting at this path level
  COUNT(DISTINCT CONCAT(fullVisitorId, '_', visitId)) AS exit_count,
  -- Calculate percentage of total website exits occurring at this path
  ROUND(
    (COUNT(DISTINCT CONCAT(fullVisitorId, '_', visitId)) / SUM(COUNT(DISTINCT CONCAT(fullVisitorId, '_', visitId))) OVER()) * 100, 2
  ) AS exit_share_pct
FROM `data-to-insights.ecommerce.all_sessions`
WHERE pagePathLevel1 IS NOT NULL
GROUP BY exit_page_path
ORDER BY exit_count DESC
LIMIT 100;
