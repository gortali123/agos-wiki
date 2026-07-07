{% macro custom_to_date(column, zero='null') %}

{% if (column | string | length) == 5 %}    
{{ exceptions.raise_compiler_error( "to_date: column value '" ~ col_str ~ "' has length 5, which is not a supported date format (expected YYYYMMDD or YYYYMM)."    ) }}
{% endif %} 

CASE
    WHEN CAST({{ column }} AS VARCHAR) = '99999999'
        THEN TO_DATE('99991231', 'YYYYMMDD')
    WHEN CAST({{ column }} AS VARCHAR) = '0'
        THEN
            {% if   zero == 'max'     %} TO_DATE('99991231', 'YYYYMMDD')
            {% elif zero == 'current' %} CURRENT_DATE
            {% else                   %} NULL
            {% endif %}
    WHEN TRY_TO_DATE({{ column }}::VARCHAR, 'YYYYMMDD') IS NOT NULL
        THEN TO_DATE({{ column }}::VARCHAR, 'YYYYMMDD')
    WHEN TRY_TO_DATE(RPAD({{ column }}::VARCHAR, 8, '01'), 'YYYYMMDD') IS NOT NULL
        THEN TO_DATE(RPAD({{ column }}::VARCHAR, 8, '01'), 'YYYYMMDD')
    ELSE NULL
END
{% endmacro %}