select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  TRY_CAST(CODICE_BANCA_DATI_PK AS VARCHAR(2)) AS codice_banca_dati_pk,
  TRY_CAST(DESCRIZIONE_BANCA_DATI AS VARCHAR(30)) AS descrizione_banca_dati,
  TRY_CAST(NUMERO_SEQUENZA_VISUALIZZAZIONE AS NUMBER(38, 0)) AS numero_sequenza_visualizzazione,
  TRY_CAST(INDICATORE_GESTIONE AS VARCHAR(1)) AS indicatore_gestione,
  TRY_CAST(INDICATORE_GESTIONE_BLOCCO AS VARCHAR(1)) AS indicatore_gestione_blocco,
  TRY_CAST(INDICATORE_GESTIONE_SBLOCCO AS VARCHAR(1)) AS indicatore_gestione_sblocco,
  TRY_CAST(ID_CONFIGURAZIONE_BLOCCO_FK AS NUMBER(38, 0)) AS id_configurazione_blocco_fk,
  TRY_CAST(ID_CONFIGURAZIONE_SBLOCCO_FK AS NUMBER(38, 0)) AS id_configurazione_sblocco_fk,
  TRY_CAST(CODICE_UTENTE_CREAZIONE AS VARCHAR(255)) AS codice_utente_creazione,
  TRY_CAST(TIMESTAMP_CREAZIONE AS TIMESTAMP_NTZ) AS timestamp_creazione,
  TRY_CAST(CODICE_UTENTE_MODIFICA AS VARCHAR(255)) AS codice_utente_modifica,
  TRY_CAST(TIMESTAMP_MODIFICA AS TIMESTAMP_NTZ) AS timestamp_modifica
from {{ source('source_l0','configurazione_banca_dati') }}
