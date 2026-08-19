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

-- Livello 1.5: Estraggo il contenitore <CreditLineAssetTypes> per ogni CreditLine
asset_types_wrapper AS (
    SELECT
        cl_cte.DT_WFS_LAST_MODIFIED,
        cl_cte.CD_ORGANISATION,
        {{ get_xml_path('cl_cte.credit_line_xml', 'CreditLineReference', 'VARCHAR(30)') }} AS CD_CREDIT_LINE, -- WARN in table NUMBER(16) ma presenta caratteri
        atw.value AS asset_types_wrapper_xml
    FROM credit_lines cl_cte,
    {{ flatten_xml('cl_cte.credit_line_xml', 'CreditLineAssetTypes', 'atw', outer=true) }}
),

-- Livello 2: Estraggo i singoli nodi <AssetType> (Genera N righe per ogni CreditLine)
asset_types AS (
    SELECT
        atw_cte.DT_WFS_LAST_MODIFIED,
        atw_cte.CD_ORGANISATION,
        atw_cte.CD_CREDIT_LINE,
        -- at_cte.value rappresenta il nodo <AssetType> stesso
        at_cte.value AS asset_type_xml
    FROM asset_types_wrapper atw_cte,
    {{ flatten_xml('atw_cte.asset_types_wrapper_xml', 'AssetType', 'at_cte', outer=true) }}
),

-- Proiezione business + watermark (ex SELECT finale del modello insert_overwrite).
-- DT_RIFERIMENTO rimosso; DT_WFS_LAST_MODIFIED diventa il watermark LASTMODIFIEDDATA
-- con cast ::TIMESTAMP_NTZ (NON custom_to_timestamp_ntz: e' gia' un DATE/TIMESTAMP -> trappola A).
extraction AS (
    SELECT
        CD_CREDIT_LINE AS CD_PRATICA,
        asset_type_xml:"$"::VARCHAR(15) AS TP_VEICOLO,
        CD_ORGANISATION AS CD_CLIENTE,
        DT_WFS_LAST_MODIFIED::TIMESTAMP_NTZ AS LASTMODIFIEDDATA
    FROM asset_types
    -- Difensivo, OFF: riattivare solo se lo snapshot puo' avere righe duplicate per (CD_PRATICA, TP_VEICOLO)
    -- nello stesso giorno (es. AssetType ripetuto sullo stesso CreditLine, o piu' righe master_data).
    -- QUALIFY ROW_NUMBER() OVER (PARTITION BY CD_PRATICA, TP_VEICOLO ORDER BY DT_WFS_LAST_MODIFIED DESC) = 1
),

storicizzazione AS (
    SELECT
        CD_PRATICA,
        TP_VEICOLO,
        LASTMODIFIEDDATA AS TS_INIZIO_VALIDITA,
        {{ ts_fine_validita('CD_PRATICA, TP_VEICOLO', 'LASTMODIFIEDDATA') }} AS TS_FINE_VALIDITA,   -- qui 'LASTMODIFIEDDATA' (alias H inesistente -> trappola B)
        CD_CLIENTE,
        LASTMODIFIEDDATA
    FROM extraction
),

dedup AS (
    SELECT
        CD_PRATICA,
        TP_VEICOLO,
        TS_INIZIO_VALIDITA,
        TS_FINE_VALIDITA,
        CD_CLIENTE,
        LASTMODIFIEDDATA,
        {{ hash_cols(['CD_PRATICA', 'TP_VEICOLO', 'CD_CLIENTE']) }} AS HASHED_COLS   -- PK + business, no TS_*, no LASTMODIFIEDDATA
    FROM storicizzazione
    {{ is_incremental_S1('CD_PRATICA, TP_VEICOLO') }}
)

-- Selezione Finale: PK -> TS_INIZIO_VALIDITA -> TS_FINE_VALIDITA -> business -> LASTMODIFIEDDATA
SELECT
    CD_PRATICA,
    TP_VEICOLO,
    H.TS_INIZIO_VALIDITA,
    {{ ts_fine_validita('CD_PRATICA, TP_VEICOLO', 'H.TS_INIZIO_VALIDITA') }} AS TS_FINE_VALIDITA,   -- qui 'H.TS_INIZIO_VALIDITA'
    CD_CLIENTE,
    LASTMODIFIEDDATA
FROM dedup H