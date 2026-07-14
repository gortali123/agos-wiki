select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  TRY_CAST(PR_ID_CONFIG_BLOCCO AS NUMBER(10,0)) AS pr_id_config_blocco,
  TRY_CAST(CD_BANCA_DATI AS VARCHAR(2)) AS cd_banca_dati,
  TRY_CAST(IN_BLOCCO_AUTO AS VARCHAR(1)) AS in_blocco_auto,
  TRY_CAST(NM_MINUTI AS NUMBER(10,0)) AS nm_minuti,
  TRY_CAST(NM_MAX_RCHT_ERRORE AS NUMBER(10,0)) AS nm_max_rcht_errore,
  TRY_CAST(NM_MAX_RCHT_ATTIV AS NUMBER(10,0)) AS nm_max_rcht_attiv,
  TRY_CAST(DN_EMAIL_ALERT AS VARCHAR(100)) AS dn_email_alert,
  TRY_CAST(CD_OPTLOCK AS NUMBER(10,0)) AS cd_optlock,
  TRY_CAST(CD_USER_INSE AS VARCHAR(32)) AS cd_user_inse,
  TRY_CAST(CD_TRANS_INSE AS VARCHAR(32)) AS cd_trans_inse,
  TRY_CAST(TS_INSE AS TIMESTAMP_NTZ) AS ts_inse
from {{ source('source_l0','blocco_bd') }}
