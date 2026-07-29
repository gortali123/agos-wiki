{% macro delete_dt_osservazione(column='DT_OSSERVAZIONE', schedule='monthly') %}
{% if execute %}
  {% if adapter.get_relation(this.database, this.schema, this.identifier) %}
    DELETE FROM {{ this }} WHERE {{ column }} = get_dt_osservazione(schedule);
  {% endif %}
{% endif %}
{% endmacro %}