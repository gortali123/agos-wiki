select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  'N' as fl_deleted,
  NULL::TIMESTAMP_NTZ as ts_deleted,
  sys_change_operation,
  TRY_CAST(lastmodifieddata AS TIMESTAMP_NTZ) as lastmodifieddata,
  TRY_CAST(IFF(RTRIM(ANFAUT_TIPO_CALCOLO) = '', ' ', RTRIM(ANFAUT_TIPO_CALCOLO)) AS VARCHAR(1)) AS anfaut_tipo_calcolo,
  TRY_CAST(ANFAUT_DATA_CALCOLO AS NUMBER(8,0)) AS anfaut_data_calcolo,
  TRY_CAST(ANFAUT_CODICE AS NUMBER(7,0)) AS anfaut_codice,
  TRY_CAST(ANFAUT_FIDO_CALCOLATO AS NUMBER(13,0)) AS anfaut_fido_calcolato,
  TRY_CAST(ANFAUT_SALDO_RILEVATO AS NUMBER(13,0)) AS anfaut_saldo_rilevato,
  TRY_CAST(ANFAUT_ANTICIP_AUTO AS NUMBER(13,0)) AS anfaut_anticip_auto,
  TRY_CAST(IFF(RTRIM(ANFAUT_DA_DISATTIVARE) = '', ' ', RTRIM(ANFAUT_DA_DISATTIVARE)) AS VARCHAR(1)) AS anfaut_da_disattivare,
  TRY_CAST(IFF(RTRIM(ANFAUT_DA_EFFETTUARE) = '', ' ', RTRIM(ANFAUT_DA_EFFETTUARE)) AS VARCHAR(1)) AS anfaut_da_effettuare,
  TRY_CAST(IFF(RTRIM(ANFAUT_MOD_REINTEGRO) = '', ' ', RTRIM(ANFAUT_MOD_REINTEGRO)) AS VARCHAR(1)) AS anfaut_mod_reintegro,
  TRY_CAST(ROWID AS NUMBER(38, 0)) AS rowid
from {{ source('source_l0','rdanfaut') }}
