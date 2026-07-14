select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  TRY_CAST(R_IDF AS VARCHAR(200)) AS r_idf,
  TRY_CAST(SH_ICR_REVAL AS VARCHAR(200)) AS sh_icr_reval
from {{ source('source_l0','rrf') }}
