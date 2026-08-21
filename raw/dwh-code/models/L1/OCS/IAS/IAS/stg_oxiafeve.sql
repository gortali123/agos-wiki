select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  'N' as fl_deleted,
  NULL::TIMESTAMP_NTZ as ts_deleted,
  sys_change_operation,
  TRY_CAST(lastmodifieddata AS TIMESTAMP_NTZ) as lastmodifieddata,
  TRY_CAST(IFF(RTRIM(IAEVE_PROCEDURA) = '', ' ', RTRIM(IAEVE_PROCEDURA)) AS VARCHAR(2)) AS iaeve_procedura,
  TRY_CAST(IFF(RTRIM(IAEVE_EVENTO) = '', ' ', RTRIM(IAEVE_EVENTO)) AS VARCHAR(3)) AS iaeve_evento,
  TRY_CAST(IFF(RTRIM(IAEVE_EVENTO_DES) = '', ' ', RTRIM(IAEVE_EVENTO_DES)) AS VARCHAR(40)) AS iaeve_evento_des,
  TRY_CAST(IFF(RTRIM(IAEVE_GENERA_PAM_IAS) = '', ' ', RTRIM(IAEVE_GENERA_PAM_IAS)) AS VARCHAR(1)) AS iaeve_genera_pam_ias,
  TRY_CAST(ROWID AS NUMBER(38, 0)) AS rowid
from {{ source('source_l0','oxiafeve') }}
