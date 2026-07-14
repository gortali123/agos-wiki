select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  TRY_CAST(FORMREQUESTID AS NUMBER(8,0)) AS formrequestid,
  TRY_CAST(CREATIONDATE AS VARCHAR(20)) AS creationdate,
  TRY_CAST(IPADDRESS AS VARCHAR(20)) AS ipaddress,
  TRY_CAST(MOBILE AS VARCHAR(18)) AS mobile,
  TRY_CAST(BROKERCODE AS VARCHAR(12)) AS brokercode,
  TRY_CAST(FORMSESSIONID AS VARCHAR(36)) AS formsessionid,
  TRY_CAST(SESSIONUID AS VARCHAR(50)) AS sessionuid,
  TRY_CAST(AMOUNT AS NUMBER(10,2)) AS amount,
  TRY_CAST(RATE AS VARCHAR(10)) AS rate,
  TRY_CAST(LAYOUT AS VARCHAR(10)) AS layout,
  TRY_CAST(REFERRER AS VARCHAR(500)) AS referrer,
  TRY_CAST(CAMPAIGNID AS VARCHAR(8)) AS campaignid
from {{ source('source_l0','pp_session') }}
