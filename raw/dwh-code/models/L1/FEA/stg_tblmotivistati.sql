select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  COALESCE(TRY_CAST(data_modifica AS TIMESTAMP_NTZ), TRY_CAST(data_creazione AS TIMESTAMP_NTZ)) AS ts_coalesce_modif_creaz, --TRYCAST prima della COALESCE altrimenti non funziona correttamente
  TRY_CAST(idMotivoStato AS NUMBER(11,0)) AS idmotivostato,
  TRY_CAST(idStato AS NUMBER(6,0)) AS idstato,
  TRY_CAST(idMotivo AS NUMBER(6,0)) AS idmotivo,
  TRY_CAST(ds_motivo_stato AS VARCHAR(250)) AS ds_motivo_stato,
  TRY_CAST(ordine AS NUMBER(6,0)) AS ordine,
  TRY_CAST(data_creazione AS TIMESTAMP_NTZ) AS data_creazione,
  TRY_CAST(data_modifica AS TIMESTAMP_NTZ) AS data_modifica
from {{ source('source_l0','tblmotivistati') }}
