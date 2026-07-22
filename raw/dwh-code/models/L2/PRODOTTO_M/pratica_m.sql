WITH
-- ==============================================================
-- CONSUMO CTEs
-- ==============================================================
cte_pltbfstat AS (
    SELECT
        PLSTAT_CODICE,
        PLSTAT_DESCRIZIONE AS DS_STATO,
        TS_INIZIO_VALIDITA, TS_FINE_VALIDITA
    FROM {{ ref('pltbfstat') }}
    WHERE FL_DELETED = 'N'
),

cte_pltbfbene AS (
    SELECT
        PLBENE_CODICE,
        PLBENE_DESCRIZIONE AS DS_DESTINAZIONE_BENE,
        TS_INIZIO_VALIDITA, TS_FINE_VALIDITA
    FROM {{ ref('pltbfbene') }}
    WHERE FL_DELETED = 'N'
),

cte_mfftbcaq_co AS (
    SELECT
        MFTBCAQ_CANALE_ACQUISIZIONE,
        MFTBCAQ_DESCRIZIONE AS DS_CANALE_ACQUISIZIONE,
        MFTBCAQ_WEB         AS FL_WEB_CANALE_ACQ,
        TS_INIZIO_VALIDITA, TS_FINE_VALIDITA
    FROM {{ ref('mfftbcaq') }}
    WHERE FL_DELETED = 'N'
),

cte_oxisfttp_co AS (
    SELECT
        OXISTTP_TIPO_PROCESSO,
        OXISTTP_DESCRIZIONE AS DS_TIPO_PROCESSO,
        TS_INIZIO_VALIDITA, TS_FINE_VALIDITA
    FROM {{ ref('oxisfttp') }}
    WHERE FL_DELETED = 'N'
),

cte_oxprftafb AS (
    SELECT
        OXTB_CODICE,
        OXTB_DESCRIZIONE AS DS_TABELLA_FINANZIARIA,
        TS_INIZIO_VALIDITA, TS_FINE_VALIDITA
    FROM {{ ref('oxprftafb') }}
    WHERE FL_DELETED = 'N'
),

cte_ccanaipv_co AS (
    SELECT
        IPV_CODICE,
        IPV_INSEGNA      AS DS_INSEGNA
    FROM {{ ref('ccanaipv') }}
),


cte_cnslflog_co AS (
    SELECT
        TMP.CNSLLOG_PRATICA,
        TRY_TO_TIMESTAMP(TO_CHAR(TMP.CNSLLOG_DATA) || LPAD(LEFT(TO_CHAR(TMP.CNSLLOG_ORA), 6), 6, '0'), 'YYYYMMDDHH24MISS') 
        AS TS_COMUNICAZIONE_ESITO_DEF
    FROM (
        SELECT
            CNSLLOG_PRATICA,
            CNSLLOG_DATA,
            CNSLLOG_ORA,
            ROW_NUMBER() OVER (PARTITION BY CNSLLOG_PRATICA ORDER BY CNSLLOG_PROGRESSIVO DESC) AS RN
        FROM {{ ref('cnslflog') }}
        WHERE CNSLLOG_PROCEDURA = 'CO'
        AND FL_DELETED = 'N'
    ) TMP
    WHERE TMP.RN = 1
),

cte_oxctfpafd_co AS (
    SELECT
        OXCTPAFD_NUM_PRATICA,
        MAX({{ custom_to_date('OXCTPAFD_DT_ACCODAMENTO') }}) AS DT_ULT_ACCODAMENTO
    FROM {{ ref('oxctfpafd') }}
    WHERE OXCTPAFD_PROCEDURA = 'CO'
    AND FL_DELETED = 'N'
    GROUP BY OXCTPAFD_NUM_PRATICA
),

cte_oxctfpaff_co AS (
    SELECT
        OXCTPAFF_NUM_PRATICA,
        {{ custom_to_date('OXCTPAFF_PRIMA_SCADENZA') }}  AS DT_PRIMA_SCADENZA_IST,
        {{ custom_to_date('OXCTPAFF_ULTIMA_SCADENZA') }} AS DT_ULTIMA_SCADENZA_IST
    FROM {{ ref('oxctfpaff') }}
    WHERE OXCTPAFF_PROCEDURA   = 'CO'
    AND OXCTPAFF_PROGRESSIVO = 1
    AND FL_DELETED = 'N'
),

cte_plpratst_rt AS (
    SELECT
        TMP.PLPRA_NUM_PRATICA,
        TMP.PLPRA_UTENTE AS CD_USER_RITIRATA
    FROM (
        SELECT
            PLPRA_NUM_PRATICA,
            PLPRA_UTENTE,
            ROW_NUMBER() OVER (PARTITION BY PLPRA_NUM_PRATICA ORDER BY PLPRA_DATA DESC) AS RN
        FROM {{ ref('plpratst') }}
        WHERE PLPRA_ATTRIBUTO = 'RT'
        AND FL_DELETED = 'N'
    ) TMP
    WHERE TMP.RN = 1
),

cte_plpratst_res AS (
    SELECT
        TMP.PLPRA_NUM_PRATICA,
        TMP.PLPRA_UTENTE AS CD_USER_RESPINTA
    FROM (
        SELECT
            PLPRA_NUM_PRATICA,
            PLPRA_UTENTE,
            ROW_NUMBER() OVER (PARTITION BY PLPRA_NUM_PRATICA ORDER BY PLPRA_DATA DESC) AS RN
        FROM {{ ref('plpratst') }}
        WHERE PLPRA_ATTRIBUTO = 'RE'
        AND FL_DELETED = 'N'
    ) TMP
    WHERE TMP.RN = 1
),

cte_oxscfpra_co AS (
    SELECT
        OXSCPRA_PRATICA,
        OXSCPRA_MODALITA_FIRMA AS TP_FIRMA,
        TS_INIZIO_VALIDITA, TS_FINE_VALIDITA
    FROM {{ ref('oxscfpra') }}
    WHERE OXSCPRA_PROCEDURA = 'CO'
    AND OXSCPRA_PROG_PSV  = 1
    AND FL_DELETED = 'N'
),

cte_ccpsvt_abb_co AS (
    SELECT DISTINCT
        PSVT_PRATICA,
        'S' AS FL_ABBUONO
    FROM {{ ref('ccpsvt') }}
    WHERE PSVT_AZIONE    = 'ABB'
    AND PSVT_PROCEDURA = 'CO'
    AND FL_DELETED = 'N'
),

cte_plchices AS (
    SELECT
        CHC_PRATICA,
        CASE WHEN CHC_CES_PERDITA IS NOT NULL THEN 'S' ELSE 'N'
        END AS FL_PERDITA_CESSIONE
    FROM {{ ref('plchices') }}
    WHERE FL_DELETED = 'N'
),

cte_plsecpra AS (
    SELECT DISTINCT
        SCPRA_NUM_PRATICA,
        'S' AS FL_CARTOLARIZZATA,
        DT_OSSERVAZIONE
    FROM {{ ref('plsecpra_m') }}
),

cte_plpratserv_as AS (
    SELECT DISTINCT
        PLSE_NUM_PRATICA,
        'S' AS FL_PRODOTTO_ASSICURATIVO,
        DT_OSSERVAZIONE
    FROM {{ ref('plpratserv_m') }}
    WHERE PLSE_TIPO_SERVIZIO = 'AS'
),

cte_re2praba_co AS (
    SELECT DISTINCT
        DPRBA_PRATICA,
        'S' AS FL_RECUPERO,
        DT_OSSERVAZIONE
    FROM {{ref("re2praba_m")}}
    WHERE DPRBA_PROVENIENZA = 'CO'
),

cte_cctrcamp_co AS (
    SELECT DISTINCT
        TRCA_NUM_PRATICA
    FROM {{ ref('cctrcamp') }}
    WHERE TRCA_PROVENIENZA = 'CO'
),

