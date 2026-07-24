select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  'N' as fl_deleted,
  NULL::TIMESTAMP_NTZ as ts_deleted,
  sys_change_operation,
  TRY_CAST(lastmodifieddata AS TIMESTAMP_NTZ) as lastmodifieddata,
  TRY_CAST(IFF(RTRIM(AITBSTA_STATO) = '', ' ', RTRIM(AITBSTA_STATO)) AS VARCHAR(2)) AS aitbsta_stato,
  TRY_CAST(IFF(RTRIM(AITBSTA_STATO) = '', ' ', RTRIM(AITBSTA_STATO)) AS VARCHAR(2)) AS aitbsta_stato,
  TRY_CAST(IFF(RTRIM(AITBSTA_DESCRIZIONE) = '', ' ', RTRIM(AITBSTA_DESCRIZIONE)) AS VARCHAR(30)) AS aitbsta_descrizione,
  TRY_CAST(IFF(RTRIM(AITBSTA_DESCRIZIONE) = '', ' ', RTRIM(AITBSTA_DESCRIZIONE)) AS VARCHAR(30)) AS aitbsta_descrizione,
  TRY_CAST(ROWID AS NUMBER(38, 0)) AS rowid,
  TRY_CAST(ROWID AS NUMBER(38, 0)) AS rowid
from {{ source('source_l0','aitbfsta') }}
