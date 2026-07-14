select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  TRY_CAST(URLISCRIZIONE AS VARCHAR(150)) AS urliscrizione,
  TRY_CAST(PRIVACY AS VARCHAR(5)) AS privacy,
  TRY_CAST(EMAIL AS VARCHAR(150)) AS email,
  TRY_CAST(APP AS VARCHAR(50)) AS app,
  TRY_CAST(IP AS VARCHAR(18)) AS ip,
  TRY_CAST(DATA AS VARCHAR(15)) AS data
from {{ source('source_l0','newsletter') }}
