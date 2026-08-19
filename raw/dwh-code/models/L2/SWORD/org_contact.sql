WITH base_data AS (
    SELECT 
        TS_RIFERIMENTO,
        DT_WFS_LAST_MODIFIED,
        PARSE_XML(GN_VALUE) AS org_xml
    FROM {{ ref('master_data') }}
),

-- Livello 0.5: Contenitore <Contacts>
contacts_wrapper AS (
    SELECT 
        b.DT_WFS_LAST_MODIFIED,
        -- Estraggo la reference dell'organizzazione usando il percorso standard
        {{ get_xml_path('b.org_xml', 'OrganisationId/OrganisationReference', 'NUMBER(10,0)') }} AS CD_ORGANISATION,
        cw.value AS contacts_wrapper_xml
    FROM base_data b,
    {{ flatten_xml('b.org_xml', 'Contacts', 'cw', outer=true) }}
),

-- Livello 1: Nodi <Contact> (Relazione 1 a Molti)
contacts AS (
    SELECT 
        cw_cte.DT_WFS_LAST_MODIFIED,
        cw_cte.CD_ORGANISATION,
        c.value AS contact_xml
    FROM contacts_wrapper cw_cte,
    {{ flatten_xml('cw_cte.contacts_wrapper_xml', 'Contact', 'c', outer=true) }}
),


-- Proiezione business + watermark (ex SELECT finale insert_overwrite).
-- DT_RIFERIMENTO rimosso; watermark = DT_WFS_LAST_MODIFIED::TIMESTAMP_NTZ (trappola A).
extraction AS (
    SELECT
        CD_ORGANISATION AS CD_CLIENTE,
        {{ get_xml_path('contact_xml', 'ContactReference', 'VARCHAR') }} AS CD_GARANTE,   -- WARN tabella NUMBER ma presenta caratteri -> VARCHAR

        {{ get_xml_path('contact_xml', 'ContactTitle', 'VARCHAR') }} AS CD_CONTACT_TITLE,
        {{ get_xml_path('contact_xml', 'ContactType', 'VARCHAR') }} AS TP_CONTACT,
        {{ get_xml_path('contact_xml', 'Email', 'VARCHAR(50)') }} AS DS_EMAIL,
        {{ get_xml_path('contact_xml', 'Fax', 'VARCHAR(1)') }} AS DS_FAX,
        {{ get_xml_path('contact_xml', 'FirstName', 'VARCHAR') }} AS DS_FIRST_NAME,
        {{ get_xml_path('contact_xml', 'LastName', 'VARCHAR') }} AS DS_LAST_NAME,
        {{ get_xml_path('contact_xml', 'Phone', 'VARCHAR(15)') }} AS DS_PHONE,
        {{ get_xml_path('contact_xml', 'Position', 'VARCHAR') }} AS DS_POSITION,

        {{ get_xml_path('contact_xml', 'Address/AddressLine4', 'VARCHAR') }} AS DS_ADDRESS_LINE_4,
        {{ get_xml_path('contact_xml', 'Address/Country', 'VARCHAR(30)') }} AS CD_COUNTRY,
        {{ get_xml_path('contact_xml', 'Address/Locality', 'VARCHAR(1)') }} AS DS_LOCALITY,
        {{ get_xml_path('contact_xml', 'Address/LocationCode', 'VARCHAR(1)') }} AS CD_LOCATION,
        {{ get_xml_path('contact_xml', 'Address/LocationReference', 'VARCHAR(30)') }} AS CD_LOCATION_REFERENCE,
        CASE
            WHEN {{ get_xml_path('contact_xml', 'Address/PostCode', 'VARCHAR') }} = ''
                 OR {{ get_xml_path('contact_xml', 'Address/PostCode', 'NUMBER') }} IS NULL
            THEN NULL
            ELSE {{ get_xml_path('contact_xml', 'Address/PostCode', 'NUMBER(5,0)') }}
        END AS CD_POSTCODE,   -- CASE WHEN: PostCode vuoto -> NULL (altrimenti cast a NUMBER impossibile)
        {{ get_xml_path('contact_xml', 'Address/PostTown', 'VARCHAR') }} AS DS_POST_TOWN,
        {{ get_xml_path('contact_xml', 'Address/PropertyNumber', 'VARCHAR(20)') }} AS CD_PROPERTY_NUMBER,
        {{ get_xml_path('contact_xml', 'Address/Street', 'VARCHAR') }} AS DS_STREET,

        DT_WFS_LAST_MODIFIED::TIMESTAMP_NTZ AS LASTMODIFIEDDATA
    FROM contacts
    -- QUALIFY ROW_NUMBER() OVER (PARTITION BY CD_CLIENTE, CD_GARANTE ORDER BY DT_WFS_LAST_MODIFIED DESC) = 1  -- difensivo, off
),

