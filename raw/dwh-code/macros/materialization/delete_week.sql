{#
  Pre_hook settimanale (L1/L2/L3): cancella la partizione DT_ACCETTAZIONE = date_expr prima del ricarico.

  Args:
    date_expr (opzionale): settimana da eliminare. Default: get_dt_accettazione().

  - modelli L1: passare get_dt_accettazione('ts_riferimento');
  - modelli L2/L3: non passare nulla.
  Gira solo se la tabella esiste gia' (skip al primo run / full-refresh).
#}
{% macro delete_week(column='DT_ACCETTAZIONE', date_expr=get_dt_accettazione()) %}
{% if execute %}
  {% if adapter.get_relation(this.database, this.schema, this.identifier) %}
    DELETE FROM {{ this }} WHERE {{ column }} = {{ date_expr }};
  {% endif %}
{% endif %}
{% endmacro %}
