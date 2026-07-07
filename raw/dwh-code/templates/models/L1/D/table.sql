select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  sys_change_operation,
  TRY_CAST(lastmodifieddata AS TIMESTAMP_NTZ) as lastmodifieddata,
  {{ get_dt_osservazione('ts_riferimento') }} as dt_osservazione,
  TRY_CAST(<col1> AS <dtype>) AS <col1>,
  -- ...
  TRY_CAST(ROWID AS NUMBER(38, 0)) as rowid
from {{ source('source_l0', '<table>') }}
