select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  TRY_CAST(R_SNA AS VARCHAR(200)) AS r_sna,
  TRY_CAST(R_IDF AS VARCHAR(200)) AS r_idf,
  TRY_CAST(EU_SVALZ AS VARCHAR(200)) AS eu_svalz
from {{ source('source_l0','degraded') }}
