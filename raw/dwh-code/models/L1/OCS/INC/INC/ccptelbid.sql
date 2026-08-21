select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  'N' as fl_deleted,
  NULL::TIMESTAMP_NTZ as ts_deleted,
  sys_change_operation,
  TRY_CAST(lastmodifieddata AS TIMESTAMP_NTZ) as lastmodifieddata,
  TRY_CAST(BOID_PROGRESSIVO AS NUMBER(13,0)) AS boid_progressivo,
  TRY_CAST(BOID_CONTO_POSTALE AS NUMBER(12,0)) AS boid_conto_postale,
  TRY_CAST(BOID_PROGRESSIVO2 AS NUMBER(5,0)) AS boid_progressivo2,
  TRY_CAST(IFF(RTRIM(BOID_TIPO_IMPORTO) = '', ' ', RTRIM(BOID_TIPO_IMPORTO)) AS VARCHAR(2)) AS boid_tipo_importo,
  TRY_CAST(BOID_IMPORTO AS NUMBER(13,0)) AS boid_importo,
  TRY_CAST(ROWID AS NUMBER(38, 0)) AS rowid
from {{ source('source_l0','ccptelbid') }}
