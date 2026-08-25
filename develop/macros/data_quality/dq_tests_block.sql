{% macro dq_cfg_by_col(model_name) %}
{%- set cfg_rows = dbt_utils.get_query_results_as_dict(
    "select ds_colonna, ds_test_type, gn_params, ds_severity from " ~ env_var('DBT_DATABASE') ~ ".tech.cfg_dq_test_config where ds_modello = '" ~ model_name ~ "' and fl_active = 'Y'"
) %}
{%- set result = {} %}
{%- for i in range(cfg_rows['DS_COLONNA']|length) %}
  {%- set col = cfg_rows['DS_COLONNA'][i] | upper %}
  {%- if col not in result %}{% do result.update({col: []}) %}{% endif %}
  {%- do result[col].append({'test_type': cfg_rows['DS_TEST_TYPE'][i], 'severity': cfg_rows['DS_SEVERITY'][i]}) %}
{%- endfor %}
{{- return(result) }}
{% endmacro %}

{% macro dq_tests_block(cfg_by_col, col_name) %}
{%- for t in cfg_by_col.get(col_name, []) %}
        tests:
          - {{ t.test_type }}:
              config:
                severity: {{ t.severity }}
{%- endfor %}
{%- endmacro %}
