{% test try_cast_from_sql(model, skip_columns=none, accepted_values=none) %}

{% if execute %}

  {% set l1_model = model.identifier | replace('_source', '') %}
  {% set l1_node = graph.nodes.values() | selectattr('name', 'equalto', ('stg_' ~ l1_model)) | first %}
  {% if not l1_node %}
    {% set l1_node = graph.nodes.values() | selectattr('name', 'equalto', l1_model) | first %}
  {% endif %}

  {% set skip_columns_lower = ((skip_columns or []) + ['ts_riferimento', 'ts_caricamento']) | map('lower') | list %}
  {% set accepted_values = accepted_values or {} %}

  {% set l1_sql = l1_node.raw_code %}
  {% set sql_upper = l1_sql | upper %}
  {% set select_idx = sql_upper.find('SELECT') %}
  {% set from_idx = sql_upper.find('FROM', select_idx) %}

  {% set cols_to_check = [] %}
  {% if select_idx >= 0 and from_idx > select_idx %}
    {% set after_select = l1_sql[select_idx + 6:from_idx] %}
    {% for line in after_select.split('\n') %}
      {% set line_upper = line | upper %}
      {% if ' AS ' in line_upper %}
        {% set as_idx = line_upper.rfind(' AS ') %}
        {% set col_name = line[as_idx + 4:] | trim | replace(',', '') %}
        {% if '--' in col_name %}
          {% set col_name = col_name.split('--')[0] | trim %}
        {% endif %}
        {% set col_expr = line[:as_idx] | trim %}
        {% if col_name and col_expr and col_name | lower not in skip_columns_lower %}
          {% set col_from_l1 = l1_node.columns.get(col_name | lower) or l1_node.columns.get(col_name) %}
          {% set col_data_type = col_from_l1.data_type | lower if col_from_l1 else '' %}
          {% set exclude_vals = accepted_values.get(col_data_type) or [] %}
          {% do cols_to_check.append({'name': col_name, 'expr': col_expr, 'exclude_vals': exclude_vals}) %}
        {% endif %}
      {% endif %}
    {% endfor %}
  {% endif %}

  {% set where_clause = '' %}
  {% if 'WHERE' in sql_upper %}
    {% set where_clause = l1_sql.split('WHERE')[1] %}
  {% endif %}

with check_results as (
  select
    object_construct(
      {% for col in cols_to_check %}
        '{{ col.name }}', iff(
          {{ col.name }} is not null
          and ({{ col.expr }}) is null
          {% if col.exclude_vals | length > 0 %}and {{ col.name }} not in ({% for val in col.exclude_vals %}'{{ val }}'{{ ',' if not loop.last else '' }}{% endfor %}){% endif %},
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
from check_results
where array_size(object_keys(failure_info)) > 0

{% endif %}
{% endtest %}
