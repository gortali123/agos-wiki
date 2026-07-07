{# -----------------------------------------------------------
   check_not_zero(campo)
   Campo obbligatorio: non NULL e non zero.
   → COUNT_IF(campo IS NULL OR campo = 0)
----------------------------------------------------------- #}
{% macro check_not_zero(campo) %}
    COUNT_IF({{ campo }} IS NULL OR {{ campo }} = 0)
{% endmacro %}
 