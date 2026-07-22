-- ============================================================================
-- Entita' L2: ACCETTAZIONE_INPUT_PRAT_PREC  |  SA: SCORING  |  Storicizzazione: S2
-- Sorgente: landing XML CDE (StrategyOneRequest, ProcessCode = 'TARGATO')
-- Grana: per pratica precedente (PK = CD_INQUIRYCODE + TP_PROCEDURA + CD_PRATICA)
-- Tutti i campi business provengono dal nodo ripetuto PRATICHE_PRECEDENTI/Variables sotto
--   Body/Richiesta/Categories. ATTENZIONE: nello xsd i tag di questo nodo sono PREFISSATI
--   con 'PR_' (es. PR_CODICE_PRATICA, PR_NETTO_EROGATO): la REGOLA FUNZIONALE riporta il
--   nome logico SENZA prefisso, quindi si estrae dal tag reale PR_<RF>.
-- Storicizzazione: TS_INSERIMENTO = TS_RIFERIMENTO della L1; incrementale su TS_RIFERIMENTO.
-- ============================================================================

WITH src AS (

    SELECT
        TS_RIFERIMENTO,
        VALUE AS xml_doc
    FROM {{ ref('cde') }}          -- ASSUNZIONE: landing CDE = ref('cde')
    WHERE XMLGET(XMLGET(XMLGET(VALUE, 'StrategyOneRequest'), 'Header'), 'ProcessCode'):"$"::VARCHAR = 'TARGATO'
    {% if is_incremental() %}
      AND TS_RIFERIMENTO > (SELECT COALESCE(MAX(TS_INSERIMENTO), '1900-01-01'::TIMESTAMP_NTZ) FROM {{ this }})
    {% endif %}

),

nodes AS (

    SELECT
        TS_RIFERIMENTO,
        XMLGET(XMLGET(xml_doc, 'StrategyOneRequest'), 'Header')                                          AS n_header,
        XMLGET(XMLGET(XMLGET(XMLGET(xml_doc, 'StrategyOneRequest'), 'Body'), 'Richiesta'), 'Categories') AS n_categories
    FROM src

),

-- Espansione dei nodi ripetuti PRATICHE_PRECEDENTI
pratiche AS (

    SELECT
        n.TS_RIFERIMENTO,
        n.n_header,
        XMLGET(F.value, 'Variables') AS n_pp_var
    FROM nodes n,
    {{ flatten_xml('n_categories', 'PRATICHE_PRECEDENTI', 'F') }}

),

