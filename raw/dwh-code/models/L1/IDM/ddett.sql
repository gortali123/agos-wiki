select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  TRY_CAST(K0 AS VARCHAR(50)) AS k0,
  TRY_CAST(CANALE AS VARCHAR(35)) AS canale,
  TRY_CAST(SCATOLA AS NUMBER(10,0)) AS scatola,
  TRY_CAST(PRATICA AS VARCHAR(20)) AS pratica,
  TRY_CAST(DOCUMENTO AS VARCHAR(20)) AS documento,
  TRY_CAST(DATA_ORA_RICEZIONE AS TIMESTAMP_NTZ) AS data_ora_ricezione,
  TRY_CAST(DATA_ORA_CARICAMENTO AS TIMESTAMP_NTZ) AS data_ora_caricamento,
  TRY_CAST(SLA AS NUMBER(3,0)) AS sla, --era number(2,0)
  TRY_CAST(NUMERO_DI_PAGINE AS NUMBER(5,0)) AS numero_di_pagine
from {{ source('source_l0','ddett') }}
