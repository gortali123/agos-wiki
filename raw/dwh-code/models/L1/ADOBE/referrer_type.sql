select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  TRY_CAST(CD_REFERRER_TYPE AS NUMBER(20,0)) AS cd_referrer_type,
  TRY_CAST(DS_REFERRER_TYPE AS VARCHAR(150)) AS ds_referrer_type,
  TRY_CAST(COLONA_DA_SKIPPARE AS VARCHAR(150)) AS colona_da_skippare
from {{ source('source_l0','referrer_type') }}
