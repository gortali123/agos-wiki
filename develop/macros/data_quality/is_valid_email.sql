{% macro is_valid_email(column_name) %}
{{ column_name }} is not null and not regexp_like({{ column_name }}, '^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$')
{% endmacro %}
