WITH base_data AS (
    SELECT 
        TS_RIFERIMENTO,
        DT_WFS_LAST_MODIFIED,
        PARSE_XML(GN_VALUE) AS org_xml
    FROM {{ ref('master_data') }}
),

-- Livello 0.5: Estraggo il contenitore <CreditLines> in sicurezza
credit_lines_wrapper AS (
    SELECT 
        b.DT_WFS_LAST_MODIFIED,
        {{ get_xml_path('b.org_xml', 'OrganisationId/OrganisationReference', 'NUMBER(10,0)') }} AS CD_ORGANISATION,
        clw.value AS credit_lines_xml
    FROM base_data b,
    {{ flatten_xml('b.org_xml', 'CreditLines', 'clw', outer=true) }}
),

-- Livello 1: Dal contenitore, estraggo i singoli nodi <CreditLine> (Relazione 1 a Molti)
credit_lines AS (
    SELECT 
        w.DT_WFS_LAST_MODIFIED,
        w.CD_ORGANISATION,
        cl.value AS credit_line_xml
    FROM credit_lines_wrapper w,
    {{ flatten_xml('w.credit_lines_xml', 'CreditLine', 'cl', outer=true) }}
),

-- Livello 1.5: Estraggo il contenitore <Plans> per ogni singola CreditLine
plans_wrapper AS (
    SELECT
        cl_cte.DT_WFS_LAST_MODIFIED,
        cl_cte.CD_ORGANISATION,
        {{ get_xml_path('cl_cte.credit_line_xml', 'CreditLineReference', 'VARCHAR(17)') }} AS CD_CREDIT_LINE,
        pw.value AS plans_wrapper_xml
    FROM credit_lines cl_cte,
    {{ flatten_xml('cl_cte.credit_line_xml', 'Plans', 'pw', outer=true) }}
),

-- Livello 2: Dal contenitore, estraggo i singoli nodi <Plan> (Relazione 1 a Molti)
plans AS (
    SELECT
        pw_cte.DT_WFS_LAST_MODIFIED,
        pw_cte.CD_ORGANISATION,
        pw_cte.CD_CREDIT_LINE,
        p.value AS plan_xml
    FROM plans_wrapper pw_cte,
    {{ flatten_xml('pw_cte.plans_wrapper_xml', 'Plan', 'p', outer=true) }}
),


-- Proiezione business + watermark (ex SELECT finale insert_overwrite).
-- DT_RIFERIMENTO rimosso; watermark = DT_WFS_LAST_MODIFIED::TIMESTAMP_NTZ (trappola A).
extraction AS (
    SELECT
        CD_CREDIT_LINE AS CD_PRATICA,
        {{ get_xml_path('plan_xml', 'PlanReference', 'VARCHAR(30)') }} AS CD_PIANO,

        CD_ORGANISATION AS CD_CLIENTE,
        {{ get_xml_path('plan_xml', 'PlanAssetType', 'VARCHAR(15)') }} AS TP_VEICOLO,
        {{ get_xml_path('plan_xml', 'PlanFacility', 'VARCHAR(30)') }} AS TP_FACILITY,
        {{ get_xml_path('plan_xml', 'PercentageFunding', 'NUMBER(3,0)') }} AS PC_FINANZIATO,   -- WARN tabella: solo NUMBER

        DT_WFS_LAST_MODIFIED::TIMESTAMP_NTZ AS LASTMODIFIEDDATA
    FROM plans
    -- QUALIFY ROW_NUMBER() OVER (PARTITION BY CD_PRATICA, CD_PIANO ORDER BY DT_WFS_LAST_MODIFIED DESC) = 1  -- difensivo, off
),

storicizzazione AS (
    SELECT
        CD_PRATICA,
        CD_PIANO,
        LASTMODIFIEDDATA AS TS_INIZIO_VALIDITA,
        {{ ts_fine_validita('CD_PRATICA, CD_PIANO', 'LASTMODIFIEDDATA') }} AS TS_FINE_VALIDITA,   -- 'LASTMODIFIEDDATA' (trappola B)
        CD_CLIENTE,
        TP_VEICOLO,
        TP_FACILITY,
        PC_FINANZIATO,
        LASTMODIFIEDDATA
    FROM extraction
),

dedup AS (
    SELECT
        CD_PRATICA,
        CD_PIANO,
        TS_INIZIO_VALIDITA,
        TS_FINE_VALIDITA,
        CD_CLIENTE,
        TP_VEICOLO,
        TP_FACILITY,
        PC_FINANZIATO,
        LASTMODIFIEDDATA,
        {{ hash_cols(['CD_PRATICA', 'CD_PIANO', 'CD_CLIENTE', 'TP_VEICOLO', 'TP_FACILITY', 'PC_FINANZIATO']) }} AS HASHED_COLS
    FROM storicizzazione
    {{ is_incremental_S1('CD_PRATICA, CD_PIANO') }}
)

-- Selezione Finale: PK -> TS_INIZIO_VALIDITA -> TS_FINE_VALIDITA -> business -> LASTMODIFIEDDATA
SELECT
        CD_PRATICA,
        CD_PIANO,
        H.TS_INIZIO_VALIDITA,
        {{ ts_fine_validita('CD_PRATICA, CD_PIANO', 'H.TS_INIZIO_VALIDITA') }} AS TS_FINE_VALIDITA,   -- 'H.TS_INIZIO_VALIDITA'
        CD_CLIENTE,
        TP_VEICOLO,
        TP_FACILITY,
        PC_FINANZIATO,
        LASTMODIFIEDDATA
FROM dedup H
