{{ config(
  alias = 'GROUP',
  quoting={'identifier': true}
)
}}

select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  TRY_CAST(Id AS VARCHAR(18)) AS id,
  TRY_CAST(DeveloperName AS VARCHAR(255)) AS developername
from {{ source('source_l0','GROUP') }}
