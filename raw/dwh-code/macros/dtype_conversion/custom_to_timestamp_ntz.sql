{% macro custom_to_timestamp_ntz(data_ins, ora_ins='00000000', zero='null') %}
CASE
    WHEN CAST({{ data_ins }} AS VARCHAR) = '0'
        THEN
            {% if   zero == 'max'     %} TO_TIMESTAMP_NTZ('9999123100000000', 'YYYYMMDDHH24MISSFF')
            {% elif zero == 'current' %} TO_TIMESTAMP_NTZ(TO_VARCHAR(CURRENT_DATE, 'YYYYMMDD') || LPAD({{ ora_ins }}::VARCHAR, 8, '0'), 'YYYYMMDDHH24MISSFF')
            {% else                   %} NULL
            {% endif %}
    ELSE TO_TIMESTAMP_NTZ(
        RPAD({{ data_ins }}::VARCHAR, 8, '01')
        || LPAD({{ ora_ins }}::VARCHAR, 8, '0'),
        'YYYYMMDDHH24MISSFF'
    )
END
{% endmacro %}
