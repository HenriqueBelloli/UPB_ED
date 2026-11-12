{{ config(
    materialized='incremental',
    incremental_strategy='delete+insert',
    unique_key=['order_id', 'order_item_id'],
    on_schema_change='fail'
) }}

SELECT
    s.order_id,
    s.order_item_id,
    CAST(
        strftime(
            CAST(s.order_purchase_timestamp AS DATE),
            '%Y%m%d'
        ) AS INTEGER
    ) AS date_key,
    c.customer_key,
    p.product_key,
    se.seller_key,
    s.order_status,
    s.price,
    s.freight_value,
    round(s.price + s.freight_value, 2) AS total_value
FROM {{ ref('stg_api_orders') }} AS s
LEFT JOIN {{ source('northmart', 'dim_customer') }} AS c
    ON s.customer_id = c.customer_id
LEFT JOIN {{ source('northmart', 'dim_product') }} AS p
    ON s.product_id = p.product_id
LEFT JOIN {{ source('northmart', 'dim_seller') }} AS se
    ON s.seller_id = se.seller_id
