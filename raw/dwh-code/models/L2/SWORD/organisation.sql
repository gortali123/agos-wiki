WITH base_data AS (
    SELECT 
        TS_RIFERIMENTO,
        DT_WFS_LAST_MODIFIED,
        PARSE_XML(GN_VALUE) AS org_xml
    FROM {{ ref('master_data') }}
),


-- Nessun flatten: org_xml E' gia' il nodo <Organisation> (grana: 1 riga per organizzazione).
-- DT_RIFERIMENTO rimosso; watermark = DT_WFS_LAST_MODIFIED::TIMESTAMP_NTZ (trappola A).
extraction AS (
    SELECT
        {{ get_xml_path('org_xml', 'OrganisationId/OrganisationReference', 'NUMBER(10,0)') }} AS CD_CLIENTE,

        {{ get_xml_path('org_xml', 'OrganisationId/OrganisationType', 'VARCHAR(10)') }} AS TP_ORGANISATION,
        {{ get_xml_path('org_xml', 'DealerType', 'VARCHAR(6)') }} AS TP_DEALER,
        {{ get_xml_path('org_xml', 'OrganisationName', 'VARCHAR(53)') }} AS DS_CONVENZIONATO,
        {{ get_xml_path('org_xml', 'Region', 'VARCHAR(7)') }} AS CD_REGIONE,
        {{ get_xml_path('org_xml', 'TaxRegistrationNumber', 'VARCHAR(12)') }} AS CD_PARTITA_IVA,
        {{ get_xml_path('org_xml', 'GlobalRiskCode', 'VARCHAR(100)') }} AS CD_RISCHIO_GLOBAL,   -- WARN tabella VARCHAR(13) ma i caratteri non corrispondono
        {{ get_xml_path('org_xml', 'LocalRiskCode', 'VARCHAR(3)') }} AS CD_RISCHIO_LOCLE,
        {{ get_xml_path('org_xml', 'RiskRating', 'VARCHAR(4)') }} AS CD_RISCHIO_VALTZ,
        {{ get_xml_path('org_xml', 'CreditLineOnStop', 'VARCHAR(2)') }} AS IN_STATUS_CONVTO,
        {{ get_xml_path('org_xml', 'NonAccural', 'VARCHAR(2)') }} AS FL_NON_ACCRUAL,
        {{ get_xml_path('org_xml', 'SalesAreaCode', 'NUMBER(3,0)') }} AS CD_SALES_AREA,
        {{ get_xml_path('org_xml', 'OrganisationStatus', 'VARCHAR(6)') }} AS CD_ORGANISATION_STATUS,
        {{ get_xml_path('org_xml', 'OrganisationLinks', 'VARCHAR(1)') }} AS CD_ORGANISATION_LINKS,
        {{ get_xml_path('org_xml', 'OrganisationActivationDate', 'VARCHAR(10)') }} AS DT_ORGANISATION_ACTIVATION,
        {{ get_xml_path('org_xml', 'BusinessCommencementDate', 'DATE') }} AS DT_ATTIVAZIONE,

        DT_WFS_LAST_MODIFIED::TIMESTAMP_NTZ AS LASTMODIFIEDDATA
    FROM base_data
    -- QUALIFY ROW_NUMBER() OVER (PARTITION BY CD_CLIENTE ORDER BY DT_WFS_LAST_MODIFIED DESC) = 1  -- difensivo, off
),

storicizzazione AS (
    SELECT
        CD_CLIENTE,
        LASTMODIFIEDDATA AS TS_INIZIO_VALIDITA,
        {{ ts_fine_validita('CD_CLIENTE', 'LASTMODIFIEDDATA') }} AS TS_FINE_VALIDITA,   -- 'LASTMODIFIEDDATA' (trappola B)
        TP_ORGANISATION,
        TP_DEALER,
        DS_CONVENZIONATO,
        CD_REGIONE,
        CD_PARTITA_IVA,
        CD_RISCHIO_GLOBAL,
        CD_RISCHIO_LOCLE,
        CD_RISCHIO_VALTZ,
        IN_STATUS_CONVTO,
        FL_NON_ACCRUAL,
        CD_SALES_AREA,
        CD_ORGANISATION_STATUS,
        CD_ORGANISATION_LINKS,
        DT_ORGANISATION_ACTIVATION,
        DT_ATTIVAZIONE,
        LASTMODIFIEDDATA
    FROM extraction
),

dedup AS (
    SELECT
        CD_CLIENTE,
        TS_INIZIO_VALIDITA,
        TS_FINE_VALIDITA,
        TP_ORGANISATION,
        TP_DEALER,
        DS_CONVENZIONATO,
        CD_REGIONE,
        CD_PARTITA_IVA,
        CD_RISCHIO_GLOBAL,
        CD_RISCHIO_LOCLE,
        CD_RISCHIO_VALTZ,
        IN_STATUS_CONVTO,
        FL_NON_ACCRUAL,
        CD_SALES_AREA,
        CD_ORGANISATION_STATUS,
        CD_ORGANISATION_LINKS,
        DT_ORGANISATION_ACTIVATION,
        DT_ATTIVAZIONE,
        LASTMODIFIEDDATA,
        {{ hash_cols(['CD_CLIENTE', 'TP_ORGANISATION', 'TP_DEALER', 'DS_CONVENZIONATO', 'CD_REGIONE', 'CD_PARTITA_IVA', 'CD_RISCHIO_GLOBAL', 'CD_RISCHIO_LOCLE', 'CD_RISCHIO_VALTZ', 'IN_STATUS_CONVTO', 'FL_NON_ACCRUAL', 'CD_SALES_AREA', 'CD_ORGANISATION_STATUS', 'CD_ORGANISATION_LINKS', 'DT_ORGANISATION_ACTIVATION', 'DT_ATTIVAZIONE']) }} AS HASHED_COLS
    FROM storicizzazione
    {{ is_incremental_S1('CD_CLIENTE') }}
)

-- Selezione Finale: PK -> TS_INIZIO_VALIDITA -> TS_FINE_VALIDITA -> business -> LASTMODIFIEDDATA
SELECT
        CD_CLIENTE,
        H.TS_INIZIO_VALIDITA,
        {{ ts_fine_validita('CD_CLIENTE', 'H.TS_INIZIO_VALIDITA') }} AS TS_FINE_VALIDITA,   -- 'H.TS_INIZIO_VALIDITA'
        TP_ORGANISATION,
        TP_DEALER,
        DS_CONVENZIONATO,
        CD_REGIONE,
        CD_PARTITA_IVA,
        CD_RISCHIO_GLOBAL,
        CD_RISCHIO_LOCLE,
        CD_RISCHIO_VALTZ,
        IN_STATUS_CONVTO,
        FL_NON_ACCRUAL,
        CD_SALES_AREA,
        CD_ORGANISATION_STATUS,
        CD_ORGANISATION_LINKS,
        DT_ORGANISATION_ACTIVATION,
        DT_ATTIVAZIONE,
        LASTMODIFIEDDATA
FROM dedup H
