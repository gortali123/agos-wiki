select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  TRY_TO_DATE(DATASURVEY,'YYYYMMDD') AS datasurvey,
  TRY_CAST(IDSURVEY AS VARCHAR(50)) AS idsurvey,
  TRY_CAST(CODICECONTROPARTE AS VARCHAR(20)) AS codicecontroparte,
  TRY_CAST(CAMPIAGGIUNTIVI AS VARCHAR(255)) AS campiaggiuntivi,
  TRY_CAST(COMMENTONPS AS VARCHAR(500)) AS commentonps,
  TRY_CAST(NPS AS VARCHAR(2)) AS nps,
  TRY_CAST(CES AS VARCHAR(50)) AS ces
from {{ source('source_l0','adb_arc') }}
