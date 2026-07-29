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
)

-- Selezione Finale: Estrazione dei campi Arrears dal nodo <Loan>
SELECT 
    DT_WFS_LAST_MODIFIED AS DT_RIFERIMENTO,
    CD_ORGANISATION AS CD_CLIENTE,
    CD_CREDIT_LINE AS CD_PRATICA,
    CD_PLAN AS CD_PIANO,
    
    -- Riferimento al prestito
    {{ get_xml_path('loan_xml', 'LoanID', 'NUMBER(9,0)') }} AS CD_CERTIFICATO, -- WARN in table solo NUMBER da capire lunghezza
    
    -- Navigazione profonda dentro il nodo 1:1 Arrears
    {{ get_xml_path('loan_xml', 'Arrears/ArrearsAmount/Amount', 'NUMBER(13,2)') }} AS EU_CAPITALE_IMPAG,
    {{ get_xml_path('loan_xml', 'Arrears/ArrearsInterest', 'NUMBER(13,2)') }} AS EU_INTERESSI_IMPAG,
    
    {{ get_xml_path('loan_xml', 'Arrears/ArrearsStartDate', 'DATE') }} AS DT_INSOLUTO

FROM loans