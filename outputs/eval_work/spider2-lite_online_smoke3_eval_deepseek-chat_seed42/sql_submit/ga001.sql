WITH navy_tee_purchases AS (
  SELECT DISTINCT user_pseudo_id
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  WHERE _TABLE_SUFFIX BETWEEN '20201201' AND '20201231'
    AND event_name = 'purchase'
    AND EXISTS (
      SELECT 1
      FROM UNNEST(items) AS item
      WHERE item.item_name = 'Google Navy Speckled Tee'
    )
),
other_items AS (
  SELECT item.item_name, SUM(item.quantity) AS total_quantity
  FROM `bigquery-public-data.ga4_obfuscated_sample_ecommerce.events_*`
  CROSS JOIN UNNEST(items) AS item
  WHERE _TABLE_SUFFIX BETWEEN '20201201' AND '20201231'
    AND event_name = 'purchase'
    AND user_pseudo_id IN (SELECT user_pseudo_id FROM navy_tee_purchases)
    AND item.item_name != 'Google Navy Speckled Tee'
  GROUP BY item.item_name
)
SELECT item_name, total_quantity
FROM other_items
ORDER BY total_quantity DESC
LIMIT 1