{# -----------------------------------------------------------
   check_present_if_not_null(campo_target, campo_cond)
   Il campo_target deve essere NOT NULL quando campo_cond è NOT NULL.
   Es: {{ check_present_if_not_null('LGD_SCORE', 'CD_CLUSTER_LGD') }}
   → COUNT_IF(CD_CLUSTER_LGD IS NOT NULL AND LGD_SCORE IS NULL)
----------------------------------------------------------- #}
{% macro check_present_if_not_null(campo_target, campo_cond) %}
    COUNT_IF(
        {{ campo_cond }} IS NOT NULL
        AND {{ campo_target }} IS NULL
    )
{% endmacro %}
 