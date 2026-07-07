{% macro truncate_models(models=[], paths=[]) %}
  {% set models = [models] if models is string else models %}
  {% set paths = [paths] if paths is string else paths %}
  {% set to_truncate = [] %}

  {% for name in models %}
    {% for _, node in graph.nodes.items() %}
      {% if node.resource_type == 'model' and node.name == name %}
        {% do to_truncate.append(node) %}
      {% endif %}
    {% endfor %}
  {% endfor %}

  {% for path in paths %}
    {% for _, node in graph.nodes.items() %}
      {% if node.resource_type == 'model' and path in node.path %}
        {% if node.name.startswith('stg_') %}
          {% set base_name = node.name[4:] %}
          {% for _, n in graph.nodes.items() %}
            {% if n.resource_type == 'snapshot' and n.name == base_name %}
              {% do to_truncate.append(n) %}
            {% endif %}
          {% endfor %}
        {% else %}
          {% do to_truncate.append(node) %}
        {% endif %}
      {% endif %}
    {% endfor %}
  {% endfor %}

  {% if execute %}
    {% for model in to_truncate %}
      {% set rel = adapter.get_relation(database=model.database, schema=model.schema, identifier=model.name) %}
      {% if rel %}
        {% do run_query('TRUNCATE TABLE ' ~ rel) %}
        {% do log('TRUNCATED: ' ~ rel, info=true) %}
      {% endif %}
    {% endfor %}
  {% endif %}
{% endmacro %}
