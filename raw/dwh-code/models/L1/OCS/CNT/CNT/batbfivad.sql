select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  'N' as fl_deleted,
  NULL::TIMESTAMP_NTZ as ts_deleted,
  sys_change_operation,
  TRY_CAST(lastmodifieddata AS TIMESTAMP_NTZ) as lastmodifieddata,
  TRY_CAST(BATBIVAD_DATA AS NUMBER(8,0)) AS batbivad_data,
  TRY_CAST(IFF(RTRIM(BATBIVAD_CODICE_IVA) = '', ' ', RTRIM(BATBIVAD_CODICE_IVA)) AS VARCHAR(2)) AS batbivad_codice_iva,
  TRY_CAST(IFF(RTRIM(BATBIVAD_CODICE_IVA_PA) = '', ' ', RTRIM(BATBIVAD_CODICE_IVA_PA)) AS VARCHAR(2)) AS batbivad_codice_iva_pa,
  TRY_CAST(ROWID AS NUMBER(38, 0)) AS rowid
from {{ source('source_l0','batbfivad') }}
