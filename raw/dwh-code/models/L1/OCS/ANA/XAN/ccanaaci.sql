select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  sys_change_operation,
  TRY_CAST(lastmodifieddata AS TIMESTAMP_NTZ) as lastmodifieddata,
  TRY_CAST(ANAACI_CONTROPARTE AS NUMBER(9,0)) AS anaaci_controparte,
  TRY_CAST(IFF(RTRIM(ANAACI_TIPO) = '', ' ', RTRIM(ANAACI_TIPO)) AS VARCHAR(3)) AS anaaci_tipo,
  TRY_CAST(IFF(RTRIM(ANAACI_CONTATTO) = '', ' ', RTRIM(ANAACI_CONTATTO)) AS VARCHAR(256)) AS anaaci_contatto,
  TRY_CAST(ROWID AS NUMBER(38, 0)) AS rowid
from {{ source('source_l0','ccanaaci') }}
