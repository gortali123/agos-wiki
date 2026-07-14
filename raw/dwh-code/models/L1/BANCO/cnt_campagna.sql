select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  TRIM(SUBSTR(DS_COLONNA, 1, 5))         AS CD_BANCA,         -- fix: era TRY_CAST AS NUMERIC(5,0)
  TRY_CAST(TRIM(SUBSTR(DS_COLONNA, 6, 10))  AS NUMERIC(10, 0)) AS CD_AZIONE,
  TRIM(SUBSTR(DS_COLONNA, 16, 16))       AS CD_NDG,            -- fix: era TRY_CAST AS NUMERIC(16,0)
  TRIM(SUBSTR(DS_COLONNA, 32, 16))       AS CD_FISCALE,
  TRIM(SUBSTR(DS_COLONNA, 48, 5))        AS CD_CANALE,
  TRIM(SUBSTR(DS_COLONNA, 53, 15))       AS CD_CAMPO_CODE,
  TRIM(SUBSTR(DS_COLONNA, 68, 5))        AS CD_CAMP_SEL,       -- fix: era TRY_CAST AS NUMERIC(5,0)
  TRIM(SUBSTR(DS_COLONNA, 73, 5))        AS CD_CAMP_EXEC,      -- fix: era TRY_CAST AS NUMERIC(5,0)
  TRIM(SUBSTR(DS_COLONNA, 78, 50))       AS CD_CAMP_DES,
  TRIM(SUBSTR(DS_COLONNA, 128, 8))       AS DT_INIZIO_VAL,     -- fix: era TRY_CAST AS DATE
  TRIM(SUBSTR(DS_COLONNA, 136, 8))       AS DT_FINE_VAL,       -- fix: era TRY_CAST AS DATE
  TRIM(SUBSTR(DS_COLONNA, 144, 5))       AS CD_SPORTELLO,      -- fix: era TRY_CAST AS NUMERIC(8,0); anche lunghezza corretta a 5 (da yml VARCHAR(8) ma substr era 5)
  TRY_CAST(TRIM(SUBSTR(DS_COLONNA, 149, 18)) AS NUMERIC(18, 3)) AS VALORE,  -- fix: precisione 0→3 (yml NUMERIC(18,3))
  TRIM(SUBSTR(DS_COLONNA, 167, 19))      AS NOTA_CODE
FROM {{ source('source_l0', 'cnt_campagna') }}