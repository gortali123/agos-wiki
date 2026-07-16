-- ============================================================================
-- Entita' L2: ACCETTAZIONE_OUTPUT  |  SA: SCORING  |  Storicizzazione: S2
-- Sorgente: landing XML CDE (payload StrategyOneResponse, ProcessCode = 'TARGATO')
-- Grana: per Applicant (PK = CD_INQUIRYCODE + CD_RUOLO)
-- Livelli: Header (InquiryCode/ProcessCode/ProcessVersion/LayoutVersion),
--   Body/Richiesta/Variables (livello pratica, REQ),
--   Categories/APPLICANT/Variables (livello soggetto, APP, incl. RUOLO).
-- Storicizzazione: TS_INSERIMENTO = TS_RIFERIMENTO della L1; incrementale su TS_RIFERIMENTO.
-- ============================================================================

WITH src AS (

    SELECT
        TS_RIFERIMENTO,
        VALUE AS xml_doc
    FROM {{ ref('cde') }}          -- ASSUNZIONE: landing CDE = ref('cde')
    WHERE XMLGET(XMLGET(XMLGET(VALUE, 'StrategyOneResponse'), 'Header'), 'ProcessCode'):"$"::VARCHAR = 'TARGATO'
    {% if is_incremental() %}
      AND TS_RIFERIMENTO > (SELECT COALESCE(MAX(TS_INSERIMENTO), '1900-01-01'::TIMESTAMP_NTZ) FROM {{ this }})
    {% endif %}

),

nodes AS (

    SELECT
        TS_RIFERIMENTO,
        xml_doc,
        XMLGET(XMLGET(xml_doc, 'StrategyOneResponse'), 'Header')                                          AS n_header,
        XMLGET(XMLGET(XMLGET(XMLGET(xml_doc, 'StrategyOneResponse'), 'Body'), 'Richiesta'), 'Variables')  AS n_req_var,
        XMLGET(XMLGET(XMLGET(XMLGET(xml_doc, 'StrategyOneResponse'), 'Body'), 'Richiesta'), 'Categories') AS n_categories
    FROM src

),

applicant AS (

    SELECT
        n.TS_RIFERIMENTO,
        n.n_header,
        n.n_req_var,
        XMLGET(F.value, 'Variables') AS n_app_var
    FROM nodes n,
    {{ flatten_xml('n_categories', 'APPLICANT', 'F') }}

),

-- 1. ESTRAZIONE
raw AS (

    SELECT
        {{ get_xml_path('n_header', 'InquiryCode', 'VARCHAR') }} AS CD_INQUIRYCODE,
        {{ get_xml_path('n_app_var', 'RUOLO', 'VARCHAR') }} AS CD_RUOLO,
        {{ get_xml_path('n_header', 'ProcessCode', 'VARCHAR') }} AS CD_PROCESSCODE,
        {{ get_xml_path('n_header', 'ProcessVersion', 'VARCHAR') }} AS CD_PROCESSVERSION,
        {{ get_xml_path('n_header', 'LayoutVersion', 'VARCHAR') }} AS CD_LAYOUTVERSION,
        {{ get_xml_path('n_req_var', 'CODICE_INTERROGAZIONE', 'VARCHAR') }} AS CD_INTERROGAZIONE,
        {{ get_xml_path('n_req_var', 'DATA_RICHIESTA', 'VARCHAR') }} AS DT_RICHIESTA_RAW,
        {{ get_xml_path('n_req_var', 'CODICE_PRATICA', 'VARCHAR') }} AS CD_PRATICA,
        {{ get_xml_path('n_req_var', 'DECISIONE_FINALE', 'VARCHAR') }} AS CD_DECISIONE_FINALE,
        {{ get_xml_path('n_req_var', 'RATA_MAX_SOSTENIBILE', 'VARCHAR') }} AS EU_RATA_MAX_SOSTENIBILE_RAW,
        {{ get_xml_path('n_req_var', 'CONTESTO', 'VARCHAR') }} AS CD_CONTESTO,
        NULL AS CD_OPERATION,  -- WARN: RF=CD_OPERATION non presente nel tracciato Response (trovato solo in RequestRichiestaType),
        {{ get_xml_path('n_app_var', 'CODICE_ANAGRAFICA', 'VARCHAR') }} AS CD_ANAGRAFICA_RAW,
        {{ get_xml_path('n_req_var', 'DBR_PERC_INDEBITAMENTO_PRATICA', 'VARCHAR') }} AS PC_DBR_PERC_INDEBITAMENTO_PRATICA_RAW,
        {{ get_xml_path('n_req_var', 'DBR_TOT_ENTRATE_PRATICA', 'VARCHAR') }} AS EU_DBR_TOT_ENTRATE_PRATICA_RAW,
        {{ get_xml_path('n_req_var', 'DBR_TOT_USCITE_PRATICA', 'VARCHAR') }} AS EU_DBR_TOT_USCITE_PRATICA_RAW,
        {{ get_xml_path('n_req_var', 'DBR_RATA_PRATICA', 'VARCHAR') }} AS EU_DBR_RATA_PRATICA_RAW,
        {{ get_xml_path('n_req_var', 'POTEREFIRMA', 'VARCHAR') }} AS CD_POTERE_FIRMA,
        {{ get_xml_path('n_req_var', 'SCIPAFI_TIPO', 'VARCHAR') }} AS TP_SCIPAFI_TIPO,
        {{ get_xml_path('n_req_var', 'IN_ORARIO_SERVIZIO', 'VARCHAR') }} AS FL_IN_ORARIO_SERVIZIO,
        {{ get_xml_path('n_req_var', 'MESSAGGIO', 'VARCHAR') }} AS DS_MESSAGGIO,
        {{ get_xml_path('n_app_var', 'ETA_CLIENTE_TERMINE_FINANZIAMENTO', 'VARCHAR') }} AS NM_ETA_CLIENTE_TERMINE_FINANZIAMENTO_RAW,
        {{ get_xml_path('n_app_var', 'ETA', 'VARCHAR') }} AS NM_ETA_RAW,
        {{ get_xml_path('n_app_var', 'ANZIANITA_LAVORATIVA', 'VARCHAR') }} AS NM_ANZIANITA_LAVORATIVA_RAW,
        {{ get_xml_path('n_req_var', 'ESITO', 'VARCHAR') }} AS CD_ESITO,
        {{ get_xml_path('n_req_var', 'FASCIA_RBP', 'VARCHAR') }} AS CD_FASCIA_RBP,
        {{ get_xml_path('n_req_var', 'PERMETTI_VENDITA_CONGIUNTA', 'VARCHAR') }} AS FL_PERMETTI_VENDITA_CONGIUNTA,
        {{ get_xml_path('n_req_var', 'FIDO_MASSIMO_SCORING', 'VARCHAR') }} AS EU_FIDO_MASSIMO_SCORING_RAW,
        {{ get_xml_path('n_req_var', 'CD_VALUTAZIONE_PRT', 'VARCHAR') }} AS CD_VALUTAZIONE_PRT,
        TS_RIFERIMENTO
    FROM applicant

),

