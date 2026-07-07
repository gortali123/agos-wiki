{% macro generate_model(model_names=None, modulo=None, sorgente=None) %}
  {% set out = [] %}
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
        s.fl_is_primary_key,
        c.cd_cluster
      from AGOS_DEV_16000.TECH.CFG_L1_SCHEMA s
      inner join max_ts on s.ds_archivio = max_ts.ds_archivio and s.ts_riferimento = max_ts.max_ts
      left join AGOS_DEV_16000.TECH.CFG_L1_CLUSTER_STO c
        on c.ds_archivio = s.ds_archivio
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
    {% set table = model | lower %}
    {% set rows  = cfg_by_table.get(model | upper, []) %}

    {# row layout: [0]ds_archivio [1]cd_modulo [2]ds_sorgente [3]ds_column_name [4]ds_data_type [5]ds_length_col [6]fl_is_nullable [7]fl_is_primary_key [8]cd_cluster #}
    {% set modulo   = none %}
    {% set sorgente = none %}
    {% set cluster  = none %}
    {% if rows | length > 0 %}
      {% set modulo   = rows[0][1] | string | trim %}
      {% set sorgente = rows[0][2] | string | trim %}
      {% set cluster  = rows[0][8] | string | trim %}
    {% endif %}

    {% set pk_cols = [] %}
    {% for row in rows %}
      {% if (row[7] | string) | upper == 'S' %}
        {% do pk_cols.append(row[3] | string | trim | lower) %}
      {% endif %}
    {% endfor %}

    {% do out.append('### sorgente: ' ~ (sorgente | default('unknown') | lower)) %}
    {% do out.append('### modulo: ' ~ (modulo | default('') | lower)) %}
    {% if cluster is not none and (cluster | upper) == 'C' %}
      {% do out.append('### model: stg_' ~ table) %}
    {% else %}
      {% do out.append('### model: ' ~ table) %}
    {% endif %}

    {% do out.append('select') %}
    {% do out.append("  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,") %}
    {% do out.append("  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,") %}
    {% if cluster is not none and (cluster | upper) in ['A', 'A1', 'A2', 'C'] and (sorgente | upper) == 'OCS'%}
      {% do out.append("  'N' as fl_deleted,") %}
      {% do out.append('  NULL::TIMESTAMP_NTZ as ts_deleted,') %}
    {% endif %}
    {% if sorgente is not none and (sorgente | upper) == 'OCS' %}
    {% do out.append('  sys_change_operation,') %}
    {% do out.append('  TRY_CAST(lastmodifieddata AS TIMESTAMP_NTZ) as lastmodifieddata,') %}
    {% endif %}
    {% if cluster is not none and (cluster | upper) == 'D' %}
    {% do out.append("  {{ get_dt_osservazione('ts_riferimento') }} as dt_osservazione,") %}
    {% endif %}
    {% if rows | length > 0 %}
      {% for row in rows %}
        {% set c = row[3] | string | trim %}
        {% set t = row[4] | string | trim %}
        {% set l = row[5] | string | trim %}
        {% set t_render = transcod_dtype(t, l) | trim %}
        {% if 'varchar' in (t_render | lower) %}
          {% set expr = '  TRY_CAST(NULLIF(RTRIM(' ~ c ~ '), \'\') AS ' ~ t_render ~ ') AS ' ~ (c | lower) %}
        {% else %}
          {% set expr = '  TRY_CAST(' ~ c ~ ' AS ' ~ t_render ~ ') AS ' ~ (c | lower) %}
        {% endif %}
        {% do out.append(expr ~ (',' if not loop.last else '')) %}
      {% endfor %}
    {% else %}
      {% do out.append('  *') %}
    {% endif %}
    {% do out.append('from {{ source(' ~ "'source_l0'," ~ "'" ~ table ~ "'" ~ ') }}') %}
    {% do out.append('---') %}
    {% do out.append('') %}
  {% endfor %}

  {% if execute %}
    {% set joined = out | join('\n') %}
    {{ print(joined) }}
    {% do return(joined) %}
  {% endif %}
{% endmacro %}
