select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  'N' as fl_deleted,
  NULL::TIMESTAMP_NTZ as ts_deleted,
  sys_change_operation,
  TRY_CAST(lastmodifieddata AS TIMESTAMP_NTZ) as lastmodifieddata,
  TRY_CAST(IFF(RTRIM(BNPTCUC_CODICE_SIA) = '', ' ', RTRIM(BNPTCUC_CODICE_SIA)) AS VARCHAR(5)) AS bnptcuc_codice_sia,
  TRY_CAST(IFF(RTRIM(BNPTCUC_CREDITOR_IDENTIFIER) = '', ' ', RTRIM(BNPTCUC_CREDITOR_IDENTIFIER)) AS VARCHAR(35)) AS bnptcuc_creditor_identifier,
  TRY_CAST(IFF(RTRIM(BNPTCUC_CODICE_CUC) = '', ' ', RTRIM(BNPTCUC_CODICE_CUC)) AS VARCHAR(35)) AS bnptcuc_codice_cuc,
  TRY_CAST(ROWID AS NUMBER(38, 0)) AS rowid
from {{ source('source_l0','bnptfcuc') }}
