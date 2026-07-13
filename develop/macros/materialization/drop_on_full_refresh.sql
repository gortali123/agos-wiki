{% macro drop_on_full_refresh() %}
  {% if execute and flags.FULL_REFRESH and model.unique_id in selected_resources %}
    {% set relation = adapter.get_relation(database=this.database, schema=this.schema, identifier=this.identifier) %}
    {% if relation is not none %}
      {% do log('--full-refresh: drop snapshot ' ~ relation, info=true) %}
      {% do adapter.drop_relation(relation) %}
    {% endif %}
  {% endif %}
{% endmacro %}
