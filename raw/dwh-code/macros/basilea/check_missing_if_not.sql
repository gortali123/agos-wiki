{# -----------------------------------------------------------
   check_missing_if_not(campo, campo_cond, val_cond)
   Il campo deve essere NULL quando campo_cond <> val_cond.
   (campo ammesso solo quando campo_cond = val_cond)
   Es: {{ check_missing_if_not('PC_CCF', 'TREATMENT', 'CCF') }}
   → COUNT_IF(TREATMENT <> 'CCF' AND PC_CCF IS NOT NULL)
----------------------------------------------------------- #}
{% macro check_missing_if_not(campo, campo_cond, val_cond) %}
    COUNT_IF(
        {{ campo_cond }} <> '{{ val_cond }}'
        AND {{ campo }} IS NOT NULL
    )
{% endmacro %}
 