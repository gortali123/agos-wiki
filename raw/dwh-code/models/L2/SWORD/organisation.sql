WITH base_data AS (
    SELECT 
        TS_RIFERIMENTO,
        DT_WFS_LAST_MODIFIED,
        PARSE_XML(GN_VALUE) AS org_xml
    FROM {{ ref('master_data') }}
)

-- Selezione finale: org_xml è GIA' il nodo <Organisation>, quindi partiamo da qui
SELECT     
    DT_WFS_LAST_MODIFIED AS DT_RIFERIMENTO,
    
    -- Nodi annidati sotto OrganisationId
    {{ get_xml_path('org_xml', 'OrganisationId/OrganisationReference', 'NUMBER(10,0)') }} AS CD_CLIENTE,
    {{ get_xml_path('org_xml', 'OrganisationId/OrganisationType', 'VARCHAR(10)') }} AS TP_ORGANISATION,
    
    -- Nodi diretti sotto Organisation
    {{ get_xml_path('org_xml', 'DealerType', 'VARCHAR(6)') }} AS TP_DEALER,
    {{ get_xml_path('org_xml', 'OrganisationName', 'VARCHAR(53)') }} AS DS_CONVENZIONATO,
    {{ get_xml_path('org_xml', 'Region', 'VARCHAR(7)') }} AS CD_REGIONE,
    {{ get_xml_path('org_xml', 'TaxRegistrationNumber', 'VARCHAR(12)') }} AS CD_PARTITA_IVA,
    {{ get_xml_path('org_xml', 'GlobalRiskCode', 'VARCHAR(100)') }} AS CD_RISCHIO_GLOBAL, --WARN in table VARCHAR(13) ma non corrispondono caratteri
    {{ get_xml_path('org_xml', 'LocalRiskCode', 'VARCHAR(3)') }} AS CD_RISCHIO_LOCLE,
    {{ get_xml_path('org_xml', 'RiskRating', 'VARCHAR(4)') }} AS CD_RISCHIO_VALTZ,
    {{ get_xml_path('org_xml', 'CreditLineOnStop', 'VARCHAR(2)') }} AS IN_STATUS_CONVTO,
    {{ get_xml_path('org_xml', 'NonAccural', 'VARCHAR(2)') }} AS FL_NON_ACCRUAL,
    {{ get_xml_path('org_xml', 'SalesAreaCode', 'NUMBER(3,0)') }} AS CD_SALES_AREA, 
    
    {{ get_xml_path('org_xml', 'OrganisationStatus', 'VARCHAR(6)') }} AS CD_ORGANISATION_STATUS,
    {{ get_xml_path('org_xml', 'OrganisationLinks', 'VARCHAR(1)') }} AS CD_ORGANISATION_LINKS,
    {{ get_xml_path('org_xml', 'OrganisationActivationDate', 'VARCHAR(10)') }} AS DT_ORGANISATION_ACTIVATION,
    {{ get_xml_path('org_xml', 'BusinessCommencementDate', 'DATE') }} AS DT_ATTIVAZIONE

FROM base_data