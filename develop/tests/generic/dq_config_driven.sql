{% test dq_config_driven(model, cfg_severity) %}

{{ config(store_failures = false) }}

{% if execute %}

{%- set cfg_rows = dbt_utils.get_query_results_as_dict(
    "select ds_colonna, ds_test_type from " ~ env_var('DBT_DATABASE') ~ ".tech.cfg_dq_test_config"
    ~ " where ds_modello = '" ~ model.identifier ~ "' and ds_severity = '" ~ cfg_severity ~ "' and fl_active = 'Y'"
) -%}

{%- set conditions = [] -%}
{%- for i in range(cfg_rows['DS_COLONNA'] | length) -%}
  {%- set col = cfg_rows['DS_COLONNA'][i] -%}
  {%- set test_type = cfg_rows['DS_TEST_TYPE'][i] -%}
  {%- if test_type == 'is_valid_email' -%}
    {%- do conditions.append(col ~ " is not null and not regexp_like(" ~ col ~ ", '^[^@\\\\s]+@[^@\\\\s]+\\\\.[^@\\\\s]+$')") -%}
  {%- else -%}
    {{ exceptions.raise_compiler_error("dq_config_driven: DS_TEST_TYPE non gestito: " ~ test_type) }}
  {%- endif -%}
{%- endfor -%}

{%- if conditions | length == 0 -%}

select * from {{ model }} where false

{%- else -%}

select * from {{ model }} where ({{ conditions | join(') or (') }})

{%- endif -%}

{% endif %}
{% endtest %}
