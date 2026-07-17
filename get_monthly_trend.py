import os
import bigframes.pandas as bpd

# Authenticate using credential file
os.environ["GOOGLE_APPLICATION_CREDENTIALS"] = "valid-keep-465517-q8-32a662053b22.json"
bpd.options.bigquery.project = 'valid-keep-465517-q8'
bpd.options.bigquery.location = 'US'

query = """
SELECT 
  FORMAT_DATE('%Y-%m', PARSE_DATE('%Y%m%d', date)) AS year_month,
  SUM(COALESCE(transactionRevenue, totalTransactionRevenue) / 1000000) AS monthly_revenue,
  COUNT(DISTINCT transactionId) AS monthly_orders
FROM `data-to-insights.ecommerce.all_sessions`
WHERE date IS NOT NULL
GROUP BY year_month
ORDER BY year_month ASC;
"""

print("Querying BigQuery monthly revenue trend...")
try:
    df = bpd.read_gbq(query)
    df_pd = df.to_pandas()
    print("\n=== Monthly Revenue & Orders from BigQuery ===")
    print(df_pd)
except Exception as e:
    print("Error querying BigQuery:", e)
