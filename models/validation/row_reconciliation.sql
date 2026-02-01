{% set pk = var('primary_key') %}

select
    coalesce(s.{{ pk }}, t.{{ pk }}) as {{ pk }},
    case
        when s.{{ pk }} is null then 'MISSING_IN_SOURCE'
        when t.{{ pk }} is null then 'MISSING_IN_TARGET'
        when s.row_hash = t.row_hash then 'MATCHED'
        else 'VALUE_MISMATCH'
    end as row_status
from {{ ref('stg_source') }} s
full outer join {{ ref('stg_target') }} t
on s.{{ pk }} = t.{{ pk }}