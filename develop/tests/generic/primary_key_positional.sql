{% test primary_key_positional(model, pk_columns, where_clause=none) %}
{{ config(severity='error') }}

{% if execute %}

  {% set l1_model = model.identifier | replace('_source', '') %}
  {% set l1_node = graph.nodes.values() | selectattr('name', 'equalto', ('stg_' ~ l1_model)) | first %}
  {% if not l1_node %}
    {% set l1_node = graph.nodes.values() | selectattr('name', 'equalto', l1_model) | first %}
  {% endif %}

  {% set pk_columns_lower = pk_columns | map('lower') | list %}

  {% set l1_sql = l1_node.raw_code %}
  {% set sql_upper = l1_sql | upper %}
  {% set select_idx = sql_upper.find('SELECT') %}
  {% set from_idx = sql_upper.find('FROM', select_idx) %}

  {# ricostruisce, per ogni pk_column, l'espressione (es. SUBSTR(...)) usata dall'L1
     per derivarla dal source posizionale: la colonna non esiste per nome nel source #}
  {% set pk_exprs = [] %}
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
        {% if col_name | lower in pk_columns_lower %}
          {% do pk_exprs.append({'name': col_name, 'expr': col_expr}) %}
        {% endif %}
      {% endif %}
    {% endfor %}
  {% endif %}

  {% set where_clause_l1 = '' %}
  {% if 'WHERE' in (l1_sql | upper) %}
    {% set where_clause_l1 = l1_sql.split('WHERE')[1] %}
  {% endif %}

with null_pks as (

  select
    object_construct(
      {% for col in pk_exprs %}
        '{{ col.name }}', iff(({{ col.expr }}) is null, 'null', null)
        {{ ',' if not loop.last else '' }}
      {% endfor %}
    ) as failure_info
  from {{ model }}
  where 1=1
    {% if where_clause %}and ({{ where_clause }}){% endif %}
    {% if where_clause_l1 %}and ({{ where_clause_l1 }}){% endif %}
    and (
      {% for col in pk_exprs %}
        ({{ col.expr }}) is null
        {% if not loop.last %} or {% endif %}
      {% endfor %}
    )

),

duplicate_pks as (

  select distinct
    object_construct(
      {% for col in pk_exprs %}
        '{{ col.name }}', cast({{ col.name }}_pk_expr as varchar)
        {{ ',' if not loop.last else '' }}
      {% endfor %}
    ) as failure_info
  from (
    select
      {% for col in pk_exprs %}
        ({{ col.expr }}) as {{ col.name }}_pk_expr,
      {% endfor %}
      count(*) over (partition by
        {% for col in pk_exprs %}
          ({{ col.expr }}){% if not loop.last %},{% endif %}
        {% endfor %}
      ) as pk_count
    from {{ model }}
    {% if where_clause or where_clause_l1 %}
    where 1=1
      {% if where_clause %}and ({{ where_clause }}){% endif %}
      {% if where_clause_l1 %}and ({{ where_clause_l1 }}){% endif %}
    {% endif %}
  )
  where pk_count > 1

)

select
  '{{ run_started_at }}' as ts_started_at,
  'primary_key_null' as ds_nome_test,
  '{{ l1_node.schema }}' as ds_schema,
  '{{ model.identifier }}' as ds_tabella,
  failure_info as gn_failure_info,
  '{{ invocation_id }}' as cd_run_dbt
from null_pks

union all

select
  '{{ run_started_at }}' as ts_started_at,
  'primary_key_duplicate' as ds_nome_test,
  '{{ l1_node.schema }}' as ds_schema,
  '{{ model.identifier }}' as ds_tabella,
  failure_info as gn_failure_info,
  '{{ invocation_id }}' as cd_run_dbt
from duplicate_pks

{% endif %}
{% endtest %}
