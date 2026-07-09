-- COPIA invariata di raw/dwh-code/tests/generic/try_cast_table.sql (nessuna modifica richiesta).
-- Inclusa qui solo per avere la cartella tests/ completa in queries/.

{% test try_cast_table(model, validation_config=none, where_clause=none, accepted_values=none, rtrim_varchar=false) %}

{% if execute %}

  {% set l1_model = model.identifier | replace('_source', '') %}
  {% set l1_node = graph.nodes.values() | selectattr('name', 'equalto', ('stg_' ~ l1_model)) | first %}
  {% if not l1_node %}
    {% set l1_node = graph.nodes.values() | selectattr('name', 'equalto', l1_model) | first %}
  {% endif %}

  {% set columns_from_source = adapter.get_columns_in_relation(model) | map(attribute='column') | map('lower') | list %}
  {% set validation_config = validation_config or {} %}
  {% set accepted_values = accepted_values or {} %}

  {# --- Costruisci prima la lista delle colonne da renderizzare --- #}
  {% set cols_to_render = [] %}
      {% for col_name, col_def in l1_node.columns.items() %}
          {% if col_name | lower in columns_from_source %}
            {% set skip = validation_config.get(col_name) == 'skip' %}
            {% if not skip %}
              {% set validation_sql = validation_config.get(col_name) if validation_config.get(col_name) and validation_config.get(col_name) != 'skip' else none %}
              {% set is_varchar = rtrim_varchar and 'varchar' in (col_def.data_type | lower) %}
              {% set col_ref = "nullif(rtrim(" ~ (col_name | upper) ~ "), '')" if is_varchar else (col_name | upper) %}
              {% if validation_sql %}
          {% set check_expr = validation_sql | replace(col_name, col_name | upper) %}
              {% else %}
          {% set check_expr = "try_cast(" ~ col_ref ~ " as " ~ col_def.data_type ~ ")" %}
              {% endif %}
        {% do cols_to_render.append({'name': col_name | upper, 'col_ref': col_ref, 'check_expr': check_expr, 'data_type': col_def.data_type}) %}
            {% endif %}
          {% endif %}
  {% endfor %}

with cast_results as (
  select
    object_construct(
      {% for col in cols_to_render %}
          {% set col_type_lower = col['data_type'] | lower %}
          {% set exclude_for_col = accepted_values.get(col_type_lower) or [] %}
          '{{ col.name }}', iff(
            {{ col.col_ref }} is not null
            and {{ col.check_expr }} is null
            {% if exclude_for_col | length > 0 %}and {{ col.col_ref }} not in ({% for val in exclude_for_col %}'{{ val }}'{{ ',' if not loop.last else '' }}{% endfor %}){% endif %},
            cast({{ col.col_ref }} as varchar),
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
