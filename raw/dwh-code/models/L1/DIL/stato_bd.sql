select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  TRY_CAST(PR_ID_STATO_BD AS NUMBER(10,0)) AS pr_id_stato_bd,
  TRY_CAST(CD_BANCA_DATI AS VARCHAR(2)) AS cd_banca_dati,
  TRY_CAST(IN_ATTIVA AS VARCHAR(1)) AS in_attiva,
  TRY_CAST(CD_OPTLOCK AS NUMBER(10,0)) AS cd_optlock,
  TRY_CAST(CD_USER_INSE AS VARCHAR(32)) AS cd_user_inse,
  TRY_CAST(CD_TRANS_INSE AS VARCHAR(32)) AS cd_trans_inse,
  TRY_CAST(TS_INSE AS TIMESTAMP_NTZ) AS ts_inse
from {{ source('source_l0','stato_bd') }}
