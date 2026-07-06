WITH user_engagement AS (
  SELECT
    user_pseudo_id,
    event_date,
    event_timestamp,
    event_name,
    (SELECT value.int_value FROM UNNEST(event_params) WHERE key = 'engagement_time_msec') AS engagement_time_msec
  FROM
    `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE
    _TABLE_SUFFIX BETWEEN '20210101' AND '20210107'
    AND event_name = 'user_engagement'
),
user_positive_engagement_7day AS (
  SELECT DISTINCT user_pseudo_id
  FROM user_engagement
  WHERE engagement_time_msec > 0
    AND event_timestamp <= 1610006399000000  -- 2021-01-07 23:59:59 UTC in microseconds
),
user_positive_engagement_2day AS (
  SELECT DISTINCT user_pseudo_id
  FROM user_engagement
  WHERE engagement_time_msec > 0
    AND event_date IN ('20210106', '20210107')
    AND event_timestamp <= 1610006399000000
)
SELECT COUNT(DISTINCT user_pseudo_id) AS distinct_users
FROM user_positive_engagement_7day
WHERE user_pseudo_id NOT IN (SELECT user_pseudo_id FROM user_positive_engagement_2day)