{# -----------------------------------------------------------
   check_score_range_by_default(campo_score, campo_default,
                                 val_default, score_min, score_max)
   Pattern ricorrente sui campi score:
     - se IN_DEFAULT = val_default → score deve essere = score_max (es. 1)
     - altrimenti                 → score in (score_min, score_max]
   Es: {{ check_score_range_by_default(
           'PD_SCORE_PRT', 'IN_DEFAULT', 'S', 0, 1
         ) }}
----------------------------------------------------------- #}
{% macro check_score_range_by_default(campo_score, campo_default, val_default, score_min, score_max) %}
    COUNT_IF(
        {{ campo_score }} IS NULL
        OR ({{ campo_default }} = '{{ val_default }}'
            AND {{ campo_score }} <> {{ score_max }})
        OR ({{ campo_default }} <> '{{ val_default }}'
            AND ({{ campo_score }} <= {{ score_min }}
                 OR {{ campo_score }} >= {{ score_max }}))
    )
{% endmacro %}