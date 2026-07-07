{% macro hash_cols(cols) %}
    MD5(CONCAT_WS('|',
        {%- for col in cols %}
        COALESCE(CAST({{ col }} AS VARCHAR), '')
            {%- if not loop.last %},{% endif %}
        {%- endfor %}
    ))
{% endmacro %}
