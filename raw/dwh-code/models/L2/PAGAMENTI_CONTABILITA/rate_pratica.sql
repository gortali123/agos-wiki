-- =============================================================================
-- L2 - PAGAMENTI E CONTABILITA - RATE_PRATICA
-- Storicizzazione: S4 (incremental / insert_overwrite) -> nessun blocco
--   incremental, nessun LASTMODIFIEDDATA.
-- Modello generato a partire dal SQL fornito dall'utente (NON dalla Regola
--   Tecnica del data model): scostamenti dalla RT sono voluti.
--
-- NOTE / punti da verificare:
-- EU_ importi: applicato custom_to_decimal (÷100 + cast NUMBER(13,2)).
-- DT_ (DATE): applicato custom_to_date su DT_SCADENZA, DT_SCADENZA_NUOVA,
--   DT_ACCODAMENTO. DT_INIZIO/FINE_VALIDITA restano NUMBER(8) grezzi (PK).
--   ATTENZIONE: NON risolve il fan-out del join ad OXCTFPAFT (le somme restano
--   moltiplicate per il numero di righe AFT del piano). Se persiste l'overflow
--   o i totali sono gonfiati, correggere il join (chiave AFA<->AFT mancante).
-- WARN evento: OXCTPAFT_EVENTO e' nel GROUP BY (grain = 5 PK + evento) ma non
--   nel SELECT finale -> la PK a 5 colonne del YML puo' NON essere univoca.
-- WARN FL_DELETED: aggiunto (cluster A2) su OXCTFPAFD, OXCTFPAFA e sul join ad
--   OXCTFPAFT; rimuovere se non desiderato.
-- NOTA nomi: EU_IMPORTO (colonna interna) = importo della singola componente,
--   distinto da EU_IMPORTO_RATA_TOT (colonna finale = totale rata).
-- Ordine colonne del SELECT allineato al contract (YML).
-- =============================================================================

