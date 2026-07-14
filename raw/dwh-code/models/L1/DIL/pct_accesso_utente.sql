select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  TRY_CAST(DS_COLONNA AS VARCHAR) AS ds_colonna
from {{ source('source_l0','pct_accesso_utente') }}
