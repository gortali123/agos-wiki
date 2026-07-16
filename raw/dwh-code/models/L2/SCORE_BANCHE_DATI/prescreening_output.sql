-- ============================================================================
-- Entita' L2: PRESCREENING_OUTPUT   |  Subject Area: SCORING  |  Storicizzazione: S2
-- Sorgente: landing XML CDE (payload StrategyOneResponse, ProcessCode = 'PRESCREENING')
-- Grana: per richiesta (PK = CD_INQUIRYCODE)
-- NOTA storicizzazione: TS_INSERIMENTO valorizzato da TS_RIFERIMENTO della L1 (CDE),
--   e strategia incrementale append filtrata sullo stesso TS_RIFERIMENTO.
-- ============================================================================

WITH src AS (

    SELECT
        TS_RIFERIMENTO,
        VALUE AS xml_doc
    FROM {{ ref('cde') }}          -- ASSUNZIONE: modello landing CDE = ref('cde'); VALIDARE nome reale
    WHERE XMLGET(XMLGET(XMLGET(VALUE, 'StrategyOneResponse'), 'Header'), 'ProcessCode'):"$"::VARCHAR = 'PRESCREENING'
    {% if is_incremental() %}
      AND TS_RIFERIMENTO > (SELECT COALESCE(MAX(TS_INSERIMENTO), '1900-01-01'::TIMESTAMP_NTZ) FROM {{ this }})
    {% endif %}

),

nodes AS (

    SELECT
        TS_RIFERIMENTO,
        XMLGET(XMLGET(xml_doc, 'StrategyOneResponse'), 'Header')                                          AS n_header,
        XMLGET(XMLGET(XMLGET(XMLGET(xml_doc, 'StrategyOneResponse'), 'Body'), 'Richiesta'), 'Variables')  AS n_req_var
    FROM src

),

-- 1. ESTRAZIONE: tutti i campi in VARCHAR
raw AS (

    SELECT
        TS_RIFERIMENTO,
        {{ get_xml_path('n_header', 'InquiryCode', 'VARCHAR') }}            AS CD_INQUIRYCODE,
        {{ get_xml_path('n_header', 'ProcessCode', 'VARCHAR') }}            AS CD_PROCESSCODE,
        {{ get_xml_path('n_header', 'ProcessVersion', 'VARCHAR') }}         AS CD_PROCESSVERSION_RAW,
        {{ get_xml_path('n_header', 'LayoutVersion', 'VARCHAR') }}          AS CD_LAYOUTVERSION_RAW,
        {{ get_xml_path('n_req_var', 'CODICE_INTERROGAZIONE', 'VARCHAR') }} AS CD_INTERROGAZIONE_RAW,
        {{ get_xml_path('n_req_var', 'DATA_RICHIESTA', 'VARCHAR') }}        AS DT_RICHIESTA_RAW,
        {{ get_xml_path('n_req_var', 'CODICE_PROCEDURA', 'VARCHAR') }}      AS CD_PROCEDURA,
        {{ get_xml_path('n_req_var', 'CODICE_PRATICA', 'VARCHAR') }}        AS CD_PRATICA_RAW,
        {{ get_xml_path('n_req_var', 'ESITO_CHIAMATA', 'VARCHAR') }}        AS CD_ESITO_CHIAMATA,
        {{ get_xml_path('n_req_var', 'ESITO_CODICE', 'VARCHAR') }}          AS CD_ESITO,
        {{ get_xml_path('n_req_var', 'ESITO_DESCRIZIONE', 'VARCHAR') }}     AS DS_ESITO,
        {{ get_xml_path('n_req_var', 'ESITO_MESSAGGIO', 'VARCHAR') }}       AS DS_ESITO_MESSAGGIO,
        {{ get_xml_path('n_req_var', 'POTEREFIRMA', 'VARCHAR') }}           AS CD_POTERE_FIRMA
    FROM nodes

),

-- 2. CONVERSIONE
conv AS (

    SELECT
        CD_INQUIRYCODE,
        CD_PROCESSCODE,
        TRY_CAST(CD_PROCESSVERSION_RAW AS NUMBER(38,0))    AS CD_PROCESSVERSION,
        TRY_CAST(CD_LAYOUTVERSION_RAW AS NUMBER(38,0))     AS CD_LAYOUTVERSION,
        TRY_CAST(CD_INTERROGAZIONE_RAW AS NUMBER(16,0))    AS CD_INTERROGAZIONE,
        TRY_TO_DATE(DT_RICHIESTA_RAW)                      AS DT_RICHIESTA,
        CD_PROCEDURA,
        TRY_CAST(CD_PRATICA_RAW AS NUMBER(16,0))           AS CD_PRATICA,
        CD_ESITO_CHIAMATA,
        CD_ESITO,
        DS_ESITO,
        DS_ESITO_MESSAGGIO,
        CD_POTERE_FIRMA,
        TS_RIFERIMENTO AS TS_INSERIMENTO
    FROM raw

)

SELECT
    -- PK
    CD_INQUIRYCODE,
    -- campo tecnico di storicizzazione (S2)
    TS_INSERIMENTO,
    -- business
    CD_PROCESSCODE,
    CD_PROCESSVERSION,
    CD_LAYOUTVERSION,
    CD_INTERROGAZIONE,
    DT_RICHIESTA,
    CD_PROCEDURA,
    CD_PRATICA,
    CD_ESITO_CHIAMATA,
    CD_ESITO,
    DS_ESITO,
    DS_ESITO_MESSAGGIO,
    CD_POTERE_FIRMA
FROM conv