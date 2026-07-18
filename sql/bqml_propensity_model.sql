-- Logistic regression model to predict purchase propensity in BigQuery ML

-- 1. Model Training
CREATE OR REPLACE MODEL `valid-keep-465517-q8.ecommerce.purchase_propensity_model`
OPTIONS(
  model_type='logistic_reg',
  input_label_cols=['label'],
  data_split_method='AUTO_SPLIT'
) AS
SELECT
  -- Purchase label: 1 if transaction completed, else 0
  IF(transactionId IS NOT NULL, 1, 0) AS label,
  
  -- Features representing session behavior, demographics, and temporal context
  channelGrouping,
  country,
  IFNULL(pageviews, 0) AS pageviews,
  IFNULL(timeOnSite, 0) AS timeOnSite,
  IFNULL(sessionQualityDim, 0) AS session_quality_score,
  EXTRACT(DAYOFWEEK FROM PARSE_DATE('%Y%m%d', date)) AS day_of_week,
  EXTRACT(HOUR FROM TIMESTAMP_MILLIS(time)) AS hour_of_day
FROM `data-to-insights.ecommerce.all_sessions`
WHERE pageviews IS NOT NULL;


-- 2. Model Evaluation
/*
SELECT *
FROM ML.EVALUATE(MODEL `valid-keep-465517-q8.ecommerce.purchase_propensity_model`,
  (
    SELECT
      IF(transactionId IS NOT NULL, 1, 0) AS label,
      channelGrouping,
      country,
      IFNULL(pageviews, 0) AS pageviews,
      IFNULL(timeOnSite, 0) AS timeOnSite,
      IFNULL(sessionQualityDim, 0) AS session_quality_score,
      EXTRACT(DAYOFWEEK FROM PARSE_DATE('%Y%m%d', date)) AS day_of_week,
      EXTRACT(HOUR FROM TIMESTAMP_MILLIS(time)) AS hour_of_day
    FROM `data-to-insights.ecommerce.all_sessions`
    WHERE pageviews IS NOT NULL
  )
);
*/


-- 3. Batch Predictions (Sample query extracting purchase probability score)
/*
SELECT
  unique_session_id,
  predicted_label,
  predicted_label_probs[OFFSET(0)].prob AS probability_not_buy,
  predicted_label_probs[OFFSET(1)].prob AS propensity_to_buy_score
FROM ML.PREDICT(MODEL `valid-keep-465517-q8.ecommerce.purchase_propensity_model`,
  (
    SELECT
      CONCAT(fullVisitorId, '_', visitId) AS unique_session_id,
      channelGrouping,
      country,
      IFNULL(pageviews, 0) AS pageviews,
      IFNULL(timeOnSite, 0) AS timeOnSite,
      IFNULL(sessionQualityDim, 0) AS session_quality_score,
      EXTRACT(DAYOFWEEK FROM PARSE_DATE('%Y%m%d', date)) AS day_of_week,
      EXTRACT(HOUR FROM TIMESTAMP_MILLIS(time)) AS hour_of_day
    FROM `data-to-insights.ecommerce.all_sessions`
    WHERE pageviews IS NOT NULL
  )
)
ORDER BY propensity_to_buy_score DESC
LIMIT 1000;
*/
