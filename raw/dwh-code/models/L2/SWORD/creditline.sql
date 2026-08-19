WITH base_data AS (
    SELECT
        TS_RIFERIMENTO,
        DT_WFS_LAST_MODIFIED,
        PARSE_XML(GN_VALUE) AS org_xml
    FROM {{ ref('master_data') }}
),

-- Livello 0.5: contenitore <CreditLines> in sicurezza
credit_lines_wrapper AS (
    SELECT
        b.DT_WFS_LAST_MODIFIED,
        {{ get_xml_path('b.org_xml', 'OrganisationId/OrganisationReference', 'NUMBER(10,0)') }} AS CD_CLIENTE,
        clw.value AS credit_lines_xml
    FROM base_data b,
    {{ flatten_xml('b.org_xml', 'CreditLines', 'clw', outer=true) }}
),

-- Livello 1: singoli nodi <CreditLine> (1 a molti)
credit_lines AS (
    SELECT
        w.DT_WFS_LAST_MODIFIED,
        w.CD_CLIENTE,
        cl.value AS credit_line_xml
    FROM credit_lines_wrapper w,
    {{ flatten_xml('w.credit_lines_xml', 'CreditLine', 'cl', outer=true) }}
),

extraction AS (
    SELECT
        CD_CLIENTE,
        {{ get_xml_path('credit_line_xml', 'CreditLineReference', 'VARCHAR(30)') }} AS CD_PRATICA,
        {{ get_xml_path('credit_line_xml', 'CreditLineName', 'VARCHAR(40)') }} AS DS_NOME_LIN_CREDIT,
        {{ get_xml_path('credit_line_xml', 'CreditEntityType', 'VARCHAR(12)') }} AS TP_LINEA_DI_CREDITO,
        {{ get_xml_path('credit_line_xml', 'ParentCreditLineReference', 'VARCHAR(20)') }} AS CD_PARENT_CREDIT_LINE,
        {{ get_xml_path('credit_line_xml', 'CreditLineStatus', 'VARCHAR(8)') }} AS CD_STATO_LIN_CRED,
        {{ get_xml_path('credit_line_xml', 'CreditLineCalculationType', 'VARCHAR(5)') }} AS TP_CREDIT_LINE_CALCULATION, -- WARN non presente naming
        {{ get_xml_path('credit_line_xml', 'Currency', 'VARCHAR(3)') }} AS CD_CURRENCY, -- WARN non presente naming
        {{ get_xml_path('credit_line_xml', 'Restructured', 'VARCHAR(5)') }} AS FL_RESTRUCTURED, -- WARN non presente naming
        {{ get_xml_path('credit_line_xml', 'CreditLineLoanCount', 'NUMBER') }} AS NM_CERTIFICATI, -- WARN in table NUMBER da capire cifre
        {{ get_xml_path('credit_line_xml', 'Marker', 'VARCHAR(1)') }} AS CD_CREDIT_LINE_MARKER, -- WARN non presente naming
        {{ get_xml_path('credit_line_xml', 'ValidForNonSupplierLoans', 'VARCHAR(5)') }} AS FL_VALID_NO_SUPPLIER_LOAN, -- WARN non presente naming
        {{ get_xml_path('credit_line_xml', 'ValidForAllSupplierLoans', 'VARCHAR(5)') }} AS FL_VALID_ALL_SUPPLIER_LOANS, -- WARN non presente naming
        {{ get_xml_path('credit_line_xml', 'ReviewDate', 'DATE') }} AS DT_REVISIONE,
        {{ get_xml_path('credit_line_xml', 'EndDate', 'DATE') }} AS DT_FINE_LIN_CREDIT,
        {{ get_xml_path('credit_line_xml', 'StartDate', 'DATE') }} AS DT_INIZIO_LIN_CREDIT,
        {{ get_xml_path('credit_line_xml', 'CreditLineRisk/Amount', 'NUMBER(13,2)') }} AS EU_CREDIT_LINE_RISK, -- WARN non presente naming
        {{ get_xml_path('credit_line_xml', 'CreditLineLimit/Amount', 'NUMBER(13,2)') }} AS EU_FIDO, -- WARN in table NUMBER(15) da capire decimali
        {{ get_xml_path('credit_line_xml', 'CreditLineUtilisation/Amount', 'NUMBER(13,2)') }} AS EU_FIDO_UTZTO,
        {{ get_xml_path('credit_line_xml', 'CreditLinePipeline/Amount', 'NUMBER(13,2)') }} AS EU_ATTESA_LIQZNE,
        {{ get_xml_path('credit_line_xml', 'CreditLineClearing/Amount', 'NUMBER(13,2)') }} AS EU_COMPENSAZIONE_BANC,
        {{ get_xml_path('credit_line_xml', 'CreditLineArrears/Amount', 'NUMBER(13,2)') }} AS EU_IMPAGATO_TOT,
        {{ get_xml_path('credit_line_xml', 'Guarantee/Amount', 'NUMBER(13,2)') }} AS EU_GUARANTEE, -- WARN non presente naming
        {{ get_xml_path('credit_line_xml', 'Guarantee/InLimit', 'NUMBER(10,3)') }} AS PC_GUARANTEE_IN_LIMIT, -- WARN non presente naming
        {{ get_xml_path('credit_line_xml', 'Guarantee/OverLimit', 'NUMBER(10,3)') }} AS PC_GUARANTEE_OVER_LIMIT, -- WARN non presente naming
        DT_WFS_LAST_MODIFIED::TIMESTAMP_NTZ AS LASTMODIFIEDDATA
    FROM credit_lines
    -- Difensivo anti-duplicati: la sorgente garantisce unicità di (CD_CLIENTE, CD_PRATICA)
    -- nello snapshot, quindi disattivato. Riattivare se venisse meno quella garanzia
    -- (es. più righe master_data per organisation nello stesso giorno, o nodi CreditLine ripetuti).
    -- QUALIFY ROW_NUMBER() OVER (PARTITION BY CD_CLIENTE, CD_PRATICA ORDER BY DT_WFS_LAST_MODIFIED DESC) = 1
),

