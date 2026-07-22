-- Entita' L2 RBPCORTO_INPUT | subject area SCORING | storicizzazione S2 (incremental/append)
-- Sorgente: landing XML CDE (L1_E_CDE.CDE), payload StrategyOneRequest, filtro ProcessCode = 'RBPCORTO'.
-- Estrazione valori dai nodi XML in VARCHAR (get_xml_path) e conversione tipi in CTE separato (TRY_CAST / TRY_TO_DATE).
-- ASSUNZIONE: nel payload il ProcessCode e' 'RBPCORTO' (lo xsd dichiara fixed="RBPCORTOX"): fonte = Regola Tecnica Perimetro.

WITH src AS (

    SELECT
        VALUE AS xml_doc,
        TS_RIFERIMENTO
    FROM {{ ref('cde') }}
    WHERE XMLGET(XMLGET(XMLGET(VALUE, 'StrategyOneRequest'), 'Header'), 'ProcessCode'):"$"::VARCHAR = 'RBPCORTO'

    {% if is_incremental() %}
        AND TS_RIFERIMENTO > (SELECT COALESCE(MAX(TS_INSERIMENTO), '1900-01-01'::TIMESTAMP_NTZ) FROM {{ this }})
    {% endif %}
),

nodes AS (

    SELECT
        TS_RIFERIMENTO,
        XMLGET(XMLGET(xml_doc, 'StrategyOneRequest'), 'Header')                                          AS n_header,
        XMLGET(XMLGET(XMLGET(XMLGET(xml_doc, 'StrategyOneRequest'), 'Body'), 'Richiesta'), 'Variables')  AS n_req_var
    FROM src

),

raw AS (

    SELECT
        TS_RIFERIMENTO,
        {{ get_xml_path('n_header', 'InquiryCode', 'VARCHAR') }} AS CD_INQUIRYCODE,
        {{ get_xml_path('n_header', 'ProcessCode', 'VARCHAR') }} AS CD_PROCESSCODE,
        {{ get_xml_path('n_header', 'ProcessVersion', 'VARCHAR') }} AS CD_PROCESSVERSION,
        {{ get_xml_path('n_header', 'LayoutVersion', 'VARCHAR') }} AS CD_LAYOUTVERSION_RAW,
        {{ get_xml_path('n_req_var', 'TAB_FINAZIARIA', 'VARCHAR') }} AS CD_TAB_FINAZIARIA,
        {{ get_xml_path('n_req_var', 'CAMPAGNA_INDIVIDUALE', 'VARCHAR') }} AS CD_CAMPAGNA_INDIVIDUALE,
        {{ get_xml_path('n_req_var', 'MESE_OFFERTA', 'VARCHAR') }} AS NM_MESE_OFFERTA_RAW,
        {{ get_xml_path('n_req_var', 'ANNO_OFFERTA', 'VARCHAR') }} AS NM_ANNO_OFFERTA_RAW,
        {{ get_xml_path('n_req_var', 'INIZIATIVA_COMMERCIALE', 'VARCHAR') }} AS CD_INIZIATIVA_COMMERCIALE,
        {{ get_xml_path('n_req_var', 'DATA_CARICAMENTO', 'VARCHAR') }} AS DT_CARICAMENTO_RAW,
        {{ get_xml_path('n_req_var', 'IMPORTO', 'VARCHAR') }} AS EU_IMPORTO_RAW,
        {{ get_xml_path('n_req_var', 'DURATA', 'VARCHAR') }} AS NM_DURATA_RAW,
        {{ get_xml_path('n_req_var', 'IRR', 'VARCHAR') }} AS NM_IRR_RAW,
        {{ get_xml_path('n_req_var', 'CANALE', 'VARCHAR') }} AS CD_CANALE,
        -- NOTA: RF = 'TIPO_CANALE'; il tag reale nello xsd e' 'Type_CANALE'
        {{ get_xml_path('n_req_var', 'Type_CANALE', 'VARCHAR') }} AS TP_CANALE,
        {{ get_xml_path('n_req_var', 'CD_TIPO_CLIENTE', 'VARCHAR') }} AS CD_TIPO_CLIENTE,
        {{ get_xml_path('n_req_var', 'NOTE1', 'VARCHAR') }} AS DS_NOTE1,
        {{ get_xml_path('n_req_var', 'NOTE2', 'VARCHAR') }} AS DS_NOTE2,
        {{ get_xml_path('n_req_var', 'MACROAREA', 'VARCHAR') }} AS CD_MACROAREA,
        {{ get_xml_path('n_req_var', 'PRODOTTO', 'VARCHAR') }} AS CD_PRODOTTO,
        {{ get_xml_path('n_req_var', 'DESTINAZIONE_FINANZIAMENTO', 'VARCHAR') }} AS TP_DESTINAZIONE_FINANZIAMENTO,
        {{ get_xml_path('n_req_var', 'ASSICURAZIONE', 'VARCHAR') }} AS CD_ASSICURAZIONE,
        {{ get_xml_path('n_req_var', 'TIPO_PROCESSO', 'VARCHAR') }} AS TP_PROCESSO,
        -- WARN: il tag FASCIA_RBP non e' presente in StrategyOneRequest/Variables (solo in Response); restituira' NULL
        {{ get_xml_path('n_req_var', 'FASCIA_RBP', 'VARCHAR') }} AS NM_FASCIA_RBP_RAW
    FROM nodes

),

