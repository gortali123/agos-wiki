WITH base_data AS (
    SELECT 
        TS_RIFERIMENTO,
        DT_WFS_LAST_MODIFIED,
        PARSE_XML(GN_VALUE) AS org_xml
    FROM {{ ref('master_data') }}
),

-- Livello 0.5: Estraggo il nodo contenitore <FinancialTransactions> in sicurezza
fin_transactions_wrapper AS (
    SELECT 
        b.DT_WFS_LAST_MODIFIED,
        {{ get_xml_path('b.org_xml', 'OrganisationId/OrganisationReference', 'NUMBER(10,0)') }} AS CD_ORGANISATION,
        ftw.value AS fin_transactions_wrapper_xml
    FROM base_data b,
    {{ flatten_xml('b.org_xml', 'FinancialTransactions', 'ftw', outer=true) }}
),

-- Livello 1: Dal contenitore, esplodo i singoli nodi <Transaction> (Relazione 1 a Molti)
fin_transactions AS (
    SELECT 
        w.DT_WFS_LAST_MODIFIED,
        w.CD_ORGANISATION,
        ft.value AS transaction_xml
    FROM fin_transactions_wrapper w,
    {{ flatten_xml('w.fin_transactions_wrapper_xml', 'Transaction', 'ft', outer=true) }}
),


extraction AS (
    SELECT
        CD_ORGANISATION AS CD_CLIENTE,
        {{ get_xml_path('transaction_xml', 'PaymentMethod/AccountReference', 'VARCHAR(80)') }} AS CD_ACCOUNT,
        {{ get_xml_path('transaction_xml', 'PaymentMethod/DebitCreditIndicator', 'VARCHAR(6)') }} AS TP_PAYMENT_METHOD_DEBIT_CREDIT,
        {{ get_xml_path('transaction_xml', 'PaymentMethod/PaymentTiming', 'VARCHAR(4)') }} AS CD_PAYMENT_TIMING,
        {{ get_xml_path('transaction_xml', 'PaymentMethod/PaymentType', 'VARCHAR(13)') }} AS TP_PAYMENT,
        {{ get_xml_path('transaction_xml', 'PaymentMethod/ValueType', 'VARCHAR(3)') }} AS TP_VALUE,
        {{ get_xml_path('transaction_xml', 'ProcessType', 'VARCHAR(7)') }} AS TP_PROCESSO,
        {{ get_xml_path('transaction_xml', 'ItemType', 'VARCHAR(15)') }} AS TP_OGGETTO_TRANSZ,
        {{ get_xml_path('transaction_xml', 'FinancialItemCategory', 'VARCHAR(18)') }} AS TP_CATEGORIA_FIN,
        {{ get_xml_path('transaction_xml', 'DebitCreditIndicator', 'VARCHAR(6)') }} AS TP_TRANSAZIONE,
        {{ get_xml_path('transaction_xml', 'Status', 'VARCHAR(14)') }} AS CD_STATO,
        {{ get_xml_path('transaction_xml', 'TransactionType', 'VARCHAR(6)') }} AS TP_TRANSACTION,
        {{ get_xml_path('transaction_xml', 'NettTaxType', 'VARCHAR(4)') }} AS TP_NET_TAX,
        {{ get_xml_path('transaction_xml', 'ProcessDate', 'DATE') }} AS DT_CONTABILE,
        {{ get_xml_path('transaction_xml', 'PaidDate', 'DATE') }} AS DT_PAGAMENTO,
        {{ get_xml_path('transaction_xml', 'DueDate', 'DATE') }} AS DT_SCADENZA,
        {{ get_xml_path('transaction_xml', 'CreationDate', 'DATE') }} AS DT_CREAZIONE_RECD,
        {{ get_xml_path('transaction_xml', 'BillingDate', 'DATE') }} AS DT_FATTURAZIONE,
        {{ get_xml_path('transaction_xml', 'TransactionAmount/Amount', 'NUMBER(13,2)') }} AS EU_MOVIMENTO,
        DT_WFS_LAST_MODIFIED::TIMESTAMP_NTZ AS LASTMODIFIEDDATA
    FROM fin_transactions
),

hashed AS (
    SELECT
        CD_CLIENTE,
        LASTMODIFIEDDATA AS TS_INSERIMENTO,
        CD_ACCOUNT,
        TP_PAYMENT_METHOD_DEBIT_CREDIT,
        CD_PAYMENT_TIMING,
        TP_PAYMENT,
        TP_VALUE,
        TP_PROCESSO,
        TP_OGGETTO_TRANSZ,
        TP_CATEGORIA_FIN,
        TP_TRANSAZIONE,
        CD_STATO,
        TP_TRANSACTION,
        TP_NET_TAX,
        DT_CONTABILE,
        DT_PAGAMENTO,
        DT_SCADENZA,
        DT_CREAZIONE_RECD,
        DT_FATTURAZIONE,
        EU_MOVIMENTO,
        LASTMODIFIEDDATA,
        MD5(TO_VARCHAR(ARRAY_CONSTRUCT(CD_CLIENTE, CD_ACCOUNT, TP_PAYMENT_METHOD_DEBIT_CREDIT, CD_PAYMENT_TIMING, TP_PAYMENT, TP_VALUE, TP_PROCESSO, TP_OGGETTO_TRANSZ, TP_CATEGORIA_FIN, TP_TRANSAZIONE, CD_STATO, TP_TRANSACTION, TP_NET_TAX, DT_CONTABILE, DT_PAGAMENTO, DT_SCADENZA, DT_CREAZIONE_RECD, DT_FATTURAZIONE, EU_MOVIMENTO))) AS HASH_TRANSACTION   -- fingerprint tecnico (no chiave business)
    FROM extraction
)

-- Append giornaliero (S2): una riga per transazione per snapshot, taggata da TS_INSERIMENTO.
-- PR_TRANSAZIONE deterministico per CD_CLIENTE (ordine: CreationDate, ProcessDate, hash).
SELECT
    CD_CLIENTE,
    ROW_NUMBER() OVER (PARTITION BY CD_CLIENTE ORDER BY DT_CREAZIONE_RECD ASC, DT_CONTABILE ASC, HASH_TRANSACTION ASC) AS PR_TRANSAZIONE,
    TS_INSERIMENTO,
    CD_ACCOUNT,
    TP_PAYMENT_METHOD_DEBIT_CREDIT,
    CD_PAYMENT_TIMING,
    TP_PAYMENT,
    TP_VALUE,
    TP_PROCESSO,
    TP_OGGETTO_TRANSZ,
    TP_CATEGORIA_FIN,
    TP_TRANSAZIONE,
    CD_STATO,
    TP_TRANSACTION,
    TP_NET_TAX,
    DT_CONTABILE,
    DT_PAGAMENTO,
    DT_SCADENZA,
    DT_CREAZIONE_RECD,
    DT_FATTURAZIONE,
    EU_MOVIMENTO,
    LASTMODIFIEDDATA,
    HASH_TRANSACTION
FROM hashed h