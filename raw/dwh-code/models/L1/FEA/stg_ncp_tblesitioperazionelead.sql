select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  --COALESCE(TRY_CAST(data_modifica AS TIMESTAMP_NTZ), TRY_CAST(data_creazione AS TIMESTAMP_NTZ)) AS ts_coalesce_modif_creaz, --TRYCAST prima della COALESCE altrimenti non funziona correttamente
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_coalesce_modif_creaz, --da togliere questa riga e sostituire con quella superiore quando ci saranno i due campi: data_modifica e data_creazione
  TRY_CAST(idEsitoOperazioneLead AS NUMBER(6,0)) AS idesitooperazionelead,
  TRY_CAST(idTipoOperazioneLead AS NUMBER(6,0)) AS idtipooperazionelead,
  TRY_CAST(ds_esito_operazione AS VARCHAR(45)) AS ds_esito_operazione,
  TRY_CAST(ordine_esito_operazione AS NUMBER(6,0)) AS ordine_esito_operazione,
  TRY_CAST(eliminato AS NUMBER(1,0)) AS eliminato
from {{ source('source_l0','ncp_tblesitioperazionelead') }}
