-- Modello L2 XML: SCORING_DETTAGLIO_OUTPUT (subject area SCORING)
-- Sorgente: landing CDE (payload StrategyOneResponse, ProcessCode='SCORING')
-- Storicizzazione: S2 (incremental/append).
-- Grana: una riga per (InquiryCode, PR_MODULO, PR_REGRESSORE).
--
-- Il payload espone i moduli/regressori come TAG PIATTI:
--   modulo   : SCORE_MODULO_0x_OBJCODE / _ALIGNED / _RAW / _DESCRIZIONE_GRIGLIA, TIPOLOGIA_MODELLO_0x
--   regress. : SCORE_MODULO_0x_DESCRIZIONE_REGRESSORE_y / _VALORE_PUNTUALE_REGRESSORE_y /
--              _VAR_y / _VAR_RC_y / _VAR_RM_y / _VAR_VALUE_y
-- con x = PR_MODULO (01..10) e y = PR_REGRESSORE (0..49), come da REGOLA FUNZIONALE.
--
-- Normalizzazione (come da esempio moduli/regressori + perimetro "UNPIVOT ... WHERE ... IS NOT NULL"):
--   * un modulo con ALMENO UN regressore -> NON genera la riga di solo modulo; le info di
--     modulo sono replicate su ogni riga di regressore.
--   * un modulo SENZA regressori -> una sola riga (PR_REGRESSORE = NULL, campi regressore NULL).
-- L'espansione x/y e' generata via loop Jinja per non scrivere ~3050 tag a mano.

{% set modules = range(1, 11) %}
{% set regressori = range(0, 50) %}
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
base AS (

    SELECT
        TS_RIFERIMENTO,
        --XMLGET(xml_doc, 'Header') AS n_header,
        --XMLGET(XMLGET(XMLGET(xml_doc, 'Body'), 'Richiesta'), 'Variables') AS n_req_var
        XMLGET(XMLGET(xml_doc, 'StrategyOneResponse'), 'Header') AS n_header,
        XMLGET(XMLGET(XMLGET(XMLGET(xml_doc, 'StrategyOneResponse'), 'Body'), 'Richiesta'), 'Variables') AS n_req_var
    FROM src

),
doc AS (   -- costanti di documento (request-level), estratte una sola volta in VARCHAR

    SELECT
        TS_RIFERIMENTO,
        n_req_var,
        {{ get_xml_path('n_header', 'InquiryCode', 'VARCHAR') }} AS CD_INQUIRYCODE,
        {{ get_xml_path('n_req_var', 'SCORING_CODICE_FUNZIONE', 'VARCHAR') }} AS CD_SCORING_CODICE_FUNZIONE,
        {{ get_xml_path('n_req_var', 'DATA_RICHIESTA', 'VARCHAR') }} AS DT_RICHIESTA_R
    FROM base

),
modulo_raw AS (   -- una riga per (documento, modulo), campi di modulo in VARCHAR
{% for x in modules %}
{% set mod = '%02d' | format(x) %}
{% if not loop.first %}
    UNION ALL
{% endif %}
    SELECT
        CD_INQUIRYCODE,
        CD_SCORING_CODICE_FUNZIONE,
        DT_RICHIESTA_R,
        TS_RIFERIMENTO,
        {{ x }} AS PR_MODULO,
        {{ get_xml_path('n_req_var', 'SCORE_MODULO_' ~ mod ~ '_OBJCODE', 'VARCHAR') }} AS CD_MODULO_OBJCODE,
        {{ get_xml_path('n_req_var', 'SCORE_MODULO_' ~ mod ~ '_ALIGNED', 'VARCHAR') }} AS NM_MODULO_ALIGNED_R,
        {{ get_xml_path('n_req_var', 'TIPOLOGIA_MODELLO_' ~ mod, 'VARCHAR') }} AS TP_TIPOLOGIA_MODELLO,
        {{ get_xml_path('n_req_var', 'SCORE_MODULO_' ~ mod ~ '_DESCRIZIONE_GRIGLIA', 'VARCHAR') }} AS DS_MODULO_DESCRIZIONE_GRIGLIA,
        {{ get_xml_path('n_req_var', 'SCORE_MODULO_' ~ mod ~ '_RAW', 'VARCHAR') }} AS NM_MODULO_RAW_R
    FROM doc
{% endfor %}
),
regressore_raw AS (   -- una riga per (documento, modulo, regressore), campi di regressore in VARCHAR
{% set ns = namespace(first = true) %}
{% for x in modules %}
{% set mod = '%02d' | format(x) %}
{% for y in regressori %}
{% if not ns.first %}
    UNION ALL
{% endif %}
    SELECT
        CD_INQUIRYCODE,
        {{ x }} AS PR_MODULO,
        {{ y }} AS PR_REGRESSORE,
        {{ get_xml_path('n_req_var', 'SCORE_MODULO_' ~ mod ~ '_DESCRIZIONE_REGRESSORE_' ~ y, 'VARCHAR') }} AS DS_REGRESSORE,
        {{ get_xml_path('n_req_var', 'SCORE_MODULO_' ~ mod ~ '_VALORE_PUNTUALE_REGRESSORE_' ~ y, 'VARCHAR') }} AS TP_VALORE_PUNTUALE_REGRESSORE,
        {{ get_xml_path('n_req_var', 'SCORE_MODULO_' ~ mod ~ '_VAR_' ~ y, 'VARCHAR') }} AS CD_VAR,
        {{ get_xml_path('n_req_var', 'SCORE_MODULO_' ~ mod ~ '_VAR_RC_' ~ y, 'VARCHAR') }} AS CD_VAR_RC,
        {{ get_xml_path('n_req_var', 'SCORE_MODULO_' ~ mod ~ '_VAR_RM_' ~ y, 'VARCHAR') }} AS CD_VAR_RM,
        {{ get_xml_path('n_req_var', 'SCORE_MODULO_' ~ mod ~ '_VAR_VALUE_' ~ y, 'VARCHAR') }} AS CD_VAR_VALUE
    FROM doc
{% set ns.first = false %}
{% endfor %}
{% endfor %}
),
modulo_conv AS (   -- tipizzazione dei campi di modulo

    SELECT
        CD_INQUIRYCODE,
        CD_SCORING_CODICE_FUNZIONE,
        TRY_TO_DATE(DT_RICHIESTA_R) AS DT_RICHIESTA,
        TS_RIFERIMENTO,
        PR_MODULO,
        CD_MODULO_OBJCODE,
        TRY_CAST(NM_MODULO_ALIGNED_R AS DECIMAL(16,0)) NM_MODULO_ALIGNED,
        TP_TIPOLOGIA_MODELLO,
        DS_MODULO_DESCRIZIONE_GRIGLIA,
        TRY_CAST(NM_MODULO_RAW_R AS DECIMAL(16,0)) NM_MODULO_RAW,
    FROM modulo_raw

),
mod_present AS (   -- moduli effettivamente valorizzati nel payload

    SELECT *
    FROM modulo_conv
    WHERE COALESCE(
              CD_MODULO_OBJCODE,
              CAST(NM_MODULO_ALIGNED AS VARCHAR),
              TP_TIPOLOGIA_MODELLO,
              DS_MODULO_DESCRIZIONE_GRIGLIA,
              CAST(NM_MODULO_RAW AS VARCHAR)
          ) IS NOT NULL

),
reg_present AS (   -- regressori effettivamente valorizzati (scarta gli slot vuoti)

    SELECT *
    FROM regressore_raw
    WHERE COALESCE(
              DS_REGRESSORE,
              TP_VALORE_PUNTUALE_REGRESSORE,
              CD_VAR,
              CD_VAR_RC,
              CD_VAR_RM,
              CD_VAR_VALUE
          ) IS NOT NULL

)
-- righe di REGRESSORE: info di modulo replicate su ogni regressore
SELECT
    m.CD_INQUIRYCODE,
    m.PR_MODULO,
    r.PR_REGRESSORE,
    m.TS_RIFERIMENTO AS TS_INSERIMENTO,
    m.CD_SCORING_CODICE_FUNZIONE,
    m.DT_RICHIESTA,
    m.CD_MODULO_OBJCODE,
    m.NM_MODULO_ALIGNED,
    m.TP_TIPOLOGIA_MODELLO,
    m.DS_MODULO_DESCRIZIONE_GRIGLIA,
    m.NM_MODULO_RAW,
    r.DS_REGRESSORE,
    r.TP_VALORE_PUNTUALE_REGRESSORE,
    r.CD_VAR,
    r.CD_VAR_RC,
    r.CD_VAR_RM,
    r.CD_VAR_VALUE
