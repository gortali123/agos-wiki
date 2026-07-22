-- ============================================================================
-- Entita' L2: ACCETTAZIONE_INPUT_CAT_AGG  |  SA: SCORING  |  Storicizzazione: S2
-- Sorgente: landing XML CDE (StrategyOneRequest, ProcessCode = 'TARGATO')
-- Grana: per nodo CATENA_AGGIUNTIVA (PK = CD_INQUIRYCODE + NM_POSIZIONE_AGG)
-- Tutti i campi (tranne Header) provengono dal nodo ripetuto CATENA_AGGIUNTIVA/Variables
--   sotto Body/Richiesta/Categories.
-- NOTA: i 4 campi rete-vendita (MacroArea/Stato/Attributo/Tipologia) hanno RF con i nomi
--   *_Rete_Vendita che nello xsd esistono solo a livello Richiesta; a parita' di grana
--   (per catena) si usano invece i tag del nodo CATENA_AGGIUNTIVA: MacroAreaRete/StatoRete/
--   AttributoRete/TipologiaRete. Verificare.
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

-- Espansione dei nodi ripetuti CATENA_AGGIUNTIVA
catena AS (

    SELECT
        n.TS_RIFERIMENTO,
        n.n_header,
        XMLGET(F.value, 'Variables') AS n_cat_var
    FROM nodes n,
    {{ flatten_xml('n_categories', 'CATENA_AGGIUNTIVA', 'F') }}

),

-- 1. ESTRAZIONE
raw AS (

    SELECT
        {{ get_xml_path('n_header', 'InquiryCode', 'VARCHAR') }} AS CD_INQUIRYCODE,
        {{ get_xml_path('n_header', 'ProcessCode', 'VARCHAR') }} AS CD_PROCESSCODE,
        {{ get_xml_path('n_cat_var', 'POSIZIONE_AGGIUNTIVA', 'VARCHAR') }} AS NM_POSIZIONE_AGG_RAW,
        {{ get_xml_path('n_cat_var', 'RETE_VENDITA_AGGIUNTIVA', 'VARCHAR') }} AS CD_RETE_VENDITA_AGG,
        {{ get_xml_path('n_cat_var', 'AGENTE_AGGIUNTIVA', 'VARCHAR') }} AS CD_AGENTE_AGG,
        {{ get_xml_path('n_cat_var', 'SUBAGENTE_AGGIUNTIVA', 'VARCHAR') }} AS CD_SUBAGENTE_AGG,
        {{ get_xml_path('n_cat_var', 'MacroAreaRete', 'VARCHAR') }} AS CD_MACROAREA_RETE_VENDITA,  -- NOTA: mappato su tag CATENA MacroAreaRete,
        {{ get_xml_path('n_cat_var', 'StatoRete', 'VARCHAR') }} AS CD_STATO_RETE_VENDITA,  -- NOTA: mappato su tag CATENA StatoRete,
        {{ get_xml_path('n_cat_var', 'AttributoRete', 'VARCHAR') }} AS CD_ATTRIBUTO_RETE_VENDITA,  -- NOTA: mappato su tag CATENA AttributoRete,
        {{ get_xml_path('n_cat_var', 'TipologiaRete', 'VARCHAR') }} AS TP_RETE_VENDITA,  -- NOTA: mappato su tag CATENA TipologiaRete,
        {{ get_xml_path('n_cat_var', 'MacroAreaAgente', 'VARCHAR') }} AS CD_MACROAREA_AGENTE,
        {{ get_xml_path('n_cat_var', 'StatoAgente', 'VARCHAR') }} AS CD_STATO_AGENTE,
        {{ get_xml_path('n_cat_var', 'AttributoAgente', 'VARCHAR') }} AS CD_ATTRIBUTO_AGENTE,
        {{ get_xml_path('n_cat_var', 'TipologiaAgente', 'VARCHAR') }} AS TP_AGENTE,
        {{ get_xml_path('n_cat_var', 'MacroAreaSubAgente', 'VARCHAR') }} AS CD_MACROAREA_SUBAGENTE,
        {{ get_xml_path('n_cat_var', 'StatoSubAgente', 'VARCHAR') }} AS CD_STATO_SUBAGENTE,
        {{ get_xml_path('n_cat_var', 'AttributoSubAgente', 'VARCHAR') }} AS CD_ATTRIBUTO_SUBAGENTE,
        {{ get_xml_path('n_cat_var', 'TipologiaSubAgente', 'VARCHAR') }} AS TP_SUBAGENTE,
        TS_RIFERIMENTO
    FROM catena

),

-- 2. CONVERSIONE
conv AS (

    SELECT
        CD_INQUIRYCODE,
        CD_PROCESSCODE,
        TRY_CAST(NM_POSIZIONE_AGG_RAW AS NUMBER(16,0)) AS NM_POSIZIONE_AGG,
        CD_RETE_VENDITA_AGG,
        CD_AGENTE_AGG,
        CD_SUBAGENTE_AGG,
        CD_MACROAREA_RETE_VENDITA,
        CD_STATO_RETE_VENDITA,
        CD_ATTRIBUTO_RETE_VENDITA,
        TP_RETE_VENDITA,
        CD_MACROAREA_AGENTE,
        CD_STATO_AGENTE,
        CD_ATTRIBUTO_AGENTE,
        TP_AGENTE,
        CD_MACROAREA_SUBAGENTE,
        CD_STATO_SUBAGENTE,
        CD_ATTRIBUTO_SUBAGENTE,
        TP_SUBAGENTE,
        TS_RIFERIMENTO AS TS_INSERIMENTO
    FROM raw

)
SELECT
    CD_INQUIRYCODE,
    NM_POSIZIONE_AGG,
    TS_INSERIMENTO,
    CD_PROCESSCODE,
    CD_RETE_VENDITA_AGG,
    CD_AGENTE_AGG,
    CD_SUBAGENTE_AGG,
    CD_MACROAREA_RETE_VENDITA,
    CD_STATO_RETE_VENDITA,
    CD_ATTRIBUTO_RETE_VENDITA,
    TP_RETE_VENDITA,
    CD_MACROAREA_AGENTE,
    CD_STATO_AGENTE,
    CD_ATTRIBUTO_AGENTE,
    TP_AGENTE,
    CD_MACROAREA_SUBAGENTE,
    CD_STATO_SUBAGENTE,
    CD_ATTRIBUTO_SUBAGENTE,
    TP_SUBAGENTE
FROM conv