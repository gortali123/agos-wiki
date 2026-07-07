{% macro custom_to_time(column) %}
CASE
    WHEN {{ column }} = 0
        THEN TO_TIME('00000000', 'HH24MISSFF2')
    WHEN TRY_TO_TIME({{ column }}::VARCHAR, 'HH24MISSFF2') IS NOT NULL
        THEN TO_TIME({{ column }}::VARCHAR, 'HH24MISSFF2')
    ELSE NULL
END
{% endmacro %}
