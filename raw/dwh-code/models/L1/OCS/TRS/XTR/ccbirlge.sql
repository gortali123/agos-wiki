select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  'N' as fl_deleted,
  NULL::TIMESTAMP_NTZ as ts_deleted,
  sys_change_operation,
  TRY_CAST(lastmodifieddata AS TIMESTAMP_NTZ) as lastmodifieddata,
  TRY_CAST(IFF(RTRIM(BIRLGE_PROCEDURA) = '', ' ', RTRIM(BIRLGE_PROCEDURA)) AS VARCHAR(2)) AS birlge_procedura,
  TRY_CAST(BIRLGE_NUM_PRATICA AS NUMBER(12,0)) AS birlge_num_pratica,
  TRY_CAST(BIRLGE_DESTINATARIO AS NUMBER(9,0)) AS birlge_destinatario,
  TRY_CAST(BIRLGE_PROG_TEST AS NUMBER(9,0)) AS birlge_prog_test,
  TRY_CAST(IFF(RTRIM(BIRLGE_FLAG_RATEALE) = '', ' ', RTRIM(BIRLGE_FLAG_RATEALE)) AS VARCHAR(1)) AS birlge_flag_rateale,
  TRY_CAST(BIRLGE_DATA_ESTRAZ AS NUMBER(8,0)) AS birlge_data_estraz,
  TRY_CAST(BIRLGE_COD_ERRORE AS NUMBER(4,0)) AS birlge_cod_errore,
  TRY_CAST(IFF(RTRIM(BIRLGE_DESC_ERRORE) = '', ' ', RTRIM(BIRLGE_DESC_ERRORE)) AS VARCHAR(132)) AS birlge_desc_errore,
  TRY_CAST(ROWID AS NUMBER(38, 0)) AS rowid
from {{ source('source_l0','ccbirlge') }}