TAB_FIN_CONSUMO AS (
    SELECT
        P.PLC_NUM_PRATICA                               AS CD_PRATICA,
        'CO'                                            AS TP_PROCEDURA,
        P.DT_OSSERVAZIONE                               AS DT_OSSERVAZIONE,
        NULL                                            AS TP_ORIG_PRAT,
        P.PLC_STATO                                     AS CD_STATO,
        STAT.DS_STATO,
        P.PLC_ATTRIBUTO                                 AS CD_ATTRIBUTO,
        P.PLC_CLIENTE                                   AS CD_CLIENTE,
        CAST(P.PLC_CONIUGE AS VARCHAR(9))               AS CD_COOBLIGATO,
        P.PLC_TIPO_PRODOTTO                             AS CD_TIPO_PRODOTTO,
        P.PLC_PRODOTTO                                  AS CD_PRODOTTO,
        MPRO.CD_MACRO_PRODOTTO_1                         AS CD_MACRO_PRODOTTO_1,
        MPRO.CD_MACRO_PRODOTTO_2                         AS CD_MACRO_PRODOTTO_2,
        MPRO.CD_MACRO_PRODOTTO_3                         AS CD_MACRO_PRODOTTO_3,
        MPRO.CD_MACRO_PRODOTTO_4                         AS CD_MACRO_PRODOTTO_4,
        COALESCE(MKT_PAPF.CD_MERCATO_1, MKT_PP.CD_MERCATO_1) AS CD_MERCATO_1,
        COALESCE(MKT_PAPF.CD_MERCATO_2, MKT_PP.CD_MERCATO_2) AS CD_MERCATO_2,
        COALESCE(MKT_PAPF.CD_MERCATO_3, MKT_PP.CD_MERCATO_3) AS CD_MERCATO_3,
        COALESCE(MKT_PAPF.CD_MERCATO_4, MKT_PP.CD_MERCATO_4) AS CD_MERCATO_4,
        CAST(CAST(CASE
            WHEN F_CO.ANATFI_AREA IN ('SED', 'FIL', 'B2B') THEN N_PLC.INT_FILIALE
            WHEN F_CO.ANATFI_AREA = 'AGE'                   THEN N_CO.INT_FILIALE
            WHEN F_CO.ANATFI_AREA = 'IFQ' THEN
                CASE
                    WHEN F_CO.ANATFI_DISTRETTO = 'I10' THEN N_PLC.INT_FILIALE
                    WHEN F_CO.ANATFI_DISTRETTO = 'I01' THEN P.PLC_RETE_VENDITA
                    WHEN F_CO.ANATFI_DISTRETTO = 'I99' THEN N_CO.INT_FILIALE
                END
        END AS NUMBER(10)) AS VARCHAR(10))              AS CD_NODO_FOGLIA,
        NULL                                            AS DS_PRODOTTO_POG,
        NULL                                            AS CD_EMETTITORE,
        NULL                                            AS EU_FIDO,
        CAST(NULL AS VARCHAR(27))                       AS CD_IBAN,
        P.PLC_BENE                                      AS CD_DESTINAZIONE_BENE,
        BENE.DS_DESTINAZIONE_BENE,
        CAST(P.PLC_FILIALE AS VARCHAR(3))               AS CD_FILIALE_PRAT,
        CAST(N_PLC.INT_FILIALE AS VARCHAR(3))           AS CD_FILIALE_INT,
        P.PLC_RESPONSABILE                              AS CD_RESPONSABILE,
        P.PLC_CANALE_ACQ                                AS CD_CANALE_ACQUISIZIONE,
        CAQ.DS_CANALE_ACQUISIZIONE,
        CAQ.FL_WEB_CANALE_ACQ,
        P.PLC_TIPO_PROCESSO                             AS CD_TIPO_PROCESSO,
        TTP.DS_TIPO_PROCESSO,
        COALESCE(
            NULLIF(P.PLC_PUNTO_VENDITA, 0),
            NULLIF(P.PLC_CONVENZIONATO, 0),
            NULLIF(P.PLC_SUB_AGENTE,    0),
            NULLIF(P.PLC_AGENTE,        0)
        ) AS CD_INTERMEDIARIO,
        CASE
            WHEN NULLIF(P.PLC_PUNTO_VENDITA, 0) IS NOT NULL THEN 'PV'
            WHEN NULLIF(P.PLC_CONVENZIONATO, 0) IS NOT NULL THEN 'CV'
            WHEN NULLIF(P.PLC_SUB_AGENTE,    0) IS NOT NULL THEN 'SA'
            WHEN NULLIF(P.PLC_AGENTE,        0) IS NOT NULL THEN 'AG'
            ELSE NULL
        END AS TP_INTERMEDIARIO,
        P.PLC_RETE_VENDITA                              AS CD_RETE_VENDITA,
        P.PLC_AGENTE                                    AS CD_AGENTE,
        P.PLC_SUB_AGENTE                                AS CD_SUB_AGENTE,
        P.PLC_CONVENZIONATO                             AS CD_CONVENZIONATO,
        P.PLC_PUNTO_VENDITA                             AS CD_PUNTO_VENDITA,    
        BPI.DS_INSEGNA                                  AS DS_INSEGNA,
        P.PLC_VENDITORE                                 AS CD_VENDITORE,
        {{ custom_to_decimal('P.PLC_FINANZIATO') }}            AS EU_FINANZIATO,
        {{ custom_to_decimal('P.PLC_IMPORTO_RATA') }}          AS EU_RATA,
        {{ custom_to_decimal('P.PLC_NETTO_EROGATO') }}         AS EU_EROGATO,
        P.PLC_PAGAMENTO                                 AS TP_PAGAMENTO,
        P.PLC_BANCA_CLI_ABI                             AS CD_ABI,
        P.PLC_BANCA_CLI_CAB                             AS CD_CAB,
        P.PLC_CONTO_CORRENTE                            AS CD_CC,
        {{ ole_to_date('P.PLC_DAT_STATO_01') }}             AS DT_CARICAMENTO,
        {{ ole_to_date('P.PLC_DAT_STATO_02') }}             AS DT_ESAMINATA,
        CASE WHEN P.PLC_DATA_DECORRENZA IS NOT NULL THEN {{ ole_to_date('P.PLC_DATA_DECORRENZA') }}
            WHEN P.PLC_ATTRIBUTO IN ('RE', 'RT') THEN {{ ole_to_date('P.PLC_DAT_STATO_03') }}
        END                                             AS DT_ESITO,
        CASE WHEN P.PLC_ATTRIBUTO NOT IN ('RE', 'RT') THEN {{ ole_to_date('P.PLC_DAT_STATO_03') }}
        END                                             AS DT_APPROVAZIONE,
        CASE WHEN P.PLC_ATTRIBUTO = 'RE' THEN {{ ole_to_date('P.PLC_DAT_STATO_03') }}
        END                                             AS DT_RESPINTA,
        CASE WHEN P.PLC_ATTRIBUTO = 'RT' THEN {{ ole_to_date('P.PLC_DAT_STATO_03') }}
        END                                             AS DT_RITIRATA,
        {{ ole_to_date('P.PLC_DAT_STATO_04') }}             AS DT_LIQUIDAZIONE,
        {{ ole_to_date('P.PLC_DATA_DECORRENZA') }}          AS DT_DECORRENZA,
        {{ ole_to_date('P.PLC_DAT_STATO_05') }}             AS DT_STORNATA,
        {{ ole_to_date('P.PLC_DAT_STATO_06') }}             AS DT_CHIUSURA_REGOLARE,
        {{ ole_to_date('P.PLC_DAT_STATO_07') }}             AS DT_ESTINZIONE_ANTICIPATA,
        {{ ole_to_date('P.PLC_DAT_STATO_08') }}             AS DT_PASSAGGIO_PERDITA,
        {{ ole_to_date('P.PLC_DATA_CESSIONE') }}            AS DT_CESSIONE,
        COALESCE(
            {{ ole_to_date('P.PLC_DAT_STATO_06') }},
            {{ ole_to_date('P.PLC_DAT_STATO_07') }},
            {{ ole_to_date('P.PLC_DAT_STATO_08') }},
            {{ ole_to_date('P.PLC_DATA_CESSIONE') }}
        )                                               AS DT_CHIUSURA_EFFETTIVA,
        {{ ole_to_date('P.PLC_DAT_STATO_09') }}             AS DT_MESSA_IN_MORA,
        {{ ole_to_date('P.PLC_DAT_STATO_10') }}             AS DT_DBT,
        {{ ole_to_date('P.PLC_PRIMA_SCADENZA') }}           AS DT_PRIMA_SCADENZA,
        {{ ole_to_date('P.PLC_ULTIMA_SCADENZA') }}          AS DT_ULTIMA_SCADENZA,
        CASE
            WHEN P.PLC_STATO = '30' AND P.PLC_ATTRIBUTO = 'RE'
                THEN {{ ole_to_date('P.PLC_DAT_STATO_03') }}
            WHEN P.PLC_STATO = '30' AND P.PLC_ATTRIBUTO = 'RT'
                THEN {{ ole_to_date('P.PLC_DAT_STATO_03') }}
            WHEN P.PLC_STATO = '51'
                THEN {{ ole_to_date('P.PLC_DAT_STATO_05') }}
            WHEN P.PLC_STATO = '55'
                THEN {{ ole_to_date('P.PLC_DAT_STATO_07') }}
            WHEN P.PLC_DATA_CESSIONE IS NOT NULL
                THEN {{ custom_to_date('P.PLC_DATA_CESSIONE') }}
            WHEN P.PLC_STATO = '95'
                THEN {{ ole_to_date('P.PLC_DAT_STATO_08') }}
            ELSE {{ ole_to_date('P.PLC_ULTIMA_SCADENZA') }}
        END AS DT_CHIUSURA_ANZIANITA,
        PAFF.DT_PRIMA_SCADENZA_IST,
        PAFF.DT_ULTIMA_SCADENZA_IST,
        LOG.TS_COMUNICAZIONE_ESITO_DEF,
        OXC.DT_ULT_ACCODAMENTO,
        P.PLC_OPE_STATO_01                              AS CD_USER_CARICAMENTO,
        P.PLC_OPE_STATO_02                              AS CD_USER_ESITO,
        P.PLC_OPE_STATO_03                              AS CD_USER_APPROVAZIONE,
        CASE
            WHEN P.PLC_ATTRIBUTO ='RE'
            THEN PSRE.CD_USER_RESPINTA
            ELSE NULL
        END                                             AS CD_USER_RESPINTA,
        CASE
            WHEN P.PLC_ATTRIBUTO ='RT'
            THEN PST.CD_USER_RITIRATA
            ELSE NULL
        END                                             AS CD_USER_RITIRATA,
        P.PLC_OPE_STATO_04                              AS CD_USER_LIQUIDAZIONE,
        P.PLC_OPE_STATO_05                              AS CD_USER_STORNO,
        P.PLC_OPE_STATO_06                              AS CD_USER_CHIUSURA_REGOLARE,
        P.PLC_OPE_STATO_07                              AS CD_USER_ESTINZIONE_ANT,
        P.PLC_OPE_STATO_08                              AS CD_USER_PASSAGGIO_PERDITA,
        P.PLC_OPE_STATO_09                              AS CD_USER_MESSA_IN_MORA,
        P.PLC_OPE_STATO_10                              AS CD_USER_DBT,
        P.PLC_TAB_FINANZ                                AS CD_TABELLA_FINANZIARIA,
        TAFB.DS_TABELLA_FINANZIARIA,
        CAST(NULL AS NUMBER(3))                         AS NM_GIORNI,
        NULL                                            AS FL_RIELAB_24,
        NULL                                            AS FL_ESITO_DEF,
        CASE WHEN P.PLC_CONIUGE_GARANT = 'C' THEN 'S' ELSE 'N' END AS FL_FIRMA_DOPPIA,
        NULL                                            AS FL_IN_NOSTART,
        CASE WHEN P.PLC_DAT_STATO_10 IS NOT NULL THEN 'S' ELSE 'N'
        END                                             AS FL_DBT,
        NULL                                            AS FL_GIA_CLIENTE_MARKETING,
        NULL                                            AS CD_GIA_CLIENTE_MARKETING,
        NULL                                            AS FL_GIA_CLIENTE_CREDITI,
        NULL                                            AS CD_GIA_CLIENTE_CREDITI,
        CASE WHEN P.PLC_PRODOTTO = '32' THEN 'S' ELSE 'N'
        END                                             AS FL_PNF,
        CASE WHEN P.PLC_PRODOTTO IN ('02', '09', '16') THEN 'S' ELSE 'N'
        END                                             AS FL_REFIN_RECUPERO,
        OXS.TP_FIRMA,
        CAST(P.PLC_INIZIATIVA_COMM AS VARCHAR(12))       AS CD_INIZIATIVA_COMM,
        CASE WHEN CAMP_CO.TRCA_NUM_PRATICA IS NOT NULL THEN 'S' ELSE 'N'
        END                                             AS FL_OFFERTA,
        ABB.FL_ABBUONO,
        CHI.FL_PERDITA_CESSIONE,
        SEC.FL_CARTOLARIZZATA,
        PAS.FL_PRODOTTO_ASSICURATIVO,
        RE2.FL_RECUPERO,
        P.LASTMODIFIEDDATA AS LASTMODIFIEDDATA
    FROM {{ ref('plprat_m') }} AS P
    LEFT JOIN cte_pltbfstat      AS STAT ON P.PLC_STATO        = STAT.PLSTAT_CODICE
    AND P.DT_OSSERVAZIONE >= STAT.TS_INIZIO_VALIDITA AND P.DT_OSSERVAZIONE < STAT.TS_FINE_VALIDITA
    LEFT JOIN cte_pltbfbene      AS BENE ON P.PLC_BENE         = BENE.PLBENE_CODICE
    AND P.DT_OSSERVAZIONE >= BENE.TS_INIZIO_VALIDITA AND P.DT_OSSERVAZIONE < BENE.TS_FINE_VALIDITA
    LEFT JOIN cte_mfftbcaq_co    AS CAQ  ON P.PLC_CANALE_ACQ   = CAQ.MFTBCAQ_CANALE_ACQUISIZIONE
    AND P.DT_OSSERVAZIONE >= CAQ.TS_INIZIO_VALIDITA AND P.DT_OSSERVAZIONE < CAQ.TS_FINE_VALIDITA
    LEFT JOIN cte_oxisfttp_co    AS TTP  ON P.PLC_TIPO_PROCESSO = TTP.OXISTTP_TIPO_PROCESSO
    AND P.DT_OSSERVAZIONE >= TTP.TS_INIZIO_VALIDITA AND P.DT_OSSERVAZIONE < TTP.TS_FINE_VALIDITA
    LEFT JOIN cte_oxprftafb AS TAFB ON P.PLC_TAB_FINANZ   = TAFB.OXTB_CODICE
    AND P.DT_OSSERVAZIONE >= TAFB.TS_INIZIO_VALIDITA AND P.DT_OSSERVAZIONE < TAFB.TS_FINE_VALIDITA
    LEFT JOIN cte_ccanaipv_co   AS BPI  ON P.PLC_PUNTO_VENDITA  = BPI.IPV_CODICE
    LEFT JOIN cte_cnslflog_co    AS LOG  ON P.PLC_NUM_PRATICA  = LOG.CNSLLOG_PRATICA
    LEFT JOIN cte_oxctfpafd_co   AS OXC  ON P.PLC_NUM_PRATICA  = OXC.OXCTPAFD_NUM_PRATICA
    LEFT JOIN cte_oxctfpaff_co   AS PAFF ON P.PLC_NUM_PRATICA  = PAFF.OXCTPAFF_NUM_PRATICA
    LEFT JOIN cte_plpratst_rt    AS PST  ON P.PLC_NUM_PRATICA  = PST.PLPRA_NUM_PRATICA
    LEFT JOIN cte_plpratst_res   AS PSRE ON P.PLC_NUM_PRATICA  = PSRE.PLPRA_NUM_PRATICA
    LEFT JOIN cte_oxscfpra_co    AS OXS  ON P.PLC_NUM_PRATICA  = OXS.OXSCPRA_PRATICA
    AND P.DT_OSSERVAZIONE >= OXS.TS_INIZIO_VALIDITA AND P.DT_OSSERVAZIONE < OXS.TS_FINE_VALIDITA
    LEFT JOIN cte_ccpsvt_abb_co  AS ABB  ON P.PLC_NUM_PRATICA  = ABB.PSVT_PRATICA
    LEFT JOIN cte_plchices       AS CHI  ON P.PLC_NUM_PRATICA  = CHI.CHC_PRATICA
    LEFT JOIN cte_plsecpra       AS SEC  ON P.PLC_NUM_PRATICA  = SEC.SCPRA_NUM_PRATICA
    AND P.DT_OSSERVAZIONE = SEC.DT_OSSERVAZIONE
    LEFT JOIN cte_plpratserv_as  AS PAS  ON P.PLC_NUM_PRATICA  = PAS.PLSE_NUM_PRATICA
    AND P.DT_OSSERVAZIONE = PAS.DT_OSSERVAZIONE
    LEFT JOIN cte_re2praba_co    AS RE2  ON P.PLC_NUM_PRATICA  = RE2.DPRBA_PRATICA
    AND P.DT_OSSERVAZIONE = RE2.DT_OSSERVAZIONE
    LEFT JOIN {{ref ('ccanainin')}} AS N_CO  ON N_CO.INT_CODICE     = P.PLC_SUB_AGENTE
    LEFT JOIN {{ ref('ccanainin') }} AS N_PLC
    ON N_PLC.INT_CODICE = COALESCE(
        NULLIF(P.PLC_PUNTO_VENDITA, 0), NULLIF(P.PLC_CONVENZIONATO, 0),
        NULLIF(P.PLC_SUB_AGENTE, 0), NULLIF(P.PLC_AGENTE, 0))
    LEFT JOIN {{ref ('ccanatfi_m')}} AS F_CO  ON F_CO.ANATFI_FILIALE = N_PLC.INT_FILIALE
    AND P.DT_OSSERVAZIONE = F_CO.DT_OSSERVAZIONE
    -- ----- MACRO PRODOTTO / MERCATO (CONSUMO) -----
    LEFT JOIN {{ source('l1_e_bsn', 'lkp_ger_macro_prodotto_co') }} AS MPRO
        ON P.PLC_PRODOTTO = MPRO.CD_PRODOTTO_OCS
        AND P.DT_OSSERVAZIONE >= MPRO.TS_INIZIO_VALIDITA AND P.DT_OSSERVAZIONE < MPRO.TS_FINE_VALIDITA
    LEFT JOIN {{ ref('ccanaipv') }} AS IPV_M
        ON IPV_M.IPV_CODICE = COALESCE(
            NULLIF(P.PLC_PUNTO_VENDITA, 0), NULLIF(P.PLC_CONVENZIONATO, 0),
            NULLIF(P.PLC_SUB_AGENTE, 0), NULLIF(P.PLC_AGENTE, 0))
    LEFT JOIN {{ ref('ccanaicv') }} AS ICV_M
        ON ICV_M.ICV_CODICE = COALESCE(
            NULLIF(P.PLC_PUNTO_VENDITA, 0), NULLIF(P.PLC_CONVENZIONATO, 0),
            NULLIF(P.PLC_SUB_AGENTE, 0), NULLIF(P.PLC_AGENTE, 0))
    LEFT JOIN {{ source('l1_e_bsn', 'lkp_mercato_pa_pf') }} AS MKT_PAPF
        ON P.PLC_TIPO_PRODOTTO IN ('PA', 'PF')
        AND MKT_PAPF.CD_SETTORE_MERCEOLOGICO = CASE
                WHEN NULLIF(P.PLC_PUNTO_VENDITA, 0) IS NOT NULL THEN IPV_M.IPV_SETTORE_MERC
                WHEN NULLIF(P.PLC_CONVENZIONATO, 0) IS NOT NULL THEN ICV_M.ICV_SETTORE_MERC
            END
        AND P.DT_OSSERVAZIONE >= MKT_PAPF.TS_INIZIO_VALIDITA AND P.DT_OSSERVAZIONE < MKT_PAPF.TS_FINE_VALIDITA
    LEFT JOIN {{ source('l1_e_bsn', 'lkp_mercato_pp') }} AS MKT_PP
        ON P.PLC_TIPO_PRODOTTO = 'PP'
        AND MKT_PP.CD_MACRO_PRODOTTO_2 = MPRO.CD_MACRO_PRODOTTO_2
        AND P.DT_OSSERVAZIONE >= MKT_PP.TS_INIZIO_VALIDITA AND P.DT_OSSERVAZIONE < MKT_PP.TS_FINE_VALIDITA
    LEFT JOIN cte_cctrcamp_co AS CAMP_CO
        ON P.PLC_INIZIATIVA_COMM = CAST(CAMP_CO.TRCA_NUM_PRATICA AS VARCHAR(12))

    {% if is_incremental() %}
    WHERE P.DT_OSSERVAZIONE = {{ last_day_past_month() }}
    {% endif %}
),

