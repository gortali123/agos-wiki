select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  sys_change_operation,
  TRY_CAST(lastmodifieddata AS TIMESTAMP_NTZ) as lastmodifieddata,
  {{ compute_dt_osservazione('ts_riferimento') }} as dt_osservazione,
  TRY_CAST(IFF(RTRIM(OXCTFBT_PROCEDURA) = '', ' ', RTRIM(OXCTFBT_PROCEDURA)) AS VARCHAR(2)) AS oxctfbt_procedura,
  TRY_CAST(OXCTFBT_NUM_PRATICA AS NUMBER(12,0)) AS oxctfbt_num_pratica,
  TRY_CAST(OXCTFBT_PROGRESSIVO AS NUMBER(5,0)) AS oxctfbt_progressivo,
  TRY_CAST(OXCTFBT_DATA_INGRESSO AS NUMBER(8,0)) AS oxctfbt_data_ingresso,
  TRY_CAST(IFF(RTRIM(OXCTFBT_STATO_INGRESSO) = '', ' ', RTRIM(OXCTFBT_STATO_INGRESSO)) AS VARCHAR(3)) AS oxctfbt_stato_ingresso,
  TRY_CAST(OXCTFBT_SALDO_INGRESSO AS NUMBER(13,0)) AS oxctfbt_saldo_ingresso,
  TRY_CAST(OXCTFBT_DATA_USCITA AS NUMBER(8,0)) AS oxctfbt_data_uscita,
  TRY_CAST(OXCTFBT_DATA_ANNULLO AS NUMBER(8,0)) AS oxctfbt_data_annullo,
  TRY_CAST(IFF(RTRIM(OXCTFBT_UTENTE_ANNULLO) = '', ' ', RTRIM(OXCTFBT_UTENTE_ANNULLO)) AS VARCHAR(10)) AS oxctfbt_utente_annullo,
  TRY_CAST(OXCTFBT_PROGR_ATTIVO AS NUMBER(5,0)) AS oxctfbt_progr_attivo,
  TRY_CAST(OXCTFBT_SALDO_PERFORM AS NUMBER(13,0)) AS oxctfbt_saldo_perform,
  TRY_CAST(OXCTFBT_CLIENTE AS NUMBER(9,0)) AS oxctfbt_cliente,
  TRY_CAST(IFF(RTRIM(OXCTFBT_CATEGORIA) = '', ' ', RTRIM(OXCTFBT_CATEGORIA)) AS VARCHAR(2)) AS oxctfbt_categoria,
  TRY_CAST(IFF(RTRIM(OXCTFBT_MOTIVO_INGRESSO) = '', ' ', RTRIM(OXCTFBT_MOTIVO_INGRESSO)) AS VARCHAR(3)) AS oxctfbt_motivo_ingresso,
  TRY_CAST(ROWID AS NUMBER(38, 0)) AS rowid
from {{ source('source_l0','oxctffbt_m') }}
where dt_osservazione = {{ get_dt_osservazione() }}
