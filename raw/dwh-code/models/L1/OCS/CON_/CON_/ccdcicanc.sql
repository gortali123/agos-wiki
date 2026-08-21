select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  'N' as fl_deleted,
  NULL::TIMESTAMP_NTZ as ts_deleted,
  sys_change_operation,
  TRY_CAST(lastmodifieddata AS TIMESTAMP_NTZ) as lastmodifieddata,
  TRY_CAST(DCANC_PROGRESSIVO AS NUMBER(9,0)) AS dcanc_progressivo,
  TRY_CAST(DCANC_DESTINATARIO AS NUMBER(9,0)) AS dcanc_destinatario,
  TRY_CAST(DCANC_NUM_PRATICA AS NUMBER(12,0)) AS dcanc_num_pratica,
  TRY_CAST(IFF(RTRIM(DCANC_TIPO_CLIENTE) = '', ' ', RTRIM(DCANC_TIPO_CLIENTE)) AS VARCHAR(2)) AS dcanc_tipo_cliente,
  TRY_CAST(IFF(RTRIM(DCANC_PROVENIENZA) = '', ' ', RTRIM(DCANC_PROVENIENZA)) AS VARCHAR(2)) AS dcanc_provenienza,
  TRY_CAST(IFF(RTRIM(DCANC_DA_STAMPARE) = '', ' ', RTRIM(DCANC_DA_STAMPARE)) AS VARCHAR(1)) AS dcanc_da_stampare,
  TRY_CAST(DCANC_PRG_PSVT_RIF_STORNO AS NUMBER(11,0)) AS dcanc_prg_psvt_rif_storno,
  TRY_CAST(ROWID AS NUMBER(38, 0)) AS rowid
from {{ source('source_l0','ccdcicanc') }}
