{% test dq_config_driven(model, severity, store_failures=false) %}

{{ config(store_failures = store_failures, severity = severity) }}

{%- if not execute -%}
  select null as dq_failures where false
{%- else -%}

{%- set cfg_rows = dbt_utils.get_query_results_as_dict(
    "select ds_colonna, ds_test_type from " ~ env_var('DBT_DATABASE') ~ ".tech.cfg_dq_test_config"
    ~ " where ds_modello = '" ~ model.identifier ~ "' and ds_severity = '" ~ severity ~ "' and fl_active = 'Y'"
) -%}

{%- if cfg_rows['DS_COLONNA'] | length == 0 -%}
  select null as dq_failures where false
{%- else -%}

  {%- set parts = [] -%}
  {%- for i in range(cfg_rows['DS_COLONNA'] | length) -%}
    {%- set col = cfg_rows['DS_COLONNA'][i] -%}
    {%- set test_type = cfg_rows['DS_TEST_TYPE'][i] -%}
    {%- if test_type == 'is_valid_email' -%}
      {%- do parts.append(test_is_valid_email(model=model, column_name=col)) -%}
    {%- else -%}
      {{ exceptions.raise_compiler_error("dq_config_driven: DS_TEST_TYPE non gestito: " ~ test_type) }}
    {%- endif -%}
  {%- endfor -%}

  {{ parts | join('\nunion all\n') }}

{%- endif -%}
{%- endif -%}

{% endtest %}
