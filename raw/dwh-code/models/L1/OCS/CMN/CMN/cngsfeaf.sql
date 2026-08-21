select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  'N' as fl_deleted,
  NULL::TIMESTAMP_NTZ as ts_deleted,
  sys_change_operation,
  TRY_CAST(lastmodifieddata AS TIMESTAMP_NTZ) as lastmodifieddata,
  TRY_CAST(CNGSEAF_PROGRESSIVO AS NUMBER(13,0)) AS cngseaf_progressivo,
  TRY_CAST(CNGSEAF_PAGINA AS NUMBER(1,0)) AS cngseaf_pagina,
  TRY_CAST(CNGSEAF_PRG_ACCOUNT AS NUMBER(13,0)) AS cngseaf_prg_account,
  TRY_CAST(IFF(RTRIM(CNGSEAF_ACCOUNT) = '', ' ', RTRIM(CNGSEAF_ACCOUNT)) AS VARCHAR(100)) AS cngseaf_account,
  TRY_CAST(ROWID AS NUMBER(38, 0)) AS rowid
from {{ source('source_l0','cngsfeaf') }}
