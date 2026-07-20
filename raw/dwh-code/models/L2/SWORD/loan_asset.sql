WITH base_data AS (
    SELECT 
        TS_RIFERIMENTO,
        DT_WFS_LAST_MODIFIED,
        PARSE_XML(GN_VALUE) AS org_xml
    FROM {{ ref('master_data') }}
),

-- Livello 0.5: Contenitore <CreditLines>
credit_lines_wrapper AS (
    SELECT 
        b.DT_WFS_LAST_MODIFIED,
        {{ get_xml_path('b.org_xml', 'OrganisationId/OrganisationReference' , 'NUMBER(10,0)') }} AS CD_ORGANISATION,
        clw.value AS credit_lines_wrapper_xml
    FROM base_data b,
    {{ flatten_xml('b.org_xml', 'CreditLines', 'clw', outer=true) }}
),

-- Livello 1: Nodi <CreditLine>
credit_lines AS (
    SELECT 
        w.DT_WFS_LAST_MODIFIED,
        w.CD_ORGANISATION,
        cl.value AS credit_line_xml
    FROM credit_lines_wrapper w,
    {{ flatten_xml('w.credit_lines_wrapper_xml', 'CreditLine', 'cl', outer=true) }}
),

-- Livello 1.5: Contenitore <Plans>
plans_wrapper AS (
    SELECT
        cl_cte.DT_WFS_LAST_MODIFIED,
        cl_cte.CD_ORGANISATION,
        {{ get_xml_path('cl_cte.credit_line_xml', 'CreditLineReference', 'VARCHAR(17)') }} AS CD_CREDIT_LINE,
        pw.value AS plans_wrapper_xml
    FROM credit_lines cl_cte,
    {{ flatten_xml('cl_cte.credit_line_xml', 'Plans', 'pw', outer=true) }}
),

-- Livello 2: Nodi <Plan>
plans AS (
    SELECT
        pw_cte.DT_WFS_LAST_MODIFIED,
        pw_cte.CD_ORGANISATION,
        pw_cte.CD_CREDIT_LINE,
        p.value AS plan_xml
    FROM plans_wrapper pw_cte,
    {{ flatten_xml('pw_cte.plans_wrapper_xml', 'Plan', 'p', outer=true) }}
),

-- Livello 2.5: Contenitore <Loans>
loans_wrapper AS (
    SELECT
        p_cte.DT_WFS_LAST_MODIFIED,
        p_cte.CD_ORGANISATION,
        p_cte.CD_CREDIT_LINE,
        {{ get_xml_path('p_cte.plan_xml', 'PlanReference', 'VARCHAR(30)') }} AS CD_PLAN,
        lw.value AS loans_wrapper_xml
    FROM plans p_cte,
    {{ flatten_xml('p_cte.plan_xml', 'Loans', 'lw', outer=true) }}
),

-- Livello 3: Nodi <Loan>
loans AS (
    SELECT
        lw_cte.DT_WFS_LAST_MODIFIED,
        lw_cte.CD_ORGANISATION,
        lw_cte.CD_CREDIT_LINE,
        lw_cte.CD_PLAN,
        l.value AS loan_xml
    FROM loans_wrapper lw_cte,
    {{ flatten_xml('lw_cte.loans_wrapper_xml', 'Loan', 'l', outer=true) }}
)

