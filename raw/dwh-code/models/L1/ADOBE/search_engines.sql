select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  TRY_CAST(CD_SEARCH_ENGINES AS NUMBER(20,0)) AS cd_search_engines,
  TRY_CAST(DS_SEARCH_ENGINES AS VARCHAR(150)) AS ds_search_engines
from {{ source('source_l0','search_engines') }}
