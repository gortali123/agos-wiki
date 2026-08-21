select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  'N' as fl_deleted,
  NULL::TIMESTAMP_NTZ as ts_deleted,
  sys_change_operation,
  TRY_CAST(lastmodifieddata AS TIMESTAMP_NTZ) as lastmodifieddata,
  TRY_CAST(MRCPLCN_PROGRESSIVO AS NUMBER(9,0)) AS mrcplcn_progressivo,
  TRY_CAST(MRCPLCN_CONTROPARTE AS NUMBER(9,0)) AS mrcplcn_controparte,
  TRY_CAST(IFF(RTRIM(MRCPLCN_COD_ANAGRAFICO_EP) = '', ' ', RTRIM(MRCPLCN_COD_ANAGRAFICO_EP)) AS VARCHAR(16)) AS mrcplcn_cod_anagrafico_ep,
  TRY_CAST(ROWID AS NUMBER(38, 0)) AS rowid
from {{ source('source_l0','mrcpflcn') }}
