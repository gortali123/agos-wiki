select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  TRY_CAST(LABEL AS VARCHAR(10)) AS label,
  TRY_CAST(VARIABLE AS VARCHAR(41)) AS variable,
  TRY_CAST(FORMAT AS VARCHAR(7)) AS format,
  TRY_CAST(LONG AS NUMBER(38,0)) AS long,
  TRY_CAST(POS AS NUMBER(38,0)) AS pos,
  TRY_CAST(VAL1 AS VARCHAR(30)) AS val1,
  TRY_CAST(VAL2 AS VARCHAR(30)) AS val2,
  TRY_CAST(VAL3 AS VARCHAR(30)) AS val3
from {{ source('source_l0','equ101') }}
