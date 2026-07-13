select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  TRY_CAST(SUBSTR(ds_colonna, 1, 3)     AS VARCHAR(3))   AS DS_FILLER_1,
  TRY_CAST(SUBSTR(ds_colonna, 4, 9)     AS VARCHAR(9))   AS CD_NDG,
  TRY_CAST(SUBSTR(ds_colonna, 13, 9)    AS VARCHAR(9))   AS DS_FILLER_2,
  TRY_CAST(SUBSTR(ds_colonna, 22, 2)    AS VARCHAR(2))   AS CD_PRODOTTO,
  TRY_CAST(SUBSTR(ds_colonna, 24, 9)    AS VARCHAR(9))   AS CD_PRATICA,
  TRY_CAST(SUBSTR(ds_colonna, 33, 9)    AS VARCHAR(9))   AS DS_FILLER_3,
  TRY_CAST(SUBSTR(ds_colonna, 42, 1)    AS VARCHAR(1))   AS CD_STATO,
  TRY_CAST(SUBSTR(ds_colonna, 43, 4)    AS VARCHAR(4))   AS DS_FILLER_4,
  TRY_CAST(SUBSTR(ds_colonna, 47, 1)    AS VARCHAR(1))   AS TP_ERRORE,
  TRY_CAST(SUBSTR(ds_colonna, 48, 5)    AS VARCHAR(5))   AS DS_FILLER_5,
  TRY_CAST(SUBSTR(ds_colonna, 53, 4)    AS VARCHAR(4))   AS CD_ERRORE,
  TRY_CAST(SUBSTR(ds_colonna, 57, 1)    AS VARCHAR(1))   AS DS_FILLER_6,
  TRY_CAST(SUBSTR(ds_colonna, 58, 62)   AS VARCHAR(62))  AS DS_ERRORE,
  TRY_CAST(SUBSTR(ds_colonna, 120, 30)  AS VARCHAR(30))  AS DS_DATO_ERRATO,
  TRY_CAST(SUBSTR(ds_colonna, 150, 850) AS VARCHAR(850)) AS DS_FILLER_7
from {{ source('source_l0','crifra_np041rt') }}
