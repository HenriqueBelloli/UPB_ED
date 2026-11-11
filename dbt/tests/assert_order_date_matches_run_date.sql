SELECT *
FROM {{ ref('stg_api_orders') }}
WHERE CAST(order_purchase_timestamp AS DATE) <> _run_date
