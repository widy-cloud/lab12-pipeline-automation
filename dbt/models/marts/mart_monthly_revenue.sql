-- A BI-ready table: the "Analytic Query" from Practice 10, now rebuilt automatically.
select
    d.ym,
    p.category,
    p.product_name,
    sum(f.quantity)     as units_sold,
    sum(f.total_amount) as revenue
from {{ ref('fact_sales') }}  f
join {{ ref('dim_product') }} p on f.product_id = p.product_id
join {{ ref('dim_date') }}    d on f.date_key   = d.date_key
group by all
order by d.ym, revenue desc
