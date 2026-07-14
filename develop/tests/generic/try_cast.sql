{% test try_cast(model, skip_columns=none, where_clause=none, accepted_values=none) %}

{% if execute %}

  {% set l1_model = model.identifier | replace('_source', '') %}
  {% set l1_node = graph.nodes.values() | selectattr('name', 'equalto', ('stg_' ~ l1_model)) | first %}
  {% if not l1_node %}
    {% set l1_node = graph.nodes.values() | selectattr('name', 'equalto', l1_model) | first %}
  {% endif %}

  {% set columns_from_source = adapter.get_columns_in_relation(model) | map(attribute='column') | map('lower') | list %}
  {% set skip_columns_lower = (skip_columns or []) | map('lower') | list %}
  {% set accepted_values = accepted_values or {} %}

  {% set cols_to_render = [] %}
      {% for col_name, col_def in l1_node.columns.items() %}
          {% if col_name | lower in columns_from_source and col_name | lower not in skip_columns_lower %}
        {% do cols_to_render.append({'name': col_name | upper, 'data_type': col_def.data_type}) %}
          {% endif %}
  {% endfor %}

with cast_results as (
  select
    object_construct(
      {% for col in cols_to_render %}
          {% set exclude_for_col = accepted_values.get(col.data_type | lower) or [] %}
          '{{ col.name }}', iff(
            {{ col.name }} is not null
            and try_cast({{ col.name }} as {{ col.data_type }}) is null
            {% if exclude_for_col | length > 0 %}and {{ col.name }} not in ({% for val in exclude_for_col %}'{{ val }}'{{ ',' if not loop.last else '' }}{% endfor %}){% endif %},
            cast({{ col.name }} as varchar),
            null
          ){{ ',' if not loop.last else '' }}
      {% endfor %}
    ) as failure_info
  from {{ model }}
  {% if where_clause %}where {{ where_clause }}{% endif %}
)

select
  '{{ run_started_at }}' as ts_started_at,
  'try_cast' as ds_nome_test,
  '{{ l1_node.schema }}' as ds_schema,
  '{{ model.identifier }}' as ds_tabella,
  failure_info as gn_failure_info,
  '{{ invocation_id }}' as cd_run_dbt
from cast_results
where array_size(object_keys(failure_info)) > 0

{% endif %}
{% endtest %}
