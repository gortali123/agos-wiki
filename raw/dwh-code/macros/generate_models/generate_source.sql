{% macro generate_source(model_names=None, modulo=None, sorgente=None) %}

  {% set out = [] %}
  {% do out.append('version: 2') %}
  {% do out.append('') %}
  {% do out.append('sources:') %}
  {% do out.append('  - name: source_l0') %}
  {% do out.append('    schema: L0') %}
  {% do out.append('    tables:') %}

  {% set model_names = get_model_names(model_names, modulo, sorgente) %}

  {# --- bulk query: una sola chiamata per tutti i modelli --- #}
  {% set cfg_by_table = {} %}
  {% if execute and (model_names | length) > 0 %}
    {% set in_clause = "'" ~ (model_names | join("','")) ~ "'" %}
    {% set all_cfg_sql %}
      with max_ts as (
        select ds_archivio, max(ts_riferimento) as max_ts
        from AGOS_DEV_16000.TECH.CFG_L1_SCHEMA
        where ds_archivio in ({{ in_clause }})
        group by ds_archivio
      )
      select
        s.ds_archivio,
        s.cd_modulo,
        s.ds_sorgente,
        s.ds_column_name,
        s.ds_data_type,
        s.ds_length_col,
        s.fl_is_nullable,
        s.fl_is_primary_key
      from AGOS_DEV_16000.TECH.CFG_L1_SCHEMA s
      inner join max_ts on s.ds_archivio = max_ts.ds_archivio and s.ts_riferimento = max_ts.max_ts
      where s.ds_archivio in ({{ in_clause }})
      order by s.ds_archivio, s.nm_campo::NUMERIC
    {% endset %}
    {% set all_cfg = run_query(all_cfg_sql) %}
    {% if all_cfg is not none %}
      {% for row in all_cfg.rows %}
        {% set tbl = row[0] | string | trim | upper %}
        {% if tbl not in cfg_by_table %}
          {% do cfg_by_table.update({tbl: []}) %}
        {% endif %}
        {% do cfg_by_table[tbl].append(row) %}
      {% endfor %}
    {% endif %}
  {% endif %}

  {% for t in model_names %}
    {% set rows = cfg_by_table.get(t | upper, []) %}

    {# row layout: [0]ds_archivio [1]cd_modulo [2]ds_sorgente [3]ds_column_name [4]ds_data_type [5]ds_length_col [6]fl_is_nullable [7]fl_is_primary_key #}
    {% set modulo   = none %}
    {% set sorgente = none %}
    {% if rows | length > 0 %}
      {% set modulo   = rows[0][1] | string | trim %}
      {% set sorgente = rows[0][2] | string | trim %}
    {% endif %}

    {% set pk_cols = [] %}
    {% for row in rows %}
      {% if (row[7] | string | trim | upper) == 'S' %}
        {% do pk_cols.append(row[3] | string | trim | lower) %}
      {% endif %}
    {% endfor %}

    {% do out.append('### sorgente: ' ~ (sorgente | default('unknown') | lower)) %}
    {% do out.append('### modulo: ' ~ (modulo | default('') | lower)) %}
    {% set is_ocs = (sorgente | upper) == 'OCS' %}

    {% do out.append('      - name: ' ~ (t | lower)) %}
    {% do out.append('        data_tests:') %}
    {% do out.append('          - try_cast') %}
    {% if pk_cols %}
      {% if is_ocs %}
    {% do out.append('          - unique_key:') %}
      {% else %}
    {% do out.append('          - primary_key:') %}
      {% endif %}
    {% do out.append('              arguments:') %}
    {% do out.append('                pk_columns: [' ~ (pk_cols | join(', ')) ~ ']') %}
    {% endif %}

    {% if is_ocs %}
    {% do out.append('      - name: ' ~ (t | lower) ~ '_deleted') %}
    {% endif %}

  {% endfor %}
  {% if execute %}
    {% set joined = out | join('\n') %}
    {{ print(joined) }}
    {% do return(joined) %}
  {% endif %}

{% endmacro %}
