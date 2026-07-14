select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  COALESCE(TRY_CAST(data_modifica AS TIMESTAMP_NTZ), TRY_CAST(data_creazione AS TIMESTAMP_NTZ)) AS ts_coalesce_modif_creaz, --TRYCAST prima della COALESCE altrimenti non funziona correttamente
  TRY_CAST(idTrackingPost AS NUMBER(38,10)) AS idtrackingpost,
  TRY_CAST(idPreventivo AS NUMBER(11,0)) AS idpreventivo,
  TRY_CAST(dsTracking AS VARCHAR) AS dstracking,
  TRY_CAST(idUsers AS NUMBER(11,0)) AS idusers,
  TRY_CAST(idNodo AS NUMBER(11,0)) AS idnodo,
  TRY_CAST(idStato AS NUMBER(6,0)) AS idstato,
  TRY_CAST(idStatoPol AS VARCHAR(1)) AS idstatopol,
  TRY_CAST(idStatoPost AS NUMBER(6,0)) AS idstatopost,
  TRY_CAST(data_creazione AS TIMESTAMP_NTZ) AS data_creazione,
  TRY_CAST(data_modifica AS TIMESTAMP_NTZ) AS data_modifica
from {{ source('source_l0','tbltrackingpost') }}
