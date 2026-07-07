{#
  Restituisce la DT_OSSERVAZIONE (DATE) del mensile.

  Args:
    ts_riferimento (opzionale): espressione timestamp da cui derivare la data.

  - con ts_riferimento: ultimo giorno del mese di quel ts (calcolo per riga, per la colonna L1/D);
  - senza, con var 'dt_osservazione': usa la var da CLI (dbt build --vars ...);
  - senza nulla: ultimo giorno del mese scorso.
#}
{%- macro get_dt_osservazione(ts_riferimento=none) -%}
{%- if ts_riferimento is not none -%}
  CASE
    WHEN EXTRACT(DAY FROM {{ ts_riferimento }}::TIMESTAMP_NTZ) = EXTRACT(DAY FROM LAST_DAY({{ ts_riferimento }}::TIMESTAMP_NTZ))
    THEN {{ ts_riferimento }}::DATE
    ELSE LAST_DAY({{ ts_riferimento }}::TIMESTAMP_NTZ - INTERVAL '1 month')
  END
{%- elif var('dt_osservazione', none) is not none -%}
  '{{ var("dt_osservazione") }}'::DATE
{%- else -%}
  LAST_DAY(DATEADD(MONTH, -1, CURRENT_DATE))
{%- endif -%}
{%- endmacro -%}
