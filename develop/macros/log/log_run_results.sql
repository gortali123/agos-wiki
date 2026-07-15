{% macro log_run_results(results) %}
  {% if execute %}

    {% set ns = namespace(rows=[]) %}

    {% for res in results %}

      {# --- MODELLI / SNAPSHOT (esclusi ephemeral e view) --- #}
      {% if res.node.resource_type in ('model', 'snapshot')
            and res.node.config.materialized not in ('ephemeral', 'view') %}

        {% set started = res.timing | selectattr("name","equalto","compile") | map(attribute="started_at") | first | default("") %}

        {% set row %}
{
  "execution_type": "MODEL",
  "ts_started_at": "{{ started }}",
  "nm_execution_time": {{ res.execution_time | default(0) }},
  "ds_schema": "{{ res.node.schema }}",
  "ds_tabella": "{{ (res.node.alias or res.node.name) | upper }}",
  "ds_status": "{{ res.status | upper }}",
  "ds_test_name": null,
  "nm_failures": null,
  "ds_message": {{ res.message | tojson if res.message else "null" }},
  "cd_run_dbt": "{{ invocation_id }}",
  "cd_query_sf": "{{ res.adapter_response.query_id | default("") }}"
}
        {% endset %}

        {% set ns.rows = ns.rows + [row] %}

      {# --- TEST --- #}
      {% elif res.node.resource_type == 'test' %}

        {% set started = res.timing | selectattr("name","equalto","compile") | map(attribute="started_at") | first | default("") %}

        {% set dep_nodes = res.node.depends_on.nodes %}
        {% set dep_id    = dep_nodes[0] if dep_nodes else "" %}
        {% set dep_node  = graph.nodes.get(dep_id) or graph.sources.get(dep_id) if dep_id else none %}

        {% set table_name = (dep_node.alias or dep_node.name) if dep_node else res.node.name %}
        {% set table_schema = dep_node.schema if dep_node else "" %}

        {% set row %}
{
  "execution_type": "TEST",
  "ts_started_at": "{{ started }}",
  "nm_execution_time": {{ res.execution_time | default(0) }},
  "ds_schema": "{{ table_schema }}",
  "ds_tabella": "{{ table_name | upper }}",
  "ds_status": "{{ res.status | upper }}",
  "ds_test_name": "{{ (res.node.test_metadata.name | default("")) | upper }}",
  "nm_failures": {{ res.failures | default("null") }},
  "ds_message": {{ res.message | tojson if res.message else "null" }},
  "cd_run_dbt": "{{ invocation_id }}",
  "cd_query_sf": "{{ res.adapter_response.query_id | default("") }}"
}
        {% endset %}

        {% set ns.rows = ns.rows + [row] %}

      {% endif %}
    {% endfor %}

    {% if ns.rows | length > 0 %}
      {% set payload = ('[' ~ (ns.rows | join(", ")) ~ ']') | replace('$$', '') %}
      CALL AGOS_DEV_16000.TECH.LOG_DBT(
        PARSE_JSON($${{ payload }}$$)
      );
    {% endif %}

  {% endif %}
{% endmacro %}
