{# -----------------------------------------------------------
   check_coerenza_if(campo_target, campo_cond, val_cond, valore_atteso)
   Verifica campo_target = valore_atteso quando campo_cond = val_cond.
   Testa anche NULL del target.
   Es:  check_coerenza_if('PD_SCORE_PRT', 'IN_DEFAULT', 'S', 1)
   → COUNT_IF(IN_DEFAULT = 'S' AND (PD_SCORE_PRT IS NULL OR PD_SCORE_PRT <> 1))
----------------------------------------------------------- #}




{% macro check_coerenza_if(campo_target, campo_cond, val_cond, valore_atteso) %}
    COUNT_IF(
        {{ campo_cond }} = '{{ val_cond }}'
        AND ({{ campo_target }} IS NULL OR {{ campo_target }} <> {{ valore_atteso }})
    )
{% endmacro %}
