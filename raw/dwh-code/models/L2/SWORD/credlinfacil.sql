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

-- Livello 1: Estraggo i singoli nodi <CreditLine>
credit_lines AS (
    SELECT 
        w.DT_WFS_LAST_MODIFIED,
        w.CD_ORGANISATION,
        cl.value AS credit_line_xml
    FROM credit_lines_wrapper w,
    {{ flatten_xml('w.credit_lines_xml', 'CreditLine', 'cl', outer=true) }}
),

-- Livello 1.5: Estraggo il contenitore <CreditLineFacilities> per ogni CreditLine
facilities_wrapper AS (
    SELECT
        cl_cte.DT_WFS_LAST_MODIFIED,
        cl_cte.CD_ORGANISATION,
        {{ get_xml_path('cl_cte.credit_line_xml', 'CreditLineReference', 'VARCHAR(25)') }} AS CD_CREDIT_LINE,
        fct.value AS facilities_wrapper_xml
    FROM credit_lines cl_cte,
    {{ flatten_xml('cl_cte.credit_line_xml', 'CreditLineFacilities', 'fct', outer=true) }}
),

-- Livello 2: Estraggo i singoli nodi <Facility> (Genera N righe per ogni CreditLine)
facility_types AS (
    SELECT
        atw_cte.DT_WFS_LAST_MODIFIED,
        atw_cte.CD_ORGANISATION,
        atw_cte.CD_CREDIT_LINE,
        -- fct_cte.value rappresenta il nodo <Facility> stesso
        fct_cte.value AS facility_type_xml
    FROM facilities_wrapper atw_cte,
    {{ flatten_xml('atw_cte.facilities_wrapper_xml', 'Facility', 'fct_cte', outer=true) }}
),

-- Proiezione business + watermark (ex SELECT finale del modello insert_overwrite).
-- DT_RIFERIMENTO rimosso; DT_WFS_LAST_MODIFIED diventa il watermark LASTMODIFIEDDATA
-- con cast ::TIMESTAMP_NTZ (NON custom_to_timestamp_ntz: e' gia' un DATE/TIMESTAMP -> trappola A).
extraction AS (
    SELECT
        CD_CREDIT_LINE AS CD_PRATICA,
        facility_type_xml:"$"::VARCHAR(25) AS TP_FACILITY,   -- WARN in table VARCHAR(11) ma non corrisponde con i dati
        CD_ORGANISATION AS CD_CLIENTE,
        DT_WFS_LAST_MODIFIED::TIMESTAMP_NTZ AS LASTMODIFIEDDATA
    FROM facility_types
    -- Difensivo, OFF: riattivare solo se lo snapshot puo' avere righe duplicate per (CD_PRATICA, TP_FACILITY)
    -- nello stesso giorno (es. Facility ripetuta sullo stesso CreditLine, o piu' righe master_data).
    -- QUALIFY ROW_NUMBER() OVER (PARTITION BY CD_PRATICA, TP_FACILITY ORDER BY DT_WFS_LAST_MODIFIED DESC) = 1
),

storicizzazione AS (
    SELECT
        CD_PRATICA,
        TP_FACILITY,
        LASTMODIFIEDDATA AS TS_INIZIO_VALIDITA,
        {{ ts_fine_validita('CD_PRATICA, TP_FACILITY', 'LASTMODIFIEDDATA') }} AS TS_FINE_VALIDITA,   -- qui 'LASTMODIFIEDDATA' (alias H inesistente -> trappola B)
        CD_CLIENTE,
        LASTMODIFIEDDATA
    FROM extraction
),

dedup AS (
    SELECT
        CD_PRATICA,
        TP_FACILITY,
        TS_INIZIO_VALIDITA,
        TS_FINE_VALIDITA,
        CD_CLIENTE,
        LASTMODIFIEDDATA,
        {{ hash_cols(['CD_PRATICA', 'TP_FACILITY', 'CD_CLIENTE']) }} AS HASHED_COLS   -- PK + business, no TS_*, no LASTMODIFIEDDATA
    FROM storicizzazione
    {{ is_incremental_S1('CD_PRATICA, TP_FACILITY') }}
)

-- Selezione Finale: PK -> TS_INIZIO_VALIDITA -> TS_FINE_VALIDITA -> business -> LASTMODIFIEDDATA
SELECT
    CD_PRATICA,
    TP_FACILITY,
    H.TS_INIZIO_VALIDITA,
    {{ ts_fine_validita('CD_PRATICA, TP_FACILITY', 'H.TS_INIZIO_VALIDITA') }} AS TS_FINE_VALIDITA,   -- qui 'H.TS_INIZIO_VALIDITA'
    CD_CLIENTE,
    LASTMODIFIEDDATA
FROM dedup H
