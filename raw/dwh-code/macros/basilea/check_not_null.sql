{# -----------------------------------------------------------
   check_not_null(campo)
   Verifica che il campo non sia NULL.
   → COUNT_IF(campo IS NULL)
----------------------------------------------------------- #}
{% macro check_not_null(campo) %}
    COUNT_IF({{ campo }} IS NULL)
{% endmacro %}
 