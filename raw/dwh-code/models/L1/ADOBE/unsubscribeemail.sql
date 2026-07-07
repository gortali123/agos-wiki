select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  TRY_CAST(AGOSCLIENTEID AS VARCHAR(100)) AS agosclienteid,
  TRY_CAST(CODICEISTITUTO AS VARCHAR(2)) AS codiceistituto,
  TRY_CAST(EMAIL AS VARCHAR(100)) AS email,
  TRY_CAST(DATAUNSUBSCRIPTION AS TIMESTAMP_NTZ) AS dataunsubscription
from {{ source('source_l0','unsubscribeemail') }}
