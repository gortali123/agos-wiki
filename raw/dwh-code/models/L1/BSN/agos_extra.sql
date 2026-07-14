select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  TRY_CAST(TRIM(SPLIT_PART(DS_COLONNA, '\t', 1)) AS VARCHAR(16))                       AS NDG,
  TRIM(SPLIT_PART(DS_COLONNA, '\t', 2))                  AS NUMERO_POSIZIONE,
  TRIM(SPLIT_PART(DS_COLONNA, '\t', 3))                        AS NUMERO_PARTITA,
  TRIM(SPLIT_PART(DS_COLONNA, '\t', 4))                        AS VOCE_ORIG,
  TRIM(SPLIT_PART(DS_COLONNA, '\t', 5))                        AS S_VOCE_ORIG,
  TRIM(SPLIT_PART(DS_COLONNA, '\t', 6))                        AS VOCE_DERIVATA,
  TRIM(SPLIT_PART(DS_COLONNA, '\t', 7))                        AS S_VOCE_DERIVATA,
  TRIM(SPLIT_PART(DS_COLONNA, '\t', 8))                        AS CAMPO_01297,
  TRY_CAST(TRIM(SPLIT_PART(DS_COLONNA, '\t', 9)) AS NUMBER(18,2))     AS IMPORTO
from {{ source('source_l0','agos_extra') }}

