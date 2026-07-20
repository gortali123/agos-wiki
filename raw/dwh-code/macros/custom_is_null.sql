{% macro custom_is_null(column) %}
({{ column }} IS NULL or {{ column }} = ' ')
{% endmacro %}
