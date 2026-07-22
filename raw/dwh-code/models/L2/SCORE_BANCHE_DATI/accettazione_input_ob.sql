-- ============================================================================
-- Entita' L2: ACCETTAZIONE_INPUT_OB  |  SA: SCORING  |  Storicizzazione: S2
-- Sorgente: landing XML CDE (StrategyOneRequest, ProcessCode = 'TARGATO')
-- Grana: per Applicant (PK = CD_INQUIRYCODE + CD_RUOLO)
-- Livelli: campi OB_* a livello APPLICANT/Variables; OB_Errore_* nel nodo ripetuto
--   ERRORI (sotto APPLICANT/Categories). I nodi ERRORI sono PRE-AGGREGATI con LISTAGG in
--   una CTE dedicata (per InquiryCode+RUOLO) e poi LEFT JOIN: le subquery correlate in
--   SELECT non sono supportate da Snowflake.
-- NOTA: la colonna TIPO del foglio e' vuota per quasi tutti i campi: tipi inferiti dai
--   prefissi (EU_->NUMBER(16,2)/100, NM_->NUMBER(16,0), FL_->VARCHAR(1), altrimenti VARCHAR).
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
        XMLGET(XMLGET(XMLGET(xml_doc, 'StrategyOneRequest'), 'Header'), 'InquiryCode'):"$"::VARCHAR AS CD_INQUIRYCODE,
        XMLGET(XMLGET(xml_doc, 'StrategyOneRequest'), 'Header')                                          AS n_header,
        XMLGET(XMLGET(XMLGET(XMLGET(xml_doc, 'StrategyOneRequest'), 'Body'), 'Richiesta'), 'Variables')  AS n_req_var,
        XMLGET(XMLGET(XMLGET(XMLGET(xml_doc, 'StrategyOneRequest'), 'Body'), 'Richiesta'), 'Categories') AS n_categories
    FROM src

),

applicant AS (

    SELECT
        n.TS_RIFERIMENTO,
        n.CD_INQUIRYCODE,
        n.n_header,
        n.n_req_var,
        XMLGET(F.value, 'Variables')  AS n_app_var,
        XMLGET(F.value, 'Categories') AS n_app_categories
    FROM nodes n,
    {{ flatten_xml('n_categories', 'APPLICANT', 'F') }}

),

-- Pre-aggregazione dei nodi ripetuti ERRORI (sotto APPLICANT) per (InquiryCode, RUOLO)
errori AS (

    SELECT
        a.CD_INQUIRYCODE,
        {{ get_xml_path('a.n_app_var', 'RUOLO', 'VARCHAR') }} AS CD_RUOLO,
        LISTAGG(DISTINCT XMLGET(XMLGET(ef.value, 'Variables'), 'OB_Errore_Codice'):"$"::VARCHAR, ',') AS CD_OB_ERRORE,
        LISTAGG(DISTINCT XMLGET(XMLGET(ef.value, 'Variables'), 'OB_Errore_Ambito'):"$"::VARCHAR, ',') AS TP_OB_ERRORE_AMBITO,
        LISTAGG(DISTINCT XMLGET(XMLGET(ef.value, 'Variables'), 'OB_Errore_Livello'):"$"::VARCHAR, ',') AS NM_OB_ERRORE_LIVELLO_RAW
    FROM applicant a,
    LATERAL FLATTEN(input => a.n_app_categories:"$", OUTER => TRUE) ef
    WHERE ef.value:"@"::VARCHAR = 'ERRORI'
    GROUP BY a.CD_INQUIRYCODE, {{ get_xml_path('a.n_app_var', 'RUOLO', 'VARCHAR') }}

),