-- ==============================================================
-- CARTA CTEs
-- ==============================================================
cte_crtabsta_ca AS (
    SELECT
        CRTSTA_STATO,
        CRTSTA_DESCRIZIONE AS DS_STATO,
        TS_INIZIO_VALIDITA, TS_FINE_VALIDITA
    FROM {{ ref('crtabsta') }}
    WHERE CRTSTA_PROCEDURA = 'CA'
    AND FL_DELETED = 'N'
),

cte_mfftbcaq_ca AS (
    SELECT
        MFTBCAQ_CANALE_ACQUISIZIONE,
        MFTBCAQ_DESCRIZIONE          AS DS_CANALE_ACQUISIZIONE,
        MFTBCAQ_WEB                  AS FL_WEB_CANALE_ACQ,
        TS_INIZIO_VALIDITA, TS_FINE_VALIDITA
    FROM {{ ref('mfftbcaq') }}
    WHERE FL_DELETED = 'N'
),

cte_oxisfttp_ca AS (
    SELECT
        OXISTTP_TIPO_PROCESSO,
        OXISTTP_DESCRIZIONE AS DS_TIPO_PROCESSO,
        TS_INIZIO_VALIDITA, TS_FINE_VALIDITA
    FROM {{ ref('oxisfttp') }}
    WHERE FL_DELETED = 'N'
),

cte_bapratint_ca AS (
    SELECT
        B.BAINT_PRATICA,
        B.BAINT_RETE_VENDITA    AS CD_RETE_VENDITA,
        B.BAINT_AGENTE          AS CD_AGENTE,
        B.BAINT_SUB_AGENTE      AS CD_SUB_AGENTE,
        B.BAINT_CONVENZIONATO   AS CD_CONVENZIONATO,
        B.BAINT_PUNTO_VENDITA   AS CD_PUNTO_VENDITA,
        C.IPV_INSEGNA           AS DS_INSEGNA,
        B.BAINT_VENDITORE       AS CD_VENDITORE,
        B.DT_OSSERVAZIONE
    FROM {{ ref('bapratint_m') }} AS B
    LEFT JOIN (
        SELECT
        IPV_CODICE,
        IPV_INSEGNA
        FROM {{ ref('ccanaipv') }}
    ) AS C
        ON  B.BAINT_PUNTO_VENDITA = C.IPV_CODICE
    WHERE B.BAINT_PROCEDURA  = 'CA'
      AND B.BAINT_PROGRESSIVO = 0
),

cte_crcarblo_rt AS (
    SELECT
        B.CAB_PRATICA,
        MAX({{ custom_to_date('B.CAB_DATA_IMMISSIONE') }})  AS DT_RITIRATA,
        B.CAB_OPE_IMMISSIONE        AS CD_USER_RITIRATA
    FROM {{ ref('crcarblo') }} AS B
    WHERE B.CAB_COD_BLOCCO_OCS = 'RT'
    AND B.FL_DELETED = 'N'
    GROUP BY B.CAB_PRATICA, B.CAB_OPE_IMMISSIONE
),

cte_crcarblo_pp_cc AS (
    SELECT
        blo.CAB_PRATICA AS CAB_PRATICA,
        CASE
            WHEN blo.CAB_PRATICA IS NOT NULL THEN NULL
            ELSE {{ custom_to_date('car.CRCAR_DATA_CHIUSURA') }}
        END AS DT_CHIUSURA_REGOLARE,
        CAR.DT_OSSERVAZIONE
    FROM {{ ref('crcar_m') }} car
    LEFT JOIN (
        SELECT DISTINCT CAB_PRATICA
        FROM {{ ref('crcarblo') }}
        WHERE CAB_COD_BLOCCO_OCS IN ('PP', 'CC') AND FL_DELETED = 'N'
    ) blo ON car.CRCAR_KEY_N = blo.CAB_PRATICA
),

cte_crcarblo_pp AS (
    SELECT
        B.CAB_PRATICA,
        MAX({{ custom_to_date('B.CAB_DATA_IMMISSIONE') }}) AS DT_PASSAGGIO_PERDITA,
        B.CAB_OPE_IMMISSIONE       AS CD_USER_PASSAGGIO_PERDITA
    FROM {{ ref('crcarblo') }} AS B
    WHERE B.CAB_COD_BLOCCO_OCS = 'PP'
    AND B.FL_DELETED = 'N'
    GROUP BY B.CAB_PRATICA, B.CAB_OPE_IMMISSIONE
),

cte_crcarblo_cc AS (
    SELECT
        CAB_PRATICA,
        MAX({{ custom_to_date('CAB_DATA_IMMISSIONE') }}) AS DT_CESSIONE
    FROM {{ ref('crcarblo') }}
    WHERE CAB_COD_BLOCCO_OCS = 'CC'
    AND FL_DELETED = 'N'
    GROUP BY CAB_PRATICA
),

cte_crcarblo_db AS (
    SELECT
        CAB_PRATICA,
        MAX({{ custom_to_date('CAB_DATA_IMMISSIONE') }}) AS DT_DBT
    FROM {{ ref('crcarblo') }}
    WHERE CAB_COD_BLOCCO_OCS = 'DB'
    AND FL_DELETED = 'N'
    GROUP BY CAB_PRATICA
),

cte_crcarblo_dt AS (
    SELECT
        CAB_PRATICA,
        CAB_OPE_IMMISSIONE AS CD_USER_DBT
    FROM {{ ref('crcarblo') }}
    WHERE CAB_COD_BLOCCO_OCS = 'DT'
    AND FL_DELETED = 'N'
),

