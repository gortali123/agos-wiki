{% macro generate_yaml(model_names=None, modulo=None, sorgente=None) %}
  {% set model_yaml = [] %}
  {% do model_yaml.append('version: 2') %}
  {% do model_yaml.append('') %}
  {% do model_yaml.append('models:') %}

  {% set model_names = get_model_names(model_names, modulo, sorgente) %}

  {# --- bulk query: una sola chiamata per tutti i modelli --- #}
  {% set cfg_by_table = {} %}
  {% if execute and (model_names | length) > 0 %}
    {% set in_clause = "'" ~ (model_names | join("','")) ~ "'" %}
    {% set all_cfg_sql %}
      with max_ts as (
        select ds_archivio, max(ts_riferimento) as max_ts
        from {{ env_var('DBT_DATABASE') }}.TECH.CFG_L1_SCHEMA
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
        s.fl_is_primary_key,
        c.cd_cluster,
        m.ds_masking_rule,
        m.fl_active,
        mlk.cd_modulo as cd_modulo_l0
      from {{ env_var('DBT_DATABASE') }}.TECH.CFG_L1_SCHEMA s
      inner join max_ts on s.ds_archivio = max_ts.ds_archivio and s.ts_riferimento = max_ts.max_ts
      left join {{ env_var('DBT_DATABASE') }}.TECH.CFG_L1_CLUSTER_STO c
        on c.ds_archivio = s.ds_archivio
      left join {{ env_var('DBT_DATABASE') }}.TECH.CFG_L1_DATAMASK m
        on m.ds_archivio = s.ds_archivio
        and m.ds_column_name = s.ds_column_name
      left join {{ env_var('DBT_DATABASE') }}.TECH.CFG_L0_L1_MODULO_LOOKUP mlk
        on mlk.cd_modulo_l1 = s.cd_modulo
        and upper(s.ds_sorgente) = 'OCS'
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

  {% for model in model_names %}
    {% set rows = cfg_by_table.get(model | upper, []) %}

    {# row layout: [0]ds_archivio [1]cd_modulo_l1 [2]sorgente [3]column_name [4]data_type [5]length_col [6]is_nullable [7]is_primary_key [8]cluster [9]masking_rule [10]fl_active [11]cd_modulo_l0 #}
    {% set modulo_l1 = none %}
    {% set sorgente   = none %}
    {% set cluster    = none %}
    {% set modulo_l0  = none %}
    {% if rows | length > 0 %}
      {% set modulo_l1 = rows[0][1] | string | trim %}
      {% set sorgente   = rows[0][2] | string | trim %}
      {% set cluster    = rows[0][8] | string | trim %}
      {% if rows[0][11] is not none %}
        {% set modulo_l0 = rows[0][11] | string | trim %}
      {% endif %}
    {% endif %}
    {% set is_ocs = (sorgente | upper) == 'OCS' %}

    {% set model_name = ('stg_' ~ model) if cluster is not none and (cluster | upper) == 'C' else model %}

    {% set pk_cols = [] %}
    {% for row in rows %}
      {% if (row[7] | string | trim | upper) == 'S' %}
        {% do pk_cols.append(row[3] | string | trim | lower) %}
      {% endif %}
    {% endfor %}

    {% set modulo_path = modulo_l1 | default('') | lower %}
    {% if is_ocs and modulo_l0 %}
      {% set modulo_path = modulo_path ~ '/' ~ (modulo_l0 | lower) %}
    {% endif %}

    {% do model_yaml.append('  - name: ' ~ (model_name | lower)) %}
    {% do model_yaml.append('### sorgente: ' ~ (sorgente | default('unknown') | lower)) %}
    {% do model_yaml.append('### modulo: ' ~ modulo_path) %}
    {% do model_yaml.append('    config:') %}

    {% if cluster is not none %}
      {% set cu = cluster | upper %}
      {% if cu in ['A', 'A1', 'A2'] %}
        {% do model_yaml.append("      materialized: incremental") %}
        {% do model_yaml.append("      incremental_strategy: merge") %}
        {% set pk_str = pk_cols | join("', '") %}
        {% do model_yaml.append("      unique_key: ['" ~ pk_str ~ "']") %}
      {% elif cu in ['B1', 'B2'] %}
        {% do model_yaml.append("      materialized: incremental") %}
        {% do model_yaml.append("      incremental_strategy: insert_overwrite") %}
      {% elif cu == 'C' %}
        {% do model_yaml.append("      materialized: ephemeral") %}
      {% elif cu == 'D' %}
        {% do model_yaml.append("      materialized: incremental") %}
        {% do model_yaml.append("      incremental_strategy: append") %}
        {% do model_yaml.append('      pre_hook:') %}
        {% do model_yaml.append('        - "{{ delete_month(get_dt_osservazione(' ~ "'ts_riferimento'" ~ ')) }}"') %}
      {% elif cu == 'TBD' %}
        {% do model_yaml.append("      materialized: table") %}
      {% endif %}
    {% endif %}

    {% if cluster is not none and (cluster | upper) in ['A', 'A1', 'A2'] and (sorgente | upper) == 'OCS' %}
      {% do model_yaml.append('      post_hook: "{{ logic_delete_merge() }}"') %}
    {% endif %}

    {% set schema_tag = 'L1_O_' ~ (modulo_l1 | upper) if (sorgente | upper) == 'OCS' else 'L1_E_' ~ (sorgente | upper) %}

    {% do model_yaml.append('      meta:') %}
    {% do model_yaml.append('        cluster: ["' ~ (cluster | upper if cluster is not none else '') ~ '"]') %}
    {% do model_yaml.append('      query_tag: \'{"app":"DBT", "sorgente":"' ~ (sorgente | upper) ~ '", "schema":"' ~ schema_tag ~ '", "archivio":"' ~ (model | upper) ~ '"}\'' ) %}

    {% if pk_cols | length > 0 and cluster is not none and cluster | upper != 'C' %}
      {% set pk_constraint_cols = pk_cols + (['dt_osservazione'] if (cluster | upper) == 'D' else []) %}
      {% do model_yaml.append('    constraints:') %}
      {% do model_yaml.append('      - type: primary_key') %}
      {% do model_yaml.append('        warn_unenforced: false') %}
      {% do model_yaml.append('        columns: [' ~ (pk_constraint_cols | join(', ')) ~ ']') %}
    {% endif %}

    {% do model_yaml.append('    columns:') %}
    {% do model_yaml.append('      - name: ts_riferimento') %}
    {% do model_yaml.append('        data_type: TIMESTAMP_NTZ') %}
    {% do model_yaml.append('      - name: ts_caricamento') %}
    {% do model_yaml.append('        data_type: TIMESTAMP_NTZ') %}
    {% if cluster is not none and cluster | upper in ['A', 'A1', 'A2', 'C'] and (sorgente | upper) == 'OCS'%}
      {% do model_yaml.append('      - name: fl_deleted') %}
      {% do model_yaml.append('        data_type: VARCHAR(1)') %}
      {% do model_yaml.append('      - name: ts_deleted') %}
      {% do model_yaml.append('        data_type: TIMESTAMP_NTZ') %}
    {% endif %}
    {% if sorgente is not none and (sorgente | upper) == 'OCS' %}
    {% do model_yaml.append('      - name: sys_change_operation') %}
    {% do model_yaml.append('        data_type: VARCHAR') %}
    {% do model_yaml.append('      - name: lastmodifieddata') %}
    {% do model_yaml.append('        data_type: TIMESTAMP_NTZ') %}
    {% endif %}
    {% if cluster is not none and (cluster | upper) == 'D' %}
    {% do model_yaml.append('      - name: dt_osservazione') %}
    {% do model_yaml.append('        data_type: DATE') %}
    {% endif %}
    {% for row in rows %}
      {% set col_name = row[3] | string | trim %}
      {% set col_type = row[4] | string | trim %}
      {% set col_len  = row[5] | string | trim %}
      {% set col_type_rendered = transcod_dtype(col_type, col_len) | trim %}
      {% set masking_rule = row[9] | string | trim %}
      {% set fl_active = row[10] | string | trim %}
      {% do model_yaml.append('      - name: ' ~ (col_name | lower)) %}
      {% do model_yaml.append('        data_type: ' ~ col_type_rendered) %}
      {% if (fl_active | upper) == 'Y' and masking_rule %}
        {% do model_yaml.append('        config:') %}
        {% do model_yaml.append('          meta:') %}
        {% do model_yaml.append('            masking: ' ~ masking_rule) %}
      {% endif %}
    {% endfor %}

  {% endfor %}

  {% if execute %}
    {% set joined = model_yaml | join('\n') %}
    {{ print(joined) }}
    {% do return(joined) %}
  {% endif %}
{% endmacro %}
