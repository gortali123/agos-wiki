WITH base_data AS (
    SELECT 
        TS_RIFERIMENTO,
        DT_WFS_LAST_MODIFIED,
        PARSE_XML(GN_VALUE) AS org_xml
    FROM {{ ref('master_data') }}
),

-- Livello 0.5 & 1: CreditLines
credit_lines_wrapper AS (
    SELECT 
        b.DT_WFS_LAST_MODIFIED,
        {{ get_xml_path('b.org_xml', 'OrganisationId/OrganisationReference', 'NUMBER(10,0)') }} AS CD_ORGANISATION,
        clw.value AS credit_lines_wrapper_xml
    FROM base_data b,
    {{ flatten_xml('b.org_xml', 'CreditLines', 'clw', outer=true) }}
),
credit_lines AS (
    SELECT 
        w.DT_WFS_LAST_MODIFIED,
        w.CD_ORGANISATION,
        cl.value AS credit_line_xml
    FROM credit_lines_wrapper w,
    {{ flatten_xml('w.credit_lines_wrapper_xml', 'CreditLine', 'cl', outer=true) }}
),

-- Livello 1.5 & 2: Plans
plans_wrapper AS (
    SELECT
        cl_cte.DT_WFS_LAST_MODIFIED,
        cl_cte.CD_ORGANISATION,
        {{ get_xml_path('cl_cte.credit_line_xml', 'CreditLineReference', 'VARCHAR(17)') }} AS CD_CREDIT_LINE,
        pw.value AS plans_wrapper_xml
    FROM credit_lines cl_cte,
    {{ flatten_xml('cl_cte.credit_line_xml', 'Plans', 'pw', outer=true) }}
),
plans AS (
    SELECT
        pw_cte.DT_WFS_LAST_MODIFIED,
        pw_cte.CD_ORGANISATION,
        pw_cte.CD_CREDIT_LINE,
        p.value AS plan_xml
    FROM plans_wrapper pw_cte,
    {{ flatten_xml('pw_cte.plans_wrapper_xml', 'Plan', 'p', outer=true) }}
),

-- Livello 2.5 & 3: Loans
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
loans AS (
    SELECT
        lw_cte.DT_WFS_LAST_MODIFIED,
        lw_cte.CD_ORGANISATION,
        lw_cte.CD_CREDIT_LINE,
        lw_cte.CD_PLAN,
        l.value AS loan_xml
    FROM loans_wrapper lw_cte,
    {{ flatten_xml('lw_cte.loans_wrapper_xml', 'Loan', 'l', outer=true) }}
),

-- Livello 3.5 & 4: FinancialTransactions
fin_transactions_wrapper AS (
    SELECT
        l_cte.DT_WFS_LAST_MODIFIED,
        l_cte.CD_ORGANISATION,
        l_cte.CD_CREDIT_LINE,
        l_cte.CD_PLAN,
        {{ get_xml_path('l_cte.loan_xml', 'LoanID', 'NUMBER(8,0)') }} AS CD_LOAN, 
        ftw.value AS fin_transactions_wrapper_xml
    FROM loans l_cte,
    {{ flatten_xml('l_cte.loan_xml', 'FinancialTransactions', 'ftw', outer=true) }}
),
transactions AS (
    SELECT
        ftw_cte.DT_WFS_LAST_MODIFIED,
        ftw_cte.CD_ORGANISATION,
        ftw_cte.CD_CREDIT_LINE,
        ftw_cte.CD_PLAN,
        ftw_cte.CD_LOAN,
        t.value AS transaction_xml
    FROM fin_transactions_wrapper ftw_cte,
    {{ flatten_xml('ftw_cte.fin_transactions_wrapper_xml', 'Transaction', 't', outer=true) }}
)

-- Selezione Finale: Estrazione campi dal nodo singolo <Transaction>
SELECT 
    DT_WFS_LAST_MODIFIED AS DT_RIFERIMENTO,
    CD_ORGANISATION AS CD_CLIENTE,
    CD_CREDIT_LINE AS CD_PRATICA,
    CD_PLAN AS CD_PIANO,
    CD_LOAN AS CD_CERTIFICATO, --WARN in table solo NUMBER
    ROW_NUMBER() OVER (PARTITION BY CD_CERTIFICATO ORDER BY CD_PRATICA) AS PR_TRANSAZIONE, -- WARN in table presente campo come PK
    -- Nodi annidati sotto PaymentMethod
    {{ get_xml_path('transaction_xml', 'PaymentMethod/AccountReference', 'VARCHAR(70)') }} AS CD_ACCOUNT,
    {{ get_xml_path('transaction_xml', 'PaymentMethod/DebitCreditIndicator', 'VARCHAR(6)') }} AS TP_PAYMENT_METHOD_DEBIT_CREDIT,
    {{ get_xml_path('transaction_xml', 'PaymentMethod/PaymentTiming', 'VARCHAR(4)') }} AS CD_PAYMENT_TIMING,
    {{ get_xml_path('transaction_xml', 'PaymentMethod/PaymentType', 'VARCHAR(13)') }} AS TP_PAYMENT,
    {{ get_xml_path('transaction_xml', 'PaymentMethod/ValueType', 'VARCHAR(3)') }} AS TP_VALUE,
    
    -- Nodi diretti sotto Transaction
    {{ get_xml_path('transaction_xml', 'ProcessType', 'VARCHAR(7)') }} AS TP_PROCESSO,
    {{ get_xml_path('transaction_xml', 'ItemType', 'VARCHAR(16)') }} AS TP_OGGETTO_TRANSZ,
    {{ get_xml_path('transaction_xml', 'FinancialItemCategory', 'VARCHAR(18)') }} AS TP_CATEGORIA_FIN,
    {{ get_xml_path('transaction_xml', 'DebitCreditIndicator', 'VARCHAR(6)') }} AS TP_TRANSACTION_DEBIT_CREDIT,
    {{ get_xml_path('transaction_xml', 'Status', 'VARCHAR(14)') }} AS CD_STATO, 
    {{ get_xml_path('transaction_xml', 'TransactionType', 'VARCHAR(10)') }} AS TP_TRANSAZIONE, -- WARN in table VARCHAR(6) ma i valori non corrispondono
    {{ get_xml_path('transaction_xml', 'NettTaxType', 'VARCHAR(4)') }} AS TP_NET_TAX,
    
    -- Date
    {{ get_xml_path('transaction_xml', 'CreationDate', 'DATE') }} AS DT_CREAZIONE_RECD,
    {{ get_xml_path('transaction_xml', 'ProcessDate', 'DATE') }} AS DT_REGISTRAZIONE,
    {{ get_xml_path('transaction_xml', 'BillingDate', 'DATE') }} AS DT_FATTURAZIONE,
    {{ get_xml_path('transaction_xml', 'PaidDate', 'DATE') }} AS DT_PAGAMENTO,
    {{ get_xml_path('transaction_xml', 'DueDate', 'DATE') }} AS DT_SCADENZA,

    -- Nodo annidato sotto TransactionAmount
    {{ get_xml_path('transaction_xml', 'TransactionAmount/Amount', 'NUMBER(13,2)') }} AS EU_MOVIMENTO

FROM transactions