-- 1. ESTRAZIONE
raw AS (

    SELECT
        a.CD_INQUIRYCODE AS CD_INQUIRYCODE,
        {{ get_xml_path('a.n_app_var', 'RUOLO', 'VARCHAR') }} AS CD_RUOLO,
        {{ get_xml_path('a.n_header', 'ProcessCode', 'VARCHAR') }} AS CD_PROCESSCODE,
        {{ get_xml_path('a.n_app_var', 'OB_Score', 'VARCHAR') }} AS NM_OB_SCORE_RAW,
        {{ get_xml_path('a.n_app_var', 'OB_Reddito_da_lavoro', 'VARCHAR') }} AS EU_OB_REDDITO_DA_LAVORO_RAW,
        {{ get_xml_path('a.n_app_var', 'OB_Altre_entrate_1_30', 'VARCHAR') }} AS EU_OB_ALTRE_ENTRATE_1_30_RAW,
        {{ get_xml_path('a.n_app_var', 'OB_Altre_entrate_31_60', 'VARCHAR') }} AS EU_OB_ALTRE_ENTRATE_31_60_RAW,
        {{ get_xml_path('a.n_app_var', 'OB_Altre_entrate_61_90', 'VARCHAR') }} AS EU_OB_ALTRE_ENTRATE_61_90_RAW,
        {{ get_xml_path('a.n_app_var', 'OB_Saldo_iniziale', 'VARCHAR') }} AS EU_OB_SALDO_INIZIALE_RAW,
        {{ get_xml_path('a.n_app_var', 'OB_Saldo_finale', 'VARCHAR') }} AS EU_OB_SALDO_FINALE_RAW,
        {{ get_xml_path('a.n_app_var', 'OB_Saldi_intermedi', 'VARCHAR') }} AS EU_OB_SALDI_INTERMEDI_RAW,
        {{ get_xml_path('a.n_app_var', 'OB_Finanziamenti', 'VARCHAR') }} AS EU_OB_FINANZIAMENTI_RAW,
        {{ get_xml_path('a.n_app_var', 'OB_Investimenti_finanziari_entrate', 'VARCHAR') }} AS EU_OB_INVESTIMENTI_FINANZIARI_ENTRATE_RAW,
        {{ get_xml_path('a.n_app_var', 'OB_Investimenti_finanziari_uscite', 'VARCHAR') }} AS EU_OB_INVESTIMENTI_FINANZIARI_USCITE_RAW,
        {{ get_xml_path('a.n_app_var', 'OB_Alert_spese_more_ritardi', 'VARCHAR') }} AS FL_OB_ALERT_SPESE_MORE_RITARDI,
        {{ get_xml_path('a.n_app_var', 'OB_Reddito_Open_Banking', 'VARCHAR') }} AS EU_OB_REDDITO_OPEN_BANKING_RAW,
        {{ get_xml_path('a.n_req_var', 'OB_Esenzione_Reddito', 'VARCHAR') }} AS FL_OB_ESENZIONE_REDDITO,  -- NOTA: livello Richiesta/Variables,
        {{ get_xml_path('a.n_app_var', 'OB_DUMMY_SIGNIFICATIVO', 'VARCHAR') }} AS FL_OB_DUMMY_SIGNIFICATIVO,
        {{ get_xml_path('a.n_app_var', 'OB_IBAN_SIGNIFICATIVO', 'VARCHAR') }} AS FL_OB_IBAN_SIGNIFICATIVO,
        {{ get_xml_path('a.n_app_var', 'OB_IBAN_1', 'VARCHAR') }} AS CD_OB_IBAN_1,
        {{ get_xml_path('a.n_app_var', 'OB_IBAN_2', 'VARCHAR') }} AS CD_OB_IBAN_2,
        {{ get_xml_path('a.n_app_var', 'OB_IBAN_3', 'VARCHAR') }} AS CD_OB_IBAN_3,
        {{ get_xml_path('a.n_app_var', 'OB_IBAN_1_NOMI', 'VARCHAR') }} AS DS_OB_IBAN_1_NOMI,
        {{ get_xml_path('a.n_app_var', 'OB_IBAN_2_NOMI', 'VARCHAR') }} AS DS_OB_IBAN_2_NOMI,
        {{ get_xml_path('a.n_app_var', 'OB_IBAN_3_NOMI', 'VARCHAR') }} AS DS_OB_IBAN_3_NOMI,
        {{ get_xml_path('a.n_app_var', 'OB_Esito', 'VARCHAR') }} AS CD_OB_ESITO,
        {{ get_xml_path('a.n_app_var', 'OB_Stato', 'VARCHAR') }} AS CD_OB_STATO,
        er.CD_OB_ERRORE AS CD_OB_ERRORE,
        er.TP_OB_ERRORE_AMBITO AS TP_OB_ERRORE_AMBITO,
        er.NM_OB_ERRORE_LIVELLO_RAW AS NM_OB_ERRORE_LIVELLO_RAW,
        a.TS_RIFERIMENTO
    FROM applicant a
    LEFT JOIN errori er ON er.CD_INQUIRYCODE = a.CD_INQUIRYCODE
                       AND er.CD_RUOLO = {{ get_xml_path('a.n_app_var', 'RUOLO', 'VARCHAR') }}

),

