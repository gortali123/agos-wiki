WITH base_data AS (
    SELECT
        TRY_CAST(TS_RIFERIMENTO AS TIMESTAMP_NTZ) AS TS_RIFERIMENTO,
        TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ) AS TS_CARICAMENTO,
        value::VARIANT AS value
    FROM {{ source('source_l0','master_data') }}
),
parsed AS (
    SELECT 
        TS_RIFERIMENTO,
        TS_CARICAMENTO,
        PARSE_XML(value) AS feed_xml
    FROM base_data
),
feed_level AS (
    SELECT 
        TS_RIFERIMENTO,
        TS_CARICAMENTO,
        feed_xml,
        XMLGET(feed_xml, 'WFSDate'):"$"::DATE AS DT_WFS_LAST_MODIFIED
    FROM parsed
),
all_organisation_data AS (
    SELECT 
        f.TS_RIFERIMENTO,
        f.TS_CARICAMENTO,
        f.DT_WFS_LAST_MODIFIED,
        macro_tag.value AS org_data_xml
    FROM feed_level f,
    LATERAL FLATTEN(input => f.feed_xml:"$") macro_tag
    WHERE macro_tag.value:"@"::VARCHAR = 'OrganisationData'
),
organisations AS (
    SELECT 
        aod.TS_RIFERIMENTO,
        aod.TS_CARICAMENTO,
        aod.DT_WFS_LAST_MODIFIED,
        org.value AS GN_VALUE
    FROM all_organisation_data aod,
    LATERAL FLATTEN(input => aod.org_data_xml:"$") org
    WHERE org.value:"@"::VARCHAR = 'Organisation'
)
SELECT 
    TS_RIFERIMENTO,
    TS_CARICAMENTO,
    DT_WFS_LAST_MODIFIED,
    GN_VALUE
FROM organisations
