select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  TRY_CAST(CODICE_SOCIETA AS VARCHAR(14)) AS codice_societa,
  TRY_CAST(CENTRO_COSTO AS VARCHAR(10)) AS centro_costo,
  TRY_CAST(SALDO_TOT_MENSILE AS VARCHAR(21)) AS saldo_tot_mensile,
  TRY_CAST(DATA AS VARCHAR(10)) AS data,
  TRY_CAST(PERIODO AS VARCHAR(3)) AS periodo
from {{ source('source_l0','collection_indiretti') }}