WITH dettaglio_CO AS (

    -- Componente FIN: dettaglio finanziario della rata (OXCTFPAFD e' sempre FIN)
    SELECT
        OXCTPAFD_PROCEDURA          AS TP_PROCEDURA,
        OXCTPAFD_NUM_PRATICA        AS CD_PRATICA,
        OXCTPAFD_PROGRESSIVO        AS NM_PROG_PIANO, 
        OXCTPAFD_PERIODO            AS NM_PROG_RATA,
        OXCTPAFD_NUMERO_RATA        AS NM_RATA,
        OXCTPAFD_NUM_RATA_ORIG      AS NM_RATA_ORIG,
        OXCTPAFD_TIPO_RATA          AS TP_RATA,
        OXCTPAFD_DATA_SCADENZA      AS DT_SCADENZA,
        OXCTPAFD_IMPORTO            AS EU_IMPORTO,
        OXCTPAFD_QTA_CAPITALE       AS EU_COMP_FIN_CAPITALE,
        OXCTPAFD_QTA_INTERESSI      AS EU_COMP_FIN_INTERESSI,
        OXCTPAFD_CAP_RESIDUO        AS EU_COMP_FIN_CAPITALE_RESIDUO,
        OXCTPAFD_DATA_SCAD_PAG      AS DT_SCADENZA_NUOVA,
        OXCTPAFD_DT_ACCODAMENTO     AS DT_ACCODAMENTO,
        OXCTPAFD_TP_ACCODAMENTO     AS TP_ACCODAMENTO,
        OXCTPAFD_INTERESSI_INT      AS EU_INTERESSI_INT,
        OXCTPAFD_INTERESSI_CNV      AS EU_INTERESSI_CNV,
        OXCTPAFD_NUM_DOCUMENTO      AS CD_NUM_DOC_CASTELLETTO,
        OXCTPAFD_TIPO_DOCUMENTO     AS TP_MOD_PAGAMENTO,
        OXCTPAFD_DETT_TIPO_RATA     AS TP_DETT_RATA,
        OXCTPAFD_ESCLUSIONE_BOLLO   AS FL_ESCLUSIONE_BOLLO
    FROM {{ ref('oxctfpafd') }}
    WHERE FL_DELETED = 'N'   -- cluster A2

    UNION ALL

    -- Altre componenti (OXCTFPAFA): il tipo componente arriva dalla join con AFT
    SELECT
        OXCTPAFA_PROCEDURA      AS TP_PROCEDURA,
        OXCTPAFA_NUM_PRATICA    AS CD_PRATICA,
        OXCTPAFA_PROGRESSIVO    AS NM_PROG_PIANO,
        OXCTPAFA_PERIODO        AS NM_PROG_RATA,
        NULL                    AS NM_RATA,
        NULL                    AS NM_RATA_ORIG,
        NULL                    AS TP_RATA,
        NULL                    AS DT_SCADENZA,
        OXCTPAFA_IMPORTO        AS EU_IMPORTO,
        NULL                    AS EU_COMP_FIN_CAPITALE,
        NULL                    AS EU_COMP_FIN_INTERESSI,
        NULL                    AS EU_COMP_FIN_CAPITALE_RESIDUO,
        NULL                    AS DT_SCADENZA_NUOVA,
        NULL                    AS DT_ACCODAMENTO,
        NULL                    AS TP_ACCODAMENTO,
        NULL                    AS EU_INTERESSI_INT,
        NULL                    AS EU_INTERESSI_CNV,
        NULL                    AS CD_NUM_DOC_CASTELLETTO,
        NULL                    AS TP_MOD_PAGAMENTO,
        NULL                    AS TP_DETT_RATA,
        NULL                    AS FL_ESCLUSIONE_BOLLO
    FROM {{ ref('oxctfpafa') }}
    WHERE FL_DELETED = 'N'   -- cluster A2
),

dettaglio_componente_CO AS (

    SELECT
        d.TP_PROCEDURA,
        d.CD_PRATICA,
        d.NM_PROG_PIANO,
        d.NM_PROG_RATA,
        d.NM_RATA,
        d.NM_RATA_ORIG,
        d.TP_RATA,
        d.DT_SCADENZA,
        d.EU_IMPORTO,
        d.EU_COMP_FIN_CAPITALE,
        d.EU_COMP_FIN_INTERESSI,
        d.EU_COMP_FIN_CAPITALE_RESIDUO,
        d.DT_SCADENZA_NUOVA,
        d.DT_ACCODAMENTO,
        d.TP_ACCODAMENTO,
        d.EU_INTERESSI_INT,
        d.EU_INTERESSI_CNV,
        d.CD_NUM_DOC_CASTELLETTO,
        d.TP_MOD_PAGAMENTO,
        d.TP_DETT_RATA,
        d.FL_ESCLUSIONE_BOLLO,
        -- FIN dalla fonte AFD, altrimenti il tipo componente lo detta AFT
        t.OXCTPAFT_TIPO_COMPONENTE AS tipo_componente,
        t.OXCTPAFT_VALIDITA_DAL AS DT_INIZIO_VALIDITA,
        t.OXCTPAFT_VALIDITA_AL  AS DT_FINE_VALIDITA,
        t.OXCTPAFT_EVENTO AS evento
    FROM dettaglio_CO d
    LEFT JOIN {{ ref('oxctfpaft') }} t
        ON  t.OXCTPAFT_PROCEDURA   = d.TP_PROCEDURA
        AND t.OXCTPAFT_NUM_PRATICA = d.CD_PRATICA
        AND t.OXCTPAFT_PROGRESSIVO = d.NM_PROG_PIANO
        AND t.OXCTPAFT_STATO_PIANO = ' '   -- solo piani attivi/storici
        AND t.FL_DELETED = 'N'             -- cluster A2 (lookup)
    -- TSE non e' una vera componente di piano -> esclusa
    WHERE t.OXCTPAFT_TIPO_COMPONENTE IS NOT NULL
    AND t.OXCTPAFT_TIPO_COMPONENTE <> 'TSE'
),

testata_componente_CQ AS(

    SELECT 
        QRPAT_NUM_PRATICA,
        QRPAT_PROGRESSIVO,
        QRPAT_VALIDITA_DAL,
        LEAD(QRPAT_VALIDITA_DAL) OVER (
											PARTITION BY QRPAT_NUM_PRATICA
											ORDER BY QRPAT_PROGRESSIVO
								) AS DT_FINE_VALIDITA,
        QRPAT_AZIONE_CREAZ,
        QRPAT_PRG_PSVT_CREAZ
    FROM {{ ref('qsratpat') }}

),

dettaglio_componente_CQ AS (

    SELECT
        'CQ' AS TP_PROCEDURA,
        a.QRPAD_NUM_PRATICA AS CD_PRATICA,
        a.QRPAD_PROGRESSIVO,
        a.QRPAD_NUMERO_RATA AS NM_PROG_RATA,
        a.QRPAD_NUMERO_RATA AS NM_RATA,
        NULL AS NM_RATA_ORIG,
        a.QRPAD_TIPO_RATA AS TP_RATA,
        a.QRPAD_DATA_SCADENZA AS DT_SCADENZA,
        a.QRPAD_IMPORTO AS EU_IMPORTO,
        a.QRPAD_QUOTA_CAPITALE AS EU_COMP_FIN_CAPITALE,
        a.QRPAD_QUOTA_INTERESSI AS EU_COMP_FIN_INTERESSI,
        NULL AS EU_COMP_FIN_CAPITALE_RESIDUO,
        NULL AS DT_SCADENZA_NUOVA,
        NULL AS DT_ACCODAMENTO,
        NULL AS TP_ACCODAMENTO,
        NULL AS EU_INTERESSI_INT,
        NULL AS EU_INTERESSI_CNV,
        NULL AS CD_NUM_DOC_CASTELLETTO,
        NULL AS TP_MOD_PAGAMENTO,
        NULL AS TP_DETT_RATA,
        NULL AS FL_ESCLUSIONE_BOLLO,
        -- FIN dalla fonte AFD, altrimenti il tipo componente lo detta AFT
        NULL AS tipo_componente,
        b.QRPAT_VALIDITA_DAL AS  DT_INIZIO_VALIDITA,
        COALESCE (b.DT_FINE_VALIDITA, 99991231) AS DT_FINE_VALIDITA,
        b.QRPAT_AZIONE_CREAZ AS CD_AZIONE_PSVT_CQ,
		b.QRPAT_PRG_PSVT_CREAZ AS PR_AZIONE_PSVT_CQ
    FROM {{ ref('qsratpad') }} a
    LEFT JOIN testata_componente_CQ b
        ON  a.QRPAD_NUM_PRATICA   = b.QRPAT_NUM_PRATICA
        AND a.QRPAD_PROGRESSIVO = b.QRPAT_PROGRESSIVO
        AND a.FL_DELETED = 'N'             -- cluster A2 (lookup)
)


SELECT
    TP_PROCEDURA,
    CD_PRATICA,
    LISTAGG(tipo_componente, ' - ') AS DS_COMPONENTI_PIANO,
    NM_PROG_RATA,
    -- finestra di validita' del piano (puo' generare piu' righe per rata)
    {{ custom_to_date('DT_INIZIO_VALIDITA', zero = 'min') }} AS DT_INIZIO_VALIDITA,
    {{ custom_to_date('DT_FINE_VALIDITA', zero = 'max') }} AS DT_FINE_VALIDITA,
    --DT_INIZIO_VALIDITA,
    --DT_FINE_VALIDITA,
    MAX(CASE WHEN tipo_componente = 'FIN' THEN NM_RATA END) AS NM_RATA,
    MAX(CASE WHEN tipo_componente = 'FIN' THEN NM_RATA_ORIG END) AS NM_RATA_ORIG,
    MAX(CASE WHEN tipo_componente = 'FIN' THEN TP_RATA END) AS TP_RATA,
    MAX(CASE WHEN tipo_componente = 'FIN' THEN {{ custom_to_date('DT_SCADENZA') }} END) AS DT_SCADENZA,
    -- totale rata = somma dell'importo di TUTTE le componenti
    {{ custom_to_decimal("SUM(CASE WHEN tipo_componente IS NOT NULL THEN EU_IMPORTO ELSE 0 END)", 16, 2) }} AS EU_IMPORTO_RATA_TOT,
    {{ custom_to_decimal("SUM(CASE WHEN tipo_componente = 'FIN' THEN EU_IMPORTO ELSE 0 END)", 13, 2) }} AS EU_COMP_FIN,  -- = importo rata (comp. FIN)
    {{ custom_to_decimal("SUM(CASE WHEN tipo_componente = 'FIN' THEN EU_COMP_FIN_CAPITALE ELSE 0 END)", 13, 2) }} AS EU_COMP_FIN_CAPITALE,
    {{ custom_to_decimal("SUM(CASE WHEN tipo_componente = 'FIN' THEN EU_COMP_FIN_INTERESSI ELSE 0 END)", 13, 2) }} AS EU_COMP_FIN_INTERESSI,
    {{ custom_to_decimal("SUM(CASE WHEN tipo_componente = 'FIN' THEN EU_COMP_FIN_CAPITALE_RESIDUO ELSE 0 END)", 13, 2) }} AS EU_COMP_FIN_CAPITALE_RESIDUO,
    {{ custom_to_decimal("SUM(CASE WHEN tipo_componente = 'SPI' THEN EU_IMPORTO ELSE 0 END)", 13, 2) }} AS EU_COMP_SPI,  -- spese di incasso
    {{ custom_to_decimal("SUM(CASE WHEN tipo_componente = 'ASS' THEN EU_IMPORTO ELSE 0 END)", 13, 2) }} AS EU_COMP_ASS,  -- assicurazione
    {{ custom_to_decimal("SUM(CASE WHEN tipo_componente = 'DLR' THEN EU_IMPORTO ELSE 0 END)", 13, 2) }} AS EU_COMP_DLR,  -- dilazione ripartita
    {{ custom_to_decimal("SUM(CASE WHEN tipo_componente = 'SPE' THEN EU_IMPORTO ELSE 0 END)", 13, 2) }} AS EU_COMP_SPE,  -- spese
    {{ custom_to_decimal("SUM(CASE WHEN tipo_componente = 'BOL' THEN EU_IMPORTO ELSE 0 END)", 13, 2) }} AS EU_COMP_BOL,  -- bollo su fattura
    {{ custom_to_decimal("SUM(CASE WHEN tipo_componente = 'SCO' THEN EU_IMPORTO ELSE 0 END)", 13, 2) }} AS EU_COMP_SCO,  -- sconto
    {{ custom_to_decimal("SUM(CASE WHEN tipo_componente = 'IAI' THEN EU_IMPORTO ELSE 0 END)", 13, 2) }} AS EU_COMP_IAI,  -- int. accod. addebito immediato
    {{ custom_to_decimal("SUM(CASE WHEN tipo_componente = 'IAD' THEN EU_IMPORTO ELSE 0 END)", 13, 2) }} AS EU_COMP_IAD,  -- int. accod. addebito differito
    {{ custom_to_decimal("SUM(CASE WHEN tipo_componente = 'TRA' THEN EU_IMPORTO ELSE 0 END)", 13, 2) }} AS EU_COMP_TRA,  -- int. traslazione piano
    {{ custom_to_decimal("SUM(CASE WHEN tipo_componente = 'IAS' THEN EU_IMPORTO ELSE 0 END)", 13, 2) }} AS EU_COMP_IAS,  -- int. accod. su rata successiva
    {{ custom_to_decimal("SUM(CASE WHEN tipo_componente = 'IND' THEN EU_IMPORTO ELSE 0 END)", 13, 2) }} AS EU_COMP_IND,  -- int. indicizzazione
    {{ custom_to_decimal("SUM(CASE WHEN tipo_componente = 'DL1' THEN EU_IMPORTO ELSE 0 END)", 13, 2) }} AS EU_COMP_DL1,  -- dilazione ripartita da rifin.
    {{ custom_to_decimal("SUM(CASE WHEN tipo_componente = 'ADD' THEN EU_IMPORTO ELSE 0 END)", 13, 2) }} AS EU_COMP_ADD,  -- altri addebiti ripartiti
    {{ custom_to_decimal("SUM(CASE WHEN tipo_componente = 'RIP' THEN EU_IMPORTO ELSE 0 END)", 13, 2) }} AS EU_COMP_RIP,  -- quote ripartite su rate a scadere
    {{ custom_to_decimal("SUM(CASE WHEN tipo_componente = 'BLR' THEN EU_IMPORTO ELSE 0 END)", 13, 2) }} AS EU_COMP_BLR,  -- bollo su rata
    {{ custom_to_decimal("SUM(CASE WHEN tipo_componente = 'IDE' THEN EU_IMPORTO ELSE 0 END)", 13, 2) }} AS EU_COMP_IDE,  -- interessi Dealer (FC)
    {{ custom_to_decimal("SUM(CASE WHEN tipo_componente = 'CDE' THEN EU_IMPORTO ELSE 0 END)", 13, 2) }} AS EU_COMP_CDE,  -- commissioni Dealer (FC)
    {{ custom_to_decimal("SUM(CASE WHEN tipo_componente = 'SEL' THEN EU_IMPORTO ELSE 0 END)", 13, 2) }} AS EU_COMP_SEL,  -- ammortamento servizi Leasing
    MAX(CASE WHEN tipo_componente = 'FIN' THEN {{ custom_to_date('DT_SCADENZA_NUOVA') }} END) AS DT_SCADENZA_NUOVA,
    MAX(CASE WHEN tipo_componente = 'FIN' THEN {{ custom_to_date('DT_ACCODAMENTO') }} END) AS DT_ACCODAMENTO,
    MAX(CASE WHEN tipo_componente = 'FIN' THEN TP_ACCODAMENTO END) AS TP_ACCODAMENTO,
    MAX(CASE WHEN tipo_componente = 'FIN' THEN
            CASE WHEN {{ custom_to_date('DT_SCADENZA_NUOVA') }} IS NOT NULL THEN 'S'
            ELSE 'N'
            END
        END) AS FL_ACCODAMENTO,
    {{ custom_to_decimal("MAX(CASE WHEN tipo_componente = 'FIN' THEN EU_INTERESSI_INT END)", 13, 2) }} AS EU_INTERESSI_INT,
    {{ custom_to_decimal("MAX(CASE WHEN tipo_componente = 'FIN' THEN EU_INTERESSI_CNV END)", 13, 2) }} AS EU_INTERESSI_CNV,
    MAX(CASE WHEN tipo_componente = 'FIN' THEN CD_NUM_DOC_CASTELLETTO END) AS CD_NUM_DOC_CASTELLETTO,
    MAX(CASE WHEN tipo_componente = 'FIN' THEN TP_MOD_PAGAMENTO END) AS TP_MOD_PAGAMENTO,
    MAX(CASE WHEN tipo_componente = 'FIN' THEN TP_DETT_RATA END) AS TP_DETT_RATA,
    MAX(CASE WHEN tipo_componente = 'FIN' THEN FL_ESCLUSIONE_BOLLO END) AS FL_ESCLUSIONE_BOLLO,
	MAX(NULL) AS CD_AZIONE_PSVT_CQ,
	MAX(NULL) AS PR_AZIONE_PSVT_CQ
FROM dettaglio_componente_CO
GROUP BY
    TP_PROCEDURA,
    CD_PRATICA,
    NM_PROG_RATA,
    DT_INIZIO_VALIDITA,
    DT_FINE_VALIDITA,
    evento

UNION ALL

SELECT
    TP_PROCEDURA,
    CD_PRATICA,
    'FIN' AS DS_COMPONENTI_PIANO,
    NM_PROG_RATA,
    {{ custom_to_date('DT_INIZIO_VALIDITA', zero = 'min') }} AS DT_INIZIO_VALIDITA,
    {{ custom_to_date('DT_FINE_VALIDITA', zero = 'max') }} AS DT_FINE_VALIDITA,
    NM_RATA,
    NM_RATA_ORIG,
    TP_RATA,
    {{ custom_to_date('DT_SCADENZA') }} AS DT_SCADENZA,
    {{ custom_to_decimal("EU_IMPORTO", 16, 2) }} AS EU_IMPORTO_RATA_TOT,
    {{ custom_to_decimal("EU_IMPORTO", 16, 2) }} AS EU_COMP_FIN, 
    {{ custom_to_decimal("EU_COMP_FIN_CAPITALE", 16, 2) }} AS EU_COMP_FIN_CAPITALE,
    {{ custom_to_decimal("EU_COMP_FIN_INTERESSI", 16, 2) }} AS EU_COMP_FIN_INTERESSI,
    {{ custom_to_decimal("EU_COMP_FIN_CAPITALE_RESIDUO", 16, 2) }} AS EU_COMP_FIN_CAPITALE_RESIDUO,
    NULL AS EU_COMP_SPI,  -- spese di incasso
    NULL AS EU_COMP_ASS,  -- assicurazione
    NULL AS EU_COMP_DLR,  -- dilazione ripartita
    NULL AS EU_COMP_SPE,  -- spese
    NULL AS EU_COMP_BOL,  -- bollo su fattura
    NULL AS EU_COMP_SCO,  -- sconto
    NULL AS EU_COMP_IAI,  -- int. accod. addebito immediato
    NULL AS EU_COMP_IAD,  -- int. accod. addebito differito
    NULL AS EU_COMP_TRA,  -- int. traslazione piano
    NULL AS EU_COMP_IAS,  -- int. accod. su rata successiva
    NULL AS EU_COMP_IND,  -- int. indicizzazione
    NULL AS EU_COMP_DL1,  -- dilazione ripartita da rifin.
    NULL AS EU_COMP_ADD,  -- altri addebiti ripartiti
    NULL AS EU_COMP_RIP,  -- quote ripartite su rate a scadere
    NULL AS EU_COMP_BLR,  -- bollo su rata
    NULL AS EU_COMP_IDE,  -- interessi Dealer (FC)
    NULL AS EU_COMP_CDE,  -- commissioni Dealer (FC)
    NULL AS EU_COMP_SEL,  -- ammortamento servizi Leasing
    NULL AS DT_SCADENZA_NUOVA,
    NULL AS DT_ACCODAMENTO,
    NULL AS TP_ACCODAMENTO,
    NULL AS FL_ACCODAMENTO,
    NULL AS EU_INTERESSI_INT,
    NULL AS EU_INTERESSI_CNV,
    NULL AS CD_NUM_DOC_CASTELLETTO,
    NULL AS TP_MOD_PAGAMENTO,
    NULL AS TP_DETT_RATA,
    NULL AS FL_ESCLUSIONE_BOLLO,
	CD_AZIONE_PSVT_CQ,
	PR_AZIONE_PSVT_CQ
FROM dettaglio_componente_CQ
	