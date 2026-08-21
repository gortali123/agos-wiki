select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  'N' as fl_deleted,
  NULL::TIMESTAMP_NTZ as ts_deleted,
  sys_change_operation,
  TRY_CAST(lastmodifieddata AS TIMESTAMP_NTZ) as lastmodifieddata,
  TRY_CAST(AMMSCB_AMMINISTR AS NUMBER(9,0)) AS ammscb_amministr,
  TRY_CAST(AMMSCB_SEDE AS NUMBER(3,0)) AS ammscb_sede,
  TRY_CAST(AMMSCB_PROGRESSIVO AS NUMBER(3,0)) AS ammscb_progressivo,
  TRY_CAST(AMMSCB_BANCA_ABI AS NUMBER(5,0)) AS ammscb_banca_abi,
  TRY_CAST(AMMSCB_BANCA_CAB AS NUMBER(5,0)) AS ammscb_banca_cab,
  TRY_CAST(IFF(RTRIM(AMMSCB_BANCA_CC) = '', ' ', RTRIM(AMMSCB_BANCA_CC)) AS VARCHAR(12)) AS ammscb_banca_cc,
  TRY_CAST(IFF(RTRIM(AMMSCB_BANCA_CIN) = '', ' ', RTRIM(AMMSCB_BANCA_CIN)) AS VARCHAR(1)) AS ammscb_banca_cin,
  TRY_CAST(ROWID AS NUMBER(38, 0)) AS rowid
from {{ source('source_l0','ccammscb') }}
