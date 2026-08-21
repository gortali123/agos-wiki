select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  'N' as fl_deleted,
  NULL::TIMESTAMP_NTZ as ts_deleted,
  sys_change_operation,
  TRY_CAST(lastmodifieddata AS TIMESTAMP_NTZ) as lastmodifieddata,
  TRY_CAST(CQASFLUL_NUM_PRATICA AS NUMBER(12,0)) AS cqasflul_num_pratica,
  TRY_CAST(IFF(RTRIM(CQASFLUL_INTERFACCIA) = '', ' ', RTRIM(CQASFLUL_INTERFACCIA)) AS VARCHAR(3)) AS cqasflul_interfaccia,
  TRY_CAST(CQASFLUL_DATA AS NUMBER(8,0)) AS cqasflul_data,
  TRY_CAST(CQASFLUL_ORA AS NUMBER(8,0)) AS cqasflul_ora,
  TRY_CAST(IFF(RTRIM(CQASFLUL_UTENTE) = '', ' ', RTRIM(CQASFLUL_UTENTE)) AS VARCHAR(10)) AS cqasflul_utente,
  TRY_CAST(IFF(RTRIM(CQASFLUL_STATO) = '', ' ', RTRIM(CQASFLUL_STATO)) AS VARCHAR(2)) AS cqasflul_stato,
  TRY_CAST(IFF(RTRIM(CQASFLUL_FUNZIONE) = '', ' ', RTRIM(CQASFLUL_FUNZIONE)) AS VARCHAR(10)) AS cqasflul_funzione,
  TRY_CAST(IFF(RTRIM(CQASFLUL_ESITO_AVANZ) = '', ' ', RTRIM(CQASFLUL_ESITO_AVANZ)) AS VARCHAR(5)) AS cqasflul_esito_avanz,
  TRY_CAST(ROWID AS NUMBER(38, 0)) AS rowid
from {{ source('source_l0','cqasfflul') }}
