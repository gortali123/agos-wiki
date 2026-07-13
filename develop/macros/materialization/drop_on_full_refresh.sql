{% macro drop_on_full_refresh() %}
  {% if execute and flags.FULL_REFRESH and model.unique_id in selected_resources %}
    {% do log('--full-refresh: drop snapshot ' ~ this, info=true) %}
    {% do adapter.drop_relation(this) %}
  {% endif %}
{% endmacro %}
