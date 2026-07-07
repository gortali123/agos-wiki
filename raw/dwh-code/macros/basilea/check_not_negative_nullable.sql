{# -----------------------------------------------------------
   check_not_negative_nullable(campo)
   Campo opzionale: se presente non può essere negativo.
   → COUNT_IF(campo < 0)
----------------------------------------------------------- #}
{% macro check_not_negative_nullable(campo) %}
    COUNT_IF({{ campo }} < 0)
{% endmacro %}
 