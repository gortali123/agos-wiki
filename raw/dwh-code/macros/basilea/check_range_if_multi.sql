{# -----------------------------------------------------------
   check_range_if_multi(campo, min_max_list, campo_cond, else_null)
   Range condizionale su più valori del campo_cond.
   min_max_list: lista di dict {val, min, max}
   else_null: se true, per valori non in lista il campo deve essere NULL
   Es:
     {{ check_range_if_multi(
          'BIN_DELTA_INCOME_INSTL',
          [{'val':'PPP','min':0,'max':19},
           {'val':'CPA','min':0,'max':11},
           {'val':'BKS','min':0,'max':8}],
          'PD_TYPE', true
        ) }}
----------------------------------------------------------- #}
{% macro check_range_if_multi(campo, min_max_list, campo_cond, else_null=true) %}
    COUNT_IF(
        {% for item in min_max_list %}
        ({{ campo_cond }} = '{{ item.val }}'
            AND ({{ campo }} IS NULL
                 OR {{ campo }} < {{ item.min }}
                 OR {{ campo }} > {{ item.max }}))
        {% if not loop.last %} OR {% endif %}
        {% endfor %}
        {% if else_null %}
        OR ({{ campo_cond }} NOT IN (
                {% for item in min_max_list %}
                    '{{ item.val }}'{% if not loop.last %}, {% endif %}
                {% endfor %}
            )
            AND {{ campo }} IS NOT NULL)
        {% endif %}
    )
{% endmacro %}
