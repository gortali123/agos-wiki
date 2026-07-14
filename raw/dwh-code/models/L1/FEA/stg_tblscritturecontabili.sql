select
  TRY_CAST(ts_riferimento AS TIMESTAMP_NTZ) as ts_riferimento,
  TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) as ts_caricamento,
  COALESCE(TRY_CAST(data_modifica AS TIMESTAMP_NTZ), TRY_CAST(data_creazione AS TIMESTAMP_NTZ)) AS ts_coalesce_modif_creaz, --TRYCAST prima della COALESCE altrimenti non funziona correttamente
  TRY_CAST(idScritturaContabile AS NUMBER(11,0)) AS idscritturacontabile,
  TRY_CAST(codice_societa AS VARCHAR(4)) AS codice_societa,
  TRY_CAST(tipo_documento AS VARCHAR(2)) AS tipo_documento,
  TRY_CAST(data_registrazione_contabile AS DATE) AS data_registrazione_contabile,
  TRY_CAST(periodo_contabile AS VARCHAR(2)) AS periodo_contabile,
  TRY_CAST(numero_documento_sap AS VARCHAR(10)) AS numero_documento_sap,
  TRY_CAST(valuta_contabilizzazione AS VARCHAR(5)) AS valuta_contabilizzazione,
  TRY_CAST(segno_contabile AS VARCHAR(2)) AS segno_contabile,
  TRY_CAST(conto_co_ge AS VARCHAR(17)) AS conto_co_ge,
  TRY_CAST(importo_movimento AS NUMBER(38,10)) AS importo_movimento,
  TRY_CAST(data_valuta AS DATE) AS data_valuta,
  TRY_CAST(testo_riga_dettaglio AS VARCHAR(50)) AS testo_riga_dettaglio,
  TRY_CAST(codice_causale_contabile AS VARCHAR(20)) AS codice_causale_contabile,
  TRY_CAST(attribuzione_sap AS VARCHAR(18)) AS attribuzione_sap,
  TRY_CAST(chiave_riferimento_1 AS VARCHAR(12)) AS chiave_riferimento_1,
  TRY_CAST(chiave_riferimento_2 AS VARCHAR(12)) AS chiave_riferimento_2,
  TRY_CAST(data_creazione_flusso AS DATE) AS data_creazione_flusso,
  TRY_CAST(data_creazione AS DATE) AS data_creazione,
  TRY_CAST(data_modifica AS DATE) AS data_modifica
from {{ source('source_l0','tblscritturecontabili') }}