storicizzazione AS (
    SELECT
        CD_CLIENTE,
        CD_PRATICA,
        LASTMODIFIEDDATA AS TS_INIZIO_VALIDITA,
        {{ ts_fine_validita('CD_CLIENTE, CD_PRATICA', 'LASTMODIFIEDDATA') }} AS TS_FINE_VALIDITA,
        DS_NOME_LIN_CREDIT,
        TP_LINEA_DI_CREDITO,
        CD_PARENT_CREDIT_LINE,
        CD_STATO_LIN_CRED,
        TP_CREDIT_LINE_CALCULATION,
        CD_CURRENCY,
        FL_RESTRUCTURED,
        NM_CERTIFICATI,
        CD_CREDIT_LINE_MARKER,
        FL_VALID_NO_SUPPLIER_LOAN,
        FL_VALID_ALL_SUPPLIER_LOANS,
        DT_REVISIONE,
        DT_FINE_LIN_CREDIT,
        DT_INIZIO_LIN_CREDIT,
        EU_CREDIT_LINE_RISK,
        EU_FIDO,
        EU_FIDO_UTZTO,
        EU_ATTESA_LIQZNE,
        EU_COMPENSAZIONE_BANC,
        EU_IMPAGATO_TOT,
        EU_GUARANTEE,
        PC_GUARANTEE_IN_LIMIT,
        PC_GUARANTEE_OVER_LIMIT,
        LASTMODIFIEDDATA
    FROM extraction
),

