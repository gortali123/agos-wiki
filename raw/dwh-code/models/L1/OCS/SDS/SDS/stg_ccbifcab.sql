select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  'N' as fl_deleted,
  NULL::TIMESTAMP_NTZ as ts_deleted,
  sys_change_operation,
  TRY_CAST(lastmodifieddata AS TIMESTAMP_NTZ) as lastmodifieddata,
  TRY_CAST(IFF(RTRIM(CCBICAB_PROVINCIA) = '', ' ', RTRIM(CCBICAB_PROVINCIA)) AS VARCHAR(2)) AS ccbicab_provincia,
  TRY_CAST(IFF(RTRIM(CCBICAB_CODICE_CAB) = '', ' ', RTRIM(CCBICAB_CODICE_CAB)) AS VARCHAR(5)) AS ccbicab_codice_cab,
  TRY_CAST(IFF(RTRIM(CCBICAB_AREA_COMPETENZA) = '', ' ', RTRIM(CCBICAB_AREA_COMPETENZA)) AS VARCHAR(1)) AS ccbicab_area_competenza,
  TRY_CAST(ROWID AS NUMBER(38, 0)) AS rowid
from {{ source('source_l0','ccbifcab') }}
