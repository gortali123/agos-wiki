select
    TRY_CAST(ds_rete AS VARCHAR(50)) AS ds_rete,
  TRY_CAST(cd_rete AS VARCHAR(10)) AS cd_rete,
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento, -- null per ora
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento, -- null per ora
  TRY_CAST(ts_inizio_validita AS TIMESTAMP_NTZ) as ts_inizio_validita,
  TRY_CAST(ts_fine_validita AS TIMESTAMP_NTZ) as ts_fine_validita,
  TRY_CAST(ds_ger_territoriale_1 AS VARCHAR(50)) AS ds_ger_territoriale_1,
  TRY_CAST(cd_ger_territoriale_1 AS NUMBER(10)) AS cd_ger_territoriale_1,
  TRY_CAST(ds_ger_territoriale_2 AS VARCHAR(50)) AS ds_ger_territoriale_2,
  TRY_CAST(cd_ger_territoriale_2 AS NUMBER(10)) AS cd_ger_territoriale_2,
  TRY_CAST(ds_ger_territoriale_3 AS VARCHAR(80)) AS ds_ger_territoriale_3,
  TRY_CAST(cd_ger_territoriale_3 AS NUMBER(10)) AS cd_ger_territoriale_3,
  TRY_CAST(ds_ger_territoriale_4 AS VARCHAR(80)) AS ds_ger_territoriale_4,
  TRY_CAST(cd_ger_territoriale_4 AS NUMBER(10)) AS cd_ger_territoriale_4,
  TRY_CAST(ds_nodo_foglia AS VARCHAR(80)) AS ds_nodo_foglia,
  TRY_CAST(cd_nodo_foglia AS VARCHAR(10)) AS cd_nodo_foglia

from {{ source('source_l0','cfg_rete_livelli') }}