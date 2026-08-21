select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  sys_change_operation,
  TRY_CAST(lastmodifieddata AS TIMESTAMP_NTZ) as lastmodifieddata,
  TRY_CAST(ANACRSU_CONTROPARTE AS NUMBER(9,0)) AS anacrsu_controparte,
  TRY_CAST(IFF(RTRIM(ANACRSU_SOCIETA) = '', ' ', RTRIM(ANACRSU_SOCIETA)) AS VARCHAR(2)) AS anacrsu_societa,
  TRY_CAST(ANACRSU_CONTROPARTE_AGOS AS NUMBER(12,0)) AS anacrsu_controparte_agos,
  TRY_CAST(ROWID AS NUMBER(38, 0)) AS rowid
from {{ source('source_l0','mgdrfcrana') }}
