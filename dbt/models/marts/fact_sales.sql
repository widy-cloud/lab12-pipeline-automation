-- The fact table: one row per order line, with keys to every dimension.
select
    order_id,
    order_date   as date_key,
    customer_id,
    product_id,
    quantity,
    price,
    total_amount
from {{ ref('stg_sales') }}
where order_date is not null
