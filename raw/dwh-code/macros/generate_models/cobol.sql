
  {#
  Reminder : unset contract enforce in model before usage 
  
  Add on top in model.sql 
  {{ config( contract = {"enforced": false} ) }}
  
   #}

{% macro cobol_parse_columns(source_table) %}

{% set query %}
    SELECT
        FILTER_CONDITION,
        START_POSITION,
        FIELD_LENGTH,
        SF_COLUMN_NAME,
        SF_DATA_TYPE,
        TYPE_RECORD,
        DECIMAL_SCALE
    FROM  {{ env_var('DBT_DATABASE') }}.TECH.CFG_COBOL_COPYBOOK_MAPPING
    WHERE SOURCE_TABLE = '{{ source_table }}'
      AND SF_COLUMN_NAME IS NOT NULL
    ORDER BY COPYBOOK_NAME, START_POSITION
{% endset %}

{% set results = run_query(query) %}

{% if execute %}
    {% set rows = results.rows %}
{% else %}
    {% set rows = [] %}
{% endif %}

{% for row in rows %}

    {% set condition = row[0] %}
    {% set start_pos = row[1] %}
    {% set length = row[2] %}
    {% set col_name = row[3] %}
    {% set data_type = row[4] %}
    {% set content_column = row[5] %}
    {% set decimal_scale = row[6] %}

    CASE 
        WHEN {{ condition }} THEN
            {% if data_type | upper == 'FLOAT' %}
            CAST(
                {{ env_var('DBT_DATABASE') }}.L0.DECODE_OVERPUNCH(
                    SUBSTR({{ content_column }}, {{ start_pos }}, {{ length }}),{{ decimal_scale }}
                )
            AS {{ data_type }})
            {% else %}
            CAST(SUBSTR({{ content_column }}, {{ start_pos }}, {{ length }}) AS {{ data_type }})
            {% endif %}
        ELSE NULL
    END AS {{ col_name }}

    {% if not loop.last %},{% endif %}

{% endfor %}

{% endmacro %}
