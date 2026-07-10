-- PROPOSTA: nuovo test generico dbt derivato da raw/dwh-code/tests/generic/primary_key_table.sql
-- Stessa struttura (stesso schema di output ts_started_at/ds_nome_test/ds_schema/ds_tabella/gn_failure_info/cd_run_dbt),
-- ma verifica SOLO l'unicita della chiave (rimossa la parte primary_key_null / null_pks).
-- Rimosso anche rtrim_varchar/nullif(rtrim(...)): inutile qui, era pensato per gestire i null su varchar
-- vuoti nel controllo primary_key_null, che questo test non fa piu.
-- Non testata: da copiare in my_dwh-x-dbt (tests/generic/) se approvata.

{% test unique_key_table(model, pk_columns, where_clause=none) %}
{{ config(severity='error') }}

{% if execute %}

  {% set l1_model = model.identifier | replace('_source', '') %}
  {% set l1_node = graph.nodes.values() | selectattr('name', 'equalto', ('stg_' ~ l1_model)) | first %}
  {% if not l1_node %}
    {% set l1_node = graph.nodes.values() | selectattr('name', 'equalto', l1_model) | first %}
  {% endif %}

with duplicate_pks as (

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