cte_cnslflog_ca AS (
    SELECT
        CNSLLOG_PRATICA,
        MAX(TO_TIMESTAMP(TO_CHAR(CNSLLOG_DATA) || LPAD(LEFT(TO_CHAR(CNSLLOG_ORA), 6), 6, '0'), 'YYYYMMDDHH24MISS')
        ) AS TS_COMUNICAZIONE_ESITO_DEF
    FROM {{ref("cnslflog")}}
    WHERE CNSLLOG_PROCEDURA = 'CA'
    AND FL_DELETED = 'N'
    GROUP BY CNSLLOG_PRATICA
),
cte_oxctfpafd_ca AS (
    SELECT
        OXCTPAFD_NUM_PRATICA,
        MAX({{ custom_to_date('OXCTPAFD_DT_ACCODAMENTO') }}) AS DT_ULT_ACCODAMENTO
    FROM {{ref("oxctfpafd")}}
    WHERE OXCTPAFD_PROCEDURA = 'CA'
    AND FL_DELETED = 'N'
    GROUP BY OXCTPAFD_NUM_PRATICA
),

cte_oxscfpra_ca AS (
    SELECT
        OXSCPRA_PRATICA,
        OXSCPRA_MODALITA_FIRMA AS TP_FIRMA,
        TS_INIZIO_VALIDITA, TS_FINE_VALIDITA
    FROM {{ref("oxscfpra")}}
    WHERE OXSCPRA_PROCEDURA = 'CA'
    AND OXSCPRA_PROG_PSV  = 1
    AND FL_DELETED = 'N'
),

cte_ccpsvt_abb_ca AS (
    SELECT DISTINCT
        PSVT_PRATICA,
        'S' AS FL_ABBUONO
    FROM {{ref("ccpsvt")}}
    WHERE PSVT_AZIONE    = 'ABB'
    AND PSVT_PROCEDURA = 'CA'
    AND FL_DELETED = 'N'
),

cte_cacsfces AS (
    SELECT
        CACSCES_CARTA,
        CASE WHEN CACSCES_TOT_PERDITA IS NOT NULL THEN 'S' ELSE 'N'
        END AS FL_PERDITA_CESSIONE
    FROM {{ ref('cacsfces') }}
    WHERE CACSCES_PROGRESSIVO = 1
    AND FL_DELETED = 'N'
),

cte_casrfser AS (
    SELECT DISTINCT
        CASRSER_CARTA,
        'S' AS FL_PRODOTTO_ASSICURATIVO,
        DT_OSSERVAZIONE
    FROM {{ ref('casrfser_m') }}
),

cte_re2praba_ca AS (
    SELECT DISTINCT
        DPRBA_PRATICA,
        'S' AS FL_RECUPERO,
        DT_OSSERVAZIONE
    FROM {{ref("re2praba_m")}}
    WHERE DPRBA_PROVENIENZA = 'CA'
),

cte_cctrcamp_ca AS (
    SELECT DISTINCT
        TRCA_NUM_PRATICA
    FROM {{ ref('cctrcamp') }}
    WHERE TRCA_PROVENIENZA = 'CA'
),

