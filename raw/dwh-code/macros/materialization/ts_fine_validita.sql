{#
  Calcola TS_FINE_VALIDITA come inizio validita' del record successivo (o 9999-12-31).

  Args:
    partition_by: colonna/e di partizione.
    ts_inizio_validita: colonna di inizio validita' (default 'TS_INIZIO_VALIDITA').
    order_extra (opzionale): tie-breaker aggiuntivo nell'ORDER BY del LEAD.
#}
{% macro ts_fine_validita(partition_by, ts_inizio_validita='TS_INIZIO_VALIDITA', order_extra=none) %}
COALESCE(
    LEAD({{ ts_inizio_validita }}) OVER (
        PARTITION BY {{ partition_by }}
        ORDER BY {{ ts_inizio_validita }}{% if order_extra is not none %}, {{ order_extra }}{% endif %}
    ),
    TO_TIMESTAMP_NTZ('9999-12-31 00:00:00.000')
)
{% endmacro %}