-- 2. CONVERSIONE
conv AS (

    SELECT
        CD_INQUIRYCODE,
        CD_RUOLO,
        CD_PROCESSCODE,
        TRY_CAST(NM_OB_SCORE_RAW AS NUMBER(16,0)) AS NM_OB_SCORE,
        TRY_CAST(EU_OB_REDDITO_DA_LAVORO_RAW AS NUMBER(16,2)) AS EU_OB_REDDITO_DA_LAVORO,
        TRY_CAST(EU_OB_ALTRE_ENTRATE_1_30_RAW AS NUMBER(16,2)) AS EU_OB_ALTRE_ENTRATE_1_30,
        TRY_CAST(EU_OB_ALTRE_ENTRATE_31_60_RAW AS NUMBER(16,2)) AS EU_OB_ALTRE_ENTRATE_31_60,
        TRY_CAST(EU_OB_ALTRE_ENTRATE_61_90_RAW AS NUMBER(16,2)) AS EU_OB_ALTRE_ENTRATE_61_90,
        TRY_CAST(EU_OB_SALDO_INIZIALE_RAW AS NUMBER(16,2)) AS EU_OB_SALDO_INIZIALE,
        TRY_CAST(EU_OB_SALDO_FINALE_RAW AS NUMBER(16,2)) AS EU_OB_SALDO_FINALE,
        TRY_CAST(EU_OB_SALDI_INTERMEDI_RAW AS NUMBER(16,2)) AS EU_OB_SALDI_INTERMEDI,
        TRY_CAST(EU_OB_FINANZIAMENTI_RAW AS NUMBER(16,2)) AS EU_OB_FINANZIAMENTI,
        TRY_CAST(EU_OB_INVESTIMENTI_FINANZIARI_ENTRATE_RAW AS NUMBER(16,2)) AS EU_OB_INVESTIMENTI_FINANZIARI_ENTRATE,
        TRY_CAST(EU_OB_INVESTIMENTI_FINANZIARI_USCITE_RAW AS NUMBER(16,2)) AS EU_OB_INVESTIMENTI_FINANZIARI_USCITE,
        FL_OB_ALERT_SPESE_MORE_RITARDI,
        TRY_CAST(EU_OB_REDDITO_OPEN_BANKING_RAW AS NUMBER(16,2)) AS EU_OB_REDDITO_OPEN_BANKING,
        FL_OB_ESENZIONE_REDDITO,
        FL_OB_DUMMY_SIGNIFICATIVO,
        FL_OB_IBAN_SIGNIFICATIVO,
        CD_OB_IBAN_1,
        CD_OB_IBAN_2,
        CD_OB_IBAN_3,
        DS_OB_IBAN_1_NOMI,
        DS_OB_IBAN_2_NOMI,
        DS_OB_IBAN_3_NOMI,
        CD_OB_ESITO,
        CD_OB_STATO,
        CD_OB_ERRORE,
        TP_OB_ERRORE_AMBITO,
        TRY_CAST(NM_OB_ERRORE_LIVELLO_RAW AS NUMBER(16,2)) AS NM_OB_ERRORE_LIVELLO,
        TS_RIFERIMENTO AS TS_INSERIMENTO
    FROM raw

)
SELECT
    CD_INQUIRYCODE,
    CD_RUOLO,
    TS_INSERIMENTO,
    CD_PROCESSCODE,
    NM_OB_SCORE,
    EU_OB_REDDITO_DA_LAVORO,
    EU_OB_ALTRE_ENTRATE_1_30,
    EU_OB_ALTRE_ENTRATE_31_60,
    EU_OB_ALTRE_ENTRATE_61_90,
    EU_OB_SALDO_INIZIALE,
    EU_OB_SALDO_FINALE,
    EU_OB_SALDI_INTERMEDI,
    EU_OB_FINANZIAMENTI,
    EU_OB_INVESTIMENTI_FINANZIARI_ENTRATE,
    EU_OB_INVESTIMENTI_FINANZIARI_USCITE,
    FL_OB_ALERT_SPESE_MORE_RITARDI,
    EU_OB_REDDITO_OPEN_BANKING,
    FL_OB_ESENZIONE_REDDITO,
    FL_OB_DUMMY_SIGNIFICATIVO,
    FL_OB_IBAN_SIGNIFICATIVO,
    CD_OB_IBAN_1,
    CD_OB_IBAN_2,
    CD_OB_IBAN_3,
    DS_OB_IBAN_1_NOMI,
    DS_OB_IBAN_2_NOMI,
    DS_OB_IBAN_3_NOMI,
    CD_OB_ESITO,
    CD_OB_STATO,
    CD_OB_ERRORE,
    TP_OB_ERRORE_AMBITO,
    NM_OB_ERRORE_LIVELLO
FROM conv