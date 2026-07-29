{#
  Restituisce la DT_ACCETTAZIONE (DATE) del settimanale, relativa al venerdi' precedente.

  Args:
    ts_riferimento (opzionale): espressione timestamp da cui derivare la data.

  - con ts_riferimento: se e' un venerdi' resta quel giorno (calcolo per riga, per la colonna L1/D), altrimenti il venerdi' precedente;
  - senza, con var 'dt_accettazione': usa la var da CLI (dbt build --vars ...);
  - senza nulla: ultimo venerdi' (oggi incluso, se oggi e' venerdi').
#}
{%- macro get_dt_accettazione(ts_riferimento=none) -%}
{%- if ts_riferimento is not none -%}
  DATEADD(DAY, -MOD(DAYOFWEEKISO({{ ts_riferimento }}::TIMESTAMP_NTZ) - 5 + 7, 7), {{ ts_riferimento }}::DATE)
{%- elif var('dt_accettazione', none) is not none -%}
  '{{ var("dt_accettazione") }}'::DATE
{%- else -%}
  DATEADD(DAY, -MOD(DAYOFWEEKISO(CURRENT_DATE) - 5 + 7, 7), CURRENT_DATE)
{%- endif -%}
{%- endmacro -%}
