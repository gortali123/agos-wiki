{# Conversione OLE to TIMESTAMP/DATE and viceversa #}

{# OLE -> TIMESTAMP #}
{% macro ole_to_timestamp(ole_column_data, ole_column_time=none) %}

    to_timestamp(
        dateadd('day', {{ ole_column_data }}, '1899-12-30'::date)::varchar
        || ' ' ||
        {% if ole_column_time %}
            to_time(lpad({{ ole_column_time }}::varchar, 6, '0'), 'HH24MISS')::varchar
        {% else %}
            '00:00:00'
        {% endif %}
    )

{% endmacro %}



{# TIMESTAMP -> OLE DATE, OLE TIME #}
{% macro timestamp_to_ole(timestamp_column) %}

    -- OLE date part (integer)
    datediff('day', '1899-12-30'::date, {{ timestamp_column }}::date)
        as ole_date,

    -- OLE time part (HHMMSS integer)
    (
        hour({{ timestamp_column }}) * 10000 +
        minute({{ timestamp_column }}) * 100 +
        second({{ timestamp_column }})
    )
        as ole_time

{% endmacro %}


{# OLE -> DATE #}
{% macro ole_to_date(ole_column) %}
    CASE
        WHEN {{ ole_column }} IS NULL OR {{ ole_column }} = 0 THEN CAST(NULL AS DATE)
        ELSE dateadd('day', {{ ole_column }}::integer, '1899-12-30'::date)::date
    END
{% endmacro %}

{# DATE -> OLE #}
{% macro date_to_ole(date_column) %}
    datediff('day', '1899-12-30'::date, {{ date_column }}::date)
{% endmacro %}
