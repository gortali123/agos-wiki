select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  TRY_CAST(ID AS NUMBER(32,0)) AS id,
  TRY_CAST(DS_BROWSER AS VARCHAR(100)) AS ds_browser
from {{ source('source_l0','browser') }}
