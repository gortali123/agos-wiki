{% test primary_key_table(model, pk_columns, where_clause=none, rtrim_varchar=false) %}
{{ config(severity='error') }}

{% if execute %}

  {% set l1_model = model.identifier | replace('_source', '') %}
  {% set l1_node = graph.nodes.values() | selectattr('name', 'equalto', ('stg_' ~ l1_model)) | first %}
  {% if not l1_node %}
    {% set l1_node = graph.nodes.values() | selectattr('name', 'equalto', l1_model) | first %}
  {% endif %}

  {# --- tipi colonne da l1_node per applicare rtrim sui varchar (come in generate_model) --- #}
  {% set col_types = {} %}
  {% if l1_node %}
    {% for col_name, col_def in l1_node.columns.items() %}
      {% do col_types.update({col_name | lower: col_def.data_type | lower}) %}
    {% endfor %}
  {% endif %}

  {% set pk_expr = {} %}
  {% for col in pk_columns %}
    {% if rtrim_varchar and 'varchar' in col_types.get(col | lower, '') %}
      {% do pk_expr.update({col: "nullif(rtrim(" ~ col ~ "), '')"}) %}
    {% else %}
      {% do pk_expr.update({col: col}) %}
    {% endif %}
  {% endfor %}

with null_pks as (

  select
    object_construct(
      {% for col in pk_columns %}
        '{{ col }}', iff({{ pk_expr[col] }} is null, 'null', null)
        {{ ',' if not loop.last else '' }}
      {% endfor %}
    ) as failure_info
  from {{ model }}
  where 1=1
    {% if where_clause %}and ({{ where_clause }}){% endif %}
    and (
      {% for col in pk_columns %}
        {{ pk_expr[col] }} is null
        {% if not loop.last %} or {% endif %}
      {% endfor %}
    )

),

duplicate_pks as (

  select distinct
    object_construct(
      {% for col in pk_columns %}
        '{{ col }}', cast({{ pk_expr[col] }} as varchar)
        {{ ',' if not loop.last else '' }}
      {% endfor %}
    ) as failure_info
  from (
    select
      *,
      count(*) over (partition by
        {% for col in pk_columns %}
          {{ pk_expr[col] }}{% if not loop.last %},{% endif %}
        {% endfor %}
      ) as pk_count
    from {{ model }}
    {% if where_clause %}where {{ where_clause }}{% endif %}
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