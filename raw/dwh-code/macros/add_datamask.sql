{% macro add_datamask() %}
  {% if execute %}

    {% set tag_name = 'AGOS_DEV_16000.TAGS.sensitivity' %}
    {% set model_name = this.name %}
    {% set model_schema = this.schema %}
    {% set model_database = this.database %}

    {{ log(" add_datamask() su " ~ model_database ~ "." ~ model_schema ~ "." ~ model_name, info=True) }}

    {% set columns = model.columns.values() %}

    {% for col in columns %}
      {# Legge meta.masking da config della colonna #}
      {% set masking_value = col.config.get('meta', {}).get('masking', none) %}

      {% if masking_value is not none %}
        {% set alter_query %}
          ALTER TABLE {{ model_database }}.{{ model_schema }}.{{ model_name }}
            MODIFY COLUMN {{ col.name }}
            SET TAG {{ tag_name }} = '{{ masking_value }}';
        {% endset %}

        {{ log("  Tag impostato -> " ~ col.name ~ " = " ~ masking_value, info=True) }}
        {% do run_query(alter_query) %}
      {% endif %}
    {% endfor %}

  {% endif %}
{% endmacro %}