-- ============================================================================
-- Entita' L2: PRESCREENING_OUTPUT_PR  |  Subject Area: SCORING  |  Storicizzazione: S2
-- Sorgente: landing XML CDE (payload StrategyOneResponse, ProcessCode = 'PRESCREENING')
-- Grana: per Policy Rule di soggetto (PK = CD_INQUIRYCODE + CD_RUOLO + CD_POLICY)
--
-- CASO "lista mista di tag fratelli": sotto Categories i tag <Applicant> e <POLICY_RULES>
--   sono fratelli e NON annidati. Ogni POLICY_RULES si riferisce all'ultimo Applicant
--   (=> RUOLO) visto prima di esso. Si usa quindi un FLATTEN grezzo (senza filtro di tag)
--   per preservare INDEX e "@", poi LAST_VALUE(... RUOLO ...) IGNORE NULLS per portare
--   avanti l'ultimo RUOLO fino al POLICY_RULES che lo consuma.
--   ASSUNZIONE da validare su payload reale: associazione "ultimo Applicant visto".
--
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

roots AS (

    SELECT
        TS_RIFERIMENTO,
        XMLGET(XMLGET(xml_doc, 'StrategyOneResponse'), 'Header')                                          AS n_header,
        XMLGET(XMLGET(XMLGET(XMLGET(xml_doc, 'StrategyOneResponse'), 'Body'), 'Richiesta'), 'Categories') AS n_categories
    FROM src

),

nodes AS (

    SELECT
        TS_RIFERIMENTO,
        {{ get_xml_path('n_header', 'InquiryCode', 'VARCHAR') }} AS CD_INQUIRYCODE,
        {{ get_xml_path('n_header', 'ProcessCode', 'VARCHAR') }} AS CD_PROCESSCODE,
        n_categories
    FROM roots

),

-- FLATTEN grezzo (nessun filtro di tag) per preservare l'ordine (INDEX) e il nome tag ("@")
categories_flat AS (

    SELECT
        CD_INQUIRYCODE,
        CD_PROCESSCODE,
        TS_RIFERIMENTO,
        F.INDEX               AS CAT_INDEX,
        F.VALUE:"@"::VARCHAR  AS CAT_TAG,
        F.VALUE               AS CAT_NODE
    FROM nodes,
    LATERAL FLATTEN(input => n_categories:"$", OUTER => TRUE) AS F

),

-- Porta avanti l'ultimo RUOLO (dal tag Applicant) fino al POLICY_RULES che lo consuma
categories_with_ruolo AS (

    SELECT
        CD_INQUIRYCODE,
        CD_PROCESSCODE,
        TS_RIFERIMENTO,
        CAT_INDEX,
        CAT_TAG,
        CAT_NODE,
        LAST_VALUE(
            CASE WHEN CAT_TAG = 'Applicant'
                THEN {{ get_xml_path('CAT_NODE', 'Variables/RUOLO', 'VARCHAR') }}
            END
        ) IGNORE NULLS OVER (
            PARTITION BY CD_INQUIRYCODE ORDER BY CAT_INDEX
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS CD_RUOLO
    FROM categories_flat

),

-- 1. ESTRAZIONE: solo i nodi POLICY_RULES; campi in VARCHAR
raw AS (

    SELECT
        CD_INQUIRYCODE,
        CD_RUOLO,
        CD_PROCESSCODE,
        TS_RIFERIMENTO,
        {{ get_xml_path('CAT_NODE', 'Variables/POLICY_CODICE', 'VARCHAR') }}      AS CD_POLICY,
        {{ get_xml_path('CAT_NODE', 'Variables/POLICY_DESCRIZIONE', 'VARCHAR') }} AS DS_POLICY_RAW,
        {{ get_xml_path('CAT_NODE', 'Variables/POLICY_ESITO', 'VARCHAR') }}       AS CD_POLICY_ESITO,
        {{ get_xml_path('CAT_NODE', 'Variables/POLICY_FIRMA', 'VARCHAR') }}       AS CD_POLICY_FIRMA,
        {{ get_xml_path('CAT_NODE', 'Variables/POLICY_MESSAGGIO', 'VARCHAR') }}   AS DS_POLICY_MESSAGGIO
    FROM categories_with_ruolo
    WHERE CAT_TAG = 'POLICY_RULES'

),

-- 2. CONVERSIONE
conv AS (

    SELECT
        CD_INQUIRYCODE,
        CD_RUOLO,
        CD_POLICY,
        -- WARN: DS_POLICY ha TIPO NUMBER nel data model ma la RF (POLICY_DESCRIZIONE) e' una descrizione testuale;
        --       tipizzato NUMBER come da data model, ma verificare (probabile refuso: dovrebbe essere VARCHAR).
        TRY_CAST(DS_POLICY_RAW AS NUMBER(38,0)) AS DS_POLICY,
        CD_POLICY_ESITO,
        CD_POLICY_FIRMA,
        DS_POLICY_MESSAGGIO,
        CD_PROCESSCODE,
        TS_RIFERIMENTO AS TS_INSERIMENTO
    FROM raw

)

SELECT
    -- PK
    CD_INQUIRYCODE,
    CD_RUOLO,
    CD_POLICY,
    -- campo tecnico di storicizzazione (S2)
    TS_INSERIMENTO,
    -- business
    DS_POLICY,
    CD_POLICY_ESITO,
    CD_POLICY_FIRMA,
    DS_POLICY_MESSAGGIO
FROM conv