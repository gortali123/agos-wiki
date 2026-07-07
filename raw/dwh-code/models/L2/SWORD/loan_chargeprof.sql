WITH base_data AS (
    SELECT 
        TS_RIFERIMENTO,
        DT_WFS_LAST_MODIFIED,
        PARSE_XML(GN_VALUE) AS org_xml
    FROM {{ ref('master_data') }}
),

-- Livello 0.5: Estraggo il contenitore <CreditLines>
credit_lines_wrapper AS (
    SELECT 
        b.DT_WFS_LAST_MODIFIED,
        {{ get_xml_path('b.org_xml', 'OrganisationId/OrganisationReference', 'NUMBER(10,0)') }} AS CD_ORGANISATION,
        clw.value AS credit_lines_xml
    FROM base_data b,
    {{ flatten_xml('b.org_xml', 'CreditLines', 'clw', outer=true) }}
),

-- Livello 1: Estraggo <CreditLine>
credit_lines AS (
    SELECT 
        w.DT_WFS_LAST_MODIFIED,
        w.CD_ORGANISATION,
        cl.value AS credit_line_xml
    FROM credit_lines_wrapper w,
    {{ flatten_xml('w.credit_lines_xml', 'CreditLine', 'cl', outer=true) }}
),

-- Livello 1.5: Estraggo il contenitore <Plans>
plans_wrapper AS (
    SELECT 
        cl_cte.DT_WFS_LAST_MODIFIED,
        cl_cte.CD_ORGANISATION,
        {{ get_xml_path('cl_cte.credit_line_xml', 'CreditLineReference', 'VARCHAR(17)') }} AS CD_CREDIT_LINE,
        pw.value AS plans_xml
    FROM credit_lines cl_cte,
    {{ flatten_xml('cl_cte.credit_line_xml', 'Plans', 'pw', outer=true) }}
),

-- Livello 2: Estraggo <Plan>
plans AS (
    SELECT 
        pw_cte.DT_WFS_LAST_MODIFIED,
        pw_cte.CD_ORGANISATION,
        pw_cte.CD_CREDIT_LINE,
        p.value AS plan_xml
    FROM plans_wrapper pw_cte,
    {{ flatten_xml('pw_cte.plans_xml', 'Plan', 'p', outer=true) }}
),

-- Livello 2.5: Estraggo il contenitore <Loans>
loans_wrapper AS (
    SELECT 
        p_cte.DT_WFS_LAST_MODIFIED,
        p_cte.CD_ORGANISATION,
        p_cte.CD_CREDIT_LINE,
        {{ get_xml_path('p_cte.plan_xml', 'PlanReference', 'VARCHAR(30)') }} AS CD_PLAN,
        lw.value AS loans_xml
    FROM plans p_cte,
    {{ flatten_xml('p_cte.plan_xml', 'Loans', 'lw', outer=true) }}
),

-- Livello 3: Estraggo i singoli <Loan>
loans AS (
    SELECT 
        lw_cte.DT_WFS_LAST_MODIFIED,
        lw_cte.CD_ORGANISATION,
        lw_cte.CD_CREDIT_LINE,
        lw_cte.CD_PLAN,
        l.value AS loan_xml
    FROM loans_wrapper lw_cte,
    {{ flatten_xml('lw_cte.loans_xml', 'Loan', 'l', outer=true) }}
),

-- Livello 4: Estraggo <ChargingProfile> (Gestione cruciale per profili multipli!)
charging_profiles AS (
    SELECT
        l_cte.DT_WFS_LAST_MODIFIED,
        l_cte.CD_ORGANISATION,
        l_cte.CD_CREDIT_LINE,
        l_cte.CD_PLAN,
        {{ get_xml_path('l_cte.loan_xml', 'LoanID', 'NUMBER(8,0)') }} AS CD_LOAN,
        cp.value AS charging_profile_xml
    FROM loans l_cte,
    {{ flatten_xml('l_cte.loan_xml', 'ChargingProfile', 'cp', outer=true) }}
)

-- Selezione Finale: Tutti i campi foglia dal foglio di analisi
SELECT
    DT_WFS_LAST_MODIFIED AS DT_RIFERIMENTO,
    CD_ORGANISATION AS CD_CLIENTE,
    CD_CREDIT_LINE AS CD_PRATICA, 
    CD_PLAN AS CD_PIANO,
    CD_LOAN AS CD_CERTIFICATO, -- WARN in table solo NUMBER
    
    -- Nodi da ChargingProfile in giù
    {{ get_xml_path('charging_profile_xml', 'ChargingTimings/Party', 'VARCHAR(6)') }} AS CD_PAGATORE,
    {{ get_xml_path('charging_profile_xml', 'ChargingTimings/BaseRateType', 'VARCHAR(7)') }} AS TP_INTERESSE_BASE,
    {{ get_xml_path('charging_profile_xml', 'ChargingTimings/BaseRate', 'NUMBER(5,4)') }} AS PC_TASSO_BSE, -- WARN in table solo NUMBER
    {{ get_xml_path('charging_profile_xml', 'ChargingTimings/PlanRateVariance', 'NUMBER(5,4)') }} AS NM_SPREAD_PIAN, -- WARN in table solo NUMBER
    {{ get_xml_path('charging_profile_xml', 'ChargingTimings/DealerRateVariance', 'NUMBER(5,4)') }} AS NM_SPREAD_DLR, -- WARN in table solo NUMBER
    {{ get_xml_path('charging_profile_xml', 'ChargingTimings/CalculationType', 'VARCHAR(7)') }} AS TP_CALCOLO,
    {{ get_xml_path('charging_profile_xml', 'ChargingTimings/Start/Date', 'DATE') }} AS DT_START,
    {{ get_xml_path('charging_profile_xml', 'ChargingTimings/End/Date', 'DATE') }} AS DT_END

FROM charging_profiles