select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  sys_change_operation,
  TRY_CAST(lastmodifieddata AS TIMESTAMP_NTZ) as lastmodifieddata,
  TRY_CAST(IFF(RTRIM(BAINT_PROCEDURA) = '', ' ', RTRIM(BAINT_PROCEDURA)) AS VARCHAR(2)) AS baint_procedura,
  TRY_CAST(BAINT_PRATICA AS NUMBER(12,0)) AS baint_pratica,
  TRY_CAST(BAINT_PROGRESSIVO AS NUMBER(3,0)) AS baint_progressivo,
  TRY_CAST(BAINT_RETE_VENDITA AS NUMBER(9,0)) AS baint_rete_vendita,
  TRY_CAST(BAINT_AGENTE AS NUMBER(9,0)) AS baint_agente,
  TRY_CAST(BAINT_SUB_AGENTE AS NUMBER(9,0)) AS baint_sub_agente,
  TRY_CAST(BAINT_CONVENZIONATO AS NUMBER(9,0)) AS baint_convenzionato,
  TRY_CAST(BAINT_PUNTO_VENDITA AS NUMBER(9,0)) AS baint_punto_vendita,
  TRY_CAST(BAINT_VENDITORE AS NUMBER(9,0)) AS baint_venditore,
  TRY_CAST(BAINT_SEGNALATORE AS NUMBER(12,0)) AS baint_segnalatore,
  TRY_CAST(IFF(RTRIM(BAINT_BRAND) = '', ' ', RTRIM(BAINT_BRAND)) AS VARCHAR(1)) AS baint_brand,
  TRY_CAST(ROWID AS NUMBER(38, 0)) AS rowid
from {{ source('source_l0','bapratint') }}
