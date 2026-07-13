{% test try_cast_positional(model, skip_columns=none, accepted_values=none) %}

{% if execute %}

  {% set l1_model = model.identifier | lower | replace('_source', '') %}
  {% set l1_node = graph.nodes.values() | selectattr('name', 'equalto', ('stg_' ~ l1_model)) | first %}
  {% if not l1_node %}
    {% set l1_node = graph.nodes.values() | selectattr('name', 'equalto', l1_model) | first %}
  {% endif %}
  {% if not l1_node %}
    {% do exceptions.raise_compiler_error("try_cast_positional: nessun nodo L1 trovato per '" ~ l1_model ~ "' (da model.identifier='" ~ model.identifier ~ "')") %}
  {% endif %}

  {% set skip_columns_lower = ((skip_columns or []) + ['ts_riferimento', 'ts_caricamento']) | map('lower') | list %}
  {% set accepted_values = accepted_values or {} %}

  {% set l1_sql = l1_node.raw_code %}
  {% set sql_upper = l1_sql | upper %}
  {% set select_idx = sql_upper.find('SELECT') %}
  {% set from_idx = sql_upper.find('FROM', select_idx) %}

  {% set cols_to_check = [] %}
  {% if select_idx >= 0 and from_idx > select_idx %}
    {% set after_select = l1_sql[select_idx + 6:from_idx] %}
    {% for line in after_select.split('\n') %}
      {% set line_upper = line | upper %}
      {% if ' AS ' in line_upper %}
        {% set as_idx = line_upper.rfind(' AS ') %}
        {% set col_name = line[as_idx + 4:] | trim | replace(',', '') %}
        {% if '--' in col_name %}
          {% set col_name = col_name.split('--')[0] | trim %}
        {% endif %}
        {% set col_expr = line[:as_idx] | trim %}
        {% if col_name and col_expr and col_name | lower not in skip_columns_lower %}
          {# col_expr e' sempre TRY_CAST(<raw> AS <type>): il "raw" da confrontare
             e' l'espressione (es. SUBSTR(...)) dentro il TRY_CAST, non una colonna
             del source (che per un archivio posizionale non esiste per nome) #}
          {% set inner = col_expr %}
          {% if inner.upper().startswith('TRY_CAST(') %}
            {% set inner = inner[9:-1] %}
            {% set as_pos = inner.upper().rfind(' AS ') %}
            {% set raw_expr = inner[:as_pos] | trim if as_pos >= 0 else inner %}
          {% else %}
            {% set raw_expr = col_expr %}
          {% endif %}
          {# col_expr/raw_expr vengono da raw_code (SQL NON renderizzato): se la
             riga usa una macro del progetto (es. custom_to_date(...)) invece di
             SQL puro, arriva qui ancora come '{{ custom_to_date(...) }}' letterale.
             render() la ri-esegue come Jinja nello stesso ambiente, risolvendo la
             macro in SQL vero prima di iniettarla nel test. #}
          {% set raw_expr = render(raw_expr) %}
          {% set cast_expr = render(col_expr) %}
          {% set exclude_vals = accepted_values.get(col_name | lower) or [] %}
          {% do cols_to_check.append({'name': col_name, 'raw_expr': raw_expr, 'cast_expr': cast_expr, 'exclude_vals': exclude_vals}) %}
        {% endif %}
      {% endif %}
    {% endfor %}
  {% endif %}

  {% set where_clause = '' %}
  {% if 'WHERE' in (l1_sql | upper) %}
    {% set where_clause = l1_sql.split('WHERE')[1] %}
  {% endif %}

with check_results as (
  select
    object_construct(
      {% for col in cols_to_check %}
        '{{ col.name }}', iff(
          ({{ col.raw_expr }}) is not null
          and ({{ col.cast_expr }}) is null
          {% if col.exclude_vals | length > 0 %}and ({{ col.raw_expr }}) not in ({% for val in col.exclude_vals %}'{{ val }}'{{ ',' if not loop.last else '' }}{% endfor %}){% endif %},
          cast(({{ col.raw_expr }}) as varchar),
          null
        ){{ ',' if not loop.last else '' }}
      {% endfor %}
    ) as failure_info
  from {{ model }}
  {% if where_clause %}where {{ where_clause }}{% endif %}
)

select
  '{{ run_started_at }}' as ts_started_at,
  'try_cast' as ds_nome_test,
  '{{ l1_node.schema }}' as ds_schema,
  '{{ model.identifier }}' as ds_tabella,
  failure_info as gn_failure_info,
  '{{ invocation_id }}' as cd_run_dbt
from check_results
where array_size(object_keys(failure_info)) > 0

{% endif %}
{% endtest %}