TAB_FIN_CARTA AS (
    SELECT
        CRCAR.CRCAR_KEY_N                           AS CD_PRATICA,
        'CA'                                        AS TP_PROCEDURA,
        CRCAR.DT_OSSERVAZIONE                       AS DT_OSSERVAZIONE,
        NULL                                        AS TP_ORIG_PRAT,
        CRCAR.CRCAR_STATO                           AS CD_STATO,
        STA.DS_STATO,
        NULL                                        AS CD_ATTRIBUTO,
        CRCAR.CRCAR_CLIENTE                         AS CD_CLIENTE,
        CAST(CRCAR.CRCAR_COOBBLIGATO1 AS VARCHAR(9)) AS CD_COOBLIGATO,
        NULL                                        AS CD_TIPO_PRODOTTO,
        CRCAR.CRCAR_EME                             AS CD_EMETTITORE,
        CRCAR.CRCAR_PRODOTTO                        AS CD_PRODOTTO,
        MPRO.CD_MACRO_PRODOTTO_1                         AS CD_MACRO_PRODOTTO_1,
        MPRO.CD_MACRO_PRODOTTO_2                         AS CD_MACRO_PRODOTTO_2,
        MPRO.CD_MACRO_PRODOTTO_3                         AS CD_MACRO_PRODOTTO_3,
        MPRO.CD_MACRO_PRODOTTO_4                         AS CD_MACRO_PRODOTTO_4,
        COALESCE(MKT_B2B.CD_MERCATO_1, MKT_B2C.CD_MERCATO_1) AS CD_MERCATO_1,
        COALESCE(MKT_B2B.CD_MERCATO_2, MKT_B2C.CD_MERCATO_2) AS CD_MERCATO_2,
        COALESCE(MKT_B2B.CD_MERCATO_3, MKT_B2C.CD_MERCATO_3) AS CD_MERCATO_3,
        COALESCE(MKT_B2B.CD_MERCATO_4, MKT_B2C.CD_MERCATO_4) AS CD_MERCATO_4,
        CAST(CAST(CASE
            WHEN F_CA.ANATFI_AREA IN ('SED', 'FIL', 'B2B') THEN N_INT.INT_FILIALE
            WHEN F_CA.ANATFI_AREA = 'AGE'                   THEN N_CA.INT_FILIALE
            WHEN F_CA.ANATFI_AREA = 'IFQ' THEN
                CASE
                    WHEN F_CA.ANATFI_DISTRETTO = 'I10' THEN N_INT.INT_FILIALE
                    WHEN F_CA.ANATFI_DISTRETTO = 'I01' THEN BPI.CD_RETE_VENDITA
                    WHEN F_CA.ANATFI_DISTRETTO = 'I99' THEN N_CA.INT_FILIALE
                END
        END AS NUMBER(10)) AS VARCHAR(10))                             AS CD_NODO_FOGLIA,
        NULL                                        AS DS_PRODOTTO_POG,
        NULL                                        AS CD_DESTINAZIONE_BENE,
        NULL                                        AS DS_DESTINAZIONE_BENE,
        CAST(CRCAR.CRCAR_FILIALE AS VARCHAR(3))     AS CD_FILIALE_PRAT,
        CAST(N_INT.INT_FILIALE AS VARCHAR(3))       AS CD_FILIALE_INT,
        CRCAR.CRCAR_RESPONSABILE                    AS CD_RESPONSABILE,
        CRCAR.CRCAR_CANALE_ACQ                      AS CD_CANALE_ACQUISIZIONE,
        CAQ.DS_CANALE_ACQUISIZIONE,
        CAQ.FL_WEB_CANALE_ACQ,
        CRCAR.CRCAR_TIPO_PROCESSO                   AS CD_TIPO_PROCESSO,
        TTP.DS_TIPO_PROCESSO,
        COALESCE(
            NULLIF(BPI.CD_PUNTO_VENDITA, 0),
            NULLIF(BPI.CD_CONVENZIONATO, 0),
            NULLIF(BPI.CD_SUB_AGENTE,    0),
            NULLIF(BPI.CD_AGENTE,        0)
        ) AS CD_INTERMEDIARIO,
        CASE
            WHEN NULLIF(BPI.CD_PUNTO_VENDITA, 0) IS NOT NULL THEN 'PV'
            WHEN NULLIF(BPI.CD_CONVENZIONATO, 0) IS NOT NULL THEN 'CV'
            WHEN NULLIF(BPI.CD_SUB_AGENTE,    0) IS NOT NULL THEN 'SA'
            WHEN NULLIF(BPI.CD_AGENTE,        0) IS NOT NULL THEN 'AG'
            ELSE NULL
        END AS TP_INTERMEDIARIO,
        BPI.CD_RETE_VENDITA,
        BPI.CD_AGENTE,
        BPI.CD_SUB_AGENTE,
        BPI.CD_CONVENZIONATO,
        BPI.CD_PUNTO_VENDITA,
        BPI.DS_INSEGNA,
        BPI.CD_VENDITORE,
        NULL                                              AS EU_FINANZIATO,
        {{ custom_to_decimal('CRCAR.CRCAR_CREDIT_LIMIT') }}      AS EU_FIDO,
        NULL                                              AS EU_RATA,
        NULL                                              AS EU_EROGATO,
        CRCAR.CRCAR_PAG_FORMA                             AS TP_PAGAMENTO,
        CAST(CRCAR.CRCAR_BANK_CODE AS VARCHAR(27))        AS CD_IBAN,
        CRCAR.CRCAR_PAG_ABI                               AS CD_ABI,
        CRCAR.CRCAR_PAG_CAB                               AS CD_CAB,
        CRCAR.CRCAR_PAG_CC                                AS CD_CC,
        {{ ole_to_date('CRCAR.CRCAR_ST_DATA_1') }}              AS DT_CARICAMENTO,
        {{ ole_to_date('CRCAR.CRCAR_ST_DATA_2') }}              AS DT_ESAMINATA,
        {{ ole_to_date('CRCAR.CRCAR_ST_DATA_3') }}              AS DT_APPROVAZIONE,
        {{ ole_to_date('CRCAR.CRCAR_ST_DATA_4') }}              AS DT_RESPINTA,
        NULL                                                AS DT_LIQUIDAZIONE,
        {{ ole_to_date('CRCAR.CRCAR_ST_DATA_3') }}              AS DT_DECORRENZA,
        NULL                                                AS DT_STORNATA,
        NULL                                                AS DT_ESTINZIONE_ANTICIPATA,
        {{ ole_to_date('CRCAR.CRCAR_DATA_CHIUSURA') }}          AS DT_CHIUSURA_EFFETTIVA,
        {{ ole_to_date('CRCAR.CRCAR_DATA_MESSA_IN_MORA') }}     AS DT_MESSA_IN_MORA,
        CASE
            WHEN CRCAR.CRCAR_STATO = '35'
                THEN {{ ole_to_date('CRCAR.CRCAR_ST_DATA_4') }}
            WHEN RT.DT_RITIRATA IS NOT NULL
                THEN RT.DT_RITIRATA
            WHEN CC.DT_CESSIONE IS NOT NULL
                THEN CC.DT_CESSIONE
            WHEN PP.DT_PASSAGGIO_PERDITA IS NOT NULL
                THEN PP.DT_PASSAGGIO_PERDITA
            ELSE {{ ole_to_date('CRCAR.CRCAR_DATA_SCADENZA') }}
        END AS DT_CHIUSURA_ANZIANITA,
        {{ ole_to_date('CRCAR.CRCAR_DATA_PRIMA_SCADENZA') }}    AS DT_PRIMA_SCADENZA,
        NULL                                                AS DT_PRIMA_SCADENZA_IST,
        NULL                                                AS DT_ULTIMA_SCADENZA,
        NULL                                                AS DT_ULTIMA_SCADENZA_IST,
        COALESCE(
            {{ ole_to_date('CRCAR.CRCAR_ST_DATA_3') }},
            {{ ole_to_date('CRCAR.CRCAR_ST_DATA_4') }},
            RT.DT_RITIRATA
        )                                                   AS DT_ESITO,
        RT.DT_RITIRATA,
        PPCC.DT_CHIUSURA_REGOLARE,
        PP.DT_PASSAGGIO_PERDITA,
        CC.DT_CESSIONE,
        DB.DT_DBT,
        LOG.TS_COMUNICAZIONE_ESITO_DEF,
        OXC.DT_ULT_ACCODAMENTO,
        CRCAR.CRCAR_ST_OPERATORE_1                        AS CD_USER_CARICAMENTO,
        CRCAR.CRCAR_ST_OPERATORE_2                        AS CD_USER_ESITO,
        CRCAR.CRCAR_ST_OPERATORE_3                        AS CD_USER_APPROVAZIONE,
        CRCAR.CRCAR_ST_OPERATORE_4                        AS CD_USER_RESPINTA,
        NULL                                        AS CD_USER_LIQUIDAZIONE,
        NULL                                        AS CD_USER_STORNO,
        NULL                                        AS CD_USER_CHIUSURA_REGOLARE,
        NULL                                        AS CD_USER_ESTINZIONE_ANT,
        NULL                                        AS CD_USER_MESSA_IN_MORA,
        RT.CD_USER_RITIRATA,
        PP.CD_USER_PASSAGGIO_PERDITA,
        DT_USR.CD_USER_DBT,
        NULL                                        AS CD_TABELLA_FINANZIARIA,
        NULL                                        AS DS_TABELLA_FINANZIARIA,
        CAST(NULL AS NUMBER(3))                     AS NM_GIORNI,
        NULL                                        AS FL_RIELAB_24,
        NULL                                        AS FL_ESITO_DEF,
        CASE WHEN CRCAR.CRCAR_TIPO_GARANTE = 'O' THEN 'S' ELSE 'N'
        END                                         AS FL_FIRMA_DOPPIA,
        NULL                                        AS FL_IN_NOSTART,
        CASE WHEN CRCAR.CRCAR_DATA_MESSA_IN_MORA IS NOT NULL THEN 'S' ELSE 'N' END AS FL_DBT,
        NULL                                        AS FL_GIA_CLIENTE_MARKETING,
        NULL                                        AS CD_GIA_CLIENTE_MARKETING,
        NULL                                        AS FL_GIA_CLIENTE_CREDITI,
        NULL                                        AS CD_GIA_CLIENTE_CREDITI,
        NULL                                        AS FL_CARTOLARIZZATA,
        NULL                                        AS FL_PNF,
        NULL                                        AS FL_REFIN_RECUPERO,
        OXS.TP_FIRMA,
        CAST(CRCAR.CRCAR_COD_INIZIATIVA  AS VARCHAR(12)) AS CD_INIZIATIVA_COMM,
        CASE WHEN CAMP_CA.TRCA_NUM_PRATICA IS NOT NULL THEN 'S' ELSE 'N'
        END                                             AS FL_OFFERTA,
        ABB.FL_ABBUONO,
        CES.FL_PERDITA_CESSIONE,
        SER.FL_PRODOTTO_ASSICURATIVO,
        RE2.FL_RECUPERO,
        CRCAR.LASTMODIFIEDDATA AS LASTMODIFIEDDATA

    FROM {{ ref('crcar_m') }} AS CRCAR
    LEFT JOIN cte_crtabsta_ca   AS STA  ON CRCAR.CRCAR_STATO        = STA.CRTSTA_STATO
    AND CRCAR.DT_OSSERVAZIONE >= STA.TS_INIZIO_VALIDITA AND CRCAR.DT_OSSERVAZIONE < STA.TS_FINE_VALIDITA
    LEFT JOIN cte_mfftbcaq_ca   AS CAQ  ON CRCAR.CRCAR_CANALE_ACQ   = CAQ.MFTBCAQ_CANALE_ACQUISIZIONE
    AND CRCAR.DT_OSSERVAZIONE >= CAQ.TS_INIZIO_VALIDITA AND CRCAR.DT_OSSERVAZIONE < CAQ.TS_FINE_VALIDITA
    LEFT JOIN cte_oxisfttp_ca   AS TTP  ON CRCAR.CRCAR_TIPO_PROCESSO = TTP.OXISTTP_TIPO_PROCESSO
    AND CRCAR.DT_OSSERVAZIONE >= TTP.TS_INIZIO_VALIDITA AND CRCAR.DT_OSSERVAZIONE < TTP.TS_FINE_VALIDITA
    LEFT JOIN cte_bapratint_ca  AS BPI  ON CRCAR.CRCAR_KEY_N        = BPI.BAINT_PRATICA
    AND CRCAR.DT_OSSERVAZIONE = BPI.DT_OSSERVAZIONE
    LEFT JOIN cte_crcarblo_rt   AS RT   ON CRCAR.CRCAR_KEY_N        = RT.CAB_PRATICA
    LEFT JOIN cte_crcarblo_pp_cc AS PPCC ON CRCAR.CRCAR_KEY_N       = PPCC.CAB_PRATICA
    AND CRCAR.DT_OSSERVAZIONE = PPCC.DT_OSSERVAZIONE
    LEFT JOIN cte_crcarblo_pp   AS PP   ON CRCAR.CRCAR_KEY_N        = PP.CAB_PRATICA
    LEFT JOIN cte_crcarblo_cc   AS CC   ON CRCAR.CRCAR_KEY_N        = CC.CAB_PRATICA
    LEFT JOIN cte_crcarblo_db   AS DB   ON CRCAR.CRCAR_KEY_N        = DB.CAB_PRATICA
    LEFT JOIN cte_crcarblo_dt   AS DT_USR ON CRCAR.CRCAR_KEY_N      = DT_USR.CAB_PRATICA
    LEFT JOIN cte_cnslflog_ca   AS LOG  ON CRCAR.CRCAR_KEY_N        = LOG.CNSLLOG_PRATICA
    LEFT JOIN cte_oxctfpafd_ca  AS OXC  ON CRCAR.CRCAR_KEY_N        = OXC.OXCTPAFD_NUM_PRATICA
    LEFT JOIN cte_oxscfpra_ca   AS OXS  ON CRCAR.CRCAR_KEY_N        = OXS.OXSCPRA_PRATICA
    AND CRCAR.DT_OSSERVAZIONE >= OXS.TS_INIZIO_VALIDITA AND CRCAR.DT_OSSERVAZIONE < OXS.TS_FINE_VALIDITA
    LEFT JOIN cte_ccpsvt_abb_ca AS ABB  ON CRCAR.CRCAR_KEY_N        = ABB.PSVT_PRATICA
    LEFT JOIN cte_cacsfces      AS CES  ON CRCAR.CRCAR_KEY_N        = CES.CACSCES_CARTA
    LEFT JOIN cte_casrfser      AS SER  ON CRCAR.CRCAR_KEY_N        = SER.CASRSER_CARTA
    AND CRCAR.DT_OSSERVAZIONE = SER.DT_OSSERVAZIONE
    LEFT JOIN cte_re2praba_ca   AS RE2  ON CRCAR.CRCAR_KEY_N        = RE2.DPRBA_PRATICA
    AND CRCAR.DT_OSSERVAZIONE = RE2.DT_OSSERVAZIONE
    LEFT JOIN {{ref ('ccanainin')}} AS N_CA ON N_CA.INT_CODICE      = BPI.CD_SUB_AGENTE
    LEFT JOIN {{ ref('ccanainin') }} AS N_INT
    ON N_INT.INT_CODICE = COALESCE(
        NULLIF(BPI.CD_PUNTO_VENDITA, 0), NULLIF(BPI.CD_CONVENZIONATO, 0),
        NULLIF(BPI.CD_SUB_AGENTE, 0), NULLIF(BPI.CD_AGENTE, 0))
    LEFT JOIN {{ref ('ccanatfi_m')}}  AS F_CA ON F_CA.ANATFI_FILIALE = N_INT.INT_FILIALE
    AND CRCAR.DT_OSSERVAZIONE = F_CA.DT_OSSERVAZIONE
    -- ----- MACRO PRODOTTO / MERCATO (CARTA) -----
    LEFT JOIN {{ source('l1_e_bsn', 'lkp_ger_macro_prodotto_ca') }} AS MPRO
        ON CRCAR.CRCAR_EME = MPRO.CD_EMETTITORE
        AND CRCAR.DT_OSSERVAZIONE >= MPRO.TS_INIZIO_VALIDITA AND CRCAR.DT_OSSERVAZIONE < MPRO.TS_FINE_VALIDITA
    LEFT JOIN {{ ref('ccanaipv') }} AS IPV_M
        ON IPV_M.IPV_CODICE = COALESCE(
            NULLIF(BPI.CD_PUNTO_VENDITA, 0), NULLIF(BPI.CD_CONVENZIONATO, 0),
            NULLIF(BPI.CD_SUB_AGENTE, 0), NULLIF(BPI.CD_AGENTE, 0))
    LEFT JOIN {{ ref('ccanaicv') }} AS ICV_M
        ON ICV_M.ICV_CODICE = COALESCE(
            NULLIF(BPI.CD_PUNTO_VENDITA, 0), NULLIF(BPI.CD_CONVENZIONATO, 0),
            NULLIF(BPI.CD_SUB_AGENTE, 0), NULLIF(BPI.CD_AGENTE, 0))
    LEFT JOIN {{ source('l1_e_bsn', 'lkp_mercato_ca_b2b') }} AS MKT_B2B
        ON MPRO.CD_MACRO_PRODOTTO_4 = 'REV_B2B'
        AND MKT_B2B.CD_SETTORE_MERCEOLOGICO = CASE
                WHEN NULLIF(BPI.CD_PUNTO_VENDITA, 0) IS NOT NULL THEN IPV_M.IPV_SETTORE_MERC
                WHEN NULLIF(BPI.CD_CONVENZIONATO, 0) IS NOT NULL THEN ICV_M.ICV_SETTORE_MERC
            END
        AND CRCAR.DT_OSSERVAZIONE >= MKT_B2B.TS_INIZIO_VALIDITA AND CRCAR.DT_OSSERVAZIONE < MKT_B2B.TS_FINE_VALIDITA
    LEFT JOIN {{ source('l1_e_bsn', 'lkp_mercato_ca_b2c') }} AS MKT_B2C
        ON MPRO.CD_MACRO_PRODOTTO_4 = 'REV_B2C'
        AND MKT_B2C.CD_MACRO_PRODOTTO_1 = MPRO.CD_MACRO_PRODOTTO_1
        AND CRCAR.DT_OSSERVAZIONE >= MKT_B2C.TS_INIZIO_VALIDITA AND CRCAR.DT_OSSERVAZIONE < MKT_B2C.TS_FINE_VALIDITA
    LEFT JOIN cte_cctrcamp_ca AS CAMP_CA
        ON CRCAR.CRCAR_COD_INIZIATIVA = CAST(CAMP_CA.TRCA_NUM_PRATICA AS VARCHAR(12))

    {% if is_incremental() %}
    WHERE CRCAR.DT_OSSERVAZIONE = {{ last_day_past_month() }}
    {% endif %}
),

-- ==============================================================
-- CQS CTEs
-- ==============================================================
qsprast_35 AS (
    SELECT 
        QPRST_NUM_PRATICA, 
        MAX({{ custom_to_date('QPRST_DATA') }}) AS DT_RESPINTA, 
        MAX(QPRST_UTENTE) AS CD_USER_RESPINTA
    FROM {{ ref('qsprast') }}
    WHERE QPRST_STATO = '35'
    AND FL_DELETED = 'N'
    GROUP BY QPRST_NUM_PRATICA
),

qsprast_rt AS (
    SELECT 
        QPRST_NUM_PRATICA, 
        MAX({{ custom_to_date('QPRST_DATA') }}) AS DT_RITIRATA, 
        MAX(QPRST_UTENTE) AS CD_USER_RITIRATA
    FROM {{ ref('qsprast') }}
    WHERE QPRST_ATTRIBUTO = 'RT'
    AND FL_DELETED = 'N'
    GROUP BY QPRST_NUM_PRATICA
),

qsprast_40 AS (
    SELECT 
        QPRST_NUM_PRATICA, 
        MAX({{ custom_to_date('QPRST_DATA') }}) AS DT_LIQUIDAZIONE, 
        MAX(QPRST_UTENTE) AS CD_USER_LIQUIDAZIONE
    FROM {{ ref('qsprast') }}
    WHERE QPRST_STATO = '40'
    AND FL_DELETED = 'N'
    GROUP BY QPRST_NUM_PRATICA
),

