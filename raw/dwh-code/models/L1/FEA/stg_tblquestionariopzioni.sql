select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  COALESCE(TRY_CAST(data_modifica AS TIMESTAMP_NTZ), TRY_CAST(data_creazione AS TIMESTAMP_NTZ)) AS ts_coalesce_modif_creaz, --TRYCAST prima della COALESCE altrimenti non funziona correttamente
  TRY_CAST(idQuestionarioOpzione AS NUMBER(11,0)) AS idquestionarioopzione,
  TRY_CAST(idQuestionarioDomanda AS NUMBER(11,0)) AS idquestionariodomanda,
  TRY_CAST(codice_opzione AS NUMBER(6,0)) AS codice_opzione,
  TRY_CAST(ds_opzione AS VARCHAR) AS ds_opzione,
  TRY_CAST(valore AS VARCHAR) AS valore,
  TRY_CAST(ordine_opzione AS NUMBER(6,0)) AS ordine_opzione,
  TRY_CAST(data_inizio_validita AS DATE) AS data_inizio_validita,
  TRY_CAST(data_fine_validita AS DATE) AS data_fine_validita,
  TRY_CAST(eliminato AS NUMBER(1,0)) AS eliminato,
  TRY_CAST(data_creazione AS TIMESTAMP_NTZ) AS data_creazione,
  TRY_CAST(data_modifica AS TIMESTAMP_NTZ) AS data_modifica
from {{ source('source_l0','tblquestionariopzioni') }}
