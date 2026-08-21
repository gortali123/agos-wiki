select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  'N' as fl_deleted,
  NULL::TIMESTAMP_NTZ as ts_deleted,
  sys_change_operation,
  TRY_CAST(lastmodifieddata AS TIMESTAMP_NTZ) as lastmodifieddata,
  TRY_CAST(IFF(RTRIM(CACICCAT_COD_TIPOLOGIA) = '', ' ', RTRIM(CACICCAT_COD_TIPOLOGIA)) AS VARCHAR(1)) AS caciccat_cod_tipologia,
  TRY_CAST(IFF(RTRIM(CACICCAT_DESC) = '', ' ', RTRIM(CACICCAT_DESC)) AS VARCHAR(30)) AS caciccat_desc,
  TRY_CAST(ROWID AS NUMBER(38, 0)) AS rowid
from {{ source('source_l0','cacifccat') }}
