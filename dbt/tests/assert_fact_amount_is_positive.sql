-- A "singular" test: any row returned = test FAILS.
select *
from {{ ref('fact_sales') }}
where total_amount < 0
   or price is null
