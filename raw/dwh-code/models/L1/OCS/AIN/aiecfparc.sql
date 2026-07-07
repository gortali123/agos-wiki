select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  sys_change_operation,
  TRY_CAST(lastmodifieddata AS TIMESTAMP_NTZ) as lastmodifieddata,
  TRY_CAST(AIECPARC_PRATICA AS NUMBER(12,0)) AS aiecparc_pratica,
  TRY_CAST(AIECPARC_PROGRESSIVO AS NUMBER(9,0)) AS aiecparc_progressivo,
  TRY_CAST(AIECPARC_PRG_FATTURA AS NUMBER(9,0)) AS aiecparc_prg_fattura,
  TRY_CAST(NULLIF(RTRIM(AIECPARC_TIPO_FATT), '') AS VARCHAR(2)) AS aiecparc_tipo_fatt,
  TRY_CAST(NULLIF(RTRIM(AIECPARC_TIPO_GENERAZ), '') AS VARCHAR(1)) AS aiecparc_tipo_generaz,
  TRY_CAST(NULLIF(RTRIM(AIECPARC_PROC_RIF), '') AS VARCHAR(2)) AS aiecparc_proc_rif,
  TRY_CAST(AIECPARC_DATA_ELABORAZIONE AS NUMBER(8,0)) AS aiecparc_data_elaborazione,
  TRY_CAST(AIECPARC_IMPORTO_RDA AS NUMBER(13,0)) AS aiecparc_importo_rda,
  TRY_CAST(ROWID AS NUMBER(38, 0)) AS rowid
from {{ source('source_l0','aiecfparc') }}
