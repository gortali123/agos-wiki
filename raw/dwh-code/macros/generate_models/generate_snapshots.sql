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
        from AGOS_DEV_16000.TECH.CFG_L1_SCHEMA
        where ds_archivio in ({{ in_clause }})
        group by ds_archivio
      )
      select
        s.ds_archivio,
        s.cd_modulo,
        s.ds_sorgente,
        c.cd_cluster,
        s.ds_column_name,
        s.fl_is_primary_key
      from AGOS_DEV_16000.TECH.CFG_L1_SCHEMA s
      inner join max_ts on s.ds_archivio = max_ts.ds_archivio and s.ts_riferimento = max_ts.max_ts
      left join AGOS_DEV_16000.TECH.CFG_L1_CLUSTER_STO c
        on c.ds_archivio = s.ds_archivio
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

    {# row layout: [0]ds_archivio [1]cd_modulo [2]ds_sorgente [3]cd_cluster [4]ds_column_name [5]fl_is_primary_key #}
    {% set modulo   = none %}
    {% set sorgente = none %}
    {% set cluster  = none %}
    {% set pk_cols  = [] %}
    {% if rows | length > 0 %}
      {% set modulo   = rows[0][1] | string | trim %}
      {% set sorgente = rows[0][2] | string | trim %}
      {% set cluster  = rows[0][3] | string | trim %}
      {% for row in rows %}
        {% if (row[5] | string | trim | upper) == 'S' %}
          {% do pk_cols.append(row[4] | string | trim | lower) %}
        {% endif %}
      {% endfor %}
    {% endif %}

    {% if cluster is not none and (cluster | upper) == 'C' %}
      {% set model_l = model | lower %}
      {% do snap_yaml.append('  - name: ' ~ model_l) %}
      {% do snap_yaml.append('### sorgente: ' ~ (sorgente | default('unknown') | lower)) %}
      {% do snap_yaml.append('### modulo: ' ~ (modulo | default('') | lower)) %}
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
