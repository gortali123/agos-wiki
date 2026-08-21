select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  sys_change_operation,
  TRY_CAST(lastmodifieddata AS TIMESTAMP_NTZ) as lastmodifieddata,
  {{ compute_dt_osservazione('ts_riferimento') }} as dt_osservazione,
  TRY_CAST(IFF(RTRIM(OXCTTASR_PROCEDURA) = '', ' ', RTRIM(OXCTTASR_PROCEDURA)) AS VARCHAR(2)) AS oxcttasr_procedura,
  TRY_CAST(OXCTTASR_NUM_PRATICA AS NUMBER(12,0)) AS oxcttasr_num_pratica,
  TRY_CAST(IFF(RTRIM(OXCTTASR_COD_RENDIMENTO) = '', ' ', RTRIM(OXCTTASR_COD_RENDIMENTO)) AS VARCHAR(3)) AS oxcttasr_cod_rendimento,
  TRY_CAST(OXCTTASR_REND_NOMINALE AS NUMBER(6,3)) AS oxcttasr_rend_nominale,
  TRY_CAST(OXCTTASR_REND_EFFETTIVO AS NUMBER(6,3)) AS oxcttasr_rend_effettivo,
  TRY_CAST(OXCTTASR_FINANZIATO AS NUMBER(13,0)) AS oxcttasr_finanziato,
  TRY_CAST(OXCTTASR_ONERI AS NUMBER(13,0)) AS oxcttasr_oneri,
  TRY_CAST(IFF(RTRIM(OXCTTASR_TIPO_AGG) = '', ' ', RTRIM(OXCTTASR_TIPO_AGG)) AS VARCHAR(1)) AS oxcttasr_tipo_agg,
  TRY_CAST(OXCTTASR_DATA AS NUMBER(8,0)) AS oxcttasr_data,
  TRY_CAST(OXCTTASR_ORA AS NUMBER(8,0)) AS oxcttasr_ora,
  TRY_CAST(IFF(RTRIM(OXCTTASR_UTENTE) = '', ' ', RTRIM(OXCTTASR_UTENTE)) AS VARCHAR(10)) AS oxcttasr_utente,
  TRY_CAST(IFF(RTRIM(OXCTTASR_FUNZIONE) = '', ' ', RTRIM(OXCTTASR_FUNZIONE)) AS VARCHAR(2)) AS oxcttasr_funzione,
  TRY_CAST(OXCTTASR_PROGRESSIVO AS NUMBER(3,0)) AS oxcttasr_progressivo,
  TRY_CAST(ROWID AS NUMBER(38, 0)) AS rowid
from {{ source('source_l0','oxctftasr_m') }}
where dt_osservazione = {{ get_dt_osservazione() }}
