{# -----------------------------------------------------------
   check_range(campo, min, max)
   Campo obbligatorio con range numerico [min, max].
   → COUNT_IF(campo IS NULL OR campo < min OR campo > max)
----------------------------------------------------------- #}
{% macro check_range(campo, min, max) %}
    COUNT_IF(
        {{ campo }} IS NULL
        OR {{ campo }} < {{ min }}
        OR {{ campo }} > {{ max }}
    )
{% endmacro %}
 