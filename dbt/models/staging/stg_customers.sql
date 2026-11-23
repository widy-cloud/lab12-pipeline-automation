-- Same cleaning as the pandas step in Practice 10:
-- trim strings, standardise region to Title Case, cast types.
select
    cast(trim(customer_id) as integer)                         as customer_id,
    trim(name)                                                 as customer_name,
    upper(left(trim(region), 1)) || lower(substr(trim(region), 2)) as region
from {{ source('raw', 'customers') }}
