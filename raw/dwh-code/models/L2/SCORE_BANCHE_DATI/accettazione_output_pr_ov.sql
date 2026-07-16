-- ============================================================================
-- Entita' L2: ACCETTAZIONE_OUTPUT_PR_OV  |  SA: SCORING  |  Storicizzazione: S2
-- Sorgente: landing XML CDE (payload StrategyOneResponse, ProcessCode = 'TARGATO')
-- Grana: una riga per REGOLA (policy rule 'PR') oppure per OVERRIDE ('OV').
-- PK: CD_INQUIRYCODE + TP_REGOLA + PR_REGOLA
--
-- Due rami uniti in UNION ALL (regola di composizione dal foglio, colonne SORGENTE CAMPI L1):
--  * Ramo 'PR' (policy rules): nel tracciato Response i gruppi REGOLA001_*..REGOLA300_*
--    sono tag PIATTI dentro Body/Richiesta/Variables (NON nodi ripetuti). Ogni gruppo
--    valorizzato genera una riga. Mappatura colonne:
--       TP_REGOLA            = 'PR'
--       PR_REGOLA            = progressivo del gruppo (001..300)
--       CD_REGOLA            = REGOLA<nnn>_CODICE
--       DS_REGOLA            = REGOLA<nnn>_DESCRIZIONE_RULES
--       DS_ESITO_REGOLA      = REGOLA<nnn>_ESITO
--       CD_FIRMA_REGOLA      = REGOLA<nnn>_FIRMA
--       DS_MESSAGGIO_REGOLA  = REGOLA<nnn>_MESSAGGIO
--    Righe con gruppo interamente vuoto (nessun _CODICE ne' _TIPO) sono scartate.
--  * Ramo 'OV' (override): dal nodo ripetuto OVERRIDE sotto Categories. Mappatura:
--       TP_REGOLA            = 'OV'
--       PR_REGOLA            = progressivo tecnico (ROW_NUMBER sui nodi OVERRIDE)
--       CD_REGOLA            = CODICE_OVR
--       DS_MESSAGGIO_REGOLA  = DESCRIZIONE_OVR
--       DS_REGOLA / DS_ESITO_REGOLA / CD_FIRMA_REGOLA = NULL (non valorizzati per 'OV')
--
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

roots AS (

    SELECT
        TS_RIFERIMENTO,
        XMLGET(XMLGET(xml_doc, 'StrategyOneResponse'), 'Header')                                          AS n_header,
        XMLGET(XMLGET(XMLGET(XMLGET(xml_doc, 'StrategyOneResponse'), 'Body'), 'Richiesta'), 'Variables')  AS n_req_var,
        XMLGET(XMLGET(XMLGET(XMLGET(xml_doc, 'StrategyOneResponse'), 'Body'), 'Richiesta'), 'Categories') AS n_categories
    FROM src

),

nodes AS (

    SELECT
        TS_RIFERIMENTO,
        {{ get_xml_path('n_header', 'InquiryCode', 'VARCHAR') }} AS CD_INQUIRYCODE,
        n_req_var,
        n_categories
    FROM roots

),

-- ========================= RAMO PR (policy rules) =========================
-- I 300 gruppi REGOLA<nnn>_* sono tag piatti in n_req_var; li estraiamo in VARCHAR e
-- li impiliamo con un UNION ALL generato via loop Jinja.
pr_raw AS (

    {%- for i in range(1, 301) %}
    {%- set n = '%03d' % i %}
    SELECT
        TS_RIFERIMENTO,
        CD_INQUIRYCODE,
        '{{ n }}'                                                              AS PR_REGOLA,
        {{ get_xml_path('n_req_var', 'REGOLA' ~ n ~ '_TIPO', 'VARCHAR') }}        AS REGOLA_TIPO,
        {{ get_xml_path('n_req_var', 'REGOLA' ~ n ~ '_CODICE', 'VARCHAR') }}      AS CD_REGOLA,
        {{ get_xml_path('n_req_var', 'REGOLA' ~ n ~ '_DESCRIZIONE_RULES', 'VARCHAR') }} AS DS_REGOLA,
        {{ get_xml_path('n_req_var', 'REGOLA' ~ n ~ '_ESITO', 'VARCHAR') }}       AS DS_ESITO_REGOLA,
        {{ get_xml_path('n_req_var', 'REGOLA' ~ n ~ '_FIRMA', 'VARCHAR') }}       AS CD_FIRMA_REGOLA,
        {{ get_xml_path('n_req_var', 'REGOLA' ~ n ~ '_MESSAGGIO', 'VARCHAR') }}   AS DS_MESSAGGIO_REGOLA
    FROM nodes
    {%- if not loop.last %}
    UNION ALL
    {%- endif %}
    {%- endfor %}
),

pr_branch AS (

    SELECT
        TS_RIFERIMENTO,
        CD_INQUIRYCODE,
        'PR'                 AS TP_REGOLA,
        PR_REGOLA,
        CD_REGOLA,
        DS_REGOLA,
        DS_ESITO_REGOLA,
        CD_FIRMA_REGOLA,
        DS_MESSAGGIO_REGOLA
    FROM pr_raw
    -- scarta i gruppi non valorizzati (nessun codice ne' tipo)
    WHERE COALESCE(CD_REGOLA, REGOLA_TIPO, DS_REGOLA, DS_ESITO_REGOLA, CD_FIRMA_REGOLA, DS_MESSAGGIO_REGOLA) IS NOT NULL

),

-- ========================= RAMO OV (override) =========================
ov_flat AS (

    SELECT
        TS_RIFERIMENTO,
        CD_INQUIRYCODE,
        F.INDEX                               AS OV_INDEX,
        XMLGET(F.value, 'Variables')          AS n_ov_var
    FROM nodes,
    {{ flatten_xml('n_categories', 'OVERRIDE', 'F') }}

),

ov_branch AS (

    SELECT
        TS_RIFERIMENTO,
        CD_INQUIRYCODE,
        'OV'                 AS TP_REGOLA,
        LPAD(CAST(ROW_NUMBER() OVER (PARTITION BY CD_INQUIRYCODE ORDER BY OV_INDEX) AS VARCHAR), 3, '0') AS PR_REGOLA,
        {{ get_xml_path('n_ov_var', 'CODICE_OVR', 'VARCHAR') }}       AS CD_REGOLA,
        CAST(NULL AS VARCHAR)                 AS DS_REGOLA,
        CAST(NULL AS VARCHAR)                 AS DS_ESITO_REGOLA,
        CAST(NULL AS VARCHAR)                 AS CD_FIRMA_REGOLA,
        {{ get_xml_path('n_ov_var', 'DESCRIZIONE_OVR', 'VARCHAR') }}  AS DS_MESSAGGIO_REGOLA
    FROM ov_flat

),

unified AS (

    SELECT * FROM pr_branch
    UNION ALL
    SELECT * FROM ov_branch

)

SELECT
    -- PK
    CD_INQUIRYCODE,
    TP_REGOLA,
    PR_REGOLA,
    -- campo tecnico di storicizzazione (S2)
    TS_RIFERIMENTO AS TS_INSERIMENTO,
    -- business
    CD_REGOLA,
    DS_REGOLA,
    DS_ESITO_REGOLA,
    CD_FIRMA_REGOLA,
    DS_MESSAGGIO_REGOLA
FROM unified