{% macro last_day_past_month() %}
{%- if var('dt_osservazione', none) is not none -%}    
    '{{ var("dt_osservazione") }}'::DATE 
{%- else -%}
    LAST_DAY(DATEADD(MONTH, -1, CURRENT_DATE))  
{%- endif -%}
{% endmacro %}