-- 2. CONVERSIONE
conv AS (

    SELECT
        CD_INQUIRYCODE,
        CD_RUOLO,
        CD_PROCESSCODE,
        CD_PROCESSVERSION,
        CD_LAYOUTVERSION,
        CD_INTERROGAZIONE,
        TRY_TO_DATE(DT_RICHIESTA_RAW) AS DT_RICHIESTA,
        CD_PRATICA,
        CD_DECISIONE_FINALE,
        TRY_CAST(EU_RATA_MAX_SOSTENIBILE_RAW AS NUMBER(16,2)) / 100 AS EU_RATA_MAX_SOSTENIBILE,
        CD_CONTESTO,
        CD_OPERATION,
        TRY_CAST(CD_ANAGRAFICA_RAW AS NUMBER(16,0)) AS CD_ANAGRAFICA,
        TRY_CAST(PC_DBR_PERC_INDEBITAMENTO_PRATICA_RAW AS NUMBER(16,0)) AS PC_DBR_PERC_INDEBITAMENTO_PRATICA,
        TRY_CAST(EU_DBR_TOT_ENTRATE_PRATICA_RAW AS NUMBER(16,2)) / 100 AS EU_DBR_TOT_ENTRATE_PRATICA,
        TRY_CAST(EU_DBR_TOT_USCITE_PRATICA_RAW AS NUMBER(16,2)) / 100 AS EU_DBR_TOT_USCITE_PRATICA,
        TRY_CAST(EU_DBR_RATA_PRATICA_RAW AS NUMBER(16,2)) / 100 AS EU_DBR_RATA_PRATICA,
        CD_POTERE_FIRMA,
        TP_SCIPAFI_TIPO,
        FL_IN_ORARIO_SERVIZIO,
        DS_MESSAGGIO,
        TRY_CAST(NM_ETA_CLIENTE_TERMINE_FINANZIAMENTO_RAW AS NUMBER(16,0)) AS NM_ETA_CLIENTE_TERMINE_FINANZIAMENTO,
        TRY_CAST(NM_ETA_RAW AS NUMBER(16,0)) AS NM_ETA,
        TRY_CAST(NM_ANZIANITA_LAVORATIVA_RAW AS NUMBER(16,0)) AS NM_ANZIANITA_LAVORATIVA,
        CD_ESITO,
        CD_FASCIA_RBP,
        FL_PERMETTI_VENDITA_CONGIUNTA,
        TRY_CAST(EU_FIDO_MASSIMO_SCORING_RAW AS NUMBER(16,2)) / 100 AS EU_FIDO_MASSIMO_SCORING,
        CD_VALUTAZIONE_PRT,
        TS_RIFERIMENTO AS TS_INSERIMENTO
    FROM raw

)
SELECT
    CD_INQUIRYCODE,
    CD_RUOLO,
    TS_INSERIMENTO,
    CD_PROCESSCODE,
    CD_PROCESSVERSION,
    CD_LAYOUTVERSION,
    CD_INTERROGAZIONE,
    DT_RICHIESTA,
    CD_PRATICA,
    CD_DECISIONE_FINALE,
    EU_RATA_MAX_SOSTENIBILE,
    CD_CONTESTO,
    CD_OPERATION,
    CD_ANAGRAFICA,
    PC_DBR_PERC_INDEBITAMENTO_PRATICA,
    EU_DBR_TOT_ENTRATE_PRATICA,
    EU_DBR_TOT_USCITE_PRATICA,
    EU_DBR_RATA_PRATICA,
    CD_POTERE_FIRMA,
    TP_SCIPAFI_TIPO,
    FL_IN_ORARIO_SERVIZIO,
    DS_MESSAGGIO,
    NM_ETA_CLIENTE_TERMINE_FINANZIAMENTO,
    NM_ETA,
    NM_ANZIANITA_LAVORATIVA,
    CD_ESITO,
    CD_FASCIA_RBP,
    FL_PERMETTI_VENDITA_CONGIUNTA,
    EU_FIDO_MASSIMO_SCORING,
    CD_VALUTAZIONE_PRT
FROM conv