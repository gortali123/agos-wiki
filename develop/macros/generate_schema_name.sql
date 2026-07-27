{% macro generate_schema_name(custom_schema_name, node) %}
  {%- if custom_schema_name is none and node.resource_type in ('model', 'seed', 'snapshot') -%}
    {{ exceptions.raise_compiler_error(
        "Modello '" ~ node.name ~ "' senza schema custom dichiarato (config `schema:` mancante) — niente fallback su target.schema."
    ) }}
  {%- else -%}
    {{ custom_schema_name if custom_schema_name else target.schema }}
  {%- endif -%}
{% endmacro %}
