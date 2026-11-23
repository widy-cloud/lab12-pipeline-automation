-- pandas equivalent (Practice 10):
--   pd.to_datetime(errors="coerce"), pd.to_numeric(...).fillna(0),
--   drop negative quantity, drop_duplicates(order_id), total = qty * price
with typed as (
    select
        try_cast(trim(order_id)    as integer)        as order_id,
        try_cast(trim(customer_id) as integer)        as customer_id,
        try_cast(trim(product_id)  as integer)        as product_id,
        try_cast(trim(order_date)  as date)           as order_date,
        coalesce(try_cast(trim(quantity) as integer), 0) as quantity,
        try_cast(trim(price)       as decimal(14, 2)) as price,
        _source_file,
        _loaded_at
    from {{ source('raw', 'sales') }}
),

deduplicated as (
    select *
    from typed
    qualify row_number() over (partition by order_id order by _source_file desc) = 1
)

select
    order_id,
    customer_id,
    product_id,
    order_date,
    quantity,
    price,
    quantity * price as total_amount,
    _source_file
from deduplicated
where quantity >= 0
