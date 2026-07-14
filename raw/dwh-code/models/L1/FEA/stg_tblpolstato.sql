select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  COALESCE(TRY_CAST(data_modifica AS TIMESTAMP_NTZ), TRY_CAST(data_creazione AS TIMESTAMP_NTZ)) AS ts_coalesce_modif_creaz, --TRYCAST prima della COALESCE altrimenti non funziona correttamente
  TRY_CAST(idStatoPol AS VARCHAR(1)) AS idstatopol,
  TRY_CAST(dsStatoPol AS VARCHAR(50)) AS dsstatopol,
  TRY_CAST(ordinePol AS NUMBER(6,0)) AS ordinepol,
  TRY_CAST(codStatoPolAgos AS VARCHAR(3)) AS codstatopolagos,
  TRY_CAST(dsStatoPolAgos AS VARCHAR(30)) AS dsstatopolagos,
  TRY_CAST(data_creazione AS TIMESTAMP_NTZ) AS data_creazione,
  TRY_CAST(data_modifica AS TIMESTAMP_NTZ) AS data_modifica
from {{ source('source_l0','tblpolstato') }}
