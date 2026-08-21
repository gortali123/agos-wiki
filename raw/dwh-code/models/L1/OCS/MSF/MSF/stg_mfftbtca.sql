select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  'N' as fl_deleted,
  NULL::TIMESTAMP_NTZ as ts_deleted,
  sys_change_operation,
  TRY_CAST(lastmodifieddata AS TIMESTAMP_NTZ) as lastmodifieddata,
  TRY_CAST(IFF(RTRIM(MFTBTCA_TIPO_CARICAMENTO) = '', ' ', RTRIM(MFTBTCA_TIPO_CARICAMENTO)) AS VARCHAR(2)) AS mftbtca_tipo_caricamento,
  TRY_CAST(IFF(RTRIM(MFTBTCA_DESCRIZIONE) = '', ' ', RTRIM(MFTBTCA_DESCRIZIONE)) AS VARCHAR(40)) AS mftbtca_descrizione,
  TRY_CAST(IFF(RTRIM(MFTBTCA_COLLEGAMENTO) = '', ' ', RTRIM(MFTBTCA_COLLEGAMENTO)) AS VARCHAR(1)) AS mftbtca_collegamento,
  TRY_CAST(ROWID AS NUMBER(38, 0)) AS rowid
from {{ source('source_l0','mfftbtca') }}
