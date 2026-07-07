WITH base_data AS (
    SELECT 
        TS_RIFERIMENTO,
        DT_WFS_LAST_MODIFIED,
        PARSE_XML(GN_VALUE) AS org_xml
    FROM {{ ref('master_data') }}
),

-- Livello 0 Estraggo il nodo contenitore <CreditLines>
credit_lines_wrapper AS (
    SELECT 
        b.DT_WFS_LAST_MODIFIED,
        b.org_xml,
        clw.value AS credit_lines_xml
    FROM base_data b,
    {{ flatten_xml('b.org_xml', 'CreditLines', 'clw', outer=true) }}
),

-- Livello 1: Dal contenitore, estraggo i singoli nodi <CreditLine>
credit_lines AS (
    SELECT 
        w.DT_WFS_LAST_MODIFIED,
        {{ get_xml_path('w.org_xml', 'OrganisationId/OrganisationReference', 'NUMBER(10,0)') }} AS CD_ORGANISATION,
        cl.value AS credit_line_xml
    FROM credit_lines_wrapper w,
    {{ flatten_xml('w.credit_lines_xml', 'CreditLine', 'cl', outer=true) }}
),

-- Livello 1.5: Dentro ogni CreditLine, estraggo il nodo contenitore <Plans>
plans_wrapper AS (
    SELECT 
        cl.DT_WFS_LAST_MODIFIED,
        cl.CD_ORGANISATION,
        cl.credit_line_xml,
        pw.value AS plans_xml
    FROM credit_lines cl,
    {{ flatten_xml('cl.credit_line_xml', 'Plans', 'pw', outer=true) }}
),

-- Livello 2: Dal contenitore, estraggo i singoli nodi <Plan>
plans AS (
    SELECT 
        pw.DT_WFS_LAST_MODIFIED,
        pw.CD_ORGANISATION,
        {{ get_xml_path('pw.credit_line_xml', 'CreditLineReference', 'VARCHAR(17)') }} AS CD_PRATICA,
        p.value AS plan_xml
    FROM plans_wrapper pw,
    {{ flatten_xml('pw.plans_xml', 'Plan', 'p', outer=true) }}
),

-- Livello 3: Plan -> ChargingProfile 
charging_profiles AS (
    SELECT
        p.DT_WFS_LAST_MODIFIED,
        p.CD_ORGANISATION,
        p.CD_PRATICA,
        {{ get_xml_path('p.plan_xml', 'PlanReference', 'VARCHAR(30)') }} AS CD_PIANO,
        cp.value AS charging_profile_xml
    FROM plans p,
    {{ flatten_xml('p.plan_xml', 'ChargingProfile', 'cp', outer=true) }}
)

-- Estrazione finale dei campi mappati dal tuo Excel

SELECT
    DT_WFS_LAST_MODIFIED AS DT_RIFERIMENTO,
    CD_ORGANISATION AS CD_CLIENTE,
    CD_PRATICA,
    CD_PIANO,
    
    -- Estraggo i campi usando esattamente i percorsi "finali" del tuo ExcelCASE 
    COALESCE(
    {{ get_xml_path('charging_profile_xml', 'ChargingTimings/CalculationType', 'VARCHAR(7)') }},
    'ND' ) AS TP_CALCOLO,
    {{ get_xml_path('charging_profile_xml', 'ChargingTimings/Start/Day', 'NUMBER') }} AS NM_START,
    {{ get_xml_path('charging_profile_xml', 'ChargingTimings/End/Day', 'NUMBER') }} AS NM_END,
    {{ get_xml_path('charging_profile_xml', 'ChargingTimings/Party', 'VARCHAR(6)') }} AS CD_PAGATORE,
    {{ get_xml_path('charging_profile_xml', 'ChargingTimings/BaseRateType', 'VARCHAR(7)') }} AS TP_INTERESSE_BASE,
    {{ get_xml_path('charging_profile_xml', 'ChargingTimings/BaseRate', 'NUMBER(5,3)') }} AS NM_INTERESSE,
    {{ get_xml_path('charging_profile_xml', 'ChargingTimings/PlanRateVariance', 'NUMBER(5,3)') }} AS NM_VARIANZA_INTSS_PIA,
    {{ get_xml_path('charging_profile_xml', 'ChargingTimings/DealerRateVariance', 'NUMBER(5,3)') }} AS NM_VARIANZA_INTSS_CLI

FROM charging_profiles
