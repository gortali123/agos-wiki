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
),


-- Proiezione business + watermark. ChargingProfile e' figlio diretto di Plan (no wrapper).
-- DT_RIFERIMENTO rimosso; watermark = DT_WFS_LAST_MODIFIED::TIMESTAMP_NTZ (trappola A).
-- TP_CALCOLO: COALESCE(...,'ND') come da modello -> stessa COALESCE nella chiusura (post_hook).
extraction AS (
    SELECT
        CD_PRATICA,
        CD_PIANO,
        {{ get_xml_path('charging_profile_xml', 'ChargingTimings/Start/Day', 'NUMBER') }} AS NM_START,
        COALESCE({{ get_xml_path('charging_profile_xml', 'ChargingTimings/CalculationType', 'VARCHAR(7)') }}, 'ND') AS TP_CALCOLO,

        CD_ORGANISATION AS CD_CLIENTE,
        {{ get_xml_path('charging_profile_xml', 'ChargingTimings/End/Day', 'NUMBER') }} AS NM_END,
        {{ get_xml_path('charging_profile_xml', 'ChargingTimings/Party', 'VARCHAR(6)') }} AS CD_PAGATORE,
        {{ get_xml_path('charging_profile_xml', 'ChargingTimings/BaseRateType', 'VARCHAR(7)') }} AS TP_INTERESSE_BASE,
        {{ get_xml_path('charging_profile_xml', 'ChargingTimings/BaseRate', 'NUMBER(5,3)') }} AS NM_INTERESSE,
        {{ get_xml_path('charging_profile_xml', 'ChargingTimings/PlanRateVariance', 'NUMBER(5,3)') }} AS NM_VARIANZA_INTSS_PIA,
        {{ get_xml_path('charging_profile_xml', 'ChargingTimings/DealerRateVariance', 'NUMBER(5,3)') }} AS NM_VARIANZA_INTSS_CLI,

        DT_WFS_LAST_MODIFIED::TIMESTAMP_NTZ AS LASTMODIFIEDDATA
    FROM charging_profiles
    -- QUALIFY ROW_NUMBER() OVER (PARTITION BY CD_PRATICA, CD_PIANO, NM_START, TP_CALCOLO ORDER BY DT_WFS_LAST_MODIFIED DESC) = 1  -- difensivo, off
),

storicizzazione AS (
    SELECT
        CD_PRATICA,
        CD_PIANO,
        NM_START,
        TP_CALCOLO,
        LASTMODIFIEDDATA AS TS_INIZIO_VALIDITA,
        {{ ts_fine_validita('CD_PRATICA, CD_PIANO, NM_START, TP_CALCOLO', 'LASTMODIFIEDDATA') }} AS TS_FINE_VALIDITA,   -- 'LASTMODIFIEDDATA' (trappola B)
        CD_CLIENTE,
        NM_END,
        CD_PAGATORE,
        TP_INTERESSE_BASE,
        NM_INTERESSE,
        NM_VARIANZA_INTSS_PIA,
        NM_VARIANZA_INTSS_CLI,
        LASTMODIFIEDDATA
    FROM extraction
),

dedup AS (
    SELECT
        CD_PRATICA,
        CD_PIANO,
        NM_START,
        TP_CALCOLO,
        TS_INIZIO_VALIDITA,
        TS_FINE_VALIDITA,
        CD_CLIENTE,
        NM_END,
        CD_PAGATORE,
        TP_INTERESSE_BASE,
        NM_INTERESSE,
        NM_VARIANZA_INTSS_PIA,
        NM_VARIANZA_INTSS_CLI,
        LASTMODIFIEDDATA,
        {{ hash_cols(['CD_PRATICA', 'CD_PIANO', 'NM_START', 'TP_CALCOLO', 'CD_CLIENTE', 'NM_END', 'CD_PAGATORE', 'TP_INTERESSE_BASE', 'NM_INTERESSE', 'NM_VARIANZA_INTSS_PIA', 'NM_VARIANZA_INTSS_CLI']) }} AS HASHED_COLS
    FROM storicizzazione
    {{ is_incremental_S1('CD_PRATICA, CD_PIANO, NM_START, TP_CALCOLO') }}
)

-- Selezione Finale: PK -> TS_INIZIO_VALIDITA -> TS_FINE_VALIDITA -> business -> LASTMODIFIEDDATA
SELECT
        CD_PRATICA,
        CD_PIANO,
        NM_START,
        TP_CALCOLO,
        H.TS_INIZIO_VALIDITA,
        {{ ts_fine_validita('CD_PRATICA, CD_PIANO, NM_START, TP_CALCOLO', 'H.TS_INIZIO_VALIDITA') }} AS TS_FINE_VALIDITA,   -- 'H.TS_INIZIO_VALIDITA'
        CD_CLIENTE,
        NM_END,
        CD_PAGATORE,
        TP_INTERESSE_BASE,
        NM_INTERESSE,
        NM_VARIANZA_INTSS_PIA,
        NM_VARIANZA_INTSS_CLI,
        LASTMODIFIEDDATA
FROM dedup H
