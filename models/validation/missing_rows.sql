{% set pk = var('primary_key') %}
select s.{{pk}}, 'MISSING_IN_TARGET' as issue
from {{ ref('stg_source') }} s
left join {{ ref('stg_target') }} t
on s.{{pk}} = t.{{pk}}
where t.{{pk}} is null

union all

select t.{{pk}}, 'MISSING_IN_SOURCE' as issue
from {{ ref('stg_target') }} t
left join {{ ref('stg_source') }} s
on s.{{pk}} = t.{{pk}}
where s.{{pk}} is null