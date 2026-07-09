-- PROPOSTA: nuovo test generico dbt derivato da raw/dwh-code/tests/generic/primary_key_table.sql
-- Stessa struttura (stesso schema di output ts_started_at/ds_nome_test/ds_schema/ds_tabella/gn_failure_info/cd_run_dbt),
-- ma verifica SOLO l'unicita della chiave (rimossa la parte primary_key_null / null_pks).
-- Non testata: da copiare in my_dwh-x-dbt (tests/generic/) se approvata.

{% test unique_key_table(model, pk_columns, where_clause=none, rtrim_varchar=false) %}
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

with duplicate_pks as (

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
  'unique_key_duplicate' as ds_nome_test,
  '{{ l1_node.schema }}' as ds_schema,
  '{{ model.identifier }}' as ds_tabella,
  failure_info as gn_failure_info,
  '{{ invocation_id }}' as cd_run_dbt
from duplicate_pks

{% endif %}
{% endtest %}
