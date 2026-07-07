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
)

-- Selezione Finale
SELECT 
    DT_WFS_LAST_MODIFIED AS DT_RIFERIMENTO,
    CD_ORGANISATION AS CD_CLIENTE,
    CD_CREDIT_LINE AS CD_PRATICA,
    
    -- Essendo AssetType il nodo foglia (es. <AssetType>CAR</AssetType>), 
    -- ne estraggo direttamente il valore testuale con il cast a VARCHAR
    asset_type_xml:"$"::VARCHAR(15) AS TP_VEICOLO

FROM asset_types