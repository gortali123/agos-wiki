select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  'N' as fl_deleted,
  NULL::TIMESTAMP_NTZ as ts_deleted,
  sys_change_operation,
  TRY_CAST(lastmodifieddata AS TIMESTAMP_NTZ) as lastmodifieddata,
  TRY_CAST(NULLIF(RTRIM(AITBATT_ATTRIBUTO), '') AS VARCHAR(2)) AS aitbatt_attributo,
  TRY_CAST(NULLIF(RTRIM(AITBATT_DESCRIZIONE), '') AS VARCHAR(30)) AS aitbatt_descrizione,
  TRY_CAST(ROWID AS NUMBER(38, 0)) AS rowid
from {{ source('source_l0','aitbfatt') }}
