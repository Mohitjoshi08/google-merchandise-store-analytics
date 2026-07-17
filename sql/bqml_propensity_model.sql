-- =====================================================================================
-- ANALYSIS: BigQuery ML (BQML) - Customer Purchase Propensity Prediction Model
-- BUSINESS PURPOSE: Train a logistic regression model directly within BigQuery to predict
--                   whether a visitor session will result in a transaction based on
--                   session engagement metrics. This enables personalized cart targeting.
-- DATA SOURCE: `data-to-insights.ecommerce.all_sessions`
-- TECH STACK: BigQuery ML (Logistic Regression, Classification Metrics)
-- =====================================================================================

-- STEP 1: CREATE OR REPLACE THE MODEL
-- Trains a binary logistic regression model to predict the 'label' (0 or 1).
CREATE OR REPLACE MODEL `valid-keep-465517-q8.ecommerce.purchase_propensity_model`
OPTIONS(
  model_type='logistic_reg',
  input_label_cols=['label'],
  data_split_method='AUTO_SPLIT'
) AS
SELECT
  -- The Label: 1 if user completed purchase (transactionId is not null), else 0
  IF(transactionId IS NOT NULL, 1, 0) AS label,
  
  -- The Features: Session behavior & demographics
  channelGrouping,
  country,
  IFNULL(pageviews, 0) AS pageviews,
  IFNULL(timeOnSite, 0) AS timeOnSite,
  IFNULL(sessionQualityDim, 0) AS session_quality_score,
  
  -- Temporal features extracted from date
  EXTRACT(DAYOFWEEK FROM PARSE_DATE('%Y%m%d', date)) AS day_of_week,
  EXTRACT(HOUR FROM TIMESTAMP_MILLIS(time)) AS hour_of_day
FROM `data-to-insights.ecommerce.all_sessions`
-- Restrict training to actual traffic data (excluding rows with completely missing values)
WHERE pageviews IS NOT NULL;


-- STEP 2: EVALUATE THE MODEL
-- Check classification performance metrics: Precision, Recall, Accuracy, F1-Score, ROC-AUC.
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


-- STEP 3: PREDICT PURCHASE PROPENSITY (PROBABILITY)
-- Run predictions on a sample of sessions, filtering for high propensity customers.
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
