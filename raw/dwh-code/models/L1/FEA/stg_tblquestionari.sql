select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  COALESCE(TRY_CAST(data_modifica AS TIMESTAMP_NTZ), TRY_CAST(data_creazione AS TIMESTAMP_NTZ)) AS ts_coalesce_modif_creaz, --TRYCAST prima della COALESCE altrimenti non funziona correttamente
  TRY_CAST(idQuestionario AS NUMBER(11,0)) AS idquestionario,
  TRY_CAST(tipo AS NUMBER(3,0)) AS tipo,
  TRY_CAST(ds_questionario AS VARCHAR(100)) AS ds_questionario,
  TRY_CAST(data_inizio_validita AS DATE) AS data_inizio_validita,
  TRY_CAST(data_fine_validita AS DATE) AS data_fine_validita,
  TRY_CAST(eliminato AS NUMBER(1,0)) AS eliminato,
  TRY_CAST(data_creazione AS TIMESTAMP_NTZ) AS data_creazione,
  TRY_CAST(data_modifica AS TIMESTAMP_NTZ) AS data_modifica
from {{ source('source_l0','tblquestionari') }}
