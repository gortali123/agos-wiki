select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  TRY_CAST(TRACKINGID AS VARCHAR(30)) AS trackingid,
  TRY_CAST(BROADLOGID AS VARCHAR(30)) AS broadlogid,
  TRY_CAST(DELIVERYID AS VARCHAR(255)) AS deliveryid,
  TRY_CAST(DATARISPOSTA AS VARCHAR(30)) AS datarisposta,
  TRY_CAST(TIPOINTERAZIONE AS VARCHAR(255)) AS tipointerazione,
  TRY_CAST(DETTAGLIOINTERAZIONECLIENTE AS VARCHAR(255)) AS dettagliointerazionecliente,
  TRY_CAST(CANALEESITO AS VARCHAR(255)) AS canaleesito,
  TRY_CAST(CATEGORIALINK AS VARCHAR(255)) AS categorialink
from {{ source('source_l0','rtresponse') }}
