select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  TRY_CAST(CODICE_SOCIETA AS VARCHAR(14)) AS codice_societa,
  TRY_CAST(CONTO_CO_GE AS VARCHAR(10)) AS conto_co_ge,
  TRY_CAST(SALDO_DARE_MENSILE AS VARCHAR(21)) AS saldo_dare_mensile,
  TRY_CAST(SALDO_AVERE_MENSILE AS VARCHAR(21)) AS saldo_avere_mensile,
  TRY_CAST(SALDO_TOT_MENSILE AS VARCHAR(21)) AS saldo_tot_mensile,
  TRY_CAST(SALDO_ACCUMULATO AS VARCHAR(21)) AS saldo_accumulato,
  TRY_CAST(DATA AS VARCHAR(10)) AS data,
  TRY_CAST(PERIODO AS VARCHAR(3)) AS periodo
from {{ source('source_l0','collection') }}
