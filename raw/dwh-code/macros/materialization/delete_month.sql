{#
  Pre_hook mensile (L1/L2/L3): cancella la partizione DT_OSSERVAZIONE = date_expr prima del ricarico.

  Args:
    date_expr (opzionale): mese da eliminare. Default: get_dt_osservazione().

  - modelli L1: passare get_dt_osservazione('ts_riferimento');
  - modelli L2/L3: non passare nulla.
  Gira solo se la tabella esiste gia' (skip al primo run / full-refresh).
#}
{% macro delete_month(column='DT_OSSERVAZIONE', date_expr=get_dt_osservazione()) %}
{% if execute %}
  {% if adapter.get_relation(this.database, this.schema, this.identifier) %}
    DELETE FROM {{ this }} WHERE DT_OSSERVAZIONE = {{ date_expr }};
  {% endif %}
{% endif %}
{% endmacro %}
