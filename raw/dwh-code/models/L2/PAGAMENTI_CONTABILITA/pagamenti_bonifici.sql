-- Entita' L2: PAGAMENTI_BONIFICI
-- Storicizzazione: S4 (incremental / insert_overwrite) -- confermata dall'utente (catalogo senza S)
-- Main: CCBONWK (cluster A2 -> filtro FL_DELETED)

SELECT
    b.BOW_NUMERO_BONIFICO AS CD_PAGAMENTO,
    b.BOW_PROVENIENZA AS TP_PROCEDURA,
    b.BOW_NUMERO_PRATICA AS CD_PRATICA,
    b.BOW_TIPO AS TP_BONIFICO,
    b.BOW_ORIGINE AS CD_ORIGINE_BONIFICO,
    b.BOW_DESCRIZIONE AS DS_BONIFICO,
    b.BOW_STATO AS CD_STATO,
    b.BOW_TIPO_FORNITORE AS TP_BENEFICIARIO,
    b.BOW_FORNITORE AS CD_BENEFICIARIO,
    b.BOW_CODICE_ABI AS CD_ABI_BENEFICIARIO,
    b.BOW_CODICE_SPORTELLO AS CD_CAB_BENEFICIARIO,
    b.BOW_CONTO_CORRENTE AS CD_CC_BENEFICIARIO,
    b.BOW_BANK_CODE AS CD_BANK_CODE_BENEFICIARIO,
    b.BOW_SUB_NUMBER AS CD_SUB_NUMBER_BENEFICIARIO,
    b.BOW_RAG_SOC_INTEST AS CD_RAGIONE_SOC_INTESTATARIO,
    {{ ole_to_date('b.BOW_DATA_CREAZIONE') }} AS DT_CREAZIONE,
    {{ ole_to_date('b.BOW_DATA_SCADENZA') }} AS DT_SCADENZA,
    {{ ole_to_date('b.BOW_DATA_PRESENTAZIONE') }} AS DT_PRESENTAZIONE,
    {{ custom_to_date('b.BOW_DATA_VALUTA_ACCR') }} AS DT_VALUTA,
    -- WARN: DT_VALUTA_ACCR ha la stessa sorgente di DT_VALUTA (BOW_DATA_VALUTA_ACCR) nel data model
    {{ custom_to_date('b.BOW_DATA_VALUTA_ACCR') }} AS DT_VALUTA_ACCR,
    {{ custom_to_date('b.BOW_DATA_RIENTRO') }} AS DT_RIENTRO,
    {{ custom_to_date('b.BOW_DATA_ESECUZ') }} AS DT_ESECUZIONE,
    -- FIX: data model aveva RT malformata "CAST(OXINREPT_IMPORTO/100 AS NUMBER(13,2) AS BOW_IMPORTO_TOTALE"
    --      (colonna OXINREPT_IMPORTO inesistente in CCBONWK, parentesi non bilanciata, alias errato).
    --      Sostituita con la macro standard EU_ (/100, NUMBER(13,2)) sulla colonna dichiarata BOW_IMPORTO_TOTALE.
    {{ custom_to_decimal('b.BOW_IMPORTO_TOTALE', 13, 2) }} AS EU_IMPORTO,
    -- WARN: EU_COMMISSIONI senza sorgente ne' regola tecnica nel data model -> NULL
    --NULL AS EU_COMMISSIONI, -> aggiornare quando sarà presente il campo sorgente 
    b.BOW_BANCA_ADDEBITO AS CD_BANCA_INTERNA,
    b.BOW_CAUSALE_RIENTRO AS CD_CAUSALE_RIENTRO,
    b.BOW_TIPO_ANOMALIA AS TP_ANOMALIA,
    b.BOW_NUMERO_FATTURA AS CD_NUMERO_FATTURA,
    b.BOW_PRESENTAZIONE AS CD_DISTINTA_PRESENTAZ,
    b.BOW_DISTINTA_ORIG AS CD_DISTINTA_ORIG,
    b.BOW_NUMERO_RATA AS NM_RATA,
    b.BOW_INTEST_PRATICA AS CD_RAGIONE_SOCIALE_CLI_PRATICA,
    b.BOW_PLICO AS CD_PLICO,
    b.BOW_MIR AS CD_MIR,
    b.BOW_COD_RIFERIMENTO AS CD_CRO,
    b.BOW_NOTE AS DS_NOTE,
    -- FIX: RT costruiva il timestamp da BOW_DATA_NOTE + BOW_ORA_NOTE con alias errato (AS CCBONWK).
    --      Sostituita con la macro standard TS_ (due colonne data/ora).
    {{ custom_to_timestamp_ntz('b.BOW_DATA_NOTE', 'b.BOW_ORA_NOTE') }} AS TS_NOTE,
    b.BOW_UTE_NOTE AS CD_UTENTE_NOTE,
    b.BOW_PROGR_PRAT AS PR_PRATICA,
    b.BOW_GROUP_STATUS AS BOW_GROUP_STATUS,
    {{ ole_to_date('b.BOW_DATA_DA') }} AS DT_COMPETENZA_PRV_DA,
    {{ ole_to_date('b.BOW_DATA_AL') }} AS DT_COMPETENZA_PRV_AL
FROM {{ ref('ccbonwk') }} b
WHERE b.FL_DELETED = 'N'
