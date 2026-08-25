{% test dq_config_driven(model, column_name) %}

{%- if not execute -%}
  select null as dq_failures where false
{%- else -%}

{%- set cfg_rows = dbt_utils.get_query_results_as_dict(
    "select ds_test_type, ds_severity from " ~ env_var('DBT_DATABASE') ~ ".tech.cfg_dq_test_config"
    ~ " where ds_modello = '" ~ model.identifier ~ "' and ds_colonna = '" ~ column_name ~ "' and fl_active = 'Y'"
) -%}

{%- if cfg_rows['DS_TEST_TYPE'] | length == 0 -%}
  select null as dq_failures where false
{%- else -%}

  {%- set test_type = cfg_rows['DS_TEST_TYPE'][0] -%}
  {%- set severity = cfg_rows['DS_SEVERITY'][0] -%}
  {{ config(severity = severity) }}

  {%- if test_type == 'is_valid_email' -%}
    {%- set condition = column_name ~ " is not null and not regexp_like(" ~ column_name ~ ", '^[^@\\\\s]+@[^@\\\\s]+\\\\.[^@\\\\s]+$')" -%}
  {%- else -%}
    {{ exceptions.raise_compiler_error("dq_config_driven: DS_TEST_TYPE non gestito: " ~ test_type) }}
  {%- endif -%}

  select * from {{ model }} where {{ condition }}

{%- endif -%}
{%- endif -%}

{% endtest %}
