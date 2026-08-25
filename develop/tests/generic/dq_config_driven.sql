{% test dq_config_driven(model, cfg_severity) %}

{{ config(store_failures = false) }}

{% if not execute %}

select * from {{ model }} where false

{% else %}

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

{%- if checks | length > 0 -%}

  {%- set counts_sql -%}
    {% for c in checks %}
    select '{{ c.col }}' as ds_colonna, '{{ c.test_type }}' as ds_test_type, count(*) as nm_failures
    from {{ model }}
    where {{ c.condition }}
    {{ "union all" if not loop.last }}
    {% endfor %}
  {%- endset -%}

  {%- set counts_table = run_query(counts_sql) -%}

  {%- set log_rows = [] -%}
  {%- for row in counts_table.rows -%}
    {%- set nm_failures = row['NM_FAILURES'] -%}
    {%- set row_status = 'PASS' if nm_failures == 0 else (cfg_severity | upper) -%}
    {%- set json_row -%}
{
  "execution_type": "TEST",
  "ts_started_at": "{{ run_started_at }}",
  "nm_execution_time": 0,
  "ds_schema": "{{ model.schema }}",
  "ds_tabella": "{{ model.identifier | upper }}",
  "ds_status": "{{ row_status }}",
  "ds_test_name": "{{ row['DS_TEST_TYPE'] | upper }}_{{ row['DS_COLONNA'] | upper }}",
  "nm_failures": {{ nm_failures }},
  "ds_message": null,
  "cd_run_dbt": "{{ invocation_id }}",
  "cd_query_sf": ""
}
    {%- endset -%}
    {%- do log_rows.append(json_row) -%}
  {%- endfor -%}

  {%- set payload = ('[' ~ (log_rows | join(', ')) ~ ']') | replace('$$', '') -%}
  {%- do run_query(
      "call " ~ env_var('DBT_DATABASE') ~ ".tech.log_dbt(parse_json($$" ~ payload ~ "$$))"
  ) -%}

select * from {{ model }} where ({{ checks | map(attribute='condition') | join(') or (') }})

{%- else -%}

select * from {{ model }} where false

{%- endif -%}

{% endif %}

{% endtest %}
