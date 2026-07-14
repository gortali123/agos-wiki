select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  TRY_CAST(ID_TIERS AS VARCHAR(11)) AS id_tiers,
  TRY_CAST(NOM_TIERS AS VARCHAR(100)) AS nom_tiers,
  TRY_CAST(NOM_COURT_TIERS AS VARCHAR(100)) AS nom_court_tiers,
  TRY_CAST(CODE_SECTEUR_ACT AS VARCHAR(10)) AS code_secteur_act,
  TRY_CAST(CODE_CAT_CONTREPARTIE AS VARCHAR(5)) AS code_cat_contrepartie,
  TRY_CAST(ALIAS_TYPE AS VARCHAR(20)) AS alias_type,
  TRY_CAST(IDENTIFIANT_ALIAS AS VARCHAR(20)) AS identifiant_alias
from {{ source('source_l0','fircom_2') }}
