select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  'N' as fl_deleted,
  NULL::TIMESTAMP_NTZ as ts_deleted,
  sys_change_operation,
  TRY_CAST(lastmodifieddata AS TIMESTAMP_NTZ) as lastmodifieddata,
  TRY_CAST(IFF(RTRIM(CREAB_ABITAZIONE) = '', ' ', RTRIM(CREAB_ABITAZIONE)) AS VARCHAR(3)) AS creab_abitazione,
  TRY_CAST(IFF(RTRIM(CREAB_DESCRIZIONE) = '', ' ', RTRIM(CREAB_DESCRIZIONE)) AS VARCHAR(30)) AS creab_descrizione,
  TRY_CAST(IFF(RTRIM(CREAB_GEST_COSTO) = '', ' ', RTRIM(CREAB_GEST_COSTO)) AS VARCHAR(1)) AS creab_gest_costo,
  TRY_CAST(IFF(RTRIM(CREAB_TIPO_COSTO) = '', ' ', RTRIM(CREAB_TIPO_COSTO)) AS VARCHAR(1)) AS creab_tipo_costo,
  TRY_CAST(IFF(RTRIM(CREAB_GEST_SPESE) = '', ' ', RTRIM(CREAB_GEST_SPESE)) AS VARCHAR(1)) AS creab_gest_spese,
  TRY_CAST(IFF(RTRIM(CREAB_OBBL_ANZIANITA) = '', ' ', RTRIM(CREAB_OBBL_ANZIANITA)) AS VARCHAR(1)) AS creab_obbl_anzianita,
  TRY_CAST(IFF(RTRIM(CREAB_OBBL_TIPO_USCITA) = '', ' ', RTRIM(CREAB_OBBL_TIPO_USCITA)) AS VARCHAR(1)) AS creab_obbl_tipo_uscita,
  TRY_CAST(ROWID AS NUMBER(38, 0)) AS rowid
from {{ source('source_l0','cccretab') }}