FROM reg_present r
INNER JOIN mod_present m
        ON m.CD_INQUIRYCODE = r.CD_INQUIRYCODE
       AND m.PR_MODULO = r.PR_MODULO
UNION ALL
-- righe di solo MODULO: unicamente per i moduli senza alcun regressore
SELECT
    m.CD_INQUIRYCODE,
    m.PR_MODULO,
    -1::NUMBER AS PR_REGRESSORE,
    m.TS_RIFERIMENTO AS TS_INSERIMENTO,
    m.CD_SCORING_CODICE_FUNZIONE,
    m.DT_RICHIESTA,
    m.CD_MODULO_OBJCODE,
    m.NM_MODULO_ALIGNED,
    m.TP_TIPOLOGIA_MODELLO,
    m.DS_MODULO_DESCRIZIONE_GRIGLIA,
    m.NM_MODULO_RAW,
    NULL::VARCHAR AS DS_REGRESSORE,
    NULL::VARCHAR AS TP_VALORE_PUNTUALE_REGRESSORE,
    NULL::VARCHAR AS CD_VAR,
    NULL::VARCHAR AS CD_VAR_RC,
    NULL::VARCHAR AS CD_VAR_RM,
    NULL::VARCHAR AS CD_VAR_VALUE
FROM mod_present m
WHERE NOT EXISTS (
    SELECT 1
    FROM reg_present r
    WHERE r.CD_INQUIRYCODE = m.CD_INQUIRYCODE
      AND r.PR_MODULO = m.PR_MODULO
)
