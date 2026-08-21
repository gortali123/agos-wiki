select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  sys_change_operation,
  TRY_CAST(lastmodifieddata AS TIMESTAMP_NTZ) as lastmodifieddata,
  TRY_CAST(ICVP_CODICE AS NUMBER(9,0)) AS icvp_codice,
  TRY_CAST(IFF(RTRIM(ICVP_TIPO_ANA) = '', ' ', RTRIM(ICVP_TIPO_ANA)) AS VARCHAR(2)) AS icvp_tipo_ana,
  TRY_CAST(IFF(RTRIM(ICVP_TIPO_RECORD) = '', ' ', RTRIM(ICVP_TIPO_RECORD)) AS VARCHAR(3)) AS icvp_tipo_record,
  TRY_CAST(IFF(RTRIM(AICVPFIL) = '', ' ', RTRIM(AICVPFIL)) AS VARCHAR(200)) AS aicvpfil,
  TRY_CAST(ROWID AS NUMBER(38, 0)) AS rowid
from {{ source('source_l0','ccanaincv') }}
