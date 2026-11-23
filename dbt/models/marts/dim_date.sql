with d as (
    select distinct order_date as dt
    from {{ ref('stg_sales') }}
    where order_date is not null
)
select
    dt                         as date_key,
    extract(year  from dt)::int as year,
    extract(month from dt)::int as month,
    strftime(dt, '%Y-%m')      as ym
from d
