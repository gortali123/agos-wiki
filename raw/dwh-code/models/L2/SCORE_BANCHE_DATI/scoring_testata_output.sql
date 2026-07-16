-- Modello L2 XML: SCORING_TESTATA_OUTPUT (subject area SCORING)
-- Sorgente: landing CDE (payload StrategyOneResponse, ProcessCode='SCORING')
-- Storicizzazione: S2 (incremental/append). Grana: una riga per InquiryCode (testata esito score).

WITH src AS (

    SELECT
        VALUE AS xml_doc,
        TS_RIFERIMENTO
    FROM {{ ref('cde') }}          -- ASSUNZIONE: modello landing = ref('cde'); TS_RIFERIMENTO esposta dalla landing
    WHERE XMLGET(XMLGET(XMLGET(VALUE, 'StrategyOneResponse'), 'Header'), 'ProcessCode'):"$"::VARCHAR = 'SCORING'
    {% if is_incremental() %}
      AND TS_RIFERIMENTO > (SELECT COALESCE(MAX(TS_RIFERIMENTO), '1900-01-01'::TIMESTAMP_NTZ) FROM {{ this }})
    {% endif %}

),
nodes AS (

    SELECT
        TS_RIFERIMENTO,
        --XMLGET(xml_doc, 'Header') AS n_header,
        --XMLGET(XMLGET(XMLGET(xml_doc, 'Body'), 'Richiesta'), 'Variables') AS n_req_var,
        --XMLGET(XMLGET(XMLGET(XMLGET(XMLGET(xml_doc, 'Body'), 'Richiesta'), 'Categories'), 'SEGMENTAZIONE'), 'Variables') AS n_seg_var
        XMLGET(XMLGET(xml_doc, 'StrategyOneResponse'), 'Header') AS n_header,
        XMLGET(XMLGET(XMLGET(XMLGET(xml_doc, 'StrategyOneResponse'), 'Body'), 'Richiesta'), 'Variables') AS n_req_var,
        XMLGET(XMLGET(XMLGET(XMLGET(XMLGET(xml_doc, 'StrategyOneResponse'), 'Body'), 'Richiesta'), 'Categories'), 'SEGMENTAZIONE') AS n_seg_var
    FROM src
),
raw AS (

    SELECT
        TS_RIFERIMENTO,
        {{ get_xml_path('n_header', 'InquiryCode', 'VARCHAR') }} AS CD_INQUIRYCODE_R,
        {{ get_xml_path('n_header', 'ProcessCode', 'VARCHAR') }} AS CD_PROCESSCODE_R,
        {{ get_xml_path('n_header', 'ProcessVersion', 'VARCHAR') }} AS CD_PROCESSVERSION_R,
        {{ get_xml_path('n_header', 'LayoutVersion', 'VARCHAR') }} AS CD_LAYOUTVERSION_R,
        {{ get_xml_path('n_req_var', 'CODICE_INTERROGAZIONE', 'VARCHAR') }} AS CD_INTERROGAZIONE_R,
        {{ get_xml_path('n_req_var', 'DATA_RICHIESTA', 'VARCHAR') }} AS DT_RICHIESTA_R,
        {{ get_xml_path('n_req_var', 'CODICE_PRATICA', 'VARCHAR') }} AS CD_PRATICA_R,
        {{ get_xml_path('n_req_var', 'CONTESTO', 'VARCHAR') }} AS CD_CONTESTO_R,
        {{ get_xml_path('n_req_var', 'SCORING_CODICE_FUNZIONE', 'VARCHAR') }} AS CD_SCORING_CODICE_FUNZIONE_R,
        {{ get_xml_path('n_req_var', 'ESITO_SCORE', 'VARCHAR') }} AS CD_ESITO_SCORE_R,
        {{ get_xml_path('n_req_var', 'ESITO_SCORE_DECISIONE', 'VARCHAR') }} AS CD_ESITO_SCORE_DECISIONE_R,
        {{ get_xml_path('n_req_var', 'ESITO_SCORE_FASCIA', 'VARCHAR') }} AS CD_ESITO_SCORE_FASCIA_R,
        {{ get_xml_path('n_req_var', 'ESITO_SCORE_MESSAGGIO', 'VARCHAR') }} AS DS_ESITO_SCORE_MESSAGGIO_R,
        {{ get_xml_path('n_seg_var', 'SEGMENTAZIONE_CODICE', 'VARCHAR') }} AS CD_SEGMENTAZIONE_R
    FROM nodes

),
conv AS (

    SELECT
        TS_RIFERIMENTO AS TS_INSERIMENTO,
        CD_INQUIRYCODE_R AS CD_INQUIRYCODE,
        CD_PROCESSCODE_R AS CD_PROCESSCODE,
        TRY_CAST(CD_PROCESSVERSION_R AS NUMBER) AS CD_PROCESSVERSION,
        TRY_CAST(CD_LAYOUTVERSION_R AS NUMBER) AS CD_LAYOUTVERSION,
        CD_INTERROGAZIONE_R AS CD_INTERROGAZIONE,
        TRY_TO_DATE(DT_RICHIESTA_R) AS DT_RICHIESTA,
        TRY_CAST(CD_PRATICA_R AS DECIMAL(16,0)) AS CD_PRATICA,
        CD_CONTESTO_R AS CD_CONTESTO,
        CD_SCORING_CODICE_FUNZIONE_R AS CD_SCORING_CODICE_FUNZIONE,
        CD_ESITO_SCORE_R AS CD_ESITO_SCORE,
        CD_ESITO_SCORE_DECISIONE_R AS CD_ESITO_SCORE_DECISIONE,
        CD_ESITO_SCORE_FASCIA_R AS CD_ESITO_SCORE_FASCIA,
        DS_ESITO_SCORE_MESSAGGIO_R AS DS_ESITO_SCORE_MESSAGGIO,
        CD_SEGMENTAZIONE_R AS CD_SEGMENTAZIONE
    FROM raw

)
SELECT
    CD_INQUIRYCODE,
    TS_INSERIMENTO,
    CD_PROCESSCODE,
    CD_PROCESSVERSION,
    CD_LAYOUTVERSION,
    CD_INTERROGAZIONE,
    DT_RICHIESTA,
    CD_PRATICA,
    CD_CONTESTO,
    CD_SCORING_CODICE_FUNZIONE,
    CD_ESITO_SCORE,
    CD_ESITO_SCORE_DECISIONE,
    CD_ESITO_SCORE_FASCIA,
    DS_ESITO_SCORE_MESSAGGIO,
    CD_SEGMENTAZIONE
FROM conv
