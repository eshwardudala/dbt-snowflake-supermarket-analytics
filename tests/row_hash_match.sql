{% set pk = var('primary_key') %}

select s.{{ pk }}
from {{ ref('stg_source') }} s
join {{ ref('stg_target') }} t
on s.{{ pk }} = t.{{ pk }}
where s.row_hash <> t.row_hash