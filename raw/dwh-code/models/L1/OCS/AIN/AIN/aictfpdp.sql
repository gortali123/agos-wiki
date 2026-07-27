select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  sys_change_operation,
  TRY_CAST(lastmodifieddata AS TIMESTAMP_NTZ) as lastmodifieddata,
  TRY_CAST(AICTPDP_IDE AS NUMBER(13,0)) AS aictpdp_ide,
  TRY_CAST(AICTPDP_PRATICA AS NUMBER(12,0)) AS aictpdp_pratica,
  TRY_CAST(IFF(RTRIM(AICTPDP_PROCEDURA_RIF) = '', ' ', RTRIM(AICTPDP_PROCEDURA_RIF)) AS VARCHAR(2)) AS aictpdp_procedura_rif,
  TRY_CAST(IFF(RTRIM(AICTPDP_EMAIL) = '', ' ', RTRIM(AICTPDP_EMAIL)) AS VARCHAR(50)) AS aictpdp_email,
  TRY_CAST(IFF(RTRIM(AICTPDP_IBAN) = '', ' ', RTRIM(AICTPDP_IBAN)) AS VARCHAR(34)) AS aictpdp_iban,
  TRY_CAST(IFF(RTRIM(AICTPDP_TIPO_INVIO) = '', ' ', RTRIM(AICTPDP_TIPO_INVIO)) AS VARCHAR(1)) AS aictpdp_tipo_invio,
  TRY_CAST(IFF(RTRIM(AICTPDP_UTENTE) = '', ' ', RTRIM(AICTPDP_UTENTE)) AS VARCHAR(10)) AS aictpdp_utente,
  TRY_CAST(AICTPDP_DATA AS NUMBER(8,0)) AS aictpdp_data,
  TRY_CAST(AICTPDP_ORA AS NUMBER(8,0)) AS aictpdp_ora,
  TRY_CAST(AICTPDP_PRG_LOG AS NUMBER(10,0)) AS aictpdp_prg_log,
  TRY_CAST(ROWID AS NUMBER(38, 0)) AS rowid
from {{ source('source_l0','aictfpdp') }}