-- Selezione Finale: Estrazione dei campi Asset dal nodo <Loan>
SELECT 
    DT_WFS_LAST_MODIFIED AS DT_RIFERIMENTO,
    CD_ORGANISATION AS CD_CLIENTE,
    CD_CREDIT_LINE AS CD_PRATICA,
    CD_PLAN AS CD_PIANO,
    
    -- ID del prestito
    {{ get_xml_path('loan_xml', 'LoanID', 'NUMBER(9,0)') }} AS CD_CERTIFICATO, -- WARN in table solo NUMBER 
    
    -- Sezione PurchasePrice
    {{ get_xml_path('loan_xml', 'Asset/PurchasePrice/Gross', 'NUMBER(13,2)') }} AS EU_PURCHASE_PRICE_GROSS,
    {{ get_xml_path('loan_xml', 'Asset/PurchasePrice/Nett', 'NUMBER(13,2)') }} AS EU_PURCHASE_PRICE_NET,
    {{ get_xml_path('loan_xml', 'Asset/PurchasePrice/Tax', 'NUMBER(13,2)') }} AS EU_PURCHASE_PRICE_TAX,
    
    -- Sezione Valuation
    {{ get_xml_path('loan_xml', 'Asset/Valuation/Gross', 'NUMBER(13,2)') }} AS EU_VALUATION_GROSS,
    {{ get_xml_path('loan_xml', 'Asset/Valuation/Nett', 'NUMBER(13,2)') }} AS EU_VALUATION_NET,
    {{ get_xml_path('loan_xml', 'Asset/Valuation/Tax', 'NUMBER(13,2)') }} AS EU_VALUATION_TAX,
    
    -- Dati identificativi dell'Asset
    {{ get_xml_path('loan_xml', 'Asset/Identifier', 'VARCHAR(3)') }} AS CD_IDENTIFIER,
    {{ get_xml_path('loan_xml', 'Asset/Identification', 'VARCHAR(17)') }} AS DS_TELAIO,
    {{ get_xml_path('loan_xml', 'Asset/StockNumber', 'VARCHAR(1)') }} AS CD_STOCK_NUMBER,
    {{ get_xml_path('loan_xml', 'Asset/InvoiceNumber', 'VARCHAR(17)') }} AS DS_NUMERO_FATTURA_NM,
    {{ get_xml_path('loan_xml', 'Asset/Make', 'VARCHAR(35)') }} AS DS_MARCA_VEIC,
    {{ get_xml_path('loan_xml', 'Asset/MakeCode', 'VARCHAR(1)') }} AS CD_MAKE,
    {{ get_xml_path('loan_xml', 'Asset/Model', 'VARCHAR(54)') }} AS DS_MODELLO_VEIC,
    CASE 
    WHEN {{ get_xml_path('loan_xml', 'Asset/ConstructionYear', 'VARCHAR') }} = '' 
         OR {{ get_xml_path('loan_xml', 'Asset/ConstructionYear', 'NUMBER') }} IS NULL 
    THEN NULL  
    ELSE {{ get_xml_path('loan_xml', 'Asset/ConstructionYear', 'NUMBER(4,0)') }}  
    END AS DS_ANNO_COSTRZ, -- FIX aggiunto CASE WHEN per gestione spazi vuoti come NULL altrimenti non possibile cast a number
    -- Documenti e Targa
    {{ get_xml_path('loan_xml', 'Asset/Title/DocumentNumber', 'VARCHAR(1)') }} AS CD_DOCUMENT_NUMBER,
    {{ get_xml_path('loan_xml', 'Asset/Plate', 'VARCHAR(20)') }} AS DS_TARGA,
    {{ get_xml_path('loan_xml', 'Asset/Baumuster', 'VARCHAR(1)') }} AS CD_BAUMUSTER,
    {{ get_xml_path('loan_xml', 'Asset/ChassisNumber', 'VARCHAR(17)') }} AS CD_CHASSIS_NUMBER,
    {{ get_xml_path('loan_xml', 'Asset/CommissionNumber', 'VARCHAR(1)') }} AS CD_COMMISSION_NUMBER,
    
    -- Metriche ed Extra
    {{ get_xml_path('loan_xml', 'Asset/VehicleInStockDays', 'NUMBER') }} AS NM_GIORNI_DEP, -- WARN in table solo NUMBER
    {{ get_xml_path('loan_xml', 'Asset/DistanceTravelled/Distance', 'NUMBER') }} AS NM_DISTANZA_PERCRS, -- WARN in table solo NUMBER
    {{ get_xml_path('loan_xml', 'Asset/DistanceTravelled/DistanceUnitType', 'VARCHAR(10)') }} AS DS_UNITA_MSRA,
    {{ get_xml_path('loan_xml', 'Asset/Location', 'VARCHAR(40)') }} AS DS_LOCATION,
    {{ get_xml_path('loan_xml', 'Asset/Supplier', 'VARCHAR(1)') }} AS CD_SUPPLIER,
    {{ get_xml_path('loan_xml', 'Asset/ThirdParty', 'VARCHAR(1)') }} AS CD_THIRD_PARTY,
    {{ get_xml_path('loan_xml', 'Asset/RegistrationDate', 'DATE') }} AS DT_REGISTRAZIONE_VEIC

FROM loans