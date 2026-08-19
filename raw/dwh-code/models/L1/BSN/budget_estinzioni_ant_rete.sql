select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  TRY_CAST(TP_BUDGET AS VARCHAR(10)) AS tp_budget,
  TRY_CAST(DT_INIZIO_VALIDITA AS TIMESTAMP_NTZ) AS dt_inizio_validita,
  TRY_CAST(DT_FINE_VALIDITA AS TIMESTAMP_NTZ) AS dt_fine_validita,
  TRY_CAST(NM_ANNO AS NUMBER(4)) AS nm_anno,
  TRY_CAST(NM_MESE AS NUMBER(2)) AS nm_mese,
  TRY_CAST(TP_PROCEDURA AS VARCHAR(10)) AS tp_procedura,
  TRY_CAST(CD_GER_TERRITORIALE_1 AS VARCHAR(50)) AS cd_ger_territoriale_1,
  TRY_CAST(CD_GER_TERRITORIALE_2 AS VARCHAR(50)) AS cd_ger_territoriale_2,
  TRY_CAST(CD_MERCATO_1 AS VARCHAR(50)) AS cd_mercato_1,
  TRY_CAST(CD_MERCATO_2 AS VARCHAR(50)) AS cd_mercato_2,
  TRY_CAST(CD_MERCATO_3 AS VARCHAR(50)) AS cd_mercato_3,
  TRY_CAST(CD_MERCATO_4 AS VARCHAR(50)) AS cd_mercato_4,
  TRY_CAST(EU_BDG_EST_ANT_TOT AS NUMBER(38,2)) AS eu_bdg_est_ant_tot,
  TRY_CAST(EU_BDG_EST_ANT_ESTERNE AS NUMBER(38,2)) AS eu_bdg_est_ant_esterne,
  TRY_CAST(PC_BDG_EST_ANT_ESTERN_SU_IMPIEG AS NUMBER(38,6)) AS pc_bdg_est_ant_estern_su_impieg
from {{ source('source_l0','budget_estinzioni_ant_rete') }}
