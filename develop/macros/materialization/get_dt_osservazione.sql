{%- macro get_dt_osservazione(schedule='monthly') -%}
{%- if var('dt_osservazione', none) is not none -%}
  '{{ var("dt_osservazione") }}'::DATE
{%- else -%}
  {%- if schedule == 'monthly' -%}
    LAST_DAY(DATEADD(MONTH, -1, CURRENT_DATE))
  {%- elif schedule == 'weekly' -%}
    DATEADD(DAY, -MOD(DAYOFWEEKISO(CURRENT_DATE) - 5 + 7, 7), CURRENT_DATE)
  {%- endif -%}
{%- endif -%}
{%- endmacro -%}