conv AS (

    SELECT
        CD_INQUIRYCODE,
        CD_PROCESSCODE,
        CD_PROCESSVERSION,
        TRY_CAST(CD_LAYOUTVERSION_RAW AS NUMBER) AS CD_LAYOUTVERSION,
        CD_TAB_FINAZIARIA,
        CD_CAMPAGNA_INDIVIDUALE,
        TRY_CAST(NM_MESE_OFFERTA_RAW AS NUMBER(16,0)) AS NM_MESE_OFFERTA,
        TRY_CAST(NM_ANNO_OFFERTA_RAW AS NUMBER(16,0)) AS NM_ANNO_OFFERTA,
        CD_INIZIATIVA_COMMERCIALE,
        TRY_TO_DATE(DT_CARICAMENTO_RAW) AS DT_CARICAMENTO,
        TRY_CAST(EU_IMPORTO_RAW AS NUMBER(16,2)) AS EU_IMPORTO,
        TRY_CAST(NM_DURATA_RAW AS NUMBER(16,0)) AS NM_DURATA,
        TRY_CAST(NM_IRR_RAW AS NUMBER(16,0)) AS NM_IRR,
        CD_CANALE,
        TP_CANALE,
        CD_TIPO_CLIENTE,
        DS_NOTE1,
        DS_NOTE2,
        CD_MACROAREA,
        CD_PRODOTTO,
        TP_DESTINAZIONE_FINANZIAMENTO,
        CD_ASSICURAZIONE,
        TP_PROCESSO,
        TRY_CAST(NM_FASCIA_RBP_RAW AS NUMBER(16,0)) AS NM_FASCIA_RBP,
        TS_RIFERIMENTO
    FROM raw

)

SELECT
    CD_INQUIRYCODE,
    TS_RIFERIMENTO AS TS_INSERIMENTO,
    CD_PROCESSCODE,
    CD_PROCESSVERSION,
    CD_LAYOUTVERSION,
    CD_TAB_FINAZIARIA,
    CD_CAMPAGNA_INDIVIDUALE,
    NM_MESE_OFFERTA,
    NM_ANNO_OFFERTA,
    CD_INIZIATIVA_COMMERCIALE,
    DT_CARICAMENTO,
    EU_IMPORTO,
    NM_DURATA,
    NM_IRR,
    CD_CANALE,
    TP_CANALE,
    CD_TIPO_CLIENTE,
    DS_NOTE1,
    DS_NOTE2,
    CD_MACROAREA,
    CD_PRODOTTO,
    TP_DESTINAZIONE_FINANZIAMENTO,
    CD_ASSICURAZIONE,
    TP_PROCESSO,
    NM_FASCIA_RBP
FROM conv