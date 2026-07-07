select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  TRY_CAST(CD_CONNECTION_TYPE AS NUMBER(20,0)) AS cd_connection_type,
  TRY_CAST(DS_CONNECTION_TYPE AS VARCHAR(150)) AS ds_connection_type
from {{ source('source_l0','connection_type') }}