-- 1. ESTRAZIONE
raw AS (

    SELECT
        {{ get_xml_path('n_header', 'InquiryCode', 'VARCHAR') }} AS CD_INQUIRYCODE,
        {{ get_xml_path('n_header', 'ProcessCode', 'VARCHAR') }} AS CD_PROCESSCODE,
        {{ get_xml_path('n_pp_var', 'PR_CODICE_PROCEDURA', 'VARCHAR') }} AS TP_PROCEDURA,
        {{ get_xml_path('n_pp_var', 'PR_CODICE_PRATICA', 'VARCHAR') }} AS CD_PRATICA,
        {{ get_xml_path('n_pp_var', 'PR_IMPORTO_FINANZIATO', 'VARCHAR') }} AS EU_IMPORTO_FINANZIATO_RAW,
        {{ get_xml_path('n_pp_var', 'PR_NETTO_EROGATO', 'VARCHAR') }} AS EU_NETTO_EROGATO_RAW,
        {{ get_xml_path('n_pp_var', 'PR_FIDO', 'VARCHAR') }} AS EU_FIDO_RAW,
        {{ get_xml_path('n_pp_var', 'PR_CODICE_ANAGRAFICA', 'VARCHAR') }} AS CD_ANAGRAFICA_RAW,
        {{ get_xml_path('n_pp_var', 'PR_STATO', 'VARCHAR') }} AS CD_STATO,
        {{ get_xml_path('n_pp_var', 'PR_DATA_ESITO', 'VARCHAR') }} AS DT_ESITO_RAW,
        {{ get_xml_path('n_pp_var', 'PR_DATA_LIQUIDAZIONE', 'VARCHAR') }} AS DT_LIQUIDAZIONE_RAW,
        {{ get_xml_path('n_pp_var', 'PR_BLOCCHI_CARTA', 'VARCHAR') }} AS CD_BLOCCO,
        {{ get_xml_path('n_pp_var', 'PR_DATA_FINE_AMMORTAMENTO', 'VARCHAR') }} AS DT_FINE_AMMORTAMENTO_RAW,
        {{ get_xml_path('n_pp_var', 'PR_MOD_RIMBORSO', 'VARCHAR') }} AS CD_MOD_RIMBORSO,
        {{ get_xml_path('n_pp_var', 'PR_SALDO_TOTALE', 'VARCHAR') }} AS EU_SALDO_TOT_RAW,
        {{ get_xml_path('n_pp_var', 'PR_DATA_INIZIO_AMMORTAMENTO', 'VARCHAR') }} AS DT_INIZIO_AMMORTAMENTO_RAW,
        {{ get_xml_path('n_pp_var', 'PR_TP_RUOLO', 'VARCHAR') }} AS TP_RUOLO,
        {{ get_xml_path('n_pp_var', 'PR_BANCA_DATI', 'VARCHAR') }} AS CD_BANCA_DATI,
        {{ get_xml_path('n_pp_var', 'PR_RISCHIO_RILEVATO', 'VARCHAR') }} AS EU_RISCHIO_RILEVATO_RAW,
        {{ get_xml_path('n_pp_var', 'PR_RISCHIO_ATTRIBUITO', 'VARCHAR') }} AS EU_RISCHIO_ATTRIBUITO_RAW,
        {{ get_xml_path('n_pp_var', 'PR_RATA_RILEVATA', 'VARCHAR') }} AS EU_RATA_RILEVATA_RAW,
        {{ get_xml_path('n_pp_var', 'PR_RATA_ATTRIBUITA', 'VARCHAR') }} AS EU_RATA_ATTRIBUITA_RAW,
        {{ get_xml_path('n_pp_var', 'PR_TP_TRAT_RATA_ATTRIB', 'VARCHAR') }} AS TP_TRAT_RATA_ATTRIB,
        {{ get_xml_path('n_pp_var', 'PR_DATA_CARICAMENTO', 'VARCHAR') }} AS DT_CARICAMENTO_RAW,
        {{ get_xml_path('n_pp_var', 'PR_MOTIVO_OVERRIDE', 'VARCHAR') }} AS CD_MOTIVO_OVERRIDE,
        {{ get_xml_path('n_pp_var', 'PR_ATTRIBUTO', 'VARCHAR') }} AS CD_ATTRIBUTO,
        {{ get_xml_path('n_pp_var', 'PR_EMETTITORE', 'VARCHAR') }} AS CD_EMETTITORE,
        {{ get_xml_path('n_pp_var', 'PR_VENDITA_CONGIUNTA', 'VARCHAR') }} AS FL_TIPO_VENDITA_CONGIUNTA,
        {{ get_xml_path('n_pp_var', 'PR_RETE_VENDITA', 'VARCHAR') }} AS CD_RETE_VENDITA,
        {{ get_xml_path('n_pp_var', 'PR_AGENTE', 'VARCHAR') }} AS CD_AGENTE,
        {{ get_xml_path('n_pp_var', 'PR_SUBAGENTE', 'VARCHAR') }} AS CD_SUBAGENTE,
        {{ get_xml_path('n_pp_var', 'PR_CONVENZIONATO', 'VARCHAR') }} AS CD_CONVENZIONATO,
        {{ get_xml_path('n_pp_var', 'PR_PUNTO_VENDITA', 'VARCHAR') }} AS CD_PUNTO_VENDITA,
        {{ get_xml_path('n_pp_var', 'PR_VENDITORE', 'VARCHAR') }} AS CD_VENDITORE,
        {{ get_xml_path('n_pp_var', 'PR_PRODOTTO', 'VARCHAR') }} AS CD_PRODOTTO,
        {{ get_xml_path('n_pp_var', 'PR_TIPO_PRODOTTO', 'VARCHAR') }} AS TP_PRODOTTO,
        {{ get_xml_path('n_pp_var', 'PR_CANALE', 'VARCHAR') }} AS CD_CANALE,
        {{ get_xml_path('n_pp_var', 'PR_CANALE_WEB', 'VARCHAR') }} AS FL_CANALE_WEB,
        {{ get_xml_path('n_pp_var', 'PR_DESTINAZIONE_FINANZIAMENTO', 'VARCHAR') }} AS CD_DESTINAZIONE_FINANZIAMENTO,
        {{ get_xml_path('n_pp_var', 'PR_CD_TRUFFA', 'VARCHAR') }} AS CD_TRUFFA,
        {{ get_xml_path('n_pp_var', 'PR_STATO_TRUFFA', 'VARCHAR') }} AS CD_STATO_TRUFFA,
        TS_RIFERIMENTO
    FROM pratiche

),