dedup AS (
    SELECT
        CD_CLIENTE,
        CD_PRATICA,
        TS_INIZIO_VALIDITA,
        TS_FINE_VALIDITA,
        DS_NOME_LIN_CREDIT,
        TP_LINEA_DI_CREDITO,
        CD_PARENT_CREDIT_LINE,
        CD_STATO_LIN_CRED,
        TP_CREDIT_LINE_CALCULATION,
        CD_CURRENCY,
        FL_RESTRUCTURED,
        NM_CERTIFICATI,
        CD_CREDIT_LINE_MARKER,
        FL_VALID_NO_SUPPLIER_LOAN,
        FL_VALID_ALL_SUPPLIER_LOANS,
        DT_REVISIONE,
        DT_FINE_LIN_CREDIT,
        DT_INIZIO_LIN_CREDIT,
        EU_CREDIT_LINE_RISK,
        EU_FIDO,
        EU_FIDO_UTZTO,
        EU_ATTESA_LIQZNE,
        EU_COMPENSAZIONE_BANC,
        EU_IMPAGATO_TOT,
        EU_GUARANTEE,
        PC_GUARANTEE_IN_LIMIT,
        PC_GUARANTEE_OVER_LIMIT,
        LASTMODIFIEDDATA,
        {{ hash_cols([
            'CD_CLIENTE',
            'CD_PRATICA',
            'DS_NOME_LIN_CREDIT',
            'TP_LINEA_DI_CREDITO',
            'CD_PARENT_CREDIT_LINE',
            'CD_STATO_LIN_CRED',
            'TP_CREDIT_LINE_CALCULATION',
            'CD_CURRENCY',
            'FL_RESTRUCTURED',
            'NM_CERTIFICATI',
            'CD_CREDIT_LINE_MARKER',
            'FL_VALID_NO_SUPPLIER_LOAN',
            'FL_VALID_ALL_SUPPLIER_LOANS',
            'DT_REVISIONE',
            'DT_FINE_LIN_CREDIT',
            'DT_INIZIO_LIN_CREDIT',
            'EU_CREDIT_LINE_RISK',
            'EU_FIDO',
            'EU_FIDO_UTZTO',
            'EU_ATTESA_LIQZNE',
            'EU_COMPENSAZIONE_BANC',
            'EU_IMPAGATO_TOT',
            'EU_GUARANTEE',
            'PC_GUARANTEE_IN_LIMIT',
            'PC_GUARANTEE_OVER_LIMIT'
        ]) }} AS HASHED_COLS
    FROM storicizzazione
    {{ is_incremental_S1('CD_CLIENTE, CD_PRATICA') }}
)

SELECT
    CD_CLIENTE,
    CD_PRATICA,
    H.TS_INIZIO_VALIDITA,
    {{ ts_fine_validita('CD_CLIENTE, CD_PRATICA', 'H.TS_INIZIO_VALIDITA') }} AS TS_FINE_VALIDITA,
    DS_NOME_LIN_CREDIT,
    TP_LINEA_DI_CREDITO,
    CD_PARENT_CREDIT_LINE,
    CD_STATO_LIN_CRED,
    TP_CREDIT_LINE_CALCULATION,
    CD_CURRENCY,
    FL_RESTRUCTURED,
    NM_CERTIFICATI,
    CD_CREDIT_LINE_MARKER,
    FL_VALID_NO_SUPPLIER_LOAN,
    FL_VALID_ALL_SUPPLIER_LOANS,
    DT_REVISIONE,
    DT_FINE_LIN_CREDIT,
    DT_INIZIO_LIN_CREDIT,
    EU_CREDIT_LINE_RISK,
    EU_FIDO,
    EU_FIDO_UTZTO,
    EU_ATTESA_LIQZNE,
    EU_COMPENSAZIONE_BANC,
    EU_IMPAGATO_TOT,
    EU_GUARANTEE,
    PC_GUARANTEE_IN_LIMIT,
    PC_GUARANTEE_OVER_LIMIT,
    LASTMODIFIEDDATA
FROM dedup H