qsprast_45 AS (
    SELECT 
        QPRST_NUM_PRATICA, 
        MAX({{ custom_to_date('QPRST_DATA') }}) AS DT_STORNATA, 
        MAX(QPRST_UTENTE) AS CD_USER_STORNO
    FROM {{ ref('qsprast') }}
    WHERE QPRST_STATO = '45'
    AND FL_DELETED = 'N'
    GROUP BY QPRST_NUM_PRATICA
),

qsprast_97 AS (
    SELECT 
        QPRST_NUM_PRATICA, 
        MAX({{ custom_to_date('QPRST_DATA') }}) AS DT_PASSAGGIO_PERDITA, 
        MAX(QPRST_UTENTE) AS CD_USER_PASSAGGIO_PERDITA
    FROM {{ ref('qsprast') }}
    WHERE QPRST_STATO = '97'
    AND FL_DELETED = 'N'
    GROUP BY QPRST_NUM_PRATICA
),

qsprast_96 AS (
    SELECT 
        QPRST_NUM_PRATICA, 
        MAX({{ custom_to_date('QPRST_DATA') }}) AS DT_DBT, 
        MAX(QPRST_UTENTE) AS CD_USER_DBT
    FROM {{ ref('qsprast') }}
    WHERE QPRST_STATO = '96'
    AND FL_DELETED = 'N'
    GROUP BY QPRST_NUM_PRATICA
),

qsprast_10 AS (
    SELECT QPRST_NUM_PRATICA, MAX(QPRST_UTENTE) AS CD_USER_CARICAMENTO
    FROM {{ ref('qsprast') }}
    WHERE QPRST_STATO = '10'
    AND FL_DELETED = 'N'
    GROUP BY QPRST_NUM_PRATICA
),

qsprast_15 AS (
    SELECT QPRST_NUM_PRATICA, MAX(QPRST_UTENTE) AS CD_USER_ESITO
    FROM {{ ref('qsprast') }}
    WHERE QPRST_STATO = '15'
    AND FL_DELETED = 'N'
    GROUP BY QPRST_NUM_PRATICA
),

qsprast_30 AS (
    SELECT QPRST_NUM_PRATICA, MAX(QPRST_UTENTE) AS CD_USER_APPROVAZIONE
    FROM {{ ref('qsprast') }}
    WHERE QPRST_STATO = '30'
    AND FL_DELETED = 'N'
    GROUP BY QPRST_NUM_PRATICA
),

qsprast_90 AS (
    SELECT QPRST_NUM_PRATICA, MAX(QPRST_UTENTE) AS CD_USER_CHIUSURA_REGOLARE
    FROM {{ ref('qsprast') }}
    WHERE QPRST_STATO = '90'
    AND FL_DELETED = 'N'
    GROUP BY QPRST_NUM_PRATICA
),

qsprast_55 AS (
    SELECT QPRST_NUM_PRATICA, MAX(QPRST_UTENTE) AS CD_USER_ESTINZIONE_ANT
    FROM {{ ref('qsprast') }}
    WHERE QPRST_STATO = '55'
    AND FL_DELETED = 'N'
    GROUP BY QPRST_NUM_PRATICA
),

cnslflog_cq AS (
    SELECT 
        CNSLLOG_PRATICA, 
        MAX(TRY_TO_TIMESTAMP(TO_CHAR(CNSLLOG_DATA) || LPAD(TO_CHAR(CNSLLOG_ORA), 6, '0'), 'YYYYMMDDHHMISS')) AS TS_COMUNICAZIONE_ESITO_DEF
    FROM {{ ref('cnslflog') }}
    WHERE CNSLLOG_PROCEDURA = 'CQ'
    AND FL_DELETED = 'N'
    GROUP BY CNSLLOG_PRATICA
),

