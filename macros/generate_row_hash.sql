{% macro generate_row_hash(relation, primary_key) %}
    md5(
        concat_ws(
            '|',
            {% for col in get_non_key_columns(relation, primary_key) %}
                cast({{ col }} as varchar)
                {% if not loop.last %},{% endif %}
            {% endfor %}
        )
    )
{% endmacro %}