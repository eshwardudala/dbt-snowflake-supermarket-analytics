

{% set pk = var('primary_key', ['customerid']) %}
{% set src = source('landing', 'migrated_customers') %}

select
    *,
    {{ generate_row_hash(src, pk) }} as row_hash
from {{ src }}