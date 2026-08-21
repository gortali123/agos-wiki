select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  'N' as fl_deleted,
  NULL::TIMESTAMP_NTZ as ts_deleted,
  sys_change_operation,
  TRY_CAST(lastmodifieddata AS TIMESTAMP_NTZ) as lastmodifieddata,
  TRY_CAST(PCCACONKO_DATA AS NUMBER(8,0)) AS pccaconko_data,
  TRY_CAST(PCCACONKO_ORA AS NUMBER(8,0)) AS pccaconko_ora,
  TRY_CAST(IFF(RTRIM(PCCACONKO_TIPO_BATCH) = '', ' ', RTRIM(PCCACONKO_TIPO_BATCH)) AS VARCHAR(1)) AS pccaconko_tipo_batch,
  TRY_CAST(PCCACONKO_ID_CONTATTO AS NUMBER(13,0)) AS pccaconko_id_contatto,
  TRY_CAST(PCCACONKO_PROGRESSIVO AS NUMBER(9,0)) AS pccaconko_progressivo,
  TRY_CAST(IFF(RTRIM(PCCACONKO_CAMPO) = '', ' ', RTRIM(PCCACONKO_CAMPO)) AS VARCHAR(20)) AS pccaconko_campo,
  TRY_CAST(IFF(RTRIM(PCCACONKO_ERRORE) = '', ' ', RTRIM(PCCACONKO_ERRORE)) AS VARCHAR(90)) AS pccaconko_errore,
  TRY_CAST(ROWID AS NUMBER(38, 0)) AS rowid
from {{ source('source_l0','pccafconko') }}
