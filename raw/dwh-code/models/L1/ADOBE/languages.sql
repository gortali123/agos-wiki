select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  TRY_CAST(CD_LANGUAGE AS NUMBER(20,0)) AS cd_language,
  TRY_CAST(DS_LANGUAGE AS VARCHAR(150)) AS ds_language
from {{ source('source_l0','languages') }}
