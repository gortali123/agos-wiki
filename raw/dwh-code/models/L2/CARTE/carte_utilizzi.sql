{#
In attesa --> da sistemare i seguenti campi da aggiungere 'NM_TAEG', 'NM_IRR'
#}
WITH base_comm_atm AS (
    SELECT
        f.CRVOC_EMETTITORE,
        f.CRVOC_PROTOCOLLO,
        f.CRVOC_RIGA,
        f.CRVOC_ESTERA,
        -- ── Commissione ATM in EURO ───────────────────────────────────────────────
        r_euro.ROTBCAU_IMPORTO AS IMP_COMM_ATM_EURO,
        r_euro.ROTBCAU_PERCENTUALE AS PERC_COMM_ATM_EURO,
        -- ── Commissione ATM in VALUTA ─────────────────────────────────────────────
        -- Se causale 42 non valorizzata → fallback su causale euro (COALESCE)
        COALESCE(r_val.ROTBCAU_IMPORTO, r_euro.ROTBCAU_IMPORTO) AS EU_MIN_COMM_ATM,
        COALESCE(r_val.ROTBCAU_PERCENTUALE, r_euro.ROTBCAU_PERCENTUALE) AS PC_COMM_ATM,
        -- ── Importo commissione ATM applicabile al movimento ─────────────────────
        -- Se acquisto estero (CRVOC_ESTERA = 'S') usa causale valuta,
        -- altrimenti usa causale euro
        CASE
            WHEN f.CRVOC_ESTERA = 'S'
            THEN COALESCE(r_val.ROTBCAU_IMPORTO, r_euro.ROTBCAU_IMPORTO)
            ELSE r_euro.ROTBCAU_IMPORTO
        END AS IMP_COMM_ATM_APPLICABILE,
        CASE
            WHEN f.CRVOC_ESTERA = 'S'
            THEN COALESCE(r_val.ROTBCAU_PERCENTUALE, r_euro.ROTBCAU_PERCENTUALE)
            ELSE r_euro.ROTBCAU_PERCENTUALE
        END AS PERC_COMM_ATM_APPLICABILE
    FROM {{ ref('crvouf') }} f
    -- ── JOIN con CREMEE per recuperare le causali ATM dell'emettitore ─────────────
    -- Chiave: CRCAR_EME = CEMEM_EMETTITORE
    -- Filtro tipo record fisso 'E' come da tracciato CREMEE
    JOIN {{ ref('cremee') }} e
        ON  e.CEMEM_EMETTITORE = f.CRVOC_EMETTITORE
        AND e.CEMEM_TIPO_RECORD = 'E'
        AND e.FL_DELETED = 'N'
    -- ── JOIN con ROTBFCAU per commissione ATM in EURO (causale pos.05) ────────────
    -- Procedura fissa 'CA', causale = CEMEM_CAU_COMMISSIO05
    JOIN {{ ref('rotbfcau') }} r_euro
        ON  r_euro.ROTBCAU_PROCEDURA = 'CA'
        AND r_euro.ROTBCAU_CAUSALE = e.CEMEM_CAU_COMMISSIO05
        AND r_euro.FL_DELETED = 'N'
    -- ── LEFT JOIN con ROTBFCAU per commissione ATM in VALUTA (causale pos.42) ─────
    -- LEFT perché CEMEM_CAU_COMMISSIO42 è facoltativa:
    -- se non valorizzata il COALESCE usa il fallback sulla causale euro
    LEFT JOIN {{ ref('rotbfcau') }} r_val
        ON  r_val.ROTBCAU_PROCEDURA = 'CA'
        AND r_val.ROTBCAU_CAUSALE = e.CEMEM_CAU_COMMISSIO42
        AND e.CEMEM_CAU_COMMISSIO42 IS NOT NULL
        AND r_val.FL_DELETED = 'N'
        --AND e.CEMEM_CAU_COMMISSIO42 <> ' '     -- causale 42 blank = non valorizzata -- ERRORE perché campo number
    WHERE f.CRVOC_CONTABILIZZATO = 'C'       -- solo acquisti contabilizzati
      AND f.CRVOC_TIPO_RECORD = 'F'           -- valore fisso tracciato CRVOUF
      AND f.FL_DELETED = 'N' 
),

-- ── Macro Prodotto + tipizzazione intermediario ──────────────────────────────
macroprodotto_ca AS (
    SELECT
        f.CRVOC_EMETTITORE,
        f.CRVOC_PROTOCOLLO,
        f.CRVOC_RIGA,
        COALESCE(
            NULLIF(a.CRVOA_CONVENZIONATO, 0),
            NULLIF(a.CRVOA_SUB_AGENTE,    0),
            NULLIF(a.CRVOA_AGENTE,        0)
        ) AS CD_INTERMEDIARIO,
        CASE
            WHEN NULLIF(a.CRVOA_CONVENZIONATO, 0) IS NOT NULL THEN 'CV'
            WHEN NULLIF(a.CRVOA_SUB_AGENTE,    0) IS NOT NULL THEN 'SA'
            WHEN NULLIF(a.CRVOA_AGENTE,        0) IS NOT NULL THEN 'AG'
            ELSE NULL
        END AS TP_INTERMEDIARIO,
        mp.CD_MACRO_PRODOTTO_1,
        mp.CD_MACRO_PRODOTTO_2,
        mp.CD_MACRO_PRODOTTO_3,
        mp.CD_MACRO_PRODOTTO_4
    FROM {{ ref('crvouf') }} f
    LEFT JOIN {{ ref('crvoua') }} a
        ON  a.CRVOA_EMETTITORE = f.CRVOC_EMETTITORE
        AND a.CRVOA_PROTOCOLLO = f.CRVOC_PROTOCOLLO
        AND a.FL_DELETED = 'N'
    -- Macro prodotto agganciato per emettitore
    LEFT JOIN {{ source('l1_e_bsn', 'lkp_ger_macro_prodotto_ca') }} mp
        ON  mp.CD_EMETTITORE = f.CRVOC_EMETTITORE
    WHERE f.FL_DELETED = 'N'
),

-- ── Mercato: B2B via settore merceologico, B2C via macro prodotto 1 ───────────
base_macro_mercato AS (
    SELECT
        m.CRVOC_EMETTITORE,
        m.CRVOC_PROTOCOLLO,
        m.CRVOC_RIGA,
        m.CD_INTERMEDIARIO,
        m.TP_INTERMEDIARIO,
        m.CD_MACRO_PRODOTTO_1,
        m.CD_MACRO_PRODOTTO_2,
        m.CD_MACRO_PRODOTTO_3,
        m.CD_MACRO_PRODOTTO_4,
        COALESCE(b2b.CD_MERCATO_1, b2c.CD_MERCATO_1) AS CD_MERCATO_1,
        COALESCE(b2b.CD_MERCATO_2, b2c.CD_MERCATO_2) AS CD_MERCATO_2,
        COALESCE(b2b.CD_MERCATO_3, b2c.CD_MERCATO_3) AS CD_MERCATO_3,
        COALESCE(b2b.CD_MERCATO_4, b2c.CD_MERCATO_4) AS CD_MERCATO_4
    FROM macroprodotto_ca m
    -- Anagrafica intermediario: PV su CCANAIPV, CV su CCANAICV
    LEFT JOIN {{ ref('ccanaipv') }} ipv
        ON  ipv.IPV_CODICE = m.CD_INTERMEDIARIO
    LEFT JOIN {{ ref('ccanaicv') }} icv
        ON  icv.ICV_CODICE = m.CD_INTERMEDIARIO
    -- Mercato B2B: aggancio per settore merceologico dell'intermediario
    LEFT JOIN {{ source('l1_e_bsn', 'lkp_mercato_ca_b2b') }} b2b
        ON  m.CD_MACRO_PRODOTTO_4 = 'REV_B2B'
        AND b2b.CD_SETTORE_MERCEOLOGICO = CASE
                WHEN m.TP_INTERMEDIARIO = 'PV' THEN ipv.IPV_SETTORE_MERC
                WHEN m.TP_INTERMEDIARIO = 'CV' THEN icv.ICV_SETTORE_MERC
            END
    -- Mercato B2C: aggancio per macro prodotto 1
    LEFT JOIN {{ source('l1_e_bsn', 'lkp_mercato_ca_b2c') }} b2c
        ON  m.CD_MACRO_PRODOTTO_4 = 'REV_B2C'
        AND b2c.CD_MACRO_PRODOTTO_1 = m.CD_MACRO_PRODOTTO_1
),

base AS (
    SELECT
        f.CRVOC_PROTOCOLLO AS CD_PROTOCOLLO,
        f.CRVOC_RIGA AS CD_RIGA,
        f.CRVOC_EMETTITORE AS CD_EMETTITORE,
        f.TS_INIZIO_VALIDITA AS TS_INIZIO_VALIDITA,
        f.TS_FINE_VALIDITA AS TS_FINE_VALIDITA,
        'CA' AS TP_PROCEDURA, 
        f.CRVOC_CARTA AS CD_PRATICA,
        f.CRVOC_CARTA_OPERANTE AS CD_PRATICA_AGGIUNTIVA,
        c.CRCAR_FILIALE AS CD_FILIALE, 
        {{ ole_to_date('f.CRVOC_DATA_ACQUISTO') }} AS DT_INSERIMENTO, 
        f.CRVOC_CAUSALE AS TP_UTILIZZO,
        f.CRVOC_AUTORIZZAZIONE AS CD_AUTORIZZAZIONE,
        a.CRVOA_PROVENIENZA AS TP_MOVIMENTO,
        f.CRVOC_CONTABILIZZATO AS TP_CONTABILIZZAZIONE, 
        f.CRVOC_DARE_AVERE AS CD_DARE_AVERE,
        au.CRAUT_PSV_AUT_POS AS FL_WEB,
        CASE WHEN f.CRVOC_CODICE_CAMP IS NOT NULL THEN 'Y' ELSE 'N' END AS FL_PROMO,
        CASE 
            WHEN f.CRVOC_CONTABILIZZATO IN ('S', 'H') THEN 'S'
            ELSE 'N'
        END AS FL_STORNATO_INTRADAY,
        CASE 
            WHEN f.CRVOC_CONTABILIZZATO IN ('S', 'H') THEN 'S'
            WHEN sv_not_a.CROSV_TIPO_COLL = 'ST' THEN 'S'
            ELSE 'N'
        END AS FL_STORNATO,
        CASE 
            WHEN sv.CROSV_TIPO_COLL = 'ST' THEN 'S'
            ELSE 'N'
        END AS FL_STORNO,
        CASE 
            WHEN a.CRVOA_NUMERO_ASSEGNO IS NOT NULL THEN 'S'
            ELSE 'N' 
        END AS FL_ASSEGNO, 
        {{ ole_to_date('a.CRVOA_DATA_REGISTRAZIONE') }} AS DT_DECORRENZA,
        {{ ole_to_date('f.CRVOC_DATA_ACQUISTO') }} AS DT_UTILIZZO,
        {{ ole_to_date('f.CRVOC_DATA_VALUTA') }} AS DT_VALUTA,
        CASE
            WHEN f.CRVOC_CONTABILIZZATO = 'S' AND sv.CROSV_EMETTITORE_A IS NULL THEN {{ ole_to_date('f.CRVOC_DATA_ACQUISTO') }}
            WHEN f.CRVOC_DARE_AVERE = 'A' AND sv.CROSV_EMETTITORE_A IS NOT NULL THEN {{ ole_to_date('a.CRVOA_DATA_REGISTRAZIONE') }}
            ELSE NULL
        END AS DT_STORNATA,
        {{ ole_to_date('a.CRVOA_DATA_LIQUIDAZIONE') }} AS DT_LIQUIDAZIONE, 
        {{ custom_to_date('a.CRVOA_CERT_DATA') }} AS DT_APPROVAZIONE_UTILIZZO,
        {{ custom_to_date('a.CRVOA_DATA_CONTAB') }} AS DT_CONTABILIZZAZIONE_ACQUISTO,
        a.CRVOA_FORMA_PAGAMENTO AS CD_MOD_LIQUIDAZIONE, 
        a.CRVOA_FORMA_PAGAMENTO AS DS_MOD_LIQUIDAZIONE, 
        {{ custom_to_decimal('f.CRVOC_IMPORTO', precision=11) }} AS EU_EROGATO,
        {{ custom_to_decimal('f.CRVOC_TOTALE', precision=11) }} AS EU_FINANZIATO,
        {{ custom_to_decimal('f.CRVOC_COMM_ATM', precision=13) }} AS EU_COMMISSIONE_ATM,
        -- Logica commissioni ATM completa dalla CTE base_comm_atm
        comm.PC_COMM_ATM,
        {{ custom_to_decimal('comm.EU_MIN_COMM_ATM', precision=6, decimal=3) }} AS EU_MIN_COMM_ATM,
        {{ custom_to_decimal('f.CRVOC_IMPORTO_ASSIC', precision=13) }} AS EU_ASSICURAZIONE_PROMO,
        {{ custom_to_decimal('f.CRVOC_SPESE_ISTRUT', precision=13) }} AS EU_SPESE_TOT_IST,
        ci.CRINS_PERC_SPESE_ISTRUT AS PC_SPESE_IST,
        ci.CRINS_BENE AS CD_BENE,
        ci.CRINS_DES_BENE AS DS_BENE,
        {{ custom_to_decimal('ci.CRINS_VALORE_BENE', precision=13) }} AS EU_VALORE_BENE,
        f.CRVOC_CODICE_CAMP AS CD_PROMOZIONE,
        f.CRVOC_MESI_DILAZ AS NM_MESI_DILAZIONE,
        f.CRVOC_NUM_RATE AS NM_DURATA_FINANZ, 
        f.CRVOC_COMMISSIONI AS PC_COMMISSIONE,
        /*f.CRVOC_TAEG*/ {{ custom_to_decimal('cast(NULL as number)') }} AS NM_TAEG, -- WARN: CRVOC_TAEG non presente in CRVOUF
        CASE WHEN f.CRVOC_CONTR_DEALER IS NOT NULL THEN 'S' ELSE 'N' END AS FL_CONTRIBUTI_PROMO, 
        {{ custom_to_decimal('ci.CRINS_TAN_CAMP') }} AS NM_TAN_PROMO,
        {{ custom_to_decimal('ci.CRINS_TEG_CAMP') }} AS NM_TEG_PROMO,
        {{ custom_to_decimal('ci.CRINS_TAEG_CAMP') }} AS NM_TAEG_PROMO,
        tc.CRTCAM_TAEG_FISSO AS FL_TAEG_FISSO,
        {{ custom_to_decimal('tc.CRTCAM_TAEG_FISSO_MIN') }} AS NM_TAEG_FISSO_MIN,
        {{ custom_to_decimal('tc.CRTCAM_TAEG_FISSO_MAX') }} AS NM_TAEG_FISSO_MAX,
        tc.CRTCAM_PERC_SCONTO AS PC_SCONTO,
        {{ custom_to_decimal('ci.CRINS_NUM_RATE_CAMP') }} AS NM_RATE,
        tc.CRTCAM_TASSO_CLI AS PC_TASSO_RATA,
        {{ custom_to_decimal('ci.CRINS_IMP_PRIMA_RATA_CAMP', precision=13) }} AS EU_PRIMA_RATA_PROMO,
        {{ custom_to_date('ci.CRINS_SCAD_PRIMA_RATA_CAMP') }} AS DT_SCAD_PRIMA_RATA_PROMO, 
        {{ custom_to_decimal('ci.CRINS_COMMISSIONI_CAMP', precision=13) }} AS EU_COMMISSIONI_PROMO,
        {{ custom_to_decimal('ci.CRINS_BOLLO_CAMP', precision=13) }} AS EU_BOLLO_PROMO,
        {{ custom_to_decimal('f.CRVOC_INTERESSI', precision=11) }} AS EU_INTERESSI_PROMO,
        /*f.CRVOC_IRR*/ {{ custom_to_decimal('cast(NULL as number)') }} AS NM_IRR, -- WARN CRVOC_IRR non presente in CRVOUF
        CASE
            WHEN sv.CROSV_RIGA IS NOT NULL THEN 'N' 
            WHEN sq.SPCLSTAQ_RIGA IS NOT NULL THEN 'Y'
        END AS FL_CIRCUITO, -- WARN: SPCLFSTAQ non in catalog sorgenti
        COALESCE(sv.CROSV_TIPO_COLL, sq.SPCLSTAQ_TIPO_COLL) AS TP_COLLEGAMENTO,
        COALESCE(sv.CROSV_PROTOCOLLO_A, sq.SPCLSTAQ_PROTOCOLLO_A) AS CD_PROTOCOLLO_UT_COLLEGATO,
        COALESCE(sv.CROSV_RIGA_A, sq.SPCLSTAQ_RIGA_A) AS CD_RIGA_UT_COLLEGATO,
        {{ custom_to_date('COALESCE(sv.CROSV_DATA_REGISTRAZIONE, sq.SPCLSTAQ_DATA)') }} AS DT_COLLEGAMENTO_STORNO,
        ps.INTACQ_CAT_ESERC AS CD_MERC,
        mc.SICCOD_MCC_DES AS DS_MERC,
        ps.INTACQ_ACQ_REF_NR AS CD_ACQUIRER,
        ps.INTACQ_NOME_ESERC AS DS_NOME_ESERC,
        ps.INTACQ_CITTA_ESERC AS DS_CITTA_ESERC,
        ps.INTACQ_COD_NAZ_ES AS CD_NAZIONE_ESERC,
        ps.INTACQ_ID_TITOLARE AS CD_METODO_IDENTIFICAZIONE,
        ps.INTACQ_CIRCUITO AS CD_CIRCUITO,
        ps.INTACQ_CAUSALE_SSB AS CD_CAUSALE,
        ps.INTACQ_COD_TRANSAZ::VARCHAR AS TP_TRANSAZIONE, --WARN: in L1 NUMBER(2,0) in L2 VARCHAR(2)
        a.CRVOA_PRODOTTO AS CD_PRODOTTO,
        NULL AS CD_CATEGORIA_PRODOTTO,
        e.CEMEM_E_COMMERCE AS TP_CATEGORIA_CARTE,
        mm.CD_MACRO_PRODOTTO_1,
        mm.CD_MACRO_PRODOTTO_2,
        mm.CD_MACRO_PRODOTTO_3,
        mm.CD_MACRO_PRODOTTO_4,
        mm.CD_MERCATO_1,
        mm.CD_MERCATO_2,
        mm.CD_MERCATO_3,
        mm.CD_MERCATO_4,
        CAST(CAST(CASE
            WHEN F_CO.ANATFI_AREA IN ('SED', 'FIL', 'B2B') THEN a.CRVOA_FILIALE
            WHEN F_CO.ANATFI_AREA = 'AGE'                   THEN N_CO.INT_FILIALE
            WHEN F_CO.ANATFI_AREA = 'IFQ' THEN
                CASE
                    WHEN F_CO.ANATFI_DISTRETTO = 'I10' THEN a.CRVOA_FILIALE
                    WHEN F_CO.ANATFI_DISTRETTO = 'I01' THEN a.CRVOA_RETE_VENDITA
                    WHEN F_CO.ANATFI_DISTRETTO = 'I99' THEN N_CO.INT_FILIALE
                END
        END AS NUMBER(10)) AS VARCHAR(10))                             AS CD_NODO_FOGLIA,
        mm.CD_INTERMEDIARIO,
        mm.TP_INTERMEDIARIO,
        a.CRVOA_RETE_VENDITA AS CD_RETE_VENDITA_ESERCENTE,
        a.CRVOA_AGENTE AS CD_AGENTE_ESERCENTE,
        a.CRVOA_SUB_AGENTE AS CD_SUB_AGENTE_ESERCENTE,
        a.CRVOA_CONVENZIONATO AS CD_CONVENZIONATO_ESERCENTE,
        a.CRVOA_FILIALE AS CD_FILIALE_ESERCENTE,
        a.CRVOA_VENDITORE AS CD_VENDITORE_ESERCENTE,
        f.LASTMODIFIEDDATA AS LASTMODIFIEDDATA
    FROM {{ ref('crvouf') }} f
    -- JOIN con CTE per logica commissioni ATM completa
    LEFT JOIN base_comm_atm comm
        ON  comm.CRVOC_EMETTITORE = f.CRVOC_EMETTITORE
        AND comm.CRVOC_PROTOCOLLO = f.CRVOC_PROTOCOLLO
        AND comm.CRVOC_RIGA = f.CRVOC_RIGA
    LEFT JOIN base_macro_mercato mm
        ON  mm.CRVOC_EMETTITORE = f.CRVOC_EMETTITORE
        AND mm.CRVOC_PROTOCOLLO = f.CRVOC_PROTOCOLLO
        AND mm.CRVOC_RIGA = f.CRVOC_RIGA
    LEFT JOIN {{ ref('crcar') }} c 
        ON  c.CRCAR_KEY_N = f.CRVOC_CARTA 
    LEFT JOIN {{ ref('crvoua') }} a
        ON  a.CRVOA_EMETTITORE = f.CRVOC_EMETTITORE
        AND a.CRVOA_PROTOCOLLO = f.CRVOC_PROTOCOLLO
        AND a.FL_DELETED = 'N'
    LEFT JOIN {{ ref('craut') }} au
        ON  au.CRAUT_EMETTITORE = f.CRVOC_EMETTITORE
        AND au.CRAUT_AUTORIZZAZIONE = f.CRVOC_AUTORIZZAZIONE
        AND au.FL_DELETED = 'N'
    LEFT JOIN {{ ref('crcrosvou') }} sv
        ON  sv.CROSV_EMETTITORE_A = f.CRVOC_EMETTITORE
        AND sv.CROSV_PROTOCOLLO_A = f.CRVOC_PROTOCOLLO
        AND sv.CROSV_RIGA_A = f.CRVOC_RIGA
        AND sv.FL_DELETED = 'N'
    LEFT JOIN {{ ref('crcrosvou') }} sv_not_a
        ON  sv_not_a.CROSV_EMETTITORE = f.CRVOC_EMETTITORE
        AND sv_not_a.CROSV_PROTOCOLLO = f.CRVOC_PROTOCOLLO
        AND sv_not_a.CROSV_RIGA = f.CRVOC_RIGA
        AND sv_not_a.FL_DELETED = 'N'
    LEFT JOIN {{ ref('spclfstaq') }} sq 
        ON  sq.SPCLSTAQ_EMETTITORE_A = f.CRVOC_EMETTITORE
        AND sq.SPCLSTAQ_PROTOCOLLO_A = f.CRVOC_PROTOCOLLO
        AND sq.SPCLSTAQ_RIGA_A = f.CRVOC_RIGA
        AND sq.FL_DELETED = 'N'
    LEFT JOIN {{ ref('crinstant') }} ci
        ON  ci.CRINS_EMETTITORE = f.CRVOC_EMETTITORE
        AND ci.CRINS_PROTOCOLLO = f.CRVOC_PROTOCOLLO
        AND ci.CRINS_RIGA = f.CRVOC_RIGA
        AND ci.FL_DELETED = 'N'
    LEFT JOIN {{ ref('crtabcam') }} tc
        ON  tc.CRTCAM_CODICE = f.CRVOC_CODICE_CAMP
        AND tc.FL_DELETED = 'N'
    LEFT JOIN {{ ref('psintacq') }} ps
        ON  ps.INTACQ_EMETTITORE = f.CRVOC_EMETTITORE
        AND ps.INTACQ_PROTOCOLLO = f.CRVOC_PROTOCOLLO
        AND ps.INTACQ_RIGA = f.CRVOC_RIGA
        AND ps.FL_DELETED = 'N'
    LEFT JOIN {{ ref('pssiccod') }} mc
        ON  mc.SICCOD_MCC_CODE = ps.INTACQ_CAT_ESERC -- CORRETTA QUESTA JOIN??? ps. --> VARCHAR(5) <> mc. --> NUMBER(4)
        AND mc.FL_DELETED = 'N'
    LEFT JOIN {{ ref('cremee') }} e 
        ON  e.CEMEM_EMETTITORE = f.CRVOC_EMETTITORE
        AND e.CEMEM_TIPO_RECORD = 'E'
    LEFT JOIN {{ ref('ccanatfi') }} F_CO
        ON  F_CO.ANATFI_FILIALE = a.CRVOA_FILIALE
    LEFT JOIN {{ ref('ccanainin') }} N_CO
        ON  N_CO.INT_CODICE = a.CRVOA_SUB_AGENTE
    WHERE f.FL_DELETED = 'N'  
),

dedup AS (
    SELECT
        CD_PROTOCOLLO,
        CD_RIGA,
        CD_EMETTITORE,
        TS_INIZIO_VALIDITA,
        TS_FINE_VALIDITA,
        TP_PROCEDURA,
        CD_PRATICA,
        CD_PRATICA_AGGIUNTIVA,
        CD_FILIALE,
        DT_INSERIMENTO,
        TP_UTILIZZO,
        CD_AUTORIZZAZIONE,
        TP_MOVIMENTO,
        TP_CONTABILIZZAZIONE,
        CD_DARE_AVERE,
        FL_WEB,
        FL_PROMO,
        FL_STORNATO_INTRADAY,
        FL_STORNATO,
        FL_STORNO,
        FL_ASSEGNO,
        DT_DECORRENZA,
        DT_UTILIZZO,
        DT_VALUTA,
        DT_STORNATA,
        DT_LIQUIDAZIONE,
        DT_APPROVAZIONE_UTILIZZO,
        DT_CONTABILIZZAZIONE_ACQUISTO,
        CD_MOD_LIQUIDAZIONE,
        DS_MOD_LIQUIDAZIONE,
        EU_EROGATO,
        EU_FINANZIATO,
        EU_COMMISSIONE_ATM,
        PC_COMM_ATM,
        EU_MIN_COMM_ATM,
        EU_ASSICURAZIONE_PROMO,
        EU_SPESE_TOT_IST,
        PC_SPESE_IST,
        CD_BENE,
        DS_BENE,
        EU_VALORE_BENE,
        CD_PROMOZIONE,
        NM_MESI_DILAZIONE,
        NM_DURATA_FINANZ,
        PC_COMMISSIONE,
        NM_TAEG,
        FL_CONTRIBUTI_PROMO,
        NM_TAN_PROMO,
        NM_TEG_PROMO,
        NM_TAEG_PROMO,
        FL_TAEG_FISSO,
        NM_TAEG_FISSO_MIN,
        NM_TAEG_FISSO_MAX,
        PC_SCONTO,
        NM_RATE,
        PC_TASSO_RATA,
        EU_PRIMA_RATA_PROMO,
        DT_SCAD_PRIMA_RATA_PROMO,
        EU_COMMISSIONI_PROMO,
        EU_BOLLO_PROMO,
        EU_INTERESSI_PROMO,
        NM_IRR,
        FL_CIRCUITO,
        TP_COLLEGAMENTO,
        CD_PROTOCOLLO_UT_COLLEGATO,
        CD_RIGA_UT_COLLEGATO,
        DT_COLLEGAMENTO_STORNO,
        CD_MERC,
        DS_MERC,
        CD_ACQUIRER,
        DS_NOME_ESERC,
        DS_CITTA_ESERC,
        CD_NAZIONE_ESERC,
        CD_METODO_IDENTIFICAZIONE,
        CD_CIRCUITO,
        CD_CAUSALE,
        TP_TRANSAZIONE,
        CD_PRODOTTO,
        CD_CATEGORIA_PRODOTTO,
        TP_CATEGORIA_CARTE,
        CD_MACRO_PRODOTTO_1,
        CD_MACRO_PRODOTTO_2,
        CD_MACRO_PRODOTTO_3,
        CD_MACRO_PRODOTTO_4,
        CD_MERCATO_1,
        CD_MERCATO_2,
        CD_MERCATO_3,
        CD_MERCATO_4,
        CD_NODO_FOGLIA,
        CD_INTERMEDIARIO,
        TP_INTERMEDIARIO,
        CD_RETE_VENDITA_ESERCENTE,
        CD_AGENTE_ESERCENTE,
        CD_SUB_AGENTE_ESERCENTE,
        CD_CONVENZIONATO_ESERCENTE,
        CD_FILIALE_ESERCENTE,
        CD_VENDITORE_ESERCENTE,
        LASTMODIFIEDDATA, 
        {{ hash_cols([
            'CD_PROTOCOLLO', 'CD_RIGA', 'CD_EMETTITORE', 'TP_PROCEDURA', 'CD_PRATICA', 'CD_PRATICA_AGGIUNTIVA',
            'CD_FILIALE', 'DT_INSERIMENTO', 'TP_UTILIZZO', 'CD_AUTORIZZAZIONE', 'TP_MOVIMENTO', 'TP_CONTABILIZZAZIONE',
            'CD_DARE_AVERE', 'FL_WEB', 'FL_PROMO', 'FL_STORNATO_INTRADAY','FL_STORNATO', 'FL_STORNO', 'FL_ASSEGNO', 'DT_DECORRENZA', 'DT_UTILIZZO',
            'DT_VALUTA', 'DT_STORNATA', 'DT_LIQUIDAZIONE', 'DT_APPROVAZIONE_UTILIZZO', 'DT_CONTABILIZZAZIONE_ACQUISTO',
            'CD_MOD_LIQUIDAZIONE', 'DS_MOD_LIQUIDAZIONE', 'EU_EROGATO', 'EU_FINANZIATO', 'EU_COMMISSIONE_ATM',
            'PC_COMM_ATM', 'EU_MIN_COMM_ATM', 'EU_ASSICURAZIONE_PROMO', 'EU_SPESE_TOT_IST', 'PC_SPESE_IST',
            'CD_BENE', 'DS_BENE', 'EU_VALORE_BENE', 'CD_PROMOZIONE', 'NM_MESI_DILAZIONE', 'NM_DURATA_FINANZ',
            'PC_COMMISSIONE', 'NM_TAEG', 'FL_CONTRIBUTI_PROMO', 'NM_TAN_PROMO', 'NM_TEG_PROMO', 'NM_TAEG_PROMO',
            'FL_TAEG_FISSO', 'NM_TAEG_FISSO_MIN', 'NM_TAEG_FISSO_MAX', 'PC_SCONTO', 'NM_RATE', 'PC_TASSO_RATA',
            'EU_PRIMA_RATA_PROMO', 'DT_SCAD_PRIMA_RATA_PROMO', 'EU_COMMISSIONI_PROMO', 'EU_BOLLO_PROMO',
            'EU_INTERESSI_PROMO', 'NM_IRR', 'FL_CIRCUITO', 'TP_COLLEGAMENTO', 'CD_PROTOCOLLO_UT_COLLEGATO',
            'CD_RIGA_UT_COLLEGATO', 'DT_COLLEGAMENTO_STORNO', 'CD_MERC', 'DS_MERC', 'CD_ACQUIRER', 'DS_NOME_ESERC',
            'DS_CITTA_ESERC', 'CD_NAZIONE_ESERC', 'CD_METODO_IDENTIFICAZIONE', 'CD_CIRCUITO', 'CD_CAUSALE',
            'TP_TRANSAZIONE', 'CD_PRODOTTO', 'CD_CATEGORIA_PRODOTTO', 'TP_CATEGORIA_CARTE',
            'CD_MACRO_PRODOTTO_1', 'CD_MACRO_PRODOTTO_2', 'CD_MACRO_PRODOTTO_3', 'CD_MACRO_PRODOTTO_4',
            'CD_MERCATO_1', 'CD_MERCATO_2', 'CD_MERCATO_3', 'CD_MERCATO_4', 'CD_NODO_FOGLIA',
            'CD_INTERMEDIARIO', 'TP_INTERMEDIARIO', 'CD_RETE_VENDITA_ESERCENTE',
            'CD_AGENTE_ESERCENTE', 'CD_SUB_AGENTE_ESERCENTE', 'CD_CONVENZIONATO_ESERCENTE', 'CD_FILIALE_ESERCENTE',
            'CD_VENDITORE_ESERCENTE'
        ]) }} AS HASHED_COLS
    FROM base {{ is_incremental_S1('[CD_PROTOCOLLO, CD_RIGA, CD_EMETTITORE]') }}
)

SELECT
    H.CD_PROTOCOLLO,
    H.CD_RIGA,
    H.CD_EMETTITORE,
    H.TS_INIZIO_VALIDITA,
    {{ ts_fine_validita('[H.CD_PROTOCOLLO, H.CD_RIGA, H.CD_EMETTITORE]', 'H.TS_INIZIO_VALIDITA') }} AS TS_FINE_VALIDITA,
    H.TP_PROCEDURA,
    H.CD_PRATICA,
    H.CD_PRATICA_AGGIUNTIVA,
    H.CD_FILIALE,
    H.DT_INSERIMENTO,
    H.TP_UTILIZZO,
    H.CD_AUTORIZZAZIONE,
    H.TP_MOVIMENTO,
    H.TP_CONTABILIZZAZIONE,
    H.CD_DARE_AVERE,
    H.FL_WEB,
    H.FL_PROMO,
    H.FL_STORNATO_INTRADAY,
    H.FL_STORNATO,
    H.FL_STORNO,
    H.FL_ASSEGNO,
    H.DT_DECORRENZA,
    H.DT_UTILIZZO,
    H.DT_VALUTA,
    H.DT_STORNATA,
    H.DT_LIQUIDAZIONE,
    H.DT_APPROVAZIONE_UTILIZZO,
    H.DT_CONTABILIZZAZIONE_ACQUISTO,
    H.CD_MOD_LIQUIDAZIONE,
    H.DS_MOD_LIQUIDAZIONE,
    H.EU_EROGATO,
    H.EU_FINANZIATO,
    H.EU_COMMISSIONE_ATM,
    H.PC_COMM_ATM,
    H.EU_MIN_COMM_ATM,
    H.EU_ASSICURAZIONE_PROMO,
    H.EU_SPESE_TOT_IST,
    H.PC_SPESE_IST,
    H.CD_BENE,
    H.DS_BENE,
    H.EU_VALORE_BENE,
    H.CD_PROMOZIONE,
    H.NM_MESI_DILAZIONE,
    H.NM_DURATA_FINANZ,
    H.PC_COMMISSIONE,
    H.NM_TAEG,
    H.FL_CONTRIBUTI_PROMO,
    H.NM_TAN_PROMO,
    H.NM_TEG_PROMO,
    H.NM_TAEG_PROMO,
    H.FL_TAEG_FISSO,
    H.NM_TAEG_FISSO_MIN,
    H.NM_TAEG_FISSO_MAX,
    H.PC_SCONTO,
    H.NM_RATE,
    H.PC_TASSO_RATA,
    H.EU_PRIMA_RATA_PROMO,
    H.DT_SCAD_PRIMA_RATA_PROMO,
    H.EU_COMMISSIONI_PROMO,
    H.EU_BOLLO_PROMO,
    H.EU_INTERESSI_PROMO,
    H.NM_IRR,
    H.FL_CIRCUITO,
    H.TP_COLLEGAMENTO,
    H.CD_PROTOCOLLO_UT_COLLEGATO,
    H.CD_RIGA_UT_COLLEGATO,
    H.DT_COLLEGAMENTO_STORNO,
    H.CD_MERC,
    H.DS_MERC,
    H.CD_ACQUIRER,
    H.DS_NOME_ESERC,
    H.DS_CITTA_ESERC,
    H.CD_NAZIONE_ESERC,
    H.CD_METODO_IDENTIFICAZIONE,
    H.CD_CIRCUITO,
    H.CD_CAUSALE,
    H.TP_TRANSAZIONE,
    H.CD_PRODOTTO,
    H.CD_CATEGORIA_PRODOTTO,
    H.TP_CATEGORIA_CARTE,
    H.CD_MACRO_PRODOTTO_1,
    H.CD_MACRO_PRODOTTO_2,
    H.CD_MACRO_PRODOTTO_3,
    H.CD_MACRO_PRODOTTO_4,
    H.CD_MERCATO_1,
    H.CD_MERCATO_2,
    H.CD_MERCATO_3,
    H.CD_MERCATO_4,
    H.CD_NODO_FOGLIA,
    H.CD_INTERMEDIARIO,
    H.TP_INTERMEDIARIO,
    H.CD_RETE_VENDITA_ESERCENTE,
    H.CD_AGENTE_ESERCENTE,
    H.CD_SUB_AGENTE_ESERCENTE,
    H.CD_CONVENZIONATO_ESERCENTE,
    H.CD_FILIALE_ESERCENTE,
    H.CD_VENDITORE_ESERCENTE,
    H.LASTMODIFIEDDATA
FROM dedup H