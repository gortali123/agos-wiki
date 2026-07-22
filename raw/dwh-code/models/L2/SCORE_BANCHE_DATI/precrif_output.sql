-- Modello L2 SCORING.PRECRIF_OUTPUT
-- Sorgente: landing XML CDE (StrategyOneResponse), ProcessCode = 'PRECRIF'.
-- Storicizzazione: S2 (incremental / append). Grana per soggetto: PK = (CD_INQUIRYCODE, CD_RUOLO).
--   -> Header + Richiesta/Variables (PRECRIF_S_*, ESITO_*) sono comuni al documento;
--      i campi per soggetto (PRECRIF_M_*, CALL_*) vengono dal FLATTEN degli Applicant.
--   NOTA: RUOLO non e' tra i tag di ResponseApplicant/Variables in questo xsd. Si assume
--         che l'ordine/associazione degli Applicant in risposta segua quello della richiesta;
--         qui RUOLO NON e' estraibile dal payload di risposta -> vedi WARN su CD_RUOLO.
-- ASSUNZIONE landing: modello dbt = ref('cde'), colonna VALUE gia' variant (nessun PARSE_XML).
-- ASSUNZIONE ProcessCode filtro = 'PRECRIF' (da Regola Tecnica Perimetro del Catalogo Entita').
--   Lo xsd dichiara Header/ProcessCode fixed="PRECRIFX": verificare su payload reale.
-- NOTA S2: data model senza TS_INSERIMENTO / LASTMODIFIEDDATA; landing CDE senza LASTMODIFIEDDATA.
--   TS_INSERIMENTO -> CURRENT_TIMESTAMP() (WARN); riconciliare il blocco incrementale S2
--   con code-generator-l2 / referente prima della produzione.

WITH src AS (

    SELECT
        TS_RIFERIMENTO,
        VALUE AS xml_doc
    FROM {{ ref('cde') }}          -- ASSUNZIONE: modello landing = ref('cde'); VALIDARE nome reale
    WHERE XMLGET(XMLGET(XMLGET(VALUE, 'StrategyOneResponse'), 'Header'), 'ProcessCode'):"$"::VARCHAR = 'PRECRIF'
    {% if is_incremental() %}
      AND TS_RIFERIMENTO > (SELECT COALESCE(MAX(TS_INSERIMENTO), '1900-01-01'::TIMESTAMP_NTZ) FROM {{ this }})
    {% endif %}

),

-- Nodi intermedi riusati: root StrategyOneResponse, poi Body/Richiesta.
nodes AS (

    SELECT
        TS_RIFERIMENTO,
        XMLGET(XMLGET(xml_doc, 'StrategyOneResponse'), 'Header')                                          AS n_header,
        XMLGET(XMLGET(XMLGET(XMLGET(xml_doc, 'StrategyOneResponse'), 'Body'), 'Richiesta'), 'Variables')  AS n_req_var,
        XMLGET(XMLGET(XMLGET(XMLGET(xml_doc, 'StrategyOneResponse'), 'Body'), 'Richiesta'), 'Categories') AS n_categories
    FROM src

),

-- Livello documento (Header + Richiesta/Variables): un record per documento, VARCHAR grezzo.
req_raw AS (

    SELECT
    TS_RIFERIMENTO,
        n_categories,
        {{ get_xml_path('n_header', 'InquiryCode', 'VARCHAR') }}          AS CD_INQUIRYCODE,
        {{ get_xml_path('n_header', 'ProcessCode', 'VARCHAR') }}          AS CD_PROCESSCODE,
        {{ get_xml_path('n_header', 'ProcessVersion', 'VARCHAR') }}       AS CD_PROCESSVERSION_RAW,
        {{ get_xml_path('n_header', 'LayoutVersion', 'VARCHAR') }}        AS CD_LAYOUTVERSION_RAW,
        {{ get_xml_path('n_req_var', 'CODICE_INTERROGAZIONE', 'VARCHAR') }} AS CD_INTERROGAZIONE_RAW,
        {{ get_xml_path('n_req_var', 'DATA_RICHIESTA', 'VARCHAR') }}      AS DT_RICHIESTA_RAW,
        {{ get_xml_path('n_req_var', 'CODICE_PROCEDURA', 'VARCHAR') }}    AS TP_PROCEDURA,
        {{ get_xml_path('n_req_var', 'CODICE_PRATICA', 'VARCHAR') }}      AS CD_PRATICA_RAW,
        {{ get_xml_path('n_req_var', 'ESITO_CHIAMATA', 'VARCHAR') }}      AS TP_ESITO_CHIAMATA,
        {{ get_xml_path('n_req_var', 'ESITO_CODICE', 'VARCHAR') }}        AS CD_ESITO,
        {{ get_xml_path('n_req_var', 'ESITO_DESCRIZIONE', 'VARCHAR') }}   AS DS_ESITO,
        {{ get_xml_path('n_req_var', 'ESITO_MESSAGGIO', 'VARCHAR') }}     AS DS_ESITO_MESSAGGIO,
        {{ get_xml_path('n_req_var', 'PRECRIF_S_NUM_01', 'VARCHAR') }}    AS NM_PRECRIF_S_NUM_01,
        {{ get_xml_path('n_req_var', 'PRECRIF_S_NUM_02', 'VARCHAR') }}    AS NM_PRECRIF_S_NUM_02,
        {{ get_xml_path('n_req_var', 'PRECRIF_S_NUM_03', 'VARCHAR') }}    AS NM_PRECRIF_S_NUM_03,
        {{ get_xml_path('n_req_var', 'PRECRIF_S_NUM_04', 'VARCHAR') }}    AS NM_PRECRIF_S_NUM_04,
        {{ get_xml_path('n_req_var', 'PRECRIF_S_NUM_05', 'VARCHAR') }}    AS NM_PRECRIF_S_NUM_05,
        {{ get_xml_path('n_req_var', 'PRECRIF_S_TEXT_01', 'VARCHAR') }}   AS DS_PRECRIF_S_TEXT_01,
        {{ get_xml_path('n_req_var', 'PRECRIF_S_TEXT_02', 'VARCHAR') }}   AS DS_PRECRIF_S_TEXT_02,
        {{ get_xml_path('n_req_var', 'PRECRIF_S_TEXT_03', 'VARCHAR') }}   AS DS_PRECRIF_S_TEXT_03,
        {{ get_xml_path('n_req_var', 'PRECRIF_S_TEXT_04', 'VARCHAR') }}   AS DS_PRECRIF_S_TEXT_04,
        {{ get_xml_path('n_req_var', 'PRECRIF_S_TEXT_05', 'VARCHAR') }}   AS DS_PRECRIF_S_TEXT_05
    FROM nodes

),

-- Livello soggetto: FLATTEN degli Applicant sotto Categories in risposta.
app_flat AS (

    SELECT
        r.CD_INQUIRYCODE,
        r.TS_RIFERIMENTO,
        XMLGET(F.value, 'Variables') AS n_app_var
    FROM req_raw r,
    {{ flatten_xml('r.n_categories', 'Applicant', 'F') }}

),

app_raw AS (

    SELECT
        CD_INQUIRYCODE,
        TS_RIFERIMENTO,
        {{ get_xml_path('n_app_var', 'PRECRIF_M_NUM_01', 'VARCHAR') }}    AS NM_PRECRIF_M_NUM_01,
        {{ get_xml_path('n_app_var', 'PRECRIF_M_NUM_02', 'VARCHAR') }}    AS NM_PRECRIF_M_NUM_02,
        {{ get_xml_path('n_app_var', 'PRECRIF_M_NUM_03', 'VARCHAR') }}    AS NM_PRECRIF_M_NUM_03,
        {{ get_xml_path('n_app_var', 'PRECRIF_M_NUM_04', 'VARCHAR') }}    AS NM_PRECRIF_M_NUM_04,
        {{ get_xml_path('n_app_var', 'PRECRIF_M_NUM_05', 'VARCHAR') }}    AS NM_PRECRIF_M_NUM_05,
        {{ get_xml_path('n_app_var', 'PRECRIF_M_TEXT_01', 'VARCHAR') }}   AS DS_PRECRIF_M_TEXT_01,
        {{ get_xml_path('n_app_var', 'PRECRIF_M_TEXT_02', 'VARCHAR') }}   AS DS_PRECRIF_M_TEXT_02,
        {{ get_xml_path('n_app_var', 'PRECRIF_M_TEXT_03', 'VARCHAR') }}   AS DS_PRECRIF_M_TEXT_03,
        {{ get_xml_path('n_app_var', 'PRECRIF_M_TEXT_04', 'VARCHAR') }}   AS DS_PRECRIF_M_TEXT_04,
        {{ get_xml_path('n_app_var', 'PRECRIF_M_TEXT_05', 'VARCHAR') }}   AS DS_PRECRIF_M_TEXT_05,
        {{ get_xml_path('n_app_var', 'CALL_EURISC_TIPO', 'VARCHAR') }}    AS TP_CALL_EURISC_TIPO,
        {{ get_xml_path('n_app_var', 'CALL_EURISC_SI_NO_DB', 'VARCHAR') }} AS FL_CALL_EURISC_SI_NO_DB,
        {{ get_xml_path('n_app_var', 'CALL_CERVED_SI_NO_DB', 'VARCHAR') }} AS FL_CALL_CERVED_SI_NO_DB
    FROM app_flat

)

-- Conversione tipi + SELECT finale per soggetto.
SELECT
    r.CD_INQUIRYCODE                                   AS CD_INQUIRYCODE,
    -- WARN: CD_RUOLO (RF=RUOLO) non presente in ResponseApplicant/Variables di questo xsd.
    --       Non estraibile dalla risposta -> NULL. La PK (CD_INQUIRYCODE, CD_RUOLO) va rivista
    --       o va recuperato RUOLO correlando gli Applicant con PRECRIF_INPUT.
    NULL                                               AS CD_RUOLO,
    r.TS_RIFERIMENTO                                AS TS_INSERIMENTO,  
    r.CD_PROCESSCODE                                   AS CD_PROCESSCODE,
    TRY_CAST(r.CD_PROCESSVERSION_RAW AS NUMBER(38,0))  AS CD_PROCESSVERSION,
    TRY_CAST(r.CD_LAYOUTVERSION_RAW AS NUMBER(38,0))   AS CD_LAYOUTVERSION,
    TRY_CAST(r.CD_INTERROGAZIONE_RAW AS NUMBER(16,0))  AS CD_INTERROGAZIONE,
    TRY_TO_DATE(r.DT_RICHIESTA_RAW)                    AS DT_RICHIESTA,
    r.TP_PROCEDURA                                     AS TP_PROCEDURA,
    TRY_CAST(r.CD_PRATICA_RAW AS NUMBER(16,0))         AS CD_PRATICA,
    r.TP_ESITO_CHIAMATA                                AS TP_ESITO_CHIAMATA,
    r.CD_ESITO                                         AS CD_ESITO,
    r.DS_ESITO                                         AS DS_ESITO,
    r.DS_ESITO_MESSAGGIO                               AS DS_ESITO_MESSAGGIO,
    r.NM_PRECRIF_S_NUM_01                              AS NM_PRECRIF_S_NUM_01,
    r.NM_PRECRIF_S_NUM_02                              AS NM_PRECRIF_S_NUM_02,
    r.NM_PRECRIF_S_NUM_03                              AS NM_PRECRIF_S_NUM_03,
    r.NM_PRECRIF_S_NUM_04                              AS NM_PRECRIF_S_NUM_04,
    r.NM_PRECRIF_S_NUM_05                              AS NM_PRECRIF_S_NUM_05,
    r.DS_PRECRIF_S_TEXT_01                             AS DS_PRECRIF_S_TEXT_01,
    r.DS_PRECRIF_S_TEXT_02                             AS DS_PRECRIF_S_TEXT_02,
    r.DS_PRECRIF_S_TEXT_03                             AS DS_PRECRIF_S_TEXT_03,
    r.DS_PRECRIF_S_TEXT_04                             AS DS_PRECRIF_S_TEXT_04,
    r.DS_PRECRIF_S_TEXT_05                             AS DS_PRECRIF_S_TEXT_05,
    a.NM_PRECRIF_M_NUM_01                              AS NM_PRECRIF_M_NUM_01,
    a.NM_PRECRIF_M_NUM_02                              AS NM_PRECRIF_M_NUM_02,
    a.NM_PRECRIF_M_NUM_03                              AS NM_PRECRIF_M_NUM_03,
    a.NM_PRECRIF_M_NUM_04                              AS NM_PRECRIF_M_NUM_04,
    a.NM_PRECRIF_M_NUM_05                              AS NM_PRECRIF_M_NUM_05,
    a.DS_PRECRIF_M_TEXT_01                             AS DS_PRECRIF_M_TEXT_01,
    a.DS_PRECRIF_M_TEXT_02                             AS DS_PRECRIF_M_TEXT_02,
    a.DS_PRECRIF_M_TEXT_03                             AS DS_PRECRIF_M_TEXT_03,
    a.DS_PRECRIF_M_TEXT_04                             AS DS_PRECRIF_M_TEXT_04,
    a.DS_PRECRIF_M_TEXT_05                             AS DS_PRECRIF_M_TEXT_05,
    a.TP_CALL_EURISC_TIPO                              AS TP_CALL_EURISC_TIPO,
    a.FL_CALL_EURISC_SI_NO_DB                          AS FL_CALL_EURISC_SI_NO_DB,
    a.FL_CALL_CERVED_SI_NO_DB                          AS FL_CALL_CERVED_SI_NO_DB
FROM req_raw r
LEFT JOIN app_raw a
    ON r.CD_INQUIRYCODE = a.CD_INQUIRYCODE