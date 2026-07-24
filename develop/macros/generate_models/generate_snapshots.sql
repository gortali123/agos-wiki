{% macro generate_snapshots(model_names=None, modulo=None, sorgente=None) %}
  {% set snap_yaml = [] %}
  {% do snap_yaml.append('version: 2') %}
  {% do snap_yaml.append('') %}
  {% do snap_yaml.append('snapshots:') %}

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
        c.cd_cluster,
        s.ds_column_name,
        s.fl_is_primary_key,
        mlk.cd_modulo as cd_modulo_l0
      from {{ env_var('DBT_DATABASE') }}.TECH.CFG_L1_SCHEMA s
      inner join max_ts on s.ds_archivio = max_ts.ds_archivio and s.ts_riferimento = max_ts.max_ts
      left join {{ env_var('DBT_DATABASE') }}.TECH.CFG_L1_CLUSTER_STO c
        on c.ds_archivio = s.ds_archivio
      left join {{ env_var('DBT_DATABASE') }}.TECH.CFG_L0_L1_MODULO_LOOKUP mlk
        on mlk.cd_modulo_l1 = s.cd_modulo
        and upper(s.ds_sorgente) = 'OCS'
      where s.ds_archivio in ({{ in_clause }})
      order by s.ds_archivio, s.nm_campo::numeric
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

    {# row layout: [0]ds_archivio [1]cd_modulo_l1 [2]ds_sorgente [3]cd_cluster [4]ds_column_name [5]fl_is_primary_key [6]cd_modulo_l0 #}
    {% set modulo_l1 = none %}
    {% set sorgente   = none %}
    {% set cluster    = none %}
    {% set modulo_l0  = none %}
    {% set pk_cols    = [] %}
    {% if rows | length > 0 %}
      {% set modulo_l1 = rows[0][1] | string | trim %}
      {% set sorgente   = rows[0][2] | string | trim %}
      {% set cluster    = rows[0][3] | string | trim %}
      {% if rows[0][6] is not none %}
        {% set modulo_l0 = rows[0][6] | string | trim %}
      {% endif %}
      {% for row in rows %}
        {% if (row[5] | string | trim | upper) == 'S' %}
          {% do pk_cols.append(row[4] | string | trim | lower) %}
        {% endif %}
      {% endfor %}
    {% endif %}
    {% set is_ocs = (sorgente | upper) == 'OCS' %}

    {% if cluster is not none and (cluster | upper) == 'C' %}
      {% set model_l = model | lower %}
      {% set modulo_path = modulo_l1 | default('') | lower %}
      {% if is_ocs and modulo_l0 %}
        {% set modulo_path = modulo_path ~ '/' ~ (modulo_l0 | lower) %}
      {% endif %}
      {% do snap_yaml.append('  - name: ' ~ model_l) %}
      {% do snap_yaml.append('### sorgente: ' ~ (sorgente | default('unknown') | lower)) %}
      {% do snap_yaml.append('### modulo: ' ~ modulo_path) %}
      {% do snap_yaml.append("    relation: ref('stg_" ~ model_l ~ "')") %}
      {% do snap_yaml.append('    config:') %}
      {% if pk_cols %}
        {% do snap_yaml.append('      unique_key: [' ~ (pk_cols | join(', ')) ~ ']') %}
      {% else %}
        {% do snap_yaml.append('      unique_key: [rowid]') %}
      {% endif %}
    {% endif %}
  {% endfor %}

  {% if execute %}
    {% set joined = snap_yaml | join('\n') %}
    {{ print(joined) }}
    {% do return(joined) %}
  {% endif %}
{% endmacro %}