-- 2. CONVERSIONE
conv AS (

    SELECT
        CD_INQUIRYCODE,
        CD_PROCESSCODE,
        TP_PROCEDURA,
        CD_PRATICA,
        TRY_CAST(EU_IMPORTO_FINANZIATO_RAW AS NUMBER(16,2)) AS EU_IMPORTO_FINANZIATO,
        TRY_CAST(EU_NETTO_EROGATO_RAW AS NUMBER(16,2)) AS EU_NETTO_EROGATO,
        TRY_CAST(EU_FIDO_RAW AS NUMBER(16,2)) AS EU_FIDO,
        TRY_CAST(CD_ANAGRAFICA_RAW AS NUMBER(16,0)) AS CD_ANAGRAFICA,
        CD_STATO,
        TRY_TO_DATE(DT_ESITO_RAW) AS DT_ESITO,
        TRY_TO_DATE(DT_LIQUIDAZIONE_RAW) AS DT_LIQUIDAZIONE,
        CD_BLOCCO,
        TRY_TO_DATE(DT_FINE_AMMORTAMENTO_RAW) AS DT_FINE_AMMORTAMENTO,
        CD_MOD_RIMBORSO,
        TRY_CAST(EU_SALDO_TOT_RAW AS NUMBER(16,2)) AS EU_SALDO_TOT,
        TRY_TO_DATE(DT_INIZIO_AMMORTAMENTO_RAW) AS DT_INIZIO_AMMORTAMENTO,
        TP_RUOLO,
        CD_BANCA_DATI,
        TRY_CAST(EU_RISCHIO_RILEVATO_RAW AS NUMBER(16,2)) AS EU_RISCHIO_RILEVATO,
        TRY_CAST(EU_RISCHIO_ATTRIBUITO_RAW AS NUMBER(16,2)) AS EU_RISCHIO_ATTRIBUITO,
        TRY_CAST(EU_RATA_RILEVATA_RAW AS NUMBER(16,2)) AS EU_RATA_RILEVATA,
        TRY_CAST(EU_RATA_ATTRIBUITA_RAW AS NUMBER(16,2)) AS EU_RATA_ATTRIBUITA,
        TP_TRAT_RATA_ATTRIB,
        TRY_TO_DATE(DT_CARICAMENTO_RAW) AS DT_CARICAMENTO,
        CD_MOTIVO_OVERRIDE,
        CD_ATTRIBUTO,
        CD_EMETTITORE,
        FL_TIPO_VENDITA_CONGIUNTA,
        CD_RETE_VENDITA,
        CD_AGENTE,
        CD_SUBAGENTE,
        CD_CONVENZIONATO,
        CD_PUNTO_VENDITA,
        CD_VENDITORE,
        CD_PRODOTTO,
        TP_PRODOTTO,
        CD_CANALE,
        FL_CANALE_WEB,
        CD_DESTINAZIONE_FINANZIAMENTO,
        CD_TRUFFA,
        CD_STATO_TRUFFA,
        TS_RIFERIMENTO AS TS_INSERIMENTO
    FROM raw

)
SELECT
    CD_INQUIRYCODE,
    TP_PROCEDURA,
    CD_PRATICA,
    TS_INSERIMENTO,
    CD_PROCESSCODE,
    EU_IMPORTO_FINANZIATO,
    EU_NETTO_EROGATO,
    EU_FIDO,
    CD_ANAGRAFICA,
    CD_STATO,
    DT_ESITO,
    DT_LIQUIDAZIONE,
    CD_BLOCCO,
    DT_FINE_AMMORTAMENTO,
    CD_MOD_RIMBORSO,
    EU_SALDO_TOT,
    DT_INIZIO_AMMORTAMENTO,
    TP_RUOLO,
    CD_BANCA_DATI,
    EU_RISCHIO_RILEVATO,
    EU_RISCHIO_ATTRIBUITO,
    EU_RATA_RILEVATA,
    EU_RATA_ATTRIBUITA,
    TP_TRAT_RATA_ATTRIB,
    DT_CARICAMENTO,
    CD_MOTIVO_OVERRIDE,
    CD_ATTRIBUTO,
    CD_EMETTITORE,
    FL_TIPO_VENDITA_CONGIUNTA,
    CD_RETE_VENDITA,
    CD_AGENTE,
    CD_SUBAGENTE,
    CD_CONVENZIONATO,
    CD_PUNTO_VENDITA,
    CD_VENDITORE,
    CD_PRODOTTO,
    TP_PRODOTTO,
    CD_CANALE,
    FL_CANALE_WEB,
    CD_DESTINAZIONE_FINANZIAMENTO,
    CD_TRUFFA,
    CD_STATO_TRUFFA
FROM conv