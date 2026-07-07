{# -----------------------------------------------------------
   check_values_if_multi(campo, valori, campo_cond, val_cond_list)
   Dominio fisso condizionale su lista di valori del campo_cond.
   Es:
     {{ check_values_if_multi(
          'BIN_MAX_INS_CLI_L6M', [0,1,2], 'PD_TYPE', ['STF','NPA']
        ) }}
----------------------------------------------------------- #}
{% macro check_values_if_multi(campo, valori, campo_cond, val_cond_list) %}
    COUNT_IF(
        ({{ campo_cond }} IN (
                {% for v in val_cond_list %}'{{ v }}'{% if not loop.last %}, {% endif %}{% endfor %}
            )
            AND ({{ campo }} IS NULL
                 OR {{ campo }} NOT IN (
                     {% for v in valori %}'{{ v }}'{% if not loop.last %}, {% endif %}{% endfor %}
                 )))
        OR ({{ campo_cond }} NOT IN (
                {% for v in val_cond_list %}'{{ v }}'{% if not loop.last %}, {% endif %}{% endfor %}
            )
            AND {{ campo }} IS NOT NULL)
    )
{% endmacro %}
 