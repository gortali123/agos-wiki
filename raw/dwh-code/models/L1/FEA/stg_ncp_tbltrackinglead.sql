select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  COALESCE(TRY_CAST(data_modifica AS TIMESTAMP_NTZ), TRY_CAST(data_creazione AS TIMESTAMP_NTZ)) AS ts_coalesce_modif_creaz, --TRYCAST prima della COALESCE altrimenti non funziona correttamente
  TRY_CAST(idTrackingLead AS NUMBER(11,0)) AS idtrackinglead,
  TRY_CAST(idUserCreazione AS NUMBER(11,0)) AS idusercreazione,
  TRY_CAST(idNodoCreazione AS NUMBER(11,0)) AS idnodocreazione,
  TRY_CAST(idUserModifica AS NUMBER(11,0)) AS idusermodifica,
  TRY_CAST(idNodoModifica AS NUMBER(11,0)) AS idnodomodifica,
  TRY_CAST(idLead AS NUMBER(11,0)) AS idlead,
  TRY_CAST(idStatoLead AS NUMBER(6,0)) AS idstatolead,
  TRY_CAST(idTipoOperazioneLead AS NUMBER(6,0)) AS idtipooperazionelead,
  TRY_CAST(idEsitoOperazioneLead AS NUMBER(6,0)) AS idesitooperazionelead,
  TRY_CAST(ds_tracking AS VARCHAR) AS ds_tracking,
  TRY_CAST(data_creazione AS TIMESTAMP_NTZ) AS data_creazione,
  TRY_CAST(data_modifica AS TIMESTAMP_NTZ) AS data_modifica
from {{ source('source_l0','ncp_tbltrackinglead') }}
