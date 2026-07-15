{% test primary_key(model, pk_columns, where_clause=none) %}
{{ config(severity='error') }}

{% if execute %}

  {% set l1_model = model.identifier | replace('_source', '') %}
  {% set l1_node = graph.nodes.values() | selectattr('name', 'equalto', ('stg_' ~ l1_model)) | first %}
  {% if not l1_node %}
    {% set l1_node = graph.nodes.values() | selectattr('name', 'equalto', l1_model) | first %}
  {% endif %}

  {% set pk_cols_typed = [] %}
  {% for col in pk_columns %}
    {% set col_def = l1_node.columns.get(col | lower) or l1_node.columns.get(col) %}
    {% if col_def %}
      {% do pk_cols_typed.append({'name': col, 'data_type': col_def.data_type}) %}
    {% endif %}
  {% endfor %}

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
    {% if where_clause %}and ({{ where_clause }}){% endif %}
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
    {% if where_clause %}where {{ where_clause }}{% endif %}
  )
  where pk_count > 1

),

cast_failed_pks as (

  select distinct
    object_construct(
      {% for col in pk_cols_typed %}
        '{{ col.name }}', iff({{ col.name }} is not null and try_cast({{ col.name }} as {{ col.data_type }}) is null, cast({{ col.name }} as varchar), null)
        {{ ',' if not loop.last else '' }}
      {% endfor %}
    ) as failure_info
  from {{ model }}
  where 1=1
    {% if where_clause %}and ({{ where_clause }}){% endif %}
    and (
      1=0
      {% for col in pk_cols_typed %}
        or ({{ col.name }} is not null and try_cast({{ col.name }} as {{ col.data_type }}) is null)
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
