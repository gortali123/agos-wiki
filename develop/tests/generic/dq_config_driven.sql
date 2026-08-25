{% test dq_config_driven(model, cfg_severity) %}

{% if execute %}

{%- set cfg_rows = dbt_utils.get_query_results_as_dict(
    "select ds_colonna, ds_test_type from " ~ env_var('DBT_DATABASE') ~ ".tech.cfg_dq_test_config"
    ~ " where ds_modello = '" ~ model.identifier ~ "' and ds_severity = '" ~ cfg_severity ~ "' and fl_active = 'Y'"
) -%}

{%- set checks = [] -%}
{%- for i in range(cfg_rows['DS_COLONNA'] | length) -%}
  {%- set col = cfg_rows['DS_COLONNA'][i] -%}
  {%- set test_type = cfg_rows['DS_TEST_TYPE'][i] -%}
  {%- if test_type == 'is_valid_email' -%}
    {%- set condition = col ~ " is not null and not regexp_like(" ~ col ~ ", '^[^@\\\\s]+@[^@\\\\s]+\\\\.[^@\\\\s]+$')" -%}
  {%- else -%}
    {{ exceptions.raise_compiler_error("dq_config_driven: DS_TEST_TYPE non gestito: " ~ test_type) }}
  {%- endif -%}
  {%- do checks.append({'col': col, 'test_type': test_type, 'condition': condition}) -%}
{%- endfor -%}

{%- if checks | length == 0 -%}

select
  '{{ run_started_at }}' as ts_started_at,
  'dq_config_driven' as ds_nome_test,
  '{{ model.schema }}' as ds_schema,
  '{{ model.identifier }}' as ds_tabella,
  object_construct() as gn_failure_info,
  '{{ invocation_id }}' as cd_run_dbt
where false

{%- else -%}

with dq_results as (
  select
    object_construct(
      {% for c in checks %}
      '{{ c.col }}', iff({{ c.condition }}, '{{ c.test_type }}', null){{ ',' if not loop.last else '' }}
      {% endfor %}
    ) as failure_info
  from {{ model }}
)

select
  '{{ run_started_at }}' as ts_started_at,
  'dq_config_driven' as ds_nome_test,
  '{{ model.schema }}' as ds_schema,
  '{{ model.identifier }}' as ds_tabella,
  failure_info as gn_failure_info,
  '{{ invocation_id }}' as cd_run_dbt
from dq_results
where array_size(object_keys(failure_info)) > 0

{%- endif -%}

{% endif %}
{% endtest %}
