{% test primary_key_from_sql(model, pk_columns) %}
{{ config(severity='error') }}

{% if execute %}

  {% set l1_model = (model.identifier | replace('_source', '')) | lower %}
  {% set l1_node = none %}
  {% for n in graph.nodes.values() %}
    {% if n.name | lower == ('stg_' ~ l1_model) or n.name | lower == l1_model %}
      {% set l1_node = n %}
    {% endif %}
  {% endfor %}

  {% set pk_columns_lower = pk_columns | map('lower') | list %}

  {# espressione di cast reale della/e colonna/e PK, parsata dal raw_code L1 (come try_cast_from_sql) #}
  {% set l1_sql = l1_node.raw_code %}
  {% set sql_upper = l1_sql | upper %}
  {% set select_idx = sql_upper.find('SELECT') %}
  {% set from_idx = sql_upper.find('FROM', select_idx) %}

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

  {# WHERE dell'L1 (se filtra righe): niente where_clause come parametro, solo questo #}
  {% set where_idx = sql_upper.find('WHERE') %}
  {% set where_clause_l1 = l1_sql[where_idx + 5:] if where_idx >= 0 else '' %}

with null_pks as (

  select
    object_construct(
      {% for col in pk_columns %}
        '{{ col }}', iff({{ col }} is null, 'null', null)
        {{ ',' if not loop.last else '' }}
      {% endfor %}
    ) as failure_info
  from {{ model }}
  where 1=1
    {% if where_clause_l1 %}and ({{ where_clause_l1 }}){% endif %}
    and (
      {% for col in pk_columns %}
        {{ col }} is null
        {% if not loop.last %} or {% endif %}
      {% endfor %}
    )

),

duplicate_pks as (

  select distinct
    object_construct(
      {% for col in pk_columns %}
        '{{ col }}', cast({{ col }} as varchar)
        {{ ',' if not loop.last else '' }}
      {% endfor %}
    ) as failure_info
  from (
    select
      *,
      count(*) over (partition by
        {% for col in pk_columns %}
          {{ col }}{% if not loop.last %},{% endif %}
        {% endfor %}
      ) as pk_count
    from {{ model }}
    {% if where_clause_l1 %}where {{ where_clause_l1 }}{% endif %}
  )
  where pk_count > 1

),

cast_failed_pks as (

  select distinct
    object_construct(
      {% for col in pk_exprs %}
        '{{ col.name }}', iff({{ col.name }} is not null and ({{ col.expr }}) is null, cast({{ col.name }} as varchar), null)
        {{ ',' if not loop.last else '' }}
      {% endfor %}
    ) as failure_info
  from {{ model }}
  where 1=1
    {% if where_clause_l1 %}and ({{ where_clause_l1 }}){% endif %}
    and (
      1=0
      {% for col in pk_exprs %}
        or ({{ col.name }} is not null and ({{ col.expr }}) is null)
      {% endfor %}
    )

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

union all

select
  '{{ run_started_at }}' as ts_started_at,
  'primary_key_cast_failed' as ds_nome_test,
  '{{ l1_node.schema }}' as ds_schema,
  '{{ model.identifier }}' as ds_tabella,
  failure_info as gn_failure_info,
  '{{ invocation_id }}' as cd_run_dbt
from cast_failed_pks

{% endif %}
{% endtest %}
