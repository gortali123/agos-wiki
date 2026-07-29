-- Entita' L2 RBPCORTO_OUTPUT | subject area SCORING | storicizzazione S2 (incremental/append)
-- Sorgente: landing XML CDE (L1_E_CDE.CDE), payload StrategyOneResponse, filtro ProcessCode = 'RBPCORTO'.
-- Estrazione valori dai nodi XML in VARCHAR (get_xml_path) e conversione tipi in CTE separato (TRY_CAST).
-- ASSUNZIONE: nel payload il ProcessCode e' 'RBPCORTO' (lo xsd dichiara fixed="RBPCORTOX"): fonte = Regola Tecnica Perimetro.

WITH src AS (

    SELECT
        VALUE AS xml_doc,
        TS_RIFERIMENTO
    FROM {{ ref('cde') }}
    WHERE XMLGET(XMLGET(XMLGET(VALUE, 'StrategyOneResponse'), 'Header'), 'ProcessCode'):"$"::VARCHAR = 'RBPCORTO'

    {% if is_incremental() %}
        AND TS_RIFERIMENTO > (SELECT COALESCE(MAX(TS_INSERIMENTO), '1900-01-01'::TIMESTAMP_NTZ) FROM {{ this }})
    {% endif %}

),

nodes AS (

    SELECT
        TS_RIFERIMENTO,
        XMLGET(XMLGET(xml_doc, 'StrategyOneResponse'), 'Header')                                          AS n_header,
        XMLGET(XMLGET(XMLGET(XMLGET(xml_doc, 'StrategyOneResponse'), 'Body'), 'Richiesta'), 'Variables')  AS n_res_var
    FROM src

),

raw AS (

    SELECT
        TS_RIFERIMENTO,
        {{ get_xml_path('n_header', 'InquiryCode', 'VARCHAR') }} AS CD_INQUIRYCODE,
        {{ get_xml_path('n_header', 'ProcessCode', 'VARCHAR') }} AS CD_PROCESSCODE,
        {{ get_xml_path('n_header', 'ProcessVersion', 'VARCHAR') }} AS CD_PROCESSVERSION,
        {{ get_xml_path('n_header', 'LayoutVersion', 'VARCHAR') }} AS CD_LAYOUTVERSION_RAW,
        {{ get_xml_path('n_res_var', 'NOTE1', 'VARCHAR') }} AS DS_NOTE1,
        {{ get_xml_path('n_res_var', 'NOTE2', 'VARCHAR') }} AS DS_NOTE2,
        {{ get_xml_path('n_res_var', 'FASCIA_RBP', 'VARCHAR') }} AS NM_FASCIA_RBP_RAW,
        {{ get_xml_path('n_res_var', 'ESITO_RBP', 'VARCHAR') }} AS TP_ESITO_RBP,
        {{ get_xml_path('n_res_var', 'FLAG_TABELLA', 'VARCHAR') }} AS FL_TABELLA,
        {{ get_xml_path('n_res_var', 'DESC_ERROR', 'VARCHAR') }} AS DS_ERROR,
        {{ get_xml_path('n_res_var', 'IRR_MIN', 'VARCHAR') }} AS NM_IRR_MIN_RAW,
        {{ get_xml_path('n_res_var', 'TAB_FIN_SUGGERITA', 'VARCHAR') }} AS CD_TAB_FIN_SUGGERITA,
        {{ get_xml_path('n_res_var', 'RETE', 'VARCHAR') }} AS CD_RETE
    FROM nodes

),

conv AS (

    SELECT
        CD_INQUIRYCODE,
        CD_PROCESSCODE,
        CD_PROCESSVERSION,
        TRY_CAST(CD_LAYOUTVERSION_RAW AS NUMBER) AS CD_LAYOUTVERSION,
        DS_NOTE1,
        DS_NOTE2,
        TRY_CAST(NM_FASCIA_RBP_RAW AS NUMBER(16,0)) AS NM_FASCIA_RBP,
        TP_ESITO_RBP,
        FL_TABELLA,
        DS_ERROR,
        TRY_CAST(NM_IRR_MIN_RAW AS NUMBER(16,2)) AS NM_IRR_MIN,
        CD_TAB_FIN_SUGGERITA,
        CD_RETE,
        TS_RIFERIMENTO
    FROM raw

)

SELECT
    CD_INQUIRYCODE,
    TS_RIFERIMENTO AS TS_INSERIMENTO,
    CD_PROCESSCODE,
    CD_PROCESSVERSION,
    CD_LAYOUTVERSION,
    DS_NOTE1,
    DS_NOTE2,
    NM_FASCIA_RBP,
    TP_ESITO_RBP,
    FL_TABELLA,
    DS_ERROR,
    NM_IRR_MIN,
    CD_TAB_FIN_SUGGERITA,
    CD_RETE
FROM conv