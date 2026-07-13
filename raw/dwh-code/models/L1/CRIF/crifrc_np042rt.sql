select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  TRY_CAST(SUBSTR(ds_colonna, 1, 3)    AS VARCHAR(3))   AS DS_FILLER_1,
  TRY_CAST(SUBSTR(ds_colonna, 4, 2)    AS VARCHAR(2))   AS CD_PRODOTTO,
  TRY_CAST(SUBSTR(ds_colonna, 6, 9)    AS VARCHAR(9))   AS CD_PRATICA,
  TRY_CAST(SUBSTR(ds_colonna, 15, 9)   AS VARCHAR(9))   AS DS_FILLER_2,
  TRY_CAST(SUBSTR(ds_colonna, 24, 1)   AS VARCHAR(1))   AS CD_STATO,
  TRY_CAST(SUBSTR(ds_colonna, 25, 5)   AS VARCHAR(5))   AS DS_FILLER_3,
  TRY_CAST(SUBSTR(ds_colonna, 30, 1)   AS VARCHAR(1))   AS TP_ERRORE,
  TRY_CAST(SUBSTR(ds_colonna, 31, 5)   AS VARCHAR(5))   AS DS_FILLER_4,
  TRY_CAST(SUBSTR(ds_colonna, 36, 3)   AS VARCHAR(3))   AS CD_ERRORE,
  TRY_CAST(SUBSTR(ds_colonna, 39, 2)   AS VARCHAR(2))   AS DS_FILLER_5,
  TRY_CAST(SUBSTR(ds_colonna, 41, 62)  AS VARCHAR(62))  AS DS_ERRORE,
  TRY_CAST(SUBSTR(ds_colonna, 103, 8)  AS VARCHAR(8))   AS DS_DATO_ERRATO,
  TRY_CAST(SUBSTR(ds_colonna, 111, 889) AS VARCHAR(889)) AS DS_FILLER_6
from {{ source('source_l0','crifrc_np042rt') }}
