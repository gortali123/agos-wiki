select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  TRY_CAST(ID_CONFIGURAZIONE_SBLOCCO_PK AS NUMBER(38, 0)) AS id_configurazione_sblocco_pk,
  TRY_CAST(CODICE_BANCA_DATI AS VARCHAR(2)) AS codice_banca_dati,
  TRY_CAST(INDICATORE_SBLOCCO_AUTOMATICO AS VARCHAR(1)) AS indicatore_sblocco_automatico,
  TRY_CAST(NUMERO_MAX_RICHIESTE_SBLOCCO AS NUMBER(38, 0)) AS numero_max_richieste_sblocco,
  TRY_CAST(NUMERO_MAX_MINUTI_SBLOCCO AS NUMBER(38, 0)) AS numero_max_minuti_sblocco,
  TRY_CAST(DENOMINAZIONE_EMAIL_ALERT AS VARCHAR(255)) AS denominazione_email_alert,
  TRY_CAST(CODICE_UTENTE_CREAZIONE AS VARCHAR(255)) AS codice_utente_creazione,
  TRY_CAST(TIMESTAMP_CREAZIONE AS TIMESTAMP_NTZ) AS timestamp_creazione
from {{ source('source_l0','configurazione_sblocco_banca_dati') }}
