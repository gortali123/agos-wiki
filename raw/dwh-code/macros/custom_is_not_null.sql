{% macro custom_is_not_null(column) %}
({{ column }} IS NOT NULL and {{ column }} != ' ')
{% endmacro %}
