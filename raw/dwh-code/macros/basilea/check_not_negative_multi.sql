{# -----------------------------------------------------------
   check_not_negative_multi(campi)
   Verifica che una lista di campi non abbiano valori negativi o NULL.
   Utile per batch di campi denormalizzati (es. IM_FIDO_1..12).
   campi: lista di nomi campo
   Es: {{ check_not_negative_multi(['IM_FIDO_1','IM_FIDO_2','IM_FIDO_3']) }}
   → COUNT_IF(IM_FIDO_1 IS NULL OR IM_FIDO_1 < 0 OR IM_FIDO_2 IS NULL OR ...)
----------------------------------------------------------- #}
{% macro check_not_negative_multi(campi) %}
    COUNT_IF(
        {% for c in campi %}
        ({{ c }} IS NULL OR {{ c }} < 0)
        {% if not loop.last %} OR {% endif %}
        {% endfor %}
    )
{% endmacro %}
 