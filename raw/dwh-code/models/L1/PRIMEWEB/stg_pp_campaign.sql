select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  TRY_CAST(CAMPAIGNID AS VARCHAR(8)) AS campaignid,
  TRY_CAST(NAME AS VARCHAR(100)) AS name,
  TRY_CAST(BROKERCODE AS VARCHAR(2)) AS brokercode,
  TRY_CAST(CATEGORY AS VARCHAR(100)) AS category,
  TRY_CAST(TYPE AS VARCHAR(100)) AS type,
  TRY_CAST(ROLE AS VARCHAR(36)) AS role,
  TRY_CAST(ACTIVE AS VARCHAR(5)) AS active,
  TRY_CAST(SETSUBSIDIARYFROMZIPCODE AS VARCHAR(5)) AS setsubsidiaryfromzipcode
from {{ source('source_l0','pp_campaign') }}
