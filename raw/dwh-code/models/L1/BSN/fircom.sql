select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  TRY_CAST(ID_TIERS AS VARCHAR(11)) AS id_tiers,
  TRY_CAST(NOM_TIERS AS VARCHAR(100)) AS nom_tiers,
  TRY_CAST(STATUT_TIERS AS VARCHAR(1)) AS statut_tiers,
  TRY_CAST(CPT AS VARCHAR(5)) AS cpt,
  TRY_CAST(CATEG_CP_TIERS AS VARCHAR(150)) AS categ_cp_tiers,
  TRY_CAST(PAYS_RES AS VARCHAR(2)) AS pays_res,
  TRY_CAST(PAYS_NAT AS VARCHAR(2)) AS pays_nat,
  TRY_CAST(PAYS_CTRL AS VARCHAR(2)) AS pays_ctrl,
  TRY_CAST(CODE_PAYS_RISQUE AS VARCHAR(2)) AS code_pays_risque,
  TRY_CAST(RUN_CA AS VARCHAR(5)) AS run_ca,
  TRY_CAST(LIBELLE_RUN AS VARCHAR(60)) AS libelle_run,
  TRY_CAST(NOTE AS VARCHAR(400)) AS note,
  TRY_CAST(DATE_NOTE AS VARCHAR(19)) AS date_note,
  TRY_CAST(SIRIS_ID_GROUPE AS VARCHAR(11)) AS siris_id_groupe,
  TRY_CAST(NOM_GROUPE AS VARCHAR(150)) AS nom_groupe
from {{ source('source_l0','fircom') }}
