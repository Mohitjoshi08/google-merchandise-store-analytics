-- =====================================================================================
-- ANALYSIS: E-Commerce Conversion Funnel by Marketing Channel
-- BUSINESS PURPOSE: Identify where users drop off in the conversion funnel and compare 
--                   the efficiency of different marketing channels.
-- DATA SOURCE: `data-to-insights.ecommerce.all_sessions` (Google Analytics Dataset)
-- TECH STACK: BigQuery (CTEs, Window Functions, PIVOT)
-- =====================================================================================

WITH session_actions AS (
  -- Step 1: Dedup and extract unique sessions with their respective marketing channels and shopping actions.
  -- Actions mapping: 0 = Unknown/Click-through, 1 = Product View, 2 = Add to Cart, 3 = Remove from Cart,
  --                  4 = Checkout, 5 = Completed Purchase
  SELECT DISTINCT
    channelGrouping,
    CONCAT(fullVisitorId, '_', visitId) AS unique_session_id,
    eCommerceAction_type
  FROM `data-to-insights.ecommerce.all_sessions`
  WHERE eCommerceAction_type IS NOT NULL
),

channel_totals AS (
  -- Step 2: Establish the baseline volume (total unique sessions) for each marketing channel.
  SELECT 
    channelGrouping,
    COUNT(DISTINCT unique_session_id) AS total_channel_sessions
  FROM session_actions
  GROUP BY channelGrouping
),

action_counts AS (
  -- Step 3: Count unique sessions reaching each specific stage in the purchase funnel per channel.
  SELECT 
    channelGrouping,
    eCommerceAction_type,
    COUNT(DISTINCT unique_session_id) AS action_session_count
  FROM session_actions
  GROUP BY channelGrouping, eCommerceAction_type
),

funnel_rates AS (
  -- Step 4: Compute the conversion percentage for each funnel stage relative to the channel's total sessions.
  -- This provides a normalized view across traffic volumes of vastly different scales.
  SELECT 
    a.channelGrouping,
    a.eCommerceAction_type,
    a.action_session_count AS unique_visitors_at_stage,
    t.total_channel_sessions AS total_unique_channel_visitors,
    ROUND((a.action_session_count / t.total_channel_sessions) * 100, 2) AS clean_action_percentage
  FROM action_counts a
  JOIN channel_totals t 
    ON a.channelGrouping = t.channelGrouping
)

-- Step 5: Final output sorted to feed the channel combo chart and matrix view.
SELECT 
  channelGrouping,
  eCommerceAction_type,
  unique_visitors_at_stage,
  total_unique_channel_visitors,
  clean_action_percentage
FROM funnel_rates
ORDER BY channelGrouping ASC, eCommerceAction_type ASC;


-- =====================================================================================
-- OPTIMIZED PIVOT QUERY: Horizontal Funnel Comparison across Channels (Matrix View)
-- =====================================================================================
/*
WITH session_actions AS (
  SELECT DISTINCT
    channelGrouping,
    CONCAT(fullVisitorId, '_', visitId) AS unique_session_id,
    eCommerceAction_type
  FROM `data-to-insights.ecommerce.all_sessions`
  WHERE eCommerceAction_type IS NOT NULL
),
channel_totals AS (
  SELECT 
    channelGrouping,
    COUNT(DISTINCT unique_session_id) AS total_channel_sessions
  FROM session_actions
  GROUP BY channelGrouping
),
action_percentages AS (
  SELECT  
    a.channelGrouping,
    a.eCommerceAction_type,
    ROUND((COUNT(DISTINCT a.unique_session_id) / t.total_channel_sessions) * 100, 2) AS action_pct
  FROM session_actions a
  JOIN channel_totals t ON a.channelGrouping = t.channelGrouping
  GROUP BY a.channelGrouping, a.eCommerceAction_type, t.total_channel_sessions
)
SELECT 
  eCommerceAction_type AS funnel_stage,
  IFNULL(Referral, 0) AS Referral,
  IFNULL(Direct, 0) AS Direct,
  IFNULL(Organic_Search, 0) AS Organic_Search,
  IFNULL(Paid_Search, 0) AS Paid_Search,
  IFNULL(Display, 0) AS Display,
  IFNULL(Social, 0) AS Social,
  IFNULL(Affiliates, 0) AS Affiliates,
  IFNULL(Other, 0) AS Other
FROM action_percentages
PIVOT(
  MAX(action_pct) 
  FOR channelGrouping IN (
    'Referral' AS Referral,
    'Direct' AS Direct,
    'Organic Search' AS Organic_Search,
    'Paid Search' AS Paid_Search,
    'Display' AS Display,
    'Social' AS Social,
    'Affiliates' AS Affiliates,
    '(Other)' AS Other
  )
)
ORDER BY funnel_stage ASC;
*/