storicizzazione AS (
    SELECT
        CD_CLIENTE,
        CD_GARANTE,
        LASTMODIFIEDDATA AS TS_INIZIO_VALIDITA,
        {{ ts_fine_validita('CD_CLIENTE, CD_GARANTE', 'LASTMODIFIEDDATA') }} AS TS_FINE_VALIDITA,   -- 'LASTMODIFIEDDATA' (trappola B)
        CD_CONTACT_TITLE,
        TP_CONTACT,
        DS_EMAIL,
        DS_FAX,
        DS_FIRST_NAME,
        DS_LAST_NAME,
        DS_PHONE,
        DS_POSITION,
        DS_ADDRESS_LINE_4,
        CD_COUNTRY,
        DS_LOCALITY,
        CD_LOCATION,
        CD_LOCATION_REFERENCE,
        CD_POSTCODE,
        DS_POST_TOWN,
        CD_PROPERTY_NUMBER,
        DS_STREET,
        LASTMODIFIEDDATA
    FROM extraction
),

dedup AS (
    SELECT
        CD_CLIENTE,
        CD_GARANTE,
        TS_INIZIO_VALIDITA,
        TS_FINE_VALIDITA,
        CD_CONTACT_TITLE,
        TP_CONTACT,
        DS_EMAIL,
        DS_FAX,
        DS_FIRST_NAME,
        DS_LAST_NAME,
        DS_PHONE,
        DS_POSITION,
        DS_ADDRESS_LINE_4,
        CD_COUNTRY,
        DS_LOCALITY,
        CD_LOCATION,
        CD_LOCATION_REFERENCE,
        CD_POSTCODE,
        DS_POST_TOWN,
        CD_PROPERTY_NUMBER,
        DS_STREET,
        LASTMODIFIEDDATA,
        {{ hash_cols(['CD_CLIENTE', 'CD_GARANTE', 'CD_CONTACT_TITLE', 'TP_CONTACT', 'DS_EMAIL', 'DS_FAX', 'DS_FIRST_NAME', 'DS_LAST_NAME', 'DS_PHONE', 'DS_POSITION', 'DS_ADDRESS_LINE_4', 'CD_COUNTRY', 'DS_LOCALITY', 'CD_LOCATION', 'CD_LOCATION_REFERENCE', 'CD_POSTCODE', 'DS_POST_TOWN', 'CD_PROPERTY_NUMBER', 'DS_STREET']) }} AS HASHED_COLS
    FROM storicizzazione
    {{ is_incremental_S1('CD_CLIENTE, CD_GARANTE') }}
)

-- Selezione Finale: PK -> TS_INIZIO_VALIDITA -> TS_FINE_VALIDITA -> business -> LASTMODIFIEDDATA
SELECT
        CD_CLIENTE,
        CD_GARANTE,
        H.TS_INIZIO_VALIDITA,
        {{ ts_fine_validita('CD_CLIENTE, CD_GARANTE', 'H.TS_INIZIO_VALIDITA') }} AS TS_FINE_VALIDITA,   -- 'H.TS_INIZIO_VALIDITA'
        CD_CONTACT_TITLE,
        TP_CONTACT,
        DS_EMAIL,
        DS_FAX,
        DS_FIRST_NAME,
        DS_LAST_NAME,
        DS_PHONE,
        DS_POSITION,
        DS_ADDRESS_LINE_4,
        CD_COUNTRY,
        DS_LOCALITY,
        CD_LOCATION,
        CD_LOCATION_REFERENCE,
        CD_POSTCODE,
        DS_POST_TOWN,
        CD_PROPERTY_NUMBER,
        DS_STREET,
        LASTMODIFIEDDATA
FROM dedup H