TAB_FIN_CQS AS (
    SELECT
        A.QPR_NUM_PRATICA AS CD_PRATICA,
        'CQ' AS TP_PROCEDURA,
        A.DT_OSSERVAZIONE AS DT_OSSERVAZIONE,
        NULL AS TP_ORIG_PRAT,
        A.QPR_STATO AS CD_STATO,
        STA.QTSTA_DESCRIZIONE AS DS_STATO,
        A.QPR_ATTRIBUTO AS CD_ATTRIBUTO,
        A.QPR_CEDENTE AS CD_CLIENTE,
        CAST(NULL AS VARCHAR(9)) AS CD_COOBLIGATO,
        NULL AS CD_TIPO_PRODOTTO,
        NULL AS CD_EMETTITORE,
        A.QPR_PRODOTTO AS CD_PRODOTTO,
        MPRO.CD_MACRO_PRODOTTO_1                         AS CD_MACRO_PRODOTTO_1,
        MPRO.CD_MACRO_PRODOTTO_2                         AS CD_MACRO_PRODOTTO_2,
        MPRO.CD_MACRO_PRODOTTO_3                         AS CD_MACRO_PRODOTTO_3,
        MPRO.CD_MACRO_PRODOTTO_4                         AS CD_MACRO_PRODOTTO_4,
        COALESCE(MKT_AREA.CD_MERCATO_1, MKT_FIL.CD_MERCATO_1) AS CD_MERCATO_1,
        COALESCE(MKT_AREA.CD_MERCATO_2, MKT_FIL.CD_MERCATO_2) AS CD_MERCATO_2,
        COALESCE(MKT_AREA.CD_MERCATO_3, MKT_FIL.CD_MERCATO_3) AS CD_MERCATO_3,
        COALESCE(MKT_AREA.CD_MERCATO_4, MKT_FIL.CD_MERCATO_4) AS CD_MERCATO_4,
        CAST(CAST(CASE
            WHEN F_CQ.ANATFI_AREA IN ('SED', 'FIL', 'B2B') THEN N_INT_CQ.INT_FILIALE
            WHEN F_CQ.ANATFI_AREA = 'AGE'                   THEN N_CQ.INT_FILIALE
            WHEN F_CQ.ANATFI_AREA = 'IFQ' THEN
                CASE
                    WHEN F_CQ.ANATFI_DISTRETTO = 'I10' THEN N_INT_CQ.INT_FILIALE
                    WHEN F_CQ.ANATFI_DISTRETTO = 'I01' THEN A.QPR_RETE_VENDITA
                    WHEN F_CQ.ANATFI_DISTRETTO = 'I99' THEN N_CQ.INT_FILIALE
                END
        END AS NUMBER(10)) AS VARCHAR(10))                             AS CD_NODO_FOGLIA,
        NULL AS DS_PRODOTTO_POG,
        NULL AS CD_DESTINAZIONE_BENE,
        NULL AS DS_DESTINAZIONE_BENE,
        CAST(A.QPR_FILIALE AS VARCHAR(3)) AS CD_FILIALE_PRAT,
        CAST(N_INT_CQ.INT_FILIALE AS VARCHAR(3)) AS CD_FILIALE_INT,
        A.QPR_RESPONSABILE AS CD_RESPONSABILE,
        A.QPR_CANALE_ACQ AS CD_CANALE_ACQUISIZIONE,
        CAQ.MFTBCAQ_DESCRIZIONE AS DS_CANALE_ACQUISIZIONE,
        A.QPR_TIPO_PROCESSO AS CD_TIPO_PROCESSO,
        TTP.OXISTTP_DESCRIZIONE AS DS_TIPO_PROCESSO,
        CAQ.MFTBCAQ_WEB AS FL_WEB_CANALE_ACQ,
        COALESCE(
            NULLIF(A.QPR_SUB_AGENTE, 0),
            NULLIF(A.QPR_AGENTE, 0)
        ) AS CD_INTERMEDIARIO,
        CASE
            WHEN NULLIF(A.QPR_SUB_AGENTE,    0) IS NOT NULL THEN 'SA'
            WHEN NULLIF(A.QPR_AGENTE,        0) IS NOT NULL THEN 'AG'
            ELSE NULL
        END AS TP_INTERMEDIARIO,
        A.QPR_RETE_VENDITA AS CD_RETE_VENDITA,
        A.QPR_AGENTE AS CD_AGENTE,
        A.QPR_SUB_AGENTE AS CD_SUB_AGENTE,
        NULL AS CD_CONVENZIONATO,
        NULL AS CD_PUNTO_VENDITA,
        NULL AS DS_INSEGNA,
        NULL AS CD_VENDITORE,
        {{ custom_to_decimal('(A.QPR_MONTANTE - A.QPR_BANCA_INTERESSI)') }} AS EU_FINANZIATO,
        NULL AS EU_FIDO,
        {{ custom_to_decimal('A.QPR_IMPORTO_RATA') }} AS EU_RATA,
        {{ custom_to_decimal('A.QPR_NETTO_EROGATO') }} AS EU_EROGATO,
        'TS' AS TP_PAGAMENTO,
        CAST(NULL AS VARCHAR(27)) AS CD_IBAN,
        A.QPR_CEDENTE_ABI AS CD_ABI,
        A.QPR_CEDENTE_CAB AS CD_CAB,
        A.QPR_CEDENTE_CONTO_C AS CD_CC,
        {{ custom_to_date('A.QPR_DATA_CARICAMENTO') }} AS DT_CARICAMENTO,
        {{ custom_to_date('A.QPR_DATA_ESAME') }} AS DT_ESAMINATA,
        COALESCE({{ custom_to_date('A.QPR_DATA_PERFEZIONAMENTO') }}, S35.DT_RESPINTA, SRT.DT_RITIRATA) AS DT_ESITO,
        {{ custom_to_date('A.QPR_DATA_APPROVAZIONE') }} AS DT_APPROVAZIONE,
        S35.DT_RESPINTA,
        SRT.DT_RITIRATA,
        S40.DT_LIQUIDAZIONE,
        {{ custom_to_date('A.QPR_DATA_PERFEZIONAMENTO') }} AS DT_DECORRENZA,
        S45.DT_STORNATA,
        {{ custom_to_date('A.QPR_DATA_CHIUSURA') }} AS DT_CHIUSURA_REGOLARE,
        {{ custom_to_date('A.QPR_CED_DATA_ESTINZIONE') }} AS DT_ESTINZIONE_ANTICIPATA,
        S97.DT_PASSAGGIO_PERDITA,
        {{ custom_to_date('A.QPR_DATA_CESSIONE') }} AS DT_CESSIONE,
        COALESCE({{ custom_to_date('A.QPR_DATA_CHIUSURA') }}, S97.DT_PASSAGGIO_PERDITA, {{ custom_to_date('A.QPR_CED_DATA_ESTINZIONE') }}, 
        {{ custom_to_date('A.QPR_DATA_CESSIONE') }}) AS DT_CHIUSURA_EFFETTIVA,
        NULL AS DT_MESSA_IN_MORA,
        S96.DT_DBT AS DT_DBT,
        LOG.TS_COMUNICAZIONE_ESITO_DEF AS TS_COMUNICAZIONE_ESITO_DEF,
        CASE
            WHEN A.QPR_STATO = '35'
                THEN S35.DT_RESPINTA
            WHEN A.QPR_STATO < '40' AND SRT.DT_RITIRATA IS NOT NULL
                THEN SRT.DT_RITIRATA
            WHEN A.QPR_STATO = '45'
                THEN S45.DT_STORNATA
            WHEN {{ custom_to_date('A.QPR_CED_DATA_ESTINZIONE') }} IS NOT NULL
                THEN {{ custom_to_date('A.QPR_CED_DATA_ESTINZIONE') }}
            WHEN {{ custom_to_date('A.QPR_DATA_CESSIONE') }} IS NOT NULL
                THEN {{ custom_to_date('A.QPR_DATA_CESSIONE') }}
            WHEN A.QPR_STATO = '97'
                THEN S97.DT_PASSAGGIO_PERDITA
            ELSE {{ custom_to_date('A.QPR_CED_ULTIMA_SCADENZA') }}
        END AS DT_CHIUSURA_ANZIANITA,
        NULL AS DT_ULT_ACCODAMENTO,
        {{ custom_to_date('A.QPR_CED_PRIMA_SCADENZA') }} AS DT_PRIMA_SCADENZA,
        {{ custom_to_date('RAT.QRPAT_PRIMA_SCADENZA') }} AS DT_PRIMA_SCADENZA_IST,
        {{ custom_to_date('A.QPR_CED_ULTIMA_SCADENZA') }} AS DT_ULTIMA_SCADENZA,
        {{ custom_to_date('RAT.QRPAT_ULTIMA_SCADENZA') }} AS DT_ULTIMA_SCADENZA_IST,
        S10.CD_USER_CARICAMENTO,
        S15.CD_USER_ESITO,
        S30.CD_USER_APPROVAZIONE,
        S35.CD_USER_RESPINTA,
        SRT.CD_USER_RITIRATA,
        S40.CD_USER_LIQUIDAZIONE,
        S45.CD_USER_STORNO,
        S90.CD_USER_CHIUSURA_REGOLARE,
        S55.CD_USER_ESTINZIONE_ANT,
        S97.CD_USER_PASSAGGIO_PERDITA,
        NULL AS CD_USER_MESSA_IN_MORA,
        S96.CD_USER_DBT,
        A.QPR_TABELLA_FINANZIARIA AS CD_TABELLA_FINANZIARIA,
        TAF.CQTBB_DESCRIZIONE AS DS_TABELLA_FINANZIARIA,
        FIR.OXSCPRA_MODALITA_FIRMA AS TP_FIRMA,
        CAST(NULL AS NUMBER(3)) AS NM_GIORNI,
        NULL AS FL_RIELAB_24,
        NULL AS FL_ESITO_DEF,
        NULL AS FL_FIRMA_DOPPIA,
        NULL AS FL_IN_NOSTART,
        NULL AS FL_DBT,
        COALESCE(ABB.FL_ABBUONO, 'N') AS FL_ABBUONO,
        NULL                                            AS CD_INIZIATIVA_COMM,
        NULL                                            AS FL_OFFERTA,
        NULL AS FL_PERDITA_CESSIONE,
        NULL AS FL_GIA_CLIENTE_MARKETING,
        NULL AS CD_GIA_CLIENTE_MARKETING,
        NULL AS FL_GIA_CLIENTE_CREDITI,
        NULL AS CD_GIA_CLIENTE_CREDITI,
        NULL AS FL_CARTOLARIZZATA,
        COALESCE(ASS.FL_PRODOTTO_ASSICURATIVO, 'N') AS FL_PRODOTTO_ASSICURATIVO,
        'N' AS FL_PNF,
        NULL AS FL_REFIN_RECUPERO,
        COALESCE(REC.FL_RECUPERO, 'N') AS FL_RECUPERO,
        A.LASTMODIFIEDDATA AS LASTMODIFIEDDATA
        
    FROM {{ ref('qspra_m') }} A
    LEFT JOIN {{ ref('qstabsta') }} STA ON A.QPR_STATO = STA.QTSTA_STATO
    AND A.DT_OSSERVAZIONE >= STA.TS_INIZIO_VALIDITA AND A.DT_OSSERVAZIONE < STA.TS_FINE_VALIDITA
    AND STA.FL_DELETED = 'N'
    LEFT JOIN {{ ref('mfftbcaq') }} CAQ ON A.QPR_CANALE_ACQ = CAQ.MFTBCAQ_CANALE_ACQUISIZIONE
    AND A.DT_OSSERVAZIONE >= CAQ.TS_INIZIO_VALIDITA AND A.DT_OSSERVAZIONE < CAQ.TS_FINE_VALIDITA
    AND STA.FL_DELETED = 'N'
    LEFT JOIN {{ ref('oxisfttp') }} TTP ON A.QPR_TIPO_PROCESSO = TTP.OXISTTP_TIPO_PROCESSO
    AND A.DT_OSSERVAZIONE >= TTP.TS_INIZIO_VALIDITA AND A.DT_OSSERVAZIONE < TTP.TS_FINE_VALIDITA
    AND STA.FL_DELETED = 'N'
    LEFT JOIN qsprast_35 S35 ON A.QPR_NUM_PRATICA = S35.QPRST_NUM_PRATICA
    LEFT JOIN qsprast_rt SRT ON A.QPR_NUM_PRATICA = SRT.QPRST_NUM_PRATICA
    LEFT JOIN qsprast_40 S40 ON A.QPR_NUM_PRATICA = S40.QPRST_NUM_PRATICA
    LEFT JOIN qsprast_45 S45 ON A.QPR_NUM_PRATICA = S45.QPRST_NUM_PRATICA
    LEFT JOIN qsprast_97 S97 ON A.QPR_NUM_PRATICA = S97.QPRST_NUM_PRATICA
    LEFT JOIN qsprast_96 S96 ON A.QPR_NUM_PRATICA = S96.QPRST_NUM_PRATICA
    LEFT JOIN cnslflog_cq LOG ON A.QPR_NUM_PRATICA = LOG.CNSLLOG_PRATICA
    LEFT JOIN {{ ref('qsratpat') }} RAT ON A.QPR_NUM_PRATICA = RAT.QRPAT_NUM_PRATICA AND RAT.QRPAT_PROGRESSIVO = 0
    AND RAT.FL_DELETED = 'N'
    LEFT JOIN qsprast_10 S10 ON A.QPR_NUM_PRATICA = S10.QPRST_NUM_PRATICA
    LEFT JOIN qsprast_15 S15 ON A.QPR_NUM_PRATICA = S15.QPRST_NUM_PRATICA
    LEFT JOIN qsprast_30 S30 ON A.QPR_NUM_PRATICA = S30.QPRST_NUM_PRATICA
    LEFT JOIN qsprast_90 S90 ON A.QPR_NUM_PRATICA = S90.QPRST_NUM_PRATICA
    LEFT JOIN qsprast_55 S55 ON A.QPR_NUM_PRATICA = S55.QPRST_NUM_PRATICA
    LEFT JOIN {{ ref('cqtbftafb') }} TAF ON A.QPR_TABELLA_FINANZIARIA = TAF.CQTBB_TABELLA
    AND A.DT_OSSERVAZIONE >= TAF.TS_INIZIO_VALIDITA AND A.DT_OSSERVAZIONE < TAF.TS_FINE_VALIDITA
    AND TAF.FL_DELETED = 'N'
    LEFT JOIN {{ ref('oxscfpra') }} FIR ON A.QPR_NUM_PRATICA = FIR.OXSCPRA_PRATICA 
    AND FIR.OXSCPRA_PROCEDURA = 'CQ' AND FIR.OXSCPRA_PROG_PSV = 1
    AND A.DT_OSSERVAZIONE >= FIR.TS_INIZIO_VALIDITA AND A.DT_OSSERVAZIONE < FIR.TS_FINE_VALIDITA
    AND FIR.FL_DELETED = 'N'
    LEFT JOIN (SELECT DISTINCT PSVT_PRATICA, 'S' AS FL_ABBUONO FROM {{ ref('ccpsvt') }} 
    WHERE PSVT_AZIONE = 'ABB' AND PSVT_PROCEDURA = 'CQ'
    ) ABB 
        ON A.QPR_NUM_PRATICA = ABB.PSVT_PRATICA
    LEFT JOIN (SELECT DISTINCT CQCTASS_NUM_PRATICA, 'S' AS FL_PRODOTTO_ASSICURATIVO, DT_OSSERVAZIONE 
    FROM {{ ref('cqctfass_m') }}) ASS 
        ON A.QPR_NUM_PRATICA = ASS.CQCTASS_NUM_PRATICA
        AND A.DT_OSSERVAZIONE = ASS.DT_OSSERVAZIONE
    LEFT JOIN (SELECT DISTINCT DPRBA_PRATICA, 'S' AS FL_RECUPERO, DT_OSSERVAZIONE 
    FROM {{ ref('re2praba_m') }} WHERE DPRBA_PROVENIENZA = 'CQ') REC 
        ON A.QPR_NUM_PRATICA = REC.DPRBA_PRATICA
        AND A.DT_OSSERVAZIONE = REC.DT_OSSERVAZIONE
    LEFT JOIN {{ref ('ccanainin')}} AS N_CQ ON N_CQ.INT_CODICE      = A.QPR_SUB_AGENTE
    LEFT JOIN {{ ref('ccanainin') }} AS N_INT_CQ
    ON N_INT_CQ.INT_CODICE = COALESCE(NULLIF(A.QPR_SUB_AGENTE, 0), NULLIF(A.QPR_AGENTE, 0))
    LEFT JOIN {{ref ('ccanatfi_m')}}  AS F_CQ ON F_CQ.ANATFI_FILIALE = N_INT_CQ.INT_FILIALE
    AND A.DT_OSSERVAZIONE = F_CQ.DT_OSSERVAZIONE
    -- ----- MACRO PRODOTTO / MERCATO (CQS) -----
    LEFT JOIN {{ source('l1_e_bsn', 'lkp_ger_macro_prodotto_cq') }} AS MPRO
        ON A.QPR_TIPO_CONTRATTO = MPRO.TP_CONTRATTO
        AND A.DT_OSSERVAZIONE >= MPRO.TS_INIZIO_VALIDITA AND A.DT_OSSERVAZIONE < MPRO.TS_FINE_VALIDITA
    LEFT JOIN {{ source('l1_e_bsn', 'lkp_mercato_cq') }} AS MKT_AREA
        ON F_CQ.ANATFI_AREA = MKT_AREA.CD_AREA
        AND A.DT_OSSERVAZIONE >= MKT_AREA.TS_INIZIO_VALIDITA AND A.DT_OSSERVAZIONE < MKT_AREA.TS_FINE_VALIDITA
    LEFT JOIN {{ source('l1_e_bsn', 'lkp_mercato_cq') }} AS MKT_FIL
        ON N_INT_CQ.INT_FILIALE = MKT_FIL.CD_FILIALE
        AND A.DT_OSSERVAZIONE >= MKT_FIL.TS_INIZIO_VALIDITA AND A.DT_OSSERVAZIONE < MKT_FIL.TS_FINE_VALIDITA

    {% if is_incremental() %}
    WHERE A.DT_OSSERVAZIONE = {{ last_day_past_month() }}
    {% endif %}
)

