SELECT
    s.order_id,
    s.order_item_id,
    s.seller_id,
    s.order_purchase_timestamp,
    d.joined_on
FROM {{ ref('stg_api_orders') }} AS s
JOIN {{ source('northmart', 'dim_seller') }} AS d
    ON s.seller_id = d.seller_id
WHERE d.joined_on IS NOT NULL
  AND CAST(s.order_purchase_timestamp AS DATE) < d.joined_on
