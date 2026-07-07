{# -----------------------------------------------------------
   check_not_negative(campo)
   Campo obbligatorio: non NULL e non negativo.
   → COUNT_IF(campo IS NULL OR campo < 0)
----------------------------------------------------------- #}
{% macro check_not_negative(campo) %}
    COUNT_IF({{ campo }} IS NULL OR {{ campo }} < 0)
{% endmacro %}
 