select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  TRY_CAST(id_row AS NUMBER(38,0)) as id_row,
  TRY_CAST(ds_filename AS VARCHAR) as ds_filename,
  parse_xml('<root>' || SUBSTRING(value,41) || '</root>')::variant AS value
from {{ source('source_l0','cde') }}
where LTRIM(value) LIKE 'IO%'
