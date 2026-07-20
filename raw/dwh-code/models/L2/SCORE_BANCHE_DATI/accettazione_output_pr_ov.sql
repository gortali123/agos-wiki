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
-- I gruppi REGOLA<n>_<attributo> sono tag PIATTI in n_req_var. ATTENZIONE: nel payload il
-- progressivo NON e' zero-padded (es. REGOLA6_TIPO, non REGOLA006_TIPO). Approccio:
--   1) si appiattiscono TUTTI i figli di Variables con LATERAL FLATTEN (una sola lettura);
--   2) si tengono solo i tag REGOLA<n>_<attributo> con attributo atteso;
--   3) dal nome tag si estraggono progressivo (REG_NUM, numerico) e attributo (REG_ATTR);
--   4) si filtra il dominio sul VALORE numerico del progressivo (1..300, tetto fisso as-is),
--      cosi' e' indipendente dallo zero-padding;
--   5) si ri-pivota per progressivo con MAX(CASE ...) GROUP BY per ricomporre la riga.
-- (UNPIVOT non e' adatto: richiederebbe di nominare a priori le colonne REGOLAn_*.)
regole_flat AS (

    SELECT
        n.TS_RIFERIMENTO,
        n.CD_INQUIRYCODE,
        rf.value:"@"::VARCHAR                                                     AS TAG_NAME,
        rf.value:"$"::VARCHAR                                                     AS TAG_VALUE,
        -- progressivo come intero (gestisce sia REGOLA6_ sia REGOLA06_/REGOLA006_)
        TRY_TO_NUMBER(REGEXP_SUBSTR(rf.value:"@"::VARCHAR, 'REGOLA([0-9]+)_', 1, 1, 'e', 1)) AS REG_NUM,
        -- attributo (tutto cio' che segue il primo underscore dopo le cifre)
        REGEXP_SUBSTR(rf.value:"@"::VARCHAR, 'REGOLA[0-9]+_(.+)$', 1, 1, 'e', 1)  AS REG_ATTR
    FROM nodes n,
    LATERAL FLATTEN(input => n.n_req_var:"$", OUTER => TRUE) rf
    -- match tag REGOLA<n>_<attributo> senza assumere lo zero-padding delle cifre
    WHERE rf.value:"@"::VARCHAR REGEXP 'REGOLA[0-9]+_(TIPO|CODICE|DESCRIZIONE_RULES|ESITO|FIRMA|MESSAGGIO)'

),

-- Re-pivot: una riga per (InquiryCode, progressivo regola)
pr_raw AS (

    SELECT
        TS_RIFERIMENTO,
        CD_INQUIRYCODE,
        -- progressivo normalizzato a 3 cifre (coerente con PR_REGOLA VARCHAR(3))
        LPAD(TO_VARCHAR(REG_NUM), 3, '0')                               AS PR_REGOLA,
        MAX(CASE WHEN REG_ATTR = 'TIPO'              THEN TAG_VALUE END) AS REGOLA_TIPO,
        MAX(CASE WHEN REG_ATTR = 'CODICE'            THEN TAG_VALUE END) AS CD_REGOLA,
        MAX(CASE WHEN REG_ATTR = 'DESCRIZIONE_RULES' THEN TAG_VALUE END) AS DS_REGOLA,
        MAX(CASE WHEN REG_ATTR = 'ESITO'             THEN TAG_VALUE END) AS DS_ESITO_REGOLA,
        MAX(CASE WHEN REG_ATTR = 'FIRMA'             THEN TAG_VALUE END) AS CD_FIRMA_REGOLA,
        MAX(CASE WHEN REG_ATTR = 'MESSAGGIO'         THEN TAG_VALUE END) AS DS_MESSAGGIO_REGOLA
    FROM regole_flat
    -- dominio dei progressivi ancorato al valore numerico 1..300 (tetto fisso noto as-is)
    GROUP BY TS_RIFERIMENTO, CD_INQUIRYCODE, REG_NUM

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
    -- scarta i gruppi non valorizzati (nessun attributo valorizzato)
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
        NULL                 AS DS_REGOLA,
        NULL                 AS DS_ESITO_REGOLA,
        NULL                 AS CD_FIRMA_REGOLA,
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
    TRY_TO_NUMBER(PR_REGOLA) AS PR_REGOLA,
    -- campo tecnico di storicizzazione (S2)
    TS_RIFERIMENTO AS TS_INSERIMENTO,
    -- business
    CD_REGOLA,
    DS_REGOLA,
    DS_ESITO_REGOLA,
    CD_FIRMA_REGOLA,
    DS_MESSAGGIO_REGOLA
FROM unified