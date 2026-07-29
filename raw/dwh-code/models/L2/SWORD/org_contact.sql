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
)

-- Selezione Finale: Estrazione campi dal nodo <Contact>
SELECT 
    DT_WFS_LAST_MODIFIED AS DT_RIFERIMENTO,
    CD_ORGANISATION AS CD_CLIENTE,
    
    -- Campi DIRETTI sotto il nodo Contact
    {{ get_xml_path('contact_xml', 'ContactReference', 'VARCHAR') }} AS CD_GARANTE, -- WARN in table NUMBER ma presenta caratteri
    {{ get_xml_path('contact_xml', 'ContactTitle', 'VARCHAR') }} AS CD_CONTACT_TITLE,
    {{ get_xml_path('contact_xml', 'ContactType', 'VARCHAR') }} AS TP_CONTACT,
    {{ get_xml_path('contact_xml', 'Email', 'VARCHAR(50)') }} AS DS_EMAIL,
    {{ get_xml_path('contact_xml', 'Fax', 'VARCHAR(1)') }} AS DS_FAX,
    {{ get_xml_path('contact_xml', 'FirstName', 'VARCHAR') }} AS DS_FIRST_NAME,
    {{ get_xml_path('contact_xml', 'LastName', 'VARCHAR') }} AS DS_LAST_NAME,
    {{ get_xml_path('contact_xml', 'Phone', 'VARCHAR(15)') }} AS DS_PHONE,
    {{ get_xml_path('contact_xml', 'Position', 'VARCHAR') }} AS DS_POSITION,

    -- Campi ANNIDATI sotto il nodo Address
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
    END AS CD_POSTCODE,
    {{ get_xml_path('contact_xml', 'Address/PostTown', 'VARCHAR') }} AS DS_POST_TOWN,
    {{ get_xml_path('contact_xml', 'Address/PropertyNumber', 'VARCHAR(20)') }} AS CD_PROPERTY_NUMBER,
    {{ get_xml_path('contact_xml', 'Address/Street', 'VARCHAR') }} AS DS_STREET

FROM contacts