WITH base_data AS (
    SELECT 
        TS_RIFERIMENTO,
        DT_WFS_LAST_MODIFIED,
        PARSE_XML(GN_VALUE) AS org_xml
    FROM {{ ref('master_data') }}
),

-- Livello 0.5: Contenitore <CreditLines>
credit_lines_wrapper AS (
    SELECT 
        b.DT_WFS_LAST_MODIFIED,
        {{ get_xml_path('b.org_xml', 'OrganisationId/OrganisationReference', 'NUMBER(10,0)') }} AS CD_ORGANISATION,
        clw.value AS credit_lines_wrapper_xml
    FROM base_data b,
    {{ flatten_xml('b.org_xml', 'CreditLines', 'clw', outer=true) }}
),

-- Livello 1: Nodi <CreditLine>
credit_lines AS (
    SELECT 
        w.DT_WFS_LAST_MODIFIED,
        w.CD_ORGANISATION,
        cl.value AS credit_line_xml
    FROM credit_lines_wrapper w,
    {{ flatten_xml('w.credit_lines_wrapper_xml', 'CreditLine', 'cl', outer=true) }}
),

-- Livello 1.5: Contenitore <Plans>
plans_wrapper AS (
    SELECT
        cl_cte.DT_WFS_LAST_MODIFIED,
        cl_cte.CD_ORGANISATION,
        {{ get_xml_path('cl_cte.credit_line_xml', 'CreditLineReference', 'VARCHAR(17)') }} AS CD_CREDIT_LINE,
        pw.value AS plans_wrapper_xml
    FROM credit_lines cl_cte,
    {{ flatten_xml('cl_cte.credit_line_xml', 'Plans', 'pw', outer=true) }}
),

-- Livello 2: Nodi <Plan>
plans AS (
    SELECT
        pw_cte.DT_WFS_LAST_MODIFIED,
        pw_cte.CD_ORGANISATION,
        pw_cte.CD_CREDIT_LINE,
        p.value AS plan_xml
    FROM plans_wrapper pw_cte,
    {{ flatten_xml('pw_cte.plans_wrapper_xml', 'Plan', 'p', outer=true) }}
),

-- Livello 2.5: Contenitore <Loans>
loans_wrapper AS (
    SELECT
        p_cte.DT_WFS_LAST_MODIFIED,
        p_cte.CD_ORGANISATION,
        p_cte.CD_CREDIT_LINE,
        {{ get_xml_path('p_cte.plan_xml', 'PlanReference', 'VARCHAR(30)') }} AS CD_PLAN,
        lw.value AS loans_wrapper_xml
    FROM plans p_cte,
    {{ flatten_xml('p_cte.plan_xml', 'Loans', 'lw', outer=true) }}
),

-- Livello 3: Nodi <Loan>
loans AS (
    SELECT
        lw_cte.DT_WFS_LAST_MODIFIED,
        lw_cte.CD_ORGANISATION,
        lw_cte.CD_CREDIT_LINE,
        lw_cte.CD_PLAN,
        l.value AS loan_xml
    FROM loans_wrapper lw_cte,
    {{ flatten_xml('lw_cte.loans_wrapper_xml', 'Loan', 'l', outer=true) }}
),

-- Proiezione business + watermark (ex SELECT finale del modello insert_overwrite).
-- DT_RIFERIMENTO rimosso; DT_WFS_LAST_MODIFIED -> watermark LASTMODIFIEDDATA con cast
-- ::TIMESTAMP_NTZ (NON custom_to_timestamp_ntz: e' gia' DATE/TIMESTAMP -> trappola A).
-- I campi Arrears sono estratti da stringhe XML grezze (get_xml_path col cast diretto: OK).
extraction AS (
    SELECT
        CD_CREDIT_LINE AS CD_PRATICA,
        CD_PLAN AS CD_PIANO,
        {{ get_xml_path('loan_xml', 'LoanID', 'NUMBER(9,0)') }} AS CD_CERTIFICATO,   -- WARN tabella: solo NUMBER, lunghezza da capire

        CD_ORGANISATION AS CD_CLIENTE,

        -- Navigazione profonda dentro il nodo 1:1 Arrears
        {{ get_xml_path('loan_xml', 'Arrears/ArrearsAmount/Amount', 'NUMBER(13,2)') }} AS EU_CAPITALE_IMPAG,
        {{ get_xml_path('loan_xml', 'Arrears/ArrearsInterest', 'NUMBER(13,2)') }} AS EU_INTERESSI_IMPAG,
        {{ get_xml_path('loan_xml', 'Arrears/ArrearsStartDate', 'DATE') }} AS DT_INSOLUTO,

        DT_WFS_LAST_MODIFIED::TIMESTAMP_NTZ AS LASTMODIFIEDDATA
    FROM loans
    -- Difensivo, OFF: riattivare se lo snapshot puo' avere duplicati per (CD_PRATICA, CD_PIANO, CD_CERTIFICATO)
    -- nello stesso giorno.
    -- QUALIFY ROW_NUMBER() OVER (PARTITION BY CD_PRATICA, CD_PIANO, CD_CERTIFICATO ORDER BY DT_WFS_LAST_MODIFIED DESC) = 1
),

storicizzazione AS (
    SELECT
        CD_PRATICA,
        CD_PIANO,
        CD_CERTIFICATO,
        LASTMODIFIEDDATA AS TS_INIZIO_VALIDITA,
        {{ ts_fine_validita('CD_PRATICA, CD_PIANO, CD_CERTIFICATO', 'LASTMODIFIEDDATA') }} AS TS_FINE_VALIDITA,   -- qui 'LASTMODIFIEDDATA' (trappola B)
        CD_CLIENTE,
        EU_CAPITALE_IMPAG,
        EU_INTERESSI_IMPAG,
        DT_INSOLUTO,
        LASTMODIFIEDDATA
    FROM extraction
),

dedup AS (
    SELECT
        CD_PRATICA,
        CD_PIANO,
        CD_CERTIFICATO,
        TS_INIZIO_VALIDITA,
        TS_FINE_VALIDITA,
        CD_CLIENTE,
        EU_CAPITALE_IMPAG,
        EU_INTERESSI_IMPAG,
        DT_INSOLUTO,
        LASTMODIFIEDDATA,
        {{ hash_cols(['CD_PRATICA', 'CD_PIANO', 'CD_CERTIFICATO', 'CD_CLIENTE', 'EU_CAPITALE_IMPAG', 'EU_INTERESSI_IMPAG', 'DT_INSOLUTO']) }} AS HASHED_COLS   -- PK + business, no TS_*, no LASTMODIFIEDDATA
    FROM storicizzazione
    {{ is_incremental_S1('CD_PRATICA, CD_PIANO, CD_CERTIFICATO') }}
)

-- Selezione Finale: PK -> TS_INIZIO_VALIDITA -> TS_FINE_VALIDITA -> business -> LASTMODIFIEDDATA
SELECT
    CD_PRATICA,
    CD_PIANO,
    CD_CERTIFICATO,
    H.TS_INIZIO_VALIDITA,
    {{ ts_fine_validita('CD_PRATICA, CD_PIANO, CD_CERTIFICATO', 'H.TS_INIZIO_VALIDITA') }} AS TS_FINE_VALIDITA,   -- qui 'H.TS_INIZIO_VALIDITA'
    CD_CLIENTE,
    EU_CAPITALE_IMPAG,
    EU_INTERESSI_IMPAG,
    DT_INSOLUTO,
    LASTMODIFIEDDATA
FROM dedup H
