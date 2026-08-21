select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  'N' as fl_deleted,
  NULL::TIMESTAMP_NTZ as ts_deleted,
  sys_change_operation,
  TRY_CAST(lastmodifieddata AS TIMESTAMP_NTZ) as lastmodifieddata,
  TRY_CAST(EMLLGD_PROGRESSIVO AS NUMBER(11,0)) AS emllgd_progressivo,
  TRY_CAST(IFF(RTRIM(EMLLGD_FUNZIONE) = '', ' ', RTRIM(EMLLGD_FUNZIONE)) AS VARCHAR(10)) AS emllgd_funzione,
  TRY_CAST(IFF(RTRIM(EMLLGD_TESTO) = '', ' ', RTRIM(EMLLGD_TESTO)) AS VARCHAR(200)) AS emllgd_testo,
  TRY_CAST(ROWID AS NUMBER(38, 0)) AS rowid
from {{ source('source_l0','ccemllgd') }}
