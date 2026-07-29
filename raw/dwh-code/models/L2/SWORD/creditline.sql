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
        {{ get_xml_path('b.org_xml', 'OrganisationId/OrganisationReference', 'NUMBER(10,0)') }} AS CD_CLIENTE,
        clw.value AS credit_lines_xml
    FROM base_data b,
    {{ flatten_xml('b.org_xml', 'CreditLines', 'clw', outer=true) }}
),

-- Livello 1: Dal contenitore, estraggo i singoli nodi <CreditLine> (Relazione 1 a Molti)
credit_lines AS (
    SELECT 
        w.DT_WFS_LAST_MODIFIED,
        w.CD_CLIENTE,
        cl.value AS credit_line_xml
    FROM credit_lines_wrapper w,
    {{ flatten_xml('w.credit_lines_xml', 'CreditLine', 'cl', outer=true) }}
)

-- Selezione Finale: Estrazione dei campi mappati dall'Excel
SELECT 
    DT_WFS_LAST_MODIFIED AS DT_RIFERIMENTO,
    CD_CLIENTE,
    
    -- Campi DIRETTI sotto il nodo CreditLine
    {{ get_xml_path('credit_line_xml', 'CreditLineReference', 'VARCHAR(30)') }} AS CD_PRATICA, -- WARN in table NUMBER(16) ma presenta caratteri
    {{ get_xml_path('credit_line_xml', 'CreditEntityType', 'VARCHAR(12)') }} AS TP_LINEA_DI_CREDITO,
    {{ get_xml_path('credit_line_xml', 'CreditLineName', 'VARCHAR(40)') }} AS DS_NOME_LIN_CREDIT,
    {{ get_xml_path('credit_line_xml', 'ParentCreditLineReference', 'VARCHAR(20)') }} AS CD_PARENT_CREDIT_LINE,
    {{ get_xml_path('credit_line_xml', 'CreditLineStatus', 'VARCHAR(8)') }} AS CD_STATO_LIN_CRED ,
    {{ get_xml_path('credit_line_xml', 'CreditLineCalculationType', 'VARCHAR(5)') }} AS TP_CREDIT_LINE_CALCULATION, -- WARN non presente naming
    {{ get_xml_path('credit_line_xml', 'Currency', 'VARCHAR(3)') }} AS CD_CURRENCY, -- WARN non presente naming
    {{ get_xml_path('credit_line_xml', 'Restructured' ,'VARCHAR(5)') }} AS FL_RESTRUCTURED, -- WARN non presente naming
    {{ get_xml_path('credit_line_xml', 'CreditLineLoanCount', 'NUMBER') }} AS NM_CERTIFICATI, -- WARN in table NUMBER da capire cifre
    {{ get_xml_path('credit_line_xml', 'Marker','VARCHAR(1)') }} AS CD_CREDIT_LINE_MARKER, -- WARN non presente naming
    {{ get_xml_path('credit_line_xml', 'ValidForNonSupplierLoans','VARCHAR(5)') }} AS FL_VALID_NO_SUPPLIER_LOAN, -- WARN non presente naming
    {{ get_xml_path('credit_line_xml', 'ValidForAllSupplierLoans','VARCHAR(5)') }} AS FL_VALID_ALL_SUPPLIER_LOANS, -- WARN non presente naming
    {{ get_xml_path('credit_line_xml', 'ReviewDate', 'DATE') }} AS DT_REVISIONE,
    {{ get_xml_path('credit_line_xml', 'EndDate', 'DATE') }} AS DT_FINE_LIN_CREDIT,
    {{ get_xml_path('credit_line_xml', 'StartDate', 'DATE') }} AS DT_INIZIO_LIN_CREDIT,

    -- Campi INNESTATI (Sotto-nodi di CreditLine per gli importi)
    {{ get_xml_path('credit_line_xml', 'CreditLineRisk/Amount', 'NUMBER(13,2)') }} AS EU_CREDIT_LINE_RISK, -- WARN non presente naming
    {{ get_xml_path('credit_line_xml', 'CreditLineLimit/Amount', 'NUMBER(13,2)') }} AS EU_FIDO, -- WARN in table NUMBER(15) da capire se ci sono decimal
    {{ get_xml_path('credit_line_xml', 'CreditLineUtilisation/Amount', 'NUMBER(13,2)') }} AS EU_FIDO_UTZTO,
    {{ get_xml_path('credit_line_xml', 'CreditLinePipeline/Amount', 'NUMBER(13,2)') }} AS EU_ATTESA_LIQZNE,
    {{ get_xml_path('credit_line_xml', 'CreditLineClearing/Amount', 'NUMBER(13,2)') }} AS EU_COMPENSAZIONE_BANC,
    {{ get_xml_path('credit_line_xml', 'CreditLineArrears/Amount', 'NUMBER(13,2)') }} AS EU_IMPAGATO_TOT,
    
    -- Campi INNESTATI (Sotto-nodi di Guarantee)
    {{ get_xml_path('credit_line_xml', 'Guarantee/Amount', 'NUMBER(13,2)') }} AS EU_GUARANTEE, -- WARN non presente naming
    {{ get_xml_path('credit_line_xml', 'Guarantee/InLimit', 'NUMBER(10,3)') }} AS PC_GUARANTEE_IN_LIMIT, -- WARN non presente naming
    {{ get_xml_path('credit_line_xml', 'Guarantee/OverLimit', 'NUMBER(10,3)') }} AS PC_GUARANTEE_OVER_LIMIT -- WARN non presente naming

FROM credit_lines