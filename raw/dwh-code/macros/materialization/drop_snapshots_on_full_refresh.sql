{% macro drop_snapshots_on_full_refresh() %}
  {% if execute and flags.FULL_REFRESH %}
    {% for node in graph.nodes.values() | selectattr('resource_type', 'equalto', 'snapshot') %}
      {% if node.unique_id in selected_resources %}
        {% set relation = adapter.get_relation(database=node.database, schema=node.schema, identifier=node.alias) %}
        {% if relation is not none %}
          {% do adapter.drop_relation(relation) %}
        {% endif %}
      {% endif %}
    {% endfor %}
  {% endif %}
{% endmacro %}
