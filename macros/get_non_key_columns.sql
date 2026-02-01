{% macro get_non_key_columns(relation, primary_key) %}
    {% set cols = adapter.get_columns_in_relation(relation) %}
    {% set non_key_cols = [] %}
    {% set pk_lower = primary_key | map('lower') | list %}

    {% for col in cols %}
        {% if col.name | lower not in pk_lower %}
            {% do non_key_cols.append(col.name) %}
        {% endif %}
    {% endfor %}

    {{ return(non_key_cols) }}
{% endmacro %}