-- depends_on: {{ ref('stg_source') }}
-- depends_on: {{ ref('stg_target') }}

{% set pk = var('primary_key') %}
{% set cols = get_non_key_columns(ref('stg_source'), var('primary_key')) %}

{% for col in cols %}
select
    '{{ col }}' as column_name,
    count(*) as total_rows,
    sum(case when s.{{ col }} = t.{{ col }} then 1 else 0 end) as matched_rows,
    round(
        sum(case when s.{{ col }} = t.{{ col }} then 1 else 0 end)
        * 100.0 / count(*),
        2
    ) as match_percentage
from {{ ref('stg_source') }} s
join {{ ref('stg_target') }} t
  on s.{{ pk }} = t.{{ pk }}
{% if not loop.last %}union all{% endif %}
{% endfor %}