-- ==============================================================
-- FINAL UNION ALL
-- ==============================================================
SELECT
    CD_PRATICA,
    TP_PROCEDURA,
    DT_OSSERVAZIONE,
    TP_ORIG_PRAT,
    CD_STATO,
    DS_STATO,
    CD_ATTRIBUTO,
    CD_CLIENTE,
    CD_COOBLIGATO,
    CD_TIPO_PRODOTTO,
    CD_EMETTITORE,
    CD_PRODOTTO,
    CD_MACRO_PRODOTTO_1,
    CD_MACRO_PRODOTTO_2,
    CD_MACRO_PRODOTTO_3,
    CD_MACRO_PRODOTTO_4,
    CD_MERCATO_1,
    CD_MERCATO_2,
    CD_MERCATO_3,
    CD_MERCATO_4,
    CD_NODO_FOGLIA,
    DS_PRODOTTO_POG,
    CD_DESTINAZIONE_BENE,
    DS_DESTINAZIONE_BENE,
    CD_FILIALE_PRAT,
    CD_FILIALE_INT,
    CD_RESPONSABILE,
    CD_CANALE_ACQUISIZIONE,
    DS_CANALE_ACQUISIZIONE,
    CD_TIPO_PROCESSO,
    DS_TIPO_PROCESSO,
    FL_WEB_CANALE_ACQ,
    CD_INTERMEDIARIO,
    TP_INTERMEDIARIO,
    CD_RETE_VENDITA,
    CD_AGENTE,
    CD_SUB_AGENTE,
    CD_CONVENZIONATO,
    CD_PUNTO_VENDITA,
    DS_INSEGNA,
    CD_VENDITORE,
    EU_FINANZIATO,
    EU_FIDO,
    EU_RATA,
    EU_EROGATO,
    TP_PAGAMENTO,
    CD_IBAN,
    CD_ABI,
    CD_CAB,
    CD_CC,
    DT_CARICAMENTO,
    DT_ESAMINATA,
    DT_ESITO,
    DT_APPROVAZIONE,
    DT_RESPINTA,
    DT_RITIRATA,
    DT_LIQUIDAZIONE,
    DT_DECORRENZA,
    DT_STORNATA,
    DT_CHIUSURA_REGOLARE,
    DT_ESTINZIONE_ANTICIPATA,
    DT_PASSAGGIO_PERDITA,
    DT_CESSIONE,
    DT_CHIUSURA_EFFETTIVA,
    DT_MESSA_IN_MORA,
    DT_DBT,
    TS_COMUNICAZIONE_ESITO_DEF,
    DT_CHIUSURA_ANZIANITA,
    DT_ULT_ACCODAMENTO,
    DT_PRIMA_SCADENZA,
    DT_PRIMA_SCADENZA_IST,
    DT_ULTIMA_SCADENZA,
    DT_ULTIMA_SCADENZA_IST,
    CD_USER_CARICAMENTO,
    CD_USER_ESITO,
    CD_USER_APPROVAZIONE,
    CD_USER_RESPINTA,
    CD_USER_RITIRATA,
    CD_USER_LIQUIDAZIONE,
    CD_USER_STORNO,
    CD_USER_CHIUSURA_REGOLARE,
    CD_USER_ESTINZIONE_ANT,
    CD_USER_PASSAGGIO_PERDITA,
    CD_USER_MESSA_IN_MORA,
    CD_USER_DBT,
    CD_TABELLA_FINANZIARIA,
    DS_TABELLA_FINANZIARIA,
    TP_FIRMA,
    NM_GIORNI,
    CD_INIZIATIVA_COMM,
    FL_OFFERTA,
    FL_RIELAB_24,
    FL_ESITO_DEF,
    FL_FIRMA_DOPPIA,
    FL_IN_NOSTART,
    FL_DBT,
    FL_ABBUONO,
    FL_PERDITA_CESSIONE,
    FL_GIA_CLIENTE_MARKETING,
    CD_GIA_CLIENTE_MARKETING,
    FL_GIA_CLIENTE_CREDITI,
    CD_GIA_CLIENTE_CREDITI,
    FL_CARTOLARIZZATA,
    FL_PRODOTTO_ASSICURATIVO,
    FL_PNF,
    FL_REFIN_RECUPERO,
    FL_RECUPERO,
    LASTMODIFIEDDATA
FROM TAB_FIN_CONSUMO
UNION ALL
SELECT
    CD_PRATICA,
    TP_PROCEDURA,
    DT_OSSERVAZIONE,
    TP_ORIG_PRAT,
    CD_STATO,
    DS_STATO,
    CD_ATTRIBUTO,
    CD_CLIENTE,
    CD_COOBLIGATO,
    CD_TIPO_PRODOTTO,
    CD_EMETTITORE,
    CD_PRODOTTO,
    CD_MACRO_PRODOTTO_1,
    CD_MACRO_PRODOTTO_2,
    CD_MACRO_PRODOTTO_3,
    CD_MACRO_PRODOTTO_4,
    CD_MERCATO_1,
    CD_MERCATO_2,
    CD_MERCATO_3,
    CD_MERCATO_4,
    CD_NODO_FOGLIA,
    DS_PRODOTTO_POG,
    CD_DESTINAZIONE_BENE,
    DS_DESTINAZIONE_BENE,
    CD_FILIALE_PRAT,
    CD_FILIALE_INT,
    CD_RESPONSABILE,
    CD_CANALE_ACQUISIZIONE,
    DS_CANALE_ACQUISIZIONE,
    CD_TIPO_PROCESSO,
    DS_TIPO_PROCESSO,
    FL_WEB_CANALE_ACQ,
    CD_INTERMEDIARIO,
    TP_INTERMEDIARIO,
    CD_RETE_VENDITA,
    CD_AGENTE,
    CD_SUB_AGENTE,
    CD_CONVENZIONATO,
    CD_PUNTO_VENDITA,
    DS_INSEGNA,
    CD_VENDITORE,
    EU_FINANZIATO,
    EU_FIDO,
    EU_RATA,
    EU_EROGATO,
    TP_PAGAMENTO,
    CD_IBAN,
    CD_ABI,
    CD_CAB,
    CD_CC,
    DT_CARICAMENTO,
    DT_ESAMINATA,
    DT_ESITO,
    DT_APPROVAZIONE,
    DT_RESPINTA,
    DT_RITIRATA,
    DT_LIQUIDAZIONE,
    DT_DECORRENZA,
    DT_STORNATA,
    DT_CHIUSURA_REGOLARE,
    DT_ESTINZIONE_ANTICIPATA,
    DT_PASSAGGIO_PERDITA,
    DT_CESSIONE,
    DT_CHIUSURA_EFFETTIVA,
    DT_MESSA_IN_MORA,
    DT_DBT,
    TS_COMUNICAZIONE_ESITO_DEF,
    DT_CHIUSURA_ANZIANITA,
    DT_ULT_ACCODAMENTO,
    DT_PRIMA_SCADENZA,
    DT_PRIMA_SCADENZA_IST,
    DT_ULTIMA_SCADENZA,
    DT_ULTIMA_SCADENZA_IST,
    CD_USER_CARICAMENTO,
    CD_USER_ESITO,
    CD_USER_APPROVAZIONE,
    CD_USER_RESPINTA,
    CD_USER_RITIRATA,
    CD_USER_LIQUIDAZIONE,
    CD_USER_STORNO,
    CD_USER_CHIUSURA_REGOLARE,
    CD_USER_ESTINZIONE_ANT,
    CD_USER_PASSAGGIO_PERDITA,
    CD_USER_MESSA_IN_MORA,
    CD_USER_DBT,
    CD_TABELLA_FINANZIARIA,
    DS_TABELLA_FINANZIARIA,
    TP_FIRMA,
    NM_GIORNI,
    CD_INIZIATIVA_COMM,
    FL_OFFERTA,
    FL_RIELAB_24,
    FL_ESITO_DEF,
    FL_FIRMA_DOPPIA,
    FL_IN_NOSTART,
    FL_DBT,
    FL_ABBUONO,
    FL_PERDITA_CESSIONE,
    FL_GIA_CLIENTE_MARKETING,
    CD_GIA_CLIENTE_MARKETING,
    FL_GIA_CLIENTE_CREDITI,
    CD_GIA_CLIENTE_CREDITI,
    FL_CARTOLARIZZATA,
    FL_PRODOTTO_ASSICURATIVO,
    FL_PNF,
    FL_REFIN_RECUPERO,
    FL_RECUPERO,
    LASTMODIFIEDDATA
FROM TAB_FIN_CARTA
UNION ALL
SELECT
    CD_PRATICA,
    TP_PROCEDURA,
    DT_OSSERVAZIONE,
    TP_ORIG_PRAT,
    CD_STATO,
    DS_STATO,
    CD_ATTRIBUTO,
    CD_CLIENTE,
    CD_COOBLIGATO,
    CD_TIPO_PRODOTTO,
    CD_EMETTITORE,
    CD_PRODOTTO,
    CD_MACRO_PRODOTTO_1,
    CD_MACRO_PRODOTTO_2,
    CD_MACRO_PRODOTTO_3,
    CD_MACRO_PRODOTTO_4,
    CD_MERCATO_1,
    CD_MERCATO_2,
    CD_MERCATO_3,
    CD_MERCATO_4,
    CD_NODO_FOGLIA,
    DS_PRODOTTO_POG,
    CD_DESTINAZIONE_BENE,
    DS_DESTINAZIONE_BENE,
    CD_FILIALE_PRAT,
    CD_FILIALE_INT,
    CD_RESPONSABILE,
    CD_CANALE_ACQUISIZIONE,
    DS_CANALE_ACQUISIZIONE,
    CD_TIPO_PROCESSO,
    DS_TIPO_PROCESSO,
    FL_WEB_CANALE_ACQ,
    CD_INTERMEDIARIO,
    TP_INTERMEDIARIO,
    CD_RETE_VENDITA,
    CD_AGENTE,
    CD_SUB_AGENTE,
    CD_CONVENZIONATO,
    CD_PUNTO_VENDITA,
    DS_INSEGNA,
    CD_VENDITORE,
    EU_FINANZIATO,
    EU_FIDO,
    EU_RATA,
    EU_EROGATO,
    TP_PAGAMENTO,
    CD_IBAN,
    CD_ABI,
    CD_CAB,
    CD_CC,
    DT_CARICAMENTO,
    DT_ESAMINATA,
    DT_ESITO,
    DT_APPROVAZIONE,
    DT_RESPINTA,
    DT_RITIRATA,
    DT_LIQUIDAZIONE,
    DT_DECORRENZA,
    DT_STORNATA,
    DT_CHIUSURA_REGOLARE,
    DT_ESTINZIONE_ANTICIPATA,
    DT_PASSAGGIO_PERDITA,
    DT_CESSIONE,
    DT_CHIUSURA_EFFETTIVA,
    DT_MESSA_IN_MORA,
    DT_DBT,
    TS_COMUNICAZIONE_ESITO_DEF,
    DT_CHIUSURA_ANZIANITA,
    DT_ULT_ACCODAMENTO,
    DT_PRIMA_SCADENZA,
    DT_PRIMA_SCADENZA_IST,
    DT_ULTIMA_SCADENZA,
    DT_ULTIMA_SCADENZA_IST,
    CD_USER_CARICAMENTO,
    CD_USER_ESITO,
    CD_USER_APPROVAZIONE,
    CD_USER_RESPINTA,
    CD_USER_RITIRATA,
    CD_USER_LIQUIDAZIONE,
    CD_USER_STORNO,
    CD_USER_CHIUSURA_REGOLARE,
    CD_USER_ESTINZIONE_ANT,
    CD_USER_PASSAGGIO_PERDITA,
    CD_USER_MESSA_IN_MORA,
    CD_USER_DBT,
    CD_TABELLA_FINANZIARIA,
    DS_TABELLA_FINANZIARIA,
    TP_FIRMA,
    NM_GIORNI,
    CD_INIZIATIVA_COMM,
    FL_OFFERTA,
    FL_RIELAB_24,
    FL_ESITO_DEF,
    FL_FIRMA_DOPPIA,
    FL_IN_NOSTART,
    FL_DBT,
    FL_ABBUONO,
    FL_PERDITA_CESSIONE,
    FL_GIA_CLIENTE_MARKETING,
    CD_GIA_CLIENTE_MARKETING,
    FL_GIA_CLIENTE_CREDITI,
    CD_GIA_CLIENTE_CREDITI,
    FL_CARTOLARIZZATA,
    FL_PRODOTTO_ASSICURATIVO,
    FL_PNF,
    FL_REFIN_RECUPERO,
    FL_RECUPERO,
    LASTMODIFIEDDATA
FROM TAB_FIN_CQS