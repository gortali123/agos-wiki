select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  'N' as fl_deleted,
  NULL::TIMESTAMP_NTZ as ts_deleted,
  sys_change_operation,
  TRY_CAST(lastmodifieddata AS TIMESTAMP_NTZ) as lastmodifieddata,
  TRY_CAST(IFF(RTRIM(TAFBL_BLOCCO) = '', ' ', RTRIM(TAFBL_BLOCCO)) AS VARCHAR(2)) AS tafbl_blocco,
  TRY_CAST(IFF(RTRIM(TAFBL_DESCRIZIONE) = '', ' ', RTRIM(TAFBL_DESCRIZIONE)) AS VARCHAR(30)) AS tafbl_descrizione,
  TRY_CAST(IFF(RTRIM(TAFBL_FLAG_ANTICIP_AUTO) = '', ' ', RTRIM(TAFBL_FLAG_ANTICIP_AUTO)) AS VARCHAR(1)) AS tafbl_flag_anticip_auto,
  TRY_CAST(IFF(RTRIM(TAFBL_FLAG_ANTICIP_MAN) = '', ' ', RTRIM(TAFBL_FLAG_ANTICIP_MAN)) AS VARCHAR(1)) AS tafbl_flag_anticip_man,
  TRY_CAST(IFF(RTRIM(TAFBL_FLAG_CONT_INTERESSI) = '', ' ', RTRIM(TAFBL_FLAG_CONT_INTERESSI)) AS VARCHAR(1)) AS tafbl_flag_cont_interessi,
  TRY_CAST(IFF(RTRIM(TAFBL_FLAG_EROSIONE_FIDO) = '', ' ', RTRIM(TAFBL_FLAG_EROSIONE_FIDO)) AS VARCHAR(1)) AS tafbl_flag_erosione_fido,
  TRY_CAST(ROWID AS NUMBER(38, 0)) AS rowid
from {{ source('source_l0','rdtafbl') }}
