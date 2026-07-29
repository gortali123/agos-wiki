{%- macro compute_dt_osservazione(column, schedule='monthly') -%}
  {%- if schedule == 'monthly' -%}
    CASE
      WHEN EXTRACT(DAY FROM {{ column }}::TIMESTAMP_NTZ) = EXTRACT(DAY FROM LAST_DAY({{ column }}::TIMESTAMP_NTZ))
      THEN {{ column }}::DATE
      ELSE LAST_DAY({{ column }}::TIMESTAMP_NTZ - INTERVAL '1 month')
    END
  {%- elif schedule == 'weekly' -%}
    DATEADD(DAY, -MOD(DAYOFWEEKISO({{ column }}::TIMESTAMP_NTZ) - 5 + 7, 7), {{ column }}::DATE)
  {%- endif -%}
{%- endmacro -%}
