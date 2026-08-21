select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  'N' as fl_deleted,
  NULL::TIMESTAMP_NTZ as ts_deleted,
  sys_change_operation,
  TRY_CAST(lastmodifieddata AS TIMESTAMP_NTZ) as lastmodifieddata,
  TRY_CAST(PCCOCOML_ID_CONTATTO AS NUMBER(13,0)) AS pccocoml_id_contatto,
  TRY_CAST(IFF(RTRIM(PCCOCOML_PROCEDURA) = '', ' ', RTRIM(PCCOCOML_PROCEDURA)) AS VARCHAR(2)) AS pccocoml_procedura,
  TRY_CAST(PCCOCOML_SIMULAZ AS NUMBER(12,0)) AS pccocoml_simulaz,
  TRY_CAST(IFF(RTRIM(PCCOCOML_UTENTE) = '', ' ', RTRIM(PCCOCOML_UTENTE)) AS VARCHAR(10)) AS pccocoml_utente,
  TRY_CAST(PCCOCOML_DATA AS NUMBER(8,0)) AS pccocoml_data,
  TRY_CAST(PCCOCOML_ORA AS NUMBER(8,0)) AS pccocoml_ora,
  TRY_CAST(ROWID AS NUMBER(38, 0)) AS rowid
from {{ source('source_l0','pccofcoml') }}
