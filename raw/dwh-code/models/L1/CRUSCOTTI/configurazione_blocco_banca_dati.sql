select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  TRY_CAST(ID_CONFIGURAZIONE_BLOCCO_PK AS NUMBER(38, 0)) AS id_configurazione_blocco_pk,
  TRY_CAST(CODICE_BANCA_DATI AS VARCHAR(2)) AS codice_banca_dati,
  TRY_CAST(INDICATORE_BLOCCO_AUTO AS VARCHAR(1)) AS indicatore_blocco_auto,
  TRY_CAST(NUMERO_MINUTI AS NUMBER(38, 0)) AS numero_minuti,
  TRY_CAST(NUMERO_MAX_RICHIESTE_ERRORE AS NUMBER(38, 0)) AS numero_max_richieste_errore,
  TRY_CAST(NUMERO_MAX_RICHIESTE_ATTIVE AS NUMBER(38, 0)) AS numero_max_richieste_attive,
  TRY_CAST(DENOMINAZIONE_EMAIL_ALERT AS VARCHAR(255)) AS denominazione_email_alert,
  TRY_CAST(CODICE_UTENTE_CREAZIONE AS VARCHAR(255)) AS codice_utente_creazione,
  TRY_CAST(TIMESTAMP_CREAZIONE AS TIMESTAMP_NTZ) AS timestamp_creazione
from {{ source('source_l0','configurazione_blocco_banca_dati') }}
