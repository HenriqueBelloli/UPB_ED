{{ config(materialized='view') }}

SELECT
    trim(order_id) AS order_id,
    try_cast(order_item_id AS BIGINT) AS order_item_id,
    trim(customer_id) AS customer_id,
    trim(product_id) AS product_id,
    trim(seller_id) AS seller_id,
    lower(trim(order_status)) AS order_status,
    try_cast(order_purchase_timestamp AS TIMESTAMP) AS order_purchase_timestamp,
    try_cast(price AS DOUBLE) AS price,
    try_cast(freight_value AS DOUBLE) AS freight_value,
    trim(order_id) || '-' || trim(order_item_id) AS order_item_key,
    _run_date,
    _source_file,
    _loaded_at
FROM {{ source('northmart', 'raw_api_orders') }}
WHERE _run_date = CAST('{{ var("run_date") }}' AS DATE)
