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

-- Selezione Finale: Estrazione dei campi dal nodo <Loan>
SELECT 
    DT_WFS_LAST_MODIFIED AS DT_RIFERIMENTO,
    CD_ORGANISATION AS CD_CLIENTE,
    CD_CREDIT_LINE AS CD_PRATICA,
    CD_PLAN AS CD_PIANO,
    
    -- Campi diretti sotto Loan
    {{ get_xml_path('loan_xml', 'LoanID', 'NUMBER(8,0)') }} AS CD_CERTIFICATO, -- WARN in table solo NUMBER da capire lunghezza
    {{ get_xml_path('loan_xml', 'LoanStatus', 'VARCHAR(12)') }} AS CD_STATO_CERTIF, 
    {{ get_xml_path('loan_xml', 'PaymentStatus', 'VARCHAR(7)') }} AS CD_PAYMENT_STATUS, -- WARN non in table
    {{ get_xml_path('loan_xml', 'Region', 'VARCHAR(2)') }} AS CD_REGION, -- WARN non in table
    {{ get_xml_path('loan_xml', 'Restructured', 'VARCHAR(5)') }} AS FL_RISTRUTTURAZIONE,
    
    -- Date (cast a VARCHAR, oppure 'DATE' se il tuo modello lo richiede specificamente)
    {{ get_xml_path('loan_xml', 'InterestStartDate', 'DATE') }} AS DT_INIZIO_CALC_INTSSI,
    {{ get_xml_path('loan_xml', 'MaturityDate', 'DATE') }} AS DT_SCADENZA_CONTR,
    {{ get_xml_path('loan_xml', 'SettlementDate', 'DATE') }} AS DT_RIMBORSO,
    {{ get_xml_path('loan_xml', 'EffectiveDate', 'DATE') }} AS DT_STATO_CERTIF,

    -- Importi annidati (cast a NUMBER)
    {{ get_xml_path('loan_xml', 'OriginalPrincipalAmount/Amount', 'NUMBER(13,2)') }} AS EU_ORIGINARIO_VEIC, -- WARN in table solo NUMBER da capire lunghezza
    {{ get_xml_path('loan_xml', 'CurrentPrincipalAmount/Amount', 'NUMBER(13,2)') }} AS EU_IMPORTO_CORR, -- WARN in table solo NUMBER da capire lunghezza
    {{ get_xml_path('loan_xml', 'Utilisation/Amount', 'NUMBER(13,2)') }} AS EU_UTILIZZATO -- WARN in table solo NUMBER da capire lunghezza

FROM loans