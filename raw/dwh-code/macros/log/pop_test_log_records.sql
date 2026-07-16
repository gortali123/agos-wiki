{% macro pop_test_log_records(results) %}
  {% if not execute %}
    {{ return('') }}
  {% endif %}

  {% set db = env_var('DBT_DATABASE') %}
  {% set sch_log = 'LOGS' %}
  {% set sch_store_fail = 'DBT_STORE_FAILURES' %}

  {% set test_log_records = adapter.get_relation(database=db, schema=sch_log, identifier='test_log_records') %}
  {% if test_log_records is none %}
    {{ return('') }}
  {% endif %}

  {% set tables = [] %}
  {% set all_tables = [] %}
  {% for res in results %}
    {% if res.node.resource_type == 'test' %}
      {% do all_tables.append(res.node.alias | upper) %}
      {% if res.status in ['warn','fail'] %}
        {% do tables.append(res.node.alias | upper) %}
      {% endif %}
    {% endif %}
  {% endfor %}

  {% if tables | length == 0 %}
    {{ return('') }}
  {% endif %}

  {% set selects = [] %}
  {% for t in tables | unique %}
    {% do selects.append(
          "("
        ~ "select "
        ~ "cd_run_dbt, "
        ~ "ts_started_at, "
        ~ "ds_nome_test, "
        ~ "ds_schema, "
        ~ "ds_tabella, "
        ~ "gn_failure_info "
        ~ "from \"" ~ db ~ "\".\"" ~ sch_store_fail ~ "\".\"" ~ t ~ "\" "
        ~ "limit 1000"
        ~ ")"
    ) %}
  {% endfor %}

  {% set drops = [] %}
  {% for t in all_tables | unique %}
    {% do drops.append("drop table if exists \"" ~ db ~ "\".\"" ~ sch_store_fail ~ "\".\"" ~ t ~ "\"") %}
  {% endfor %}

  {% set sql %}
  insert into {{ test_log_records }}
  (cd_run_dbt, ts_started_at, ds_nome_test, ds_schema, ds_tabella, gn_failure_info)
{{ selects | join("\nunion all\n") }};
{{ drops | join(";\n") }};
  {% endset %}

  {{ return(sql) }}
{% endmacro %}
