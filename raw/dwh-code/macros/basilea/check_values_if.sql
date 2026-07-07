{# -----------------------------------------------------------
   check_values_if(campo, valori, campo_cond, val_cond)
   Dominio fisso condizionale su singolo valore:
     - se campo_cond = val_cond  → campo NOT NULL e in valori
     - altrimenti               → campo deve essere NULL
----------------------------------------------------------- #}
{% macro check_values_if(campo, valori, campo_cond, val_cond) %}
    COUNT_IF(
        ({{ campo_cond }} = '{{ val_cond }}'
            AND ({{ campo }} IS NULL
                 OR {{ campo }} NOT IN (
                     {% for v in valori %}'{{ v }}'{% if not loop.last %}, {% endif %}{% endfor %}
                 )))
        OR ({{ campo_cond }} <> '{{ val_cond }}'
            AND {{ campo }} IS NOT NULL)
    )
{% endmacro %}