select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  TRY_CAST(TRIM(SUBSTR(ds_colonna, 1, 5))    AS VARCHAR(5))    AS CD_BANCA,
  TRY_CAST(TRIM(SUBSTR(ds_colonna, 6, 10))   AS NUMERIC(10, 0)) AS CD_AZIONE,
  TRY_CAST(TRIM(SUBSTR(ds_colonna, 16, 16))  AS VARCHAR(16))   AS CD_NDG,
  TRY_CAST(TRIM(SUBSTR(ds_colonna, 32, 16))  AS VARCHAR(16))   AS CD_FISCALE,
  TRY_CAST(TRIM(SUBSTR(ds_colonna, 48, 5))   AS VARCHAR(5))    AS CD_CANALE,
  TRY_CAST(TRIM(SUBSTR(ds_colonna, 53, 15))  AS VARCHAR(15))   AS CD_CAMPO_CODE,
  TRY_CAST(TRIM(SUBSTR(ds_colonna, 68, 5))   AS VARCHAR(5))    AS CD_CAMP_SEL,
  TRY_CAST(TRIM(SUBSTR(ds_colonna, 73, 5))   AS VARCHAR(5))    AS CD_CAMP_EXEC,
  TRY_CAST(TRIM(SUBSTR(ds_colonna, 78, 50))  AS VARCHAR(50))   AS CD_CAMP_DES,
  TRY_CAST(TRIM(SUBSTR(ds_colonna, 128, 8))  AS VARCHAR(8))    AS DT_INIZIO_VAL,
  TRY_CAST(TRIM(SUBSTR(ds_colonna, 136, 8))  AS VARCHAR(8))    AS DT_FINE_VAL,
  TRY_CAST(TRIM(SUBSTR(ds_colonna, 144, 5))  AS VARCHAR(5))    AS CD_SPORTELLO,
  TRY_CAST(TRIM(SUBSTR(ds_colonna, 149, 18)) AS NUMERIC(18, 3)) AS VALORE,
  TRY_CAST(TRIM(SUBSTR(ds_colonna, 167, 19)) AS VARCHAR(19))   AS NOTA_CODE
from {{ source('source_l0','cnt_campagna') }}