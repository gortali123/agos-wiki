select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  TRY_CAST(SOCIETA AS NUMBER(38,10)) AS societa,
  TRY_CAST(DOMINIO AS VARCHAR(4)) AS dominio,
  TRY_CAST(PERIODO AS VARCHAR(7)) AS periodo,
  TRY_CAST(PCCO AS VARCHAR(8)) AS pcco,
  TRY_CAST(NATO AS VARCHAR(7)) AS nato,
  TRY_CAST(CONTO AS VARCHAR(10)) AS conto,
  TRY_CAST(VALUTA AS VARCHAR(3)) AS valuta,
  TRY_CAST(SALDO AS NUMBER(38,10)) AS saldo
from {{ source('source_l0','ag_arpe_crrv4') }}
