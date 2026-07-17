-- =====================================================================================
-- ANALYSIS: Page Exit Share Analysis (URL drop-offs)
-- BUSINESS PURPOSE: Locate website exit hot-spots (e.g. checkout forms or general search)
--                   to identify where UX optimizations will yield the highest conversion lift.
-- DATA SOURCE: `data-to-insights.ecommerce.all_sessions`
-- TECH STACK: BigQuery (Session Aggregations, Exits, Window Functions)
-- =====================================================================================

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
