{# -----------------------------------------------------------
   check_range_if(campo, min, max, campo_cond, val_cond)
   Range condizionale su singolo valore:
     - se campo_cond = val_cond  → campo NOT NULL e in [min, max]
     - altrimenti               → campo deve essere NULL
   → COUNT_IF(
         (campo_cond = 'val' AND (campo IS NULL OR campo < min OR campo > max))
      OR (campo_cond <> 'val' AND campo IS NOT NULL)
     )
----------------------------------------------------------- #}
{% macro check_range_if(campo, min, max, campo_cond, val_cond) %}
    COUNT_IF(
        ({{ campo_cond }} = '{{ val_cond }}'
            AND ({{ campo }} IS NULL OR {{ campo }} < {{ min }} OR {{ campo }} > {{ max }}))
        OR ({{ campo_cond }} <> '{{ val_cond }}'
            AND {{ campo }} IS NOT NULL)
    )
{% endmacro %}