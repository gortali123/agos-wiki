{% macro get_model_names(model_names, modulo=None, sorgente=None) %}
  {% if model_names is none %}
    {% set model_names = [] %}
  {% endif %}
  {% if execute and (model_names | length) == 0 %}
    {% set tables_sql %}
      select distinct ds_archivio
      from AGOS_DEV_16000.TECH.CFG_L1_SCHEMA
      where ds_archivio is not null
      {% if modulo is not none and modulo != '' %}
        and UPPER(cd_modulo) = '{{ modulo | upper }}'
      {% endif %}
      {% if sorgente is not none and sorgente != '' %}
        and UPPER(ds_sorgente) in ('{{ sorgente | upper | replace(",", "','") }}')
      {% endif %}
      order by ds_archivio
    {% endset %}
    {% set tables_res = run_query(tables_sql) %}
    {% if tables_res is not none and (tables_res.rows | length) > 0 %}
      {% for r in tables_res.rows %}
        {% do model_names.append((r[0] | string | trim)) %}
      {% endfor %}
    {% endif %}
  {% endif %}
  {% do return(model_names) %}
{% endmacro %}
