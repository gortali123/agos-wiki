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
        {{ get_xml_path('b.org_xml', 'OrganisationId/OrganisationReference', 'NUMBER(10,0)') }} AS CD_ORGANISATION,
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

-- Livello 3: PaymentSchedule (Relazione 1 a 1 -> USO XMLGET DIRETTO!)
payment_schedules AS (
    SELECT
        p_cte.DT_WFS_LAST_MODIFIED,
        p_cte.CD_ORGANISATION,
        p_cte.CD_CREDIT_LINE,
        {{ get_xml_path('p_cte.plan_xml', 'PlanReference', 'VARCHAR(30)') }} AS CD_PLAN,
        XMLGET(XMLGET(p_cte.plan_xml, 'PaymentSchedules'), 'PaymentSchedule') AS payment_schedule_xml -- FIX Estrazione del sotto-tag PaymentSchedule
    FROM plans p_cte
),

-- Livello 4: Payments (Relazione 1 a Molti -> Torno ad usare la Macro FLATTEN)
payments AS (
    SELECT
        ps_cte.DT_WFS_LAST_MODIFIED,
        ps_cte.CD_ORGANISATION,
        ps_cte.CD_CREDIT_LINE,
        ps_cte.CD_PLAN,
        ps_cte.payment_schedule_xml,
        pmt.value AS payment_xml
    FROM payment_schedules ps_cte,
    -- Esplodo i molteplici <Payment> contenuti in <Payments>
    {{ flatten_xml("XMLGET(ps_cte.payment_schedule_xml, 'Payments')", 'Payment', 'pmt', outer=true) }}
),


-- Proiezione business + watermark. Campi da PaymentSchedule (1:1) e da Payment (1:molti).
-- DT_RIFERIMENTO rimosso; watermark = DT_WFS_LAST_MODIFIED::TIMESTAMP_NTZ (trappola A).
extraction AS (
    SELECT
        CD_CREDIT_LINE AS CD_PRATICA,
        CD_PLAN AS CD_PIANO,
        {{ get_xml_path('payment_xml', 'Period/DayMonth', 'NUMBER(3,0)') }} AS NM_GIORNI_SCADZ_RTA,   -- WARN tabella: solo NUMBER

        CD_ORGANISATION AS CD_CLIENTE,
        {{ get_xml_path('payment_schedule_xml', 'PartialPaymentType', 'VARCHAR(5)') }} AS TP_PARTIAL_PAYMENT,
        {{ get_xml_path('payment_schedule_xml', 'Reference', 'VARCHAR(5)') }} AS CD_REFERENCE,
        {{ get_xml_path('payment_schedule_xml', 'ScheduleType', 'VARCHAR(12)') }} AS TP_SCHEDULE,
        {{ get_xml_path('payment_schedule_xml', 'CalculationType', 'VARCHAR(10)') }} AS TP_VALORE_PGM,
        {{ get_xml_path('payment_schedule_xml', 'DrivenBy', 'VARCHAR(4)') }} AS TP_PERIODO_PGM,
        {{ get_xml_path('payment_schedule_xml', 'Adjustment', 'VARCHAR(20)') }} AS EU_ADJUSTMENT,
        {{ get_xml_path('payment_xml', 'Value/Amount', 'NUMBER(3,0)') }} AS PC_RATA,   -- WARN tabella: solo NUMBER
        {{ get_xml_path('payment_xml', 'TransactionType', 'VARCHAR(10)') }} AS TP_TRANSACTION,

        DT_WFS_LAST_MODIFIED::TIMESTAMP_NTZ AS LASTMODIFIEDDATA
    FROM payments
    -- QUALIFY ROW_NUMBER() OVER (PARTITION BY CD_PRATICA, CD_PIANO, NM_GIORNI_SCADZ_RTA ORDER BY DT_WFS_LAST_MODIFIED DESC) = 1  -- difensivo, off
),

storicizzazione AS (
    SELECT
        CD_PRATICA,
        CD_PIANO,
        NM_GIORNI_SCADZ_RTA,
        LASTMODIFIEDDATA AS TS_INIZIO_VALIDITA,
        {{ ts_fine_validita('CD_PRATICA, CD_PIANO, NM_GIORNI_SCADZ_RTA', 'LASTMODIFIEDDATA') }} AS TS_FINE_VALIDITA,   -- 'LASTMODIFIEDDATA' (trappola B)
        CD_CLIENTE,
        TP_PARTIAL_PAYMENT,
        CD_REFERENCE,
        TP_SCHEDULE,
        TP_VALORE_PGM,
        TP_PERIODO_PGM,
        EU_ADJUSTMENT,
        PC_RATA,
        TP_TRANSACTION,
        LASTMODIFIEDDATA
    FROM extraction
),

dedup AS (
    SELECT
        CD_PRATICA,
        CD_PIANO,
        NM_GIORNI_SCADZ_RTA,
        TS_INIZIO_VALIDITA,
        TS_FINE_VALIDITA,
        CD_CLIENTE,
        TP_PARTIAL_PAYMENT,
        CD_REFERENCE,
        TP_SCHEDULE,
        TP_VALORE_PGM,
        TP_PERIODO_PGM,
        EU_ADJUSTMENT,
        PC_RATA,
        TP_TRANSACTION,
        LASTMODIFIEDDATA,
        {{ hash_cols(['CD_PRATICA', 'CD_PIANO', 'NM_GIORNI_SCADZ_RTA', 'CD_CLIENTE', 'TP_PARTIAL_PAYMENT', 'CD_REFERENCE', 'TP_SCHEDULE', 'TP_VALORE_PGM', 'TP_PERIODO_PGM', 'EU_ADJUSTMENT', 'PC_RATA', 'TP_TRANSACTION']) }} AS HASHED_COLS
    FROM storicizzazione
    {{ is_incremental_S1('CD_PRATICA, CD_PIANO, NM_GIORNI_SCADZ_RTA') }}
)

-- Selezione Finale: PK -> TS_INIZIO_VALIDITA -> TS_FINE_VALIDITA -> business -> LASTMODIFIEDDATA
SELECT
        CD_PRATICA,
        CD_PIANO,
        NM_GIORNI_SCADZ_RTA,
        H.TS_INIZIO_VALIDITA,
        {{ ts_fine_validita('CD_PRATICA, CD_PIANO, NM_GIORNI_SCADZ_RTA', 'H.TS_INIZIO_VALIDITA') }} AS TS_FINE_VALIDITA,   -- 'H.TS_INIZIO_VALIDITA'
        CD_CLIENTE,
        TP_PARTIAL_PAYMENT,
        CD_REFERENCE,
        TP_SCHEDULE,
        TP_VALORE_PGM,
        TP_PERIODO_PGM,
        EU_ADJUSTMENT,
        PC_RATA,
        TP_TRANSACTION,
        LASTMODIFIEDDATA
FROM dedup H
