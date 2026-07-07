select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  TRY_CAST(RECAPITO AS VARCHAR(80)) AS recapito,
  TRY_CAST(MOTIVO AS VARCHAR(80)) AS motivo,
  TRY_CAST(DATABLACKLIST AS VARCHAR(20)) AS datablacklist
from {{ source('source_l0','blacklist') }}
