/*
================================================================================
  DM_CONTROLLI_DQ_BASILEA
  Datamart dei controlli Data Quality per Basilea (PD / CCF / LGD-ELBE)

  Struttura:
    1. Selezione ultimo mese da ciascuna sorgente
    2. UNION ALL immediata → dataset unico con campo PROVENIENZA
       CO = consumo (IFBLFSCRCO) | CA = carte (IFBLFSCRCA)
    3. CTE per ogni controllo atomico (1 campo = 1 riga nel DM)
    4. Esito aggregato: OK se N_RECORD_KO = 0, KO altrimenti, N/A se campo assente

  Macro utilizzate (macros/check_dq.sql):
    check_not_null            check_not_negative         check_not_negative_nullable
    check_not_zero            check_values               check_range
    check_range_if            check_range_if_multi       check_values_if
    check_values_if_multi     check_missing_if_not       check_present_if_not_null
    check_monotonia           check_lte_date             check_coerenza_if
    check_not_negative_multi  check_score_range_by_default

  Chiave: (CD_CONTROLLO, DT_CONTROLLO)
  Schedulazione: fine mese — incremental merge
================================================================================
*/

{% set data_esecuzione %}
    SELECT MAX(SCRCO_DATA_ESTRAZIONE)
        FROM {{ env_var('DBT_DATABASE') }}.L1_O_BAS.IFBLFSCRCO_TEST
    LIMIT 1
{% endset %}

{% if execute %}
    {% set data_esecuzione_result = run_query(data_esecuzione) %}
    {% set DATA_ESTRAZIONE = data_esecuzione_result.columns[0].values()[0] %}
{% else %}
    {% set DATA_ESTRAZIONE = TO_DATE('99991231') %}
{% endif %}




-- ============================================================
-- STEP 1: ultimo mese per ciascuna sorgente
-- ============================================================
with last_scrco AS (
    SELECT *
    FROM {{ env_var('DBT_DATABASE') }}.L1_O_BAS.IFBLFSCRCO_TEST
    WHERE SCRCO_DATA_ESTRAZIONE = (
        SELECT MAX(SCRCO_DATA_ESTRAZIONE)
        FROM {{ env_var('DBT_DATABASE') }}.L1_O_BAS.IFBLFSCRCO_TEST
    )
  --      WHERE SCRCO_DATA_ESTRAZIONE = LAST_DAY(DATEADD(MONTH, -3, CURRENT_DATE()))
)

, last_scrca AS (
    SELECT *
    FROM {{ env_var('DBT_DATABASE') }}.L1_O_BAS.IFBLFSCRCA_TEST
    WHERE SCRCA_DATA_ESTRAZIONE = (
        SELECT MAX(SCRCA_DATA_ESTRAZIONE)
        FROM {{ env_var('DBT_DATABASE') }}.L1_O_BAS.IFBLFSCRCA_TEST
    )
)





-- ============================================================
-- STEP 2: UNION ALL unica — campi comuni allineati
-- Nota: i campi che esistono solo in una delle due sorgenti
--       vengono portati a NULL nell'altra.
--       PROVENIENZA discrimina CO / CA.
-- ============================================================
, base AS (

    -- ── CONSUMO ──────────────────────────────────────────────
    SELECT
        SCRCO_DATA_ESTRAZIONE                   AS DATA_ESTRAZIONE,
        SCRCO_PROVENIENZA                       AS PROVENIENZA,
        SCRCO_PRATICA                           AS PRATICA,
        SCRCO_CLIENTE                           AS CLIENTE,

        -- flag stato
        SCRCO_IN_DEFAULT                        AS IN_DEFAULT,
        --SCRCO_IN_DFLT_EBA                       AS IN_DFLT_EBA,

        -- tipologia segmento
        SCRCO_PD_TYPE                           AS PD_TYPE,
        SCRCO_LGD_TYPE                          AS LGD_TYPE,

        -- campi input PD condivisi
        SCRCO_INFIRMAD                          AS INFIRMAD,
        SCRCO_IMCOOBRD                          AS IMCOOBRD,
        SCRCO_IMRDTANN                          AS IMRDTANN,
        SCRCO_IM_AIM_RATA_MENSIL_CLI            AS IM_AIM_RATA_MENSIL_CLI,
        SCRCO_IM_AIM_RATA_MENSIL_COOB           AS IM_AIM_RATA_MENSIL_COOB,
        SCRCO_IMRATA                            AS IMRATA,
        SCRCO_IMRATA_2                          AS IMRATA_2,
        SCRCO_IMAMCRFC                          AS IMAMCRFC,
        SCRCO_IMAMCLIE                          AS IMAMCLIE,
        SCRCO_IMAIRTCB                          AS IMAIRTCB,
        SCRCO_IMCRFCB                           AS IMCRFCB,
        SCRCO_NMRRT                             AS NMRRT,
        SCRCO_NRMXARR                           AS NRMXARR,
        SCRCO_MESI_CLIENTE                      AS MESI_CLIENTE,
        SCRCO_NM_CONTRATTI_CA                   AS NM_CONTRATTI_CA,
        SCRCO_NM_CONTRATTI_TOT                  AS NM_CONTRATTI_TOT,
        SCRCO_NM_PRAT_RES_GEST                  AS NM_PRAT_RES_GEST,
        SCRCO_NM_RESPINTE_L12M                  AS NM_RESPINTE_L12M,
        SCRCO_MAX_INS_CLI_L6M                   AS MAX_INS_CLI_L6M,
        SCRCO_MAX_INS_CLI_L9M                   AS MAX_INS_CLI_L9M,
        SCRCO_MAX_INS_CLI_L18M                  AS MAX_INS_CLI_L18M,
        SCRCO_CDSTCIV                           AS CDSTCIV,
        SCRCO_DT_DECORRENZA                     AS DT_DECORRENZA,
        SCRCO_IMFINANZ                          AS IMFINANZ,
        SCRCO_E_ONB                             AS E_ONB,
        SCRCO_ONB_FIDO                          AS ONB_FIDO,
        SCRCO_CONTRACT_NUM                      AS CONTRACT_NUM,
        SCRCO_REGIONE                           AS REGIONE,
        SCRCO_DATA_CARICAMENTO                  AS DATA_CARICAMENTO,

        -- impieghi ultimi 3 mesi (denormalizzati SCRCO)
        SCRCO_IM_IMPIEGHI0                      AS IM_IMPIEGHI0,
        SCRCO_IM_IMPIEGHI1                      AS IM_IMPIEGHI1,
        SCRCO_IM_IMPIEGHI2                      AS IM_IMPIEGHI2,

        -- campi calcolati PD — SCRCO
        SCRCO_BIN_INCOME                        AS BIN_INCOME,
        SCRCO_BIN_INSTL_TO_INCOME               AS BIN_INSTL_TO_INCOME,
        SCRCO_BIN_DELTA_INCOME_INSTL            AS BIN_DELTA_INCOME_INSTL,
        SCRCO_BIN_IMPIEGO_CNG_L3M               AS BIN_IMPIEGO_CNG_L3M,
        SCRCO_BIN_IMPI_TOFIDO_SUM_L3M           AS BIN_IMPIEGO_TO_FIDO_SUM_L3M,
        SCRCO_BIN_MAX_INS_CLI_L18M              AS BIN_MAX_INS_CLI_L18M,
        SCRCO_BIN_MAX_INS_CLI_L6M               AS BIN_MAX_INS_CLI_L6M,
        SCRCO_BIN_MAX_INS_CLI_L9M               AS BIN_MAX_INS_CLI_L9M,
        SCRCO_BIN_MESI_CLIENTE                  AS BIN_MESI_CLIENTE,
        SCRCO_BIN_NM_CONTRATTI_CA               AS BIN_NM_CONTRATTI_CA,
        SCRCO_BIN_NM_CONTRATTI_TOT              AS BIN_NM_CONTRATTI_TOT,
        SCRCO_BIN_NM_PRAT_RES_GEST              AS BIN_NM_PRAT_RES_GEST,
        SCRCO_BIN_NMRRT                         AS BIN_NMRRT,
        SCRCO_BIN_NRMXARR                       AS BIN_NRMXARR,
        SCRCO_BIN_BKS_MESI_ATTIVITA             AS BIN_MESI_ATTIVITA,
		SCRCO_BIN_BKS_DELTA_IMP_TO_INSTA_L3M	AS BIN_DELTA_IMP_TO_INSTA_L3M,
        SCRCO_C_CDOCC                           AS C_CDOCC,
        SCRCO_C_CL_CRIF                         AS C_CL_CRIF,
        SCRCO_C_RESPINTE_L12M                   AS C_RESPINTE_L12M,
        SCRCO_C_TPBENE                          AS C_TPBENE,
        SCRCO_C_TPLOC                           AS C_TPLOC,

        -- score PD
        SCRCO_PD_SCORE_PRT                      AS PD_SCORE_PRT,
        SCRCO_PD_SCORE                          AS PD_SCORE,
        SCRCO_PD_TOT_PRT                        AS PD_TOT_PRT,
        SCRCO_PD_TOT                            AS PD_TOT,
        SCRCO_CLASSE_RISCHIO                    AS CLASSE_RISCHIO,
        SCRCO_CLASSE_RISCHIO_PRT                AS CLASSE_RISCHIO_PRT,

        -- LGD / ELBE
        SCRCO_CD_CLUSTER_LGD                    AS CD_CLUSTER_LGD,
        SCRCO_LGD_SCORE                         AS LGD_SCORE,
        SCRCO_CD_CLUSTER_ELBE                   AS CD_CLUSTER_ELBE,
        SCRCO_ELBE_SCORE                        AS ELBE_SCORE,
        SCRCO_ELBE_CLASSE_RISC                  AS ELBE_CLASSE_RISC,
        SCRCO_ANZ_ABITATIVA_MESI                AS ANZ_ABITATIVA_MESI,

        -- campi solo CA → NULL per CO
        NULL::NUMBER                            AS CM_CRLMT,
        NULL::NUMBER                            AS CMAVCRED,
        NULL::VARCHAR                           AS CARTA_UTILIZZATA,
        NULL::VARCHAR                           AS C_CARTA_UTILIZZATA,
        NULL::NUMBER                            AS NM_RESPINTE_L12M_CO,
        NULL::VARCHAR                           AS C_RESPINTE_L12M_CO,
        NULL::NUMBER                            AS BIN_DISPONIBILE_LE0_CNT_L12M,
        NULL::NUMBER                            AS BIN_DISPONIBILE_LE0_CNT_L3M,
        NULL::NUMBER                            AS BIN_DISPONIBILE_TO_FIDO_AVG_L6M,
        NULL::NUMBER                            AS BIN_FIDO_MAX_L6M,
        NULL::NUMBER                            AS BIN_IMPIEGO_TO_FIDO_CNT90BP_L6M,
        NULL::NUMBER                            AS IM_FIDO_1,
        NULL::NUMBER                            AS IM_FIDO_2,
        NULL::NUMBER                            AS IM_FIDO_3,
        NULL::NUMBER                            AS IM_FIDO_4,
        NULL::NUMBER                            AS IM_FIDO_5,
        NULL::NUMBER                            AS IM_FIDO_6,
        NULL::NUMBER                            AS IM_FIDO_7,
        NULL::NUMBER                            AS IM_FIDO_8,
        NULL::NUMBER                            AS IM_FIDO_9,
        NULL::NUMBER                            AS IM_FIDO_10,
        NULL::NUMBER                            AS IM_FIDO_11,
        NULL::NUMBER                            AS IM_FIDO_12,
        -- NULL::NUMBER                            AS IM_IMPIEGHICA_1,
        -- NULL::NUMBER                            AS IM_IMPIEGHICA_2,
        NULL::NUMBER                            AS IM_IMPIEGHI3,
        NULL::NUMBER                            AS IM_IMPIEGHI4,
        NULL::NUMBER                            AS IM_IMPIEGHI5,
        NULL::NUMBER                            AS IM_IMPIEGHI6,
        NULL::NUMBER                            AS IM_IMPIEGHI7,
        NULL::NUMBER                            AS IM_IMPIEGHI8,
        NULL::NUMBER                            AS IM_IMPIEGHI9,
        NULL::NUMBER                            AS IM_IMPIEGHI10,
        NULL::NUMBER                            AS IM_IMPIEGHI11,
        -- NULL::NUMBER                            AS IM_IMPIEGHI12,
        NULL::VARCHAR                           AS CCF_MARGIN_TO_DRAWN,
        NULL::VARCHAR                           AS CCF_MAX_BTW_LIMIT_ONB,
        NULL::VARCHAR                           AS CCF_MARGIN,
        NULL::VARCHAR                           AS CCF_DELTA_LIMIT_12M,
        NULL::VARCHAR                           AS K_DELTA_LIMIT_12M,
        NULL::VARCHAR                           AS K_MAX_UTIL_RATE_6M,
        NULL::VARCHAR                           AS CD_CLUSTER_CCF,
        NULL::NUMBER                            AS CD_CLUSTER_K,
        NULL::NUMBER                            AS PC_CCF,
        NULL::NUMBER                            AS PC_K,
        NULL::VARCHAR                           AS TREATMENT,
        NULL::NUMBER                            AS DISPONIBILE_NOUTI_REAL0,
        NULL::NUMBER                            AS DISPONIBILE_NOUTI_REAL1,
        NULL::NUMBER                            AS DISPONIBILE_NOUTI_REAL2,
        NULL::NUMBER                            AS DISPONIBILE_NOUTI_REAL3,
        NULL::NUMBER                            AS DISPONIBILE_NOUTI_REAL4,
        NULL::NUMBER                            AS DISPONIBILE_NOUTI_REAL5,
        NULL::NUMBER                            AS DISPONIBILE_NOUTI_REAL6,
        NULL::NUMBER                            AS DISPONIBILE_NOUTI_REAL7,
        NULL::NUMBER                            AS DISPONIBILE_NOUTI_REAL8,
        NULL::NUMBER                            AS DISPONIBILE_NOUTI_REAL9,
        NULL::NUMBER                            AS DISPONIBILE_NOUTI_REAL10,
        NULL::NUMBER                            AS DISPONIBILE_NOUTI_REAL11,
        NULL::NUMBER                            AS DISPONIBILE_NOUTI
    

    FROM last_scrco

    UNION ALL

    -- ── CARTE ────────────────────────────────────────────────
    SELECT
        SCRCA_DATA_ESTRAZIONE                   AS DATA_ESTRAZIONE,
        SCRCA_PROVENIENZA                       AS PROVENIENZA,
        SCRCA_PRATICA                           AS PRATICA,
        SCRCA_CLIENTE                           AS CLIENTE,

        --SCRCA_IN_DEFAULT,
        SCRCA_IN_DFLT_EBA                       AS IN_DEFAULT,
        SCRCA_PD_TYPE                           AS PD_TYPE,
        SCRCA_LGD_TYPE                          AS LGD_TYPE,

        -- campi input PD condivisi
        SCRCA_INFIRMAD                          AS INFIRMAD,
        SCRCA_IMCOOBRD                          AS IMCOOBRD,
        SCRCA_IMRDTANN                          AS IMRDTANN,
        SCRCA_IM_AIM_RATA_MENSIL_CLI            AS IM_AIM_RATA_MENSIL_CLI,
        SCRCA_IM_AIM_RATA_MENSIL_COOB           AS IM_AIM_RATA_MENSIL_COOB,
        SCRCA_IMRATA                            AS IMRATA,
        SCRCA_IMRATA_2                          AS IMRATA_2,
        SCRCA_IMAMCRFC                          AS IMAMCRFC,
        SCRCA_IMAMCLIE                          AS IMAMCLIE,
        SCRCA_IMAIRTCB                          AS IMAIRTCB,
        SCRCA_IMCRFCB                           AS IMCRFCB,
        NULL::NUMBER                            AS NMRRT,               -- NMRRT (SOLO CO)
        NULL::NUMBER                            AS NRMXARR,             -- NRMXARR (SOLO CO)
        SCRCA_MESI_CLIENTE                      AS MESI_CLIENTE,
        NULL::NUMBER                            AS NM_CONTRATTI_CA,     -- NM_CONTRATTI_CA (solo CO)
        SCRCA_NM_CONTRATTI_TOT                  AS NM_CONTRATTI_TOT,
        NULL::NUMBER                            AS NM_PRAT_RES_GEST,    -- NM_PRAT_RES_GEST (solo CO)
        NULL::NUMBER                            AS NM_RESPINTE_L12M,    -- NM_RESPINTE_L12M (solo CO)
        SCRCA_MAX_INS_CLI_L6M                   AS MAX_INS_CLI_L6M,
        SCRCA_MAX_INS_CLI_L9M                   AS MAX_INS_CLI_L9M,
        NULL::NUMBER                            AS MAX_INS_CLI_L18M,    -- MAX_INS_CLI_L18M (solo CO)
        NULL::VARCHAR                           AS CDSTCIV,             -- CDSTCIV (solo CO)
        SCRCA_DT_DECORRENZA                     AS DT_DECORRENZA,
        NULL::NUMBER                            AS IMFINANZ,            -- IMFINANZ (solo CO)
        SCRCA_E_ONB                             AS E_ONB,
        SCRCA_ONB_FIDO                          AS ONB_FIDO,
        SCRCA_CONTRACT_NUM                      AS CONTRACT_NUM,
        SCRCA_REGIONE                           AS REGIONE,
        NULL::DATE                              AS DATA_CARICAMENTO,    -- DATA_CARICAMENTO (solo CO)

        -- impieghi ultimi 3 mesi → NULL per CA (storico CA è _1.._12)
        SCRCA_IM_IMPIEGHI0                      AS IM_IMPIEGHI0,
        SCRCA_IM_IMPIEGHI1                      AS IM_IMPIEGHI1,
        SCRCA_IM_IMPIEGHI2                      AS IM_IMPIEGHI2,

        -- campi calcolati PD solo CO → NULL per CA
        NULL::NUMBER                            AS BIN_INCOME,
        NULL::NUMBER                            AS BIN_INSTL_TO_INCOME,
        SCRCA_BIN_DELTA_INCOME_INSTL            AS BIN_DELTA_INCOME_INSTL,
        NULL::NUMBER                            AS BIN_IMPIEGO_CNG_L3M,
        NULL::NUMBER                            AS BIN_IMPIEGO_TO_FIDO_SUM_L3M,
        NULL::NUMBER                            AS BIN_MAX_INS_CLI_L18M,
        SCRCA_BIN_MAX_INS_CLI_L6M               AS BIN_MAX_INS_CLI_L6M,
        SCRCA_BIN_MAX_INS_CLI_L9M               AS BIN_MAX_INS_CLI_L9M,
        NULL::NUMBER                            AS BIN_MESI_CLIENTE,
        NULL::NUMBER                            AS BIN_NM_CONTRATTI_CA,
        SCRCA_BIN_NM_CONTRATTI_TOT              AS BIN_NM_CONTRATTI_TOT,
        NULL::NUMBER                            AS BIN_NM_PRAT_RES_GEST,
        NULL::NUMBER                            AS BIN_NMRRT,
        NULL::NUMBER                            AS BIN_NRMXARR,
        NULL::NUMBER                            AS BIN_MESI_ATTIVITA,
		NULL::NUMBER 				            AS BIN_DELTA_IMP_TO_INSTA_L3M,
        SCRCA_C_CDOCC                           AS C_CDOCC,
        SCRCA_C_CL_CRIF                         AS C_CL_CRIF,
        NULL::VARCHAR                           AS C_RESPINTE_L12M,
        NULL::VARCHAR                           AS C_TPBENE,
        SCRCA_C_TPLOC                           AS C_TPLOC,

        -- score PD
        SCRCA_PD_SCORE_PRT                      AS PD_SCORE_PRT,
        SCRCA_PD_SCORE                          AS PD_SCORE,
        SCRCA_PD_TOT_PRT                        AS PD_TOT_PRT,
        SCRCA_PD_TOT                            AS PD_TOT,
        SCRCA_CLASSE_RISCHIO                    AS CLASSE_RISCHIO,
        SCRCA_CLASSE_RISCHIO_PRT                AS CLASSE_RISCHIO_PRT,

        -- LGD / ELBE
        SCRCA_CD_CLUSTER_LGD                    AS CD_CLUSTER_LGD,
        SCRCA_LGD_SCORE                         AS LGD_SCORE,
        SCRCA_CD_CLUSTER_ELBE                   AS CD_CLUSTER_ELBE,
        SCRCA_ELBE_SCORE                        AS ELBE_SCORE,
        SCRCA_ELBE_CLASSE_RISC                  AS ELBE_CLASSE_RISC,
        NULL::NUMBER                            AS ANZ_ABITATIVA_MESI,

        -- campi solo CA
        SCRCA_CM_CRLMT                          AS CM_CRLMT,
        SCRCA_CMAVCRED                          AS CMAVCRED,
        SCRCA_CARTA_UTILIZZATA                  AS CARTA_UTILIZZATA,
        SCRCA_C_CARTA_UTILIZZATA                AS C_CARTA_UTILIZZATA,
        SCRCA_NM_RESPINTE_L12M_CO               AS NM_RESPINTE_L12M_CO,
        SCRCA_C_RESPINTE_L12M_CO                AS C_RESPINTE_L12M_CO,
        SCRCA_BIN_DISP_LE0_CNT_L12M             AS BIN_DISPONIBILE_LE0_CNT_L12M,
        SCRCA_BIN_DISP_LE0_CNT_L3M              AS BIN_DISPONIBILE_LE0_CNT_L3M,
        SCRCA_BIN_DISP_TOFIDOAVG_L6M            AS BIN_DISPONIBILE_TO_FIDO_AVG_L6M, -- DA cambiare a SCRCA_BIN_DISP_TO_FIDO_AVG_L6M
        SCRCA_BIN_FIDO_MAX_L6M                  AS BIN_FIDO_MAX_L6M,
        SCRCA_BIN_IMPI_FIDOCNT90BP_L6M          AS BIN_IMPIEGO_TO_FIDO_CNT90BP_L6M, -- da cambiare a SCRCA_BIN_IMPIEGO_TO_FIDO_CNT90BP_L6M
        SCRCA_IM_FIDO1                          AS IM_FIDO_1,
        SCRCA_IM_FIDO2                          AS IM_FIDO_2,
        SCRCA_IM_FIDO3                          AS IM_FIDO_3,
        SCRCA_IM_FIDO4                          AS IM_FIDO_4,
        SCRCA_IM_FIDO5                          AS IM_FIDO_5,
        SCRCA_IM_FIDO6                          AS IM_FIDO_6,
        SCRCA_IM_FIDO7                          AS IM_FIDO_7,
        SCRCA_IM_FIDO8                          AS IM_FIDO_8,
        SCRCA_IM_FIDO9                          AS IM_FIDO_9,
        SCRCA_IM_FIDO10                         AS IM_FIDO_10,
        SCRCA_IM_FIDO11                         AS IM_FIDO_11,
        SCRCA_IM_FIDO12                         AS IM_FIDO_12,
        -- SCRCA_IM_IMPIEGHI1,
        -- SCRCA_IM_IMPIEGHI2,
        SCRCA_IM_IMPIEGHI3                      AS IM_IMPIEGHI3,
        SCRCA_IM_IMPIEGHI4                      AS IM_IMPIEGHI4,
        SCRCA_IM_IMPIEGHI5                      AS IM_IMPIEGHI5,
        SCRCA_IM_IMPIEGHI6                      AS IM_IMPIEGHI6,
        SCRCA_IM_IMPIEGHI7                      AS IM_IMPIEGHI7,
        SCRCA_IM_IMPIEGHI8                      AS IM_IMPIEGHI8,
        SCRCA_IM_IMPIEGHI9                      AS IM_IMPIEGHI9,
        SCRCA_IM_IMPIEGHI10                     AS IM_IMPIEGHI10,
        SCRCA_IM_IMPIEGHI11                     AS IM_IMPIEGHI11,
        -- SCRCA_IM_IMPIEGHI12,
        SCRCA_CCF_MARGIN_TO_DRAWN               AS CCF_MARGIN_TO_DRAWN,
        SCRCA_CCF_MAX_BTW_LIMIT_ONB             AS CCF_MAX_BTW_LIMIT_ONB,
        SCRCA_CCF_MARGIN                        AS CCF_MARGIN,
        SCRCA_CCF_DELTA_LIMIT_12M               AS CCF_DELTA_LIMIT_12M,
        SCRCA_K_DELTA_LIMIT_12M                 AS K_DELTA_LIMIT_12M,
        SCRCA_K_MAX_UTIL_RATE_6M                AS K_MAX_UTIL_RATE_6M,
        SCRCA_CD_CLUSTER_CCF                    AS CD_CLUSTER_CCF,
        SCRCA_CD_CLUSTER_K                      AS CD_CLUSTER_K,
        SCRCA_PC_CCF                            AS PC_CCF,
        SCRCA_PC_K                              AS PC_K,
        SCRCA_TREATMENT                         AS TREATMENT,
        SCRCA_DISPONIBILE_NOUTI_REAL0           AS DISPONIBILE_NOUTI_REAL0,
        SCRCA_DISPONIBILE_NOUTI_REAL1           AS DISPONIBILE_NOUTI_REAL1,
        SCRCA_DISPONIBILE_NOUTI_REAL2           AS DISPONIBILE_NOUTI_REAL2,
        SCRCA_DISPONIBILE_NOUTI_REAL3           AS DISPONIBILE_NOUTI_REAL3,
        SCRCA_DISPONIBILE_NOUTI_REAL4           AS DISPONIBILE_NOUTI_REAL4,
        SCRCA_DISPONIBILE_NOUTI_REAL5           AS DISPONIBILE_NOUTI_REAL5,
        SCRCA_DISPONIBILE_NOUTI_REAL6           AS DISPONIBILE_NOUTI_REAL6,
        SCRCA_DISPONIBILE_NOUTI_REAL7           AS DISPONIBILE_NOUTI_REAL7,
        SCRCA_DISPONIBILE_NOUTI_REAL8           AS DISPONIBILE_NOUTI_REAL8,
        SCRCA_DISPONIBILE_NOUTI_REAL9           AS DISPONIBILE_NOUTI_REAL9,
        SCRCA_DISPONIBILE_NOUTI_REAL10          AS DISPONIBILE_NOUTI_REAL10,
        SCRCA_DISPONIBILE_NOUTI_REAL11          AS DISPONIBILE_NOUTI_REAL11,
        SCRCA_DISPONIBILE_NOUTI                 AS DISPONIBILE_NOUTI

    FROM last_scrca
    ), 

-- CTE intermedia: calcola MIN(PD_SCORE_PRT) per cliente per PD_057 e PD_059
pd_score_min AS (
    SELECT
        *,
        MIN(PD_SCORE_PRT) OVER (PARTITION BY CLIENTE) AS MIN_PD_SCORE_PRT,
        MIN(PD_TOT_PRT)   OVER (PARTITION BY CLIENTE) AS MIN_PD_TOT_PRT
    FROM base
)

-- ============================================================
-- STEP 3: CONTROLLI ATOMICI
-- Ogni CTE testa un solo campo su tutto il dataset base.
-- Il filtro PROVENIENZA isola il perimetro corretto:
--   'CO'       → solo consumo
--   'CA'       → solo carte
--   nessun filtro → entrambe le sorgenti
-- ============================================================

-- ── SEZIONE PD ───────────────────────────────────────────────

-- PD_001 | PD_001 INPUT | CO + CA
-- IMCOOBRD: se INFIRMAD=N deve essere missing/zero; se INFIRMAD=S no negativi
, PD_001 AS (
    SELECT 'PD_001',
           'IMCOOBRD: missing/zero se INFIRMAD=N; no valori negativi se INFIRMAD=S',
           COUNT_IF(
               (INFIRMAD = 'N' AND IMCOOBRD IS NOT NULL AND IMCOOBRD <> 0)
            OR (INFIRMAD = 'S' AND (IMCOOBRD IS NULL OR IMCOOBRD < 0))
           ) AS n_ko,
           'CO;CA' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
)

-- PD_002 | PD_001 INPUT | CO + CA
-- IMRDTANN: no NULL, no negativi
, PD_002 AS (
    SELECT 'PD_002',
           'IMRDTANN: non sono ammessi valori NULL o negativi',
           {{ check_not_negative('IMRDTANN') }},
           'CO;CA' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
)

-- PD_003 | PD_001 CALC | CO
-- BIN_INCOME: range 0-12 se PD_TYPE=STF; missing altrimenti
, PD_003 AS (
    SELECT 'PD_003',
           'BIN_INCOME: range [0,12] se PD_TYPE=STF; deve essere NULL altrimenti',
           {{ check_range_if('BIN_INCOME', 0, 12, 'PD_TYPE', 'STF') }},
           'CO' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
    WHERE PROVENIENZA = 'CO'
)

-- PD_004 | PD_002 INPUT | CO + CA
-- Coerenza garante: se INFIRMAD=N i campi coobbligato devono essere missing/zero
, PD_004 AS (
    SELECT 'PD_004',
           'Coerenza garante: se INFIRMAD=N allora IM_AIM_RATA_MENSIL_COOB/IMAIRTCB/IMCRFCB devono essere NULL o zero',
           COUNT_IF(
               INFIRMAD = 'N'
               AND (
                      (IM_AIM_RATA_MENSIL_COOB IS NOT NULL AND IM_AIM_RATA_MENSIL_COOB <> 0)
                   OR (IMAIRTCB IS NOT NULL AND IMAIRTCB <> 0)
                   OR (IMCRFCB  IS NOT NULL AND IMCRFCB  <> 0)
               )
           ),
           'CO;CA' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
)

-- PD_005 | PD_002 INPUT | CO + CA 
-- IM_AIM_RATA_MENSIL_CLI: no NULL, no negativi
, PD_005 AS (
    SELECT 'PD_005',
           'IM_AIM_RATA_MENSIL_CLI: non sono ammessi valori NULL o negativi',
           {{ check_not_negative('IM_AIM_RATA_MENSIL_CLI') }},
           'CO;CA' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
)

-- PD_006 | PD_002 INPUT | CO + CA
-- se INFIRMAD=S allora IM_AIM_RATA_MENSIL_COOB: non sono ammessi valori negativi 
, PD_006 AS (
    SELECT 'PD_006',
          'se INFIRMAD=S allora IM_AIM_RATA_MENSIL_COOB: non sono ammessi valori negativi',
           
    COUNT_IF(INFIRMAD = 'S' AND IM_AIM_RATA_MENSIL_COOB < 0)
,
           'CO;CA' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
    
)

-- PD_007 | PD_002 INPUT | CO + CA
-- IMRATA: no NULL, no negativi
, PD_007 AS (
    SELECT 'PD_007',
           'IMRATA: non sono ammessi valori NULL o negativi',
           {{ check_not_negative('IMRATA') }},
           'CO;CA' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
)

-- PD_008 | PD_002 INPUT | CO + CA
-- IMRATA_2: no negativi (campo opzionale per finanziamenti a due periodi)
, PD_008 AS (
    SELECT 'PD_008',
           'IMRATA_2: non sono ammessi valori negativi',
           {{ check_not_negative_nullable('IMRATA_2') }},
           'CO;CA' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
)

-- PD_009 | PD_002 INPUT | CO + CA
-- IMAMCRFC: no NULL, no negativi
, PD_009 AS (
    SELECT 'PD_009',
           'IMAMCRFC: non sono ammessi valori NULL o negativi',
           {{ check_not_negative('IMAMCRFC') }},
           'CO;CA' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
)

-- PD_010 | PD_002 INPUT | CO + CA
-- IMAMCLIE: no NULL, no negativi
, PD_010 AS (
    SELECT 'PD_010',
           'IMAMCLIE: non sono ammessi valori NULL o negativi',
           {{ check_not_negative('IMAMCLIE') }},
           'CO;CA' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
)

-- PD_011 | PD_002 INPUT | CO + CA
--  se INFIRMAD=S allora IMAIRTCB: non sono ammessi valori negativi
, PD_011 AS (
    SELECT 'PD_011',
           'se INFIRMAD=S allora IMAIRTCB: non sono ammessi valori negativi',
           
    COUNT_IF(INFIRMAD = 'S' AND IMAIRTCB < 0)
,
           'CO;CA' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
)


-- PD_012 | PD_002 INPUT | CO + CA
-- se INFIRMAD=S allora IMCRFCB: non sono ammessi valori negativi
, PD_012 AS (
    SELECT 'PD_012',
           'se INFIRMAD=S allora IMCRFCB: non sono ammessi valori negativi',
     COUNT_IF(INFIRMAD = 'S' AND IMCRFCB < 0)
,
           'CO;CA' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
)

-- PD_013 | PD_002 CALC | CO
-- BIN_INSTL_TO_INCOME: range 0-19 se VEH; missing altrimenti
, PD_013 AS (
    SELECT 'PD_013',
           'BIN_INSTL_TO_INCOME: range [0,19] se PD_TYPE=VEH; deve essere NULL altrimenti',
           {{ check_range_if('BIN_INSTL_TO_INCOME', 0, 19, 'PD_TYPE', 'VEH') }},
           'CO' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
    WHERE PROVENIENZA = 'CO'
)

-- PD_014 | PD_003 CALC | CO + CA 
-- BIN_DELTA_INCOME_INSTL: range PPP(0-19)/CPA(0-11)/BKS(0-8); missing altrimenti
, PD_014 AS (
    SELECT 'PD_014',
           'BIN_DELTA_INCOME_INSTL: range [0,19] PPP / [0,11] CPA / [0,8] BKS; NULL altrimenti',
           {{ check_range_if_multi(
               'BIN_DELTA_INCOME_INSTL',
               [{'val':'PPP','min':0,'max':19},
                {'val':'CPA','min':0,'max':11},
                {'val':'BKS','min':0,'max':8}],
               'PD_TYPE', true
             ) }},
           'CO;CA' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
)

-- PD_015 | PD_008 INPUT | CA
-- DISPONIBILE_NOUTI_REAL 0-11: no NULL, no negativi su tutti i 12 periodi
, PD_015 AS (
    SELECT 'PD_015',
           'DISPONIBILE_NOUTI_REAL 0-11: non sono ammessi valori NULL o negativi su nessuno dei 12 periodi',
           {{ check_not_negative_multi(['DISPONIBILE_NOUTI_REAL0',
                                        'DISPONIBILE_NOUTI_REAL1',
                                        'DISPONIBILE_NOUTI_REAL2',
                                        'DISPONIBILE_NOUTI_REAL3',
                                        'DISPONIBILE_NOUTI_REAL4',
                                        'DISPONIBILE_NOUTI_REAL5',
                                        'DISPONIBILE_NOUTI_REAL6',
                                        'DISPONIBILE_NOUTI_REAL7',
                                        'DISPONIBILE_NOUTI_REAL8',
                                        'DISPONIBILE_NOUTI_REAL9',
                                        'DISPONIBILE_NOUTI_REAL10',
                                        'DISPONIBILE_NOUTI_REAL11']) }},
		   'CA' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
    WHERE PROVENIENZA = 'CA'
)

-- PD_016 | PD_004 CALC | CA
-- BIN_DISPONIBILE_LE0_CNT_L12M: range 0-2 se NPA; missing altrimenti
, PD_016 AS (
    SELECT 'PD_016',
           'BIN_DISPONIBILE_LE0_CNT_L12M: range [0,2] se PD_TYPE=NPA; deve essere NULL altrimenti',
           {{ check_range_if('BIN_DISPONIBILE_LE0_CNT_L12M', 0, 2, 'PD_TYPE', 'NPA') }},
           'CA' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
    WHERE PROVENIENZA = 'CA'
)

-- PD_017 | PD_005 CALC | CA
-- BIN_DISPONIBILE_LE0_CNT_L3M: range 0-2 se CPA; missing altrimenti
, PD_017 AS (
    SELECT 'PD_017',
           'BIN_DISPONIBILE_LE0_CNT_L3M: range [0,2] se PD_TYPE=CPA; deve essere NULL altrimenti',
           {{ check_range_if('BIN_DISPONIBILE_LE0_CNT_L3M', 0, 2, 'PD_TYPE', 'CPA') }},
           'CA' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
    WHERE PROVENIENZA = 'CA'
)

-- PD_018 | PD_006 INPUT | CA
-- CM_CRLMT: no NULL, no negativi
, PD_018 AS (
    SELECT 'PD_018',
           'CM_CRLMT (importo fido): non sono ammessi valori NULL o negativi',
           {{ check_not_negative('CM_CRLMT') }},
           'CA' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
    WHERE PROVENIENZA = 'CA'
)

-- PD_019 | PD_006 CALC | CA
-- BIN_DISPONIBILE_TO_FIDO_AVG_L6M: range 0-4 se CPA; missing altrimenti
, PD_019 AS (
    SELECT 'PD_019',
           'BIN_DISPONIBILE_TO_FIDO_AVG_L6M: range [0,4] se PD_TYPE=CPA; deve essere NULL altrimenti',
           {{ check_range_if('BIN_DISPONIBILE_TO_FIDO_AVG_L6M', 0, 4, 'PD_TYPE', 'CPA') }},
           'CA' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
    WHERE PROVENIENZA = 'CA'
)

-- PD_020 | PD_007 CALC | CA
-- BIN_FIDO_MAX_L6M: range 0-3 se NPA; missing altrimenti
, PD_020 AS (
    SELECT 'PD_020',
           'BIN_FIDO_MAX_L6M: range [0,3] se PD_TYPE=NPA; deve essere NULL altrimenti',
           {{ check_range_if('BIN_FIDO_MAX_L6M', 0, 3, 'PD_TYPE', 'NPA') }},
           'CA' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
    WHERE PROVENIENZA = 'CA'
)

-- PD_021 | PD_008 INPUT | CO + CA
-- IM_IMPIEGHI (ultimi 3 mesi): no NULL, no negativi su tutti e tre i periodi
, PD_021 AS (
    SELECT 'PD_021',
           'IM_IMPIEGHI0/1/2: non sono ammessi valori NULL o negativi su nessuno dei 3 periodi',
           {{ check_not_negative_multi(['IM_IMPIEGHI0','IM_IMPIEGHI1','IM_IMPIEGHI2']) }},
           'CO;CA' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
    
)

-- PD_022 | PD_008 CALC | CO
-- BIN_IMPIEGO_CNG_L3M: range VEH(0-4)/PPP(0-7)/STF(0-5); missing altrimenti
, PD_022 AS (
    SELECT 'PD_022',
           'BIN_IMPIEGO_CNG_L3M: range [0,4] VEH / [0,7] PPP / [0,5] STF; NULL altrimenti',
           {{ check_range_if_multi(
               'BIN_IMPIEGO_CNG_L3M',
               [{'val':'VEH','min':0,'max':4},
                {'val':'PPP','min':0,'max':7},
                {'val':'STF','min':0,'max':5}],
               'PD_TYPE', true
             ) }},
           'CO' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
    WHERE PROVENIENZA = 'CO'
)

-- PD_023 | PD_009 CALC | CA
-- BIN_IMPIEGO_TO_FIDO_CNT90BP_L6M: range 0-4 se NPA; missing altrimenti
, PD_023 AS (
    SELECT 'PD_023',
           'BIN_IMPIEGO_TO_FIDO_CNT90BP_L6M: range [0,4] se PD_TYPE=NPA; deve essere NULL altrimenti',
           {{ check_range_if('BIN_IMPIEGO_TO_FIDO_CNT90BP_L6M', 0, 4, 'PD_TYPE', 'NPA') }},
           'CA' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
    WHERE PROVENIENZA = 'CA'
)

-- PD_024 | PD_010 CALC | CO
-- BIN_IMPIEGO_TO_FIDO_SUM_L3M: range 0-6 se STF; missing altrimenti
, PD_024 AS (
    SELECT 'PD_024',
           'BIN_IMPIEGO_TO_FIDO_SUM_L3M: range [0,6] se PD_TYPE=STF; deve essere NULL altrimenti',
           {{ check_range_if('BIN_IMPIEGO_TO_FIDO_SUM_L3M', 0, 6, 'PD_TYPE', 'STF') }},
           'CO' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
    WHERE PROVENIENZA = 'CO'
)

/*
-- PD_025 | PD_011 INPUT | CA 
-- MAX_INS_CLI: monotonia L9M >= L6M — include NULL
, PD_025 AS (
    SELECT 'PD_025',
           'MAX_INS_CLI: violazione monotonia L9M >= L6M  (include NULL)',
           COUNT_IF(
               {{ check_monotonia('MAX_INS_CLI_L9M','MAX_INS_CLI_L6M') }}  > 0
           ),
           'CA' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
    WHERE PROVENIENZA = 'CA'
)


-- PD_026 | PD_011 INPUT | CO 
-- MAX_INS_CLI: monotonia L18M >= L9M >= L6M — include NULL
, PD_026 AS (
    SELECT 'PD_026',
           'MAX_INS_CLI: violazione monotonia L18M >= L9M >= L6M (include NULL)',
           COUNT_IF(
               {{ check_monotonia('MAX_INS_CLI_L18M','MAX_INS_CLI_L9M') }} > 0
               OR
               {{ check_monotonia('MAX_INS_CLI_L9M','MAX_INS_CLI_L6M') }} > 0
           ),
           'CO' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
    WHERE PROVENIENZA = 'CO'
)
*/

-- PD_025 | PD_011 INPUT | CA 
-- MAX_INS_CLI: monotonia L9M >= L6M — include NULL
, PD_025 AS (
    SELECT 'PD_025',
           'MAX_INS_CLI: violazione monotonia L9M >= L6M (include NULL)',
           COUNT_IF(
               MAX_INS_CLI_L9M IS NULL
               OR MAX_INS_CLI_L6M IS NULL
               OR MAX_INS_CLI_L9M < MAX_INS_CLI_L6M
           ),
           'CA' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
    WHERE PROVENIENZA = 'CA'
)

-- PD_026 | PD_011 INPUT | CO 
-- MAX_INS_CLI: monotonia L18M >= L9M >= L6M — include NULL
, PD_026 AS (
    SELECT 'PD_026',
           'MAX_INS_CLI: violazione monotonia L18M >= L9M >= L6M (include NULL)',
           COUNT_IF(
               MAX_INS_CLI_L18M IS NULL
               OR MAX_INS_CLI_L9M IS NULL
               OR MAX_INS_CLI_L6M IS NULL
               OR MAX_INS_CLI_L18M < MAX_INS_CLI_L9M
               OR MAX_INS_CLI_L9M < MAX_INS_CLI_L6M
           ),
           'CO' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
    WHERE PROVENIENZA = 'CO'
)
-- PD_027 | PD_011 CALC | CO
-- BIN_MAX_INS_CLI_L18M: range 0-3 se VEH; missing altrimenti
, PD_027 AS (
    SELECT 'PD_027',
           'BIN_MAX_INS_CLI_L18M: range [0,3] se PD_TYPE=VEH; deve essere NULL altrimenti',
           {{ check_range_if('BIN_MAX_INS_CLI_L18M', 0, 3, 'PD_TYPE', 'VEH') }},
           'CO' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
    WHERE PROVENIENZA = 'CO'
)

-- PD_028 | PD_012 CALC | CO+CA
-- BIN_MAX_INS_CLI_L6M: range 0-2 se STF/NPA; missing altrimenti
, PD_028 AS (
    SELECT 'PD_028',
           'BIN_MAX_INS_CLI_L6M: range [0,2] se PD_TYPE in (STF,NPA); deve essere NULL altrimenti',
           {{ check_values_if_multi('BIN_MAX_INS_CLI_L6M', [0,1,2], 'PD_TYPE', ['STF','NPA']) }},
           'CO;CA' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base

)

-- PD_029 | PD_013 CALC | CO + CA
-- BIN_MAX_INS_CLI_L9M: range CPA/BKS(0-2)/PPP(0-3); missing altrimenti
, PD_029 AS (
    SELECT 'PD_029',
           'BIN_MAX_INS_CLI_L9M: range [0,2] CPA/BKS / [0,3] PPP; NULL altrimenti',
           {{ check_range_if_multi(
               'BIN_MAX_INS_CLI_L9M',
               [{'val':'CPA','min':0,'max':2},
                {'val':'BKS','min':0,'max':2},
                {'val':'PPP','min':0,'max':3}],
               'PD_TYPE', true
             ) }},
           'CO;CA' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
    
)

-- PD_030 | PD_014 INPUT | CO
-- MESI_CLIENTE: no NULL, no negativi
, PD_030 AS (
    SELECT 'PD_030',
           'MESI_CLIENTE: non sono ammessi valori NULL o negativi',
           {{ check_not_negative('MESI_CLIENTE') }},
           'CO' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
    WHERE PROVENIENZA = 'CO'
)

-- PD_031 | PD_014 CALC | CO
-- BIN_MESI_CLIENTE: range 0-3 se STF; missing altrimenti
, PD_031 AS (
    SELECT 'PD_031',
           'BIN_MESI_CLIENTE: range [0,3] se PD_TYPE=STF; deve essere NULL altrimenti',
           {{ check_range_if('BIN_MESI_CLIENTE', 0, 3, 'PD_TYPE', 'STF') }},
           'CO' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
    WHERE PROVENIENZA = 'CO'
)

-- PD_032 | PD_015 INPUT | CO
-- NM_CONTRATTI_CA: no NULL, no negativi
, PD_032 AS (
    SELECT 'PD_032',
           'NM_CONTRATTI_CA: non sono ammessi valori NULL o negativi',
           {{ check_not_negative('NM_CONTRATTI_CA') }},
           'CO' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
    WHERE PROVENIENZA = 'CO'
)

-- PD_033 | PD_015 CALC | CO
-- BIN_NM_CONTRATTI_CA: range 0-2 se PPP/BKS; missing altrimenti
, PD_033 AS (
    SELECT 'PD_033',
           'BIN_NM_CONTRATTI_CA: range [0,2] se PD_TYPE in (PPP,BKS); deve essere NULL altrimenti',
           {{ check_values_if_multi('BIN_NM_CONTRATTI_CA', [0,1,2], 'PD_TYPE', ['PPP','BKS']) }},
           'CO' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
    WHERE PROVENIENZA = 'CO'
)

-- PD_034 | PD_016 INPUT | CO + CA 
-- NM_CONTRATTI_TOT: no NULL, no negativi
, PD_034 AS (
    SELECT 'PD_034',
           'NM_CONTRATTI_TOT: non sono ammessi valori NULL o negativi',
           {{ check_not_negative('NM_CONTRATTI_TOT') }},
           'CO;CA' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
)

-- PD_035 | PD_016 CALC | CO + CA
-- BIN_NM_CONTRATTI_TOT: range STF/CPA(0-3)/VEH/PPP(0-2); missing altrimenti
, PD_035 AS (
    SELECT 'PD_035',
           'BIN_NM_CONTRATTI_TOT: range [0,3] STF/CPA / [0,2] VEH/PPP; NULL altrimenti',
           {{ check_range_if_multi(
               'BIN_NM_CONTRATTI_TOT',
               [{'val':'STF','min':0,'max':3},
                {'val':'CPA','min':0,'max':3},
                {'val':'VEH','min':0,'max':2},
                {'val':'PPP','min':0,'max':2}],
               'PD_TYPE', true
             ) }},
           'CO;CA' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
)

-- PD_036 | PD_017 INPUT | CO
-- NM_PRAT_RES_GEST: no NULL, no negativi
, PD_036 AS (
    SELECT 'PD_036',
           'NM_PRAT_RES_GEST: non sono ammessi valori NULL o negativi',
           {{ check_not_negative('NM_PRAT_RES_GEST') }},
           'CO' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
    WHERE PROVENIENZA = 'CO'
)

-- PD_037 | PD_017 CALC | CO
-- BIN_NM_PRAT_RES_GEST: range STF/PPP/BKS(0-3)/VEH(0-2); missing altrimenti
, PD_037 AS (
    SELECT 'PD_037',
           'BIN_NM_PRAT_RES_GEST: range [0,3] STF/PPP/BKS / [0,2] VEH; NULL altrimenti',
           {{ check_range_if_multi(
               'BIN_NM_PRAT_RES_GEST',
               [{'val':'STF','min':0,'max':3},
                {'val':'PPP','min':0,'max':3},
                {'val':'BKS','min':0,'max':3},
                {'val':'VEH','min':0,'max':2}],
               'PD_TYPE', true
             ) }},
           'CO' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
    WHERE PROVENIENZA = 'CO'
)

-- PD_038 | PD_018 INPUT | CO
-- NMRRT: no NULL, no negativi
, PD_038 AS (
    SELECT 'PD_038',
           'NMRRT: non sono ammessi valori NULL o negativi',
           {{ check_not_negative('NMRRT') }},
           'CO' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
    WHERE PROVENIENZA = 'CO'
)

-- PD_039 | PD_018 CALC | CO
-- BIN_NMRRT: range 0-5 se VEH/STF; missing altrimenti
, PD_039 AS (
    SELECT 'PD_039',
           'BIN_NMRRT: range [0,5] se PD_TYPE in (VEH,STF); deve essere NULL altrimenti',
           {{ check_values_if_multi('BIN_NMRRT', [0,1,2,3,4,5], 'PD_TYPE', ['VEH','STF']) }},
           'CO' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
    WHERE PROVENIENZA = 'CO'
)

-- PD_040 | PD_019 INPUT | CO
-- NRMXARR: no NULL, no negativi
, PD_040 AS (
    SELECT 'PD_040',
           'NRMXARR: non sono ammessi valori NULL o negativi',
           {{ check_not_negative('NRMXARR') }},
           'CO' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
    WHERE PROVENIENZA = 'CO'
)

-- PD_041 | PD_019 CALC | CO
-- BIN_NRMXARR: range 0-3 se PPP; missing altrimenti
, PD_041 AS (
    SELECT 'PD_041',
           'BIN_NRMXARR: range [0,3] se PD_TYPE=PPP; deve essere NULL altrimenti',
           {{ check_range_if('BIN_NRMXARR', 0, 3, 'PD_TYPE', 'PPP') }},
           'CO' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
    WHERE PROVENIENZA = 'CO'
)

-- PD_042 | PD_020 INPUT | CA
-- CARTA_UTILIZZATA: valori ammessi Y/N
, PD_042 AS (
    SELECT 'PD_042',
           'CARTA_UTILIZZATA: valori ammessi Y o N',
           {{ check_values('CARTA_UTILIZZATA', ['Y','N']) }},
           'CA' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
    WHERE PROVENIENZA = 'CA'
)  -- controllare quando ci arrivano i dati se è Y/N oppure SI/NO

-- PD_043 | PD_020 CALC | CA
-- C_CARTA_UTILIZZATA: Y/N se NPA; missing altrimenti
, PD_043 AS (
    SELECT 'PD_043',
           'C_CARTA_UTILIZZATA: valori Y/N se PD_TYPE=NPA; deve essere NULL altrimenti',
           {{ check_values_if('C_CARTA_UTILIZZATA', ['Y','N'], 'PD_TYPE', 'NPA') }},
           'CA' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
    WHERE PROVENIENZA = 'CA'
)   -- controllare quando ci arrivano i dati se è Y/N oppure SI/NO

-- PD_044 | PD_021 CALC | CO + CA
-- C_CDOCC: valori per segmento
, PD_044 AS (
    SELECT 'PD_044',
           'C_CDOCC: valori ammessi HIGH/MEDIUM/LOW_RISK per CPA/NPA; HIGH_MEDIUM/MEDIUM_LOW/LOW per VEH; in più MEDIUM_HIGH per BKS; NULL altrimenti',
           COUNT_IF(
               (PD_TYPE IN ('CPA','NPA') AND (C_CDOCC IS NULL OR C_CDOCC NOT IN ('HIGH_RISK','MEDIUM_RISK','LOW_RISK')))
            OR (PD_TYPE = 'VEH'          AND (C_CDOCC IS NULL OR C_CDOCC NOT IN ('HIGH_MEDIUM_RISK','MEDIUM_LOW_RISK','LOW_RISK')))
            OR (PD_TYPE = 'BKS'          AND (C_CDOCC IS NULL OR C_CDOCC NOT IN ('HIGH_RISK','MEDIUM_HIGH_RISK','MEDIUM_LOW_RISK','LOW_RISK')))
            OR (PD_TYPE NOT IN ('CPA','NPA','VEH','BKS') AND C_CDOCC IS NOT NULL)
           ),
           'CO;CA' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
)

-- PD_045 | PD_022 CALC | CO + CA
-- C_CL_CRIF: valori per segmento
, PD_045 AS (
    SELECT 'PD_045',
           'C_CL_CRIF: HIGH_MEDIUM/MEDIUM_LOW/LOW_RISK per VEH/PPP/STF/CPA; HIGH/MEDIUM/LOW_RISK per BKS; NULL altrimenti',
           COUNT_IF(
               (PD_TYPE IN ('VEH','PPP','STF','CPA') AND (C_CL_CRIF IS NULL OR  C_CL_CRIF NOT IN ('HIGH_MEDIUM_RISK','MEDIUM_LOW_RISK','LOW_RISK')))
            OR (PD_TYPE = 'BKS'                      AND (C_CL_CRIF IS NULL OR  C_CL_CRIF NOT IN ('HIGH_RISK','MEDIUM_RISK','LOW_RISK')))
            OR (PD_TYPE NOT IN ('VEH','PPP','STF','CPA','BKS') AND C_CL_CRIF IS NOT NULL)
           ),
           'CO;CA' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
)

-- PD_046 | PD_023 INPUT | CO
-- NM_RESPINTE_L12M: no NULL, no negativi
, PD_046 AS (
    SELECT 'PD_046',
           'NM_RESPINTE_L12M: non sono ammessi valori NULL o negativi',
           {{ check_not_negative('NM_RESPINTE_L12M') }},
           'CO' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
    WHERE PROVENIENZA = 'CO'
)

-- PD_047 | PD_023 CALC | CO
-- C_RESPINTE_L12M: Y/N se PPP; missing altrimenti
, PD_047 AS (
    SELECT 'PD_047',
           'C_RESPINTE_L12M: valori Y/N se PD_TYPE=PPP; deve essere NULL altrimenti',
           {{ check_values_if('C_RESPINTE_L12M', ['Y','N'], 'PD_TYPE', 'PPP') }},
           'CO' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
    WHERE PROVENIENZA = 'CO'
)

-- PD_048 | PD_024 INPUT | CA
-- NM_RESPINTE_L12M_CO: no NULL, no negativi
, PD_048 AS (
    SELECT 'PD_048',
           'NM_RESPINTE_L12M_CO: non sono ammessi valori NULL o negativi',
           {{ check_not_negative('NM_RESPINTE_L12M_CO') }},
           'CA' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
    WHERE PROVENIENZA = 'CA'
)

-- PD_049 | PD_024 CALC | CA
-- C_RESPINTE_L12M_CO: Y/N se NPA; missing altrimenti
, PD_049 AS (
    SELECT 'PD_049',
           'C_RESPINTE_L12M_CO: valori Y/N se PD_TYPE=NPA; deve essere NULL altrimenti',
           {{ check_values_if('C_RESPINTE_L12M_CO', ['Y','N'], 'PD_TYPE', 'NPA') }},
           'CA' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
    WHERE PROVENIENZA = 'CA'
)

-- PD_050 | PD_025 CALC | CO
-- C_TPBENE: HIGH/MEDIUM/LOW_RISK se VEH; missing altrimenti
, PD_050 AS (
    SELECT 'PD_050',
           'C_TPBENE: HIGH/MEDIUM/LOW_RISK se PD_TYPE=VEH; deve essere NULL altrimenti',
           {{ check_values_if('C_TPBENE', ['HIGH_RISK','MEDIUM_RISK','LOW_RISK'], 'PD_TYPE', 'VEH') }},
           'CO' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
    WHERE PROVENIENZA = 'CO'
)

-- PD_051 | PD_026 CALC | CO + CA
-- C_TPLOC: Property/Else per VEH/STF/PPP/CPA/BKS; missing altrimenti
, PD_051 AS (
    SELECT 'PD_051',
           'C_TPLOC: PROPERTY/ELSE per PD_TYPE in (VEH,STF,PPP,CPA,BKS); deve essere NULL altrimenti',
           COUNT_IF(
               (PD_TYPE IN ('VEH','STF','PPP','CPA','BKS') AND (C_TPLOC IS NULL OR UPPER(C_TPLOC) NOT IN ('PROPERTY','ELSE')))
            OR (PD_TYPE NOT IN ('VEH','STF','PPP','CPA','BKS') AND C_TPLOC IS NOT NULL)
           ),
           'CO;CA' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
)

-- PD_052 | PD_027 CALC | CO
-- CDSTCIV: LOW/HIGH_RISK se BKS; missing altrimenti
, PD_052 AS (
    SELECT 'PD_052',
           'CDSTCIV: LOW_RISK/HIGH_RISK se PD_TYPE=BKS; deve essere NULL altrimenti',
           {{ check_values_if('CDSTCIV', ['LOW_RISK','HIGH_RISK'], 'PD_TYPE', 'BKS') }},
           'CO' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
    WHERE PROVENIENZA = 'CO'
)

-- PD_053 | PD_028 INPUT | CO + CA
-- DT_DECORRENZA: non NULL e <= DATA_ESTRAZIONE
, PD_053 AS (
    SELECT 'PD_053',
           'DT_DECORRENZA: non deve essere NULL e deve essere <= DATA_ESTRAZIONE',
           COUNT_IF(
					DT_DECORRENZA IS NULL OR DATA_ESTRAZIONE IS NULL
					OR DT_DECORRENZA > DATA_ESTRAZIONE
    ),
           'CO;CA' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
)

-- PD_054 | PD_028 CALC | CO
-- BIN_MESI_ATTIVITA: range 0-13 se BKS; missing altrimenti
, PD_054 AS (
    SELECT 'PD_054',
           'BIN_MESI_ATTIVITA: range [0,13] se PD_TYPE=BKS; deve essere NULL altrimenti',
           {{ check_range_if('BIN_MESI_ATTIVITA', 0, 13, 'PD_TYPE', 'BKS') }},
           'CO' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
    WHERE PROVENIENZA = 'CO'
	
)

-- PD_055 | PD_029 CALC | CO
-- BIN_DELTA_IMP_TO_INSTA_L3M: range 0-4 se BKS; missing altrimenti
, PD_055 AS (
    SELECT 'PD_055',
           'BIN_DELTA_IMP_TO_INSTA_L3M: range [0,4] se PD_TYPE=BKS; deve essere NULL altrimenti',
           {{ check_range_if('BIN_DELTA_IMP_TO_INSTA_L3M', 0, 4, 'PD_TYPE', 'BKS') }},
           'CO' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
    WHERE PROVENIENZA = 'CO'
	
)

-- PD_056 | PD_030 CALC | CO + CA
-- PD_SCORE_PRT: (0,1]; se IN_DEFAULT=S deve essere 1
, PD_056 AS (
    SELECT 'PD_056',
           'PD_SCORE_PRT: range (0,100]; se IN_DEFAULT=S deve essere esattamente 100',
           {{ check_score_range_by_default('PD_SCORE_PRT', 'IN_DEFAULT', 'S', 0, 100) }},
           'CO;CA' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
)

-- PD_057 | PD_031 CALC | CO + CA
-- PD_SCORE: deve essere uguale al minimo di PD_SCORE_PRT tra tutti i contratti del cliente
/*, PD_057 AS (
    SELECT 'PD_057',
           'PD_SCORE: deve essere uguale a MIN(PD_SCORE_PRT) calcolato sui contratti del cliente alla stessa data di osservazione',
           COUNT_IF(
               PD_SCORE IS NULL
            OR PD_SCORE_PRT IS NULL
            OR PD_SCORE <> MIN(PD_SCORE_PRT) OVER (PARTITION BY CLIENTE)
           ),
           'CO;CA' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
) */

, PD_057 AS (
    SELECT 'PD_057',
           'PD_SCORE: deve essere uguale a MIN(PD_SCORE_PRT) calcolato sui contratti del cliente alla stessa data di osservazione',
           COUNT_IF(
               PD_SCORE IS NULL
               OR PD_SCORE_PRT IS NULL
               OR PD_SCORE <> MIN_PD_SCORE_PRT
           ),
           'CO;CA' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM pd_score_min
)

-- PD_058 | PD_032 CALC | CO + CA
-- PD_TOT_PRT: range [0,400] se IN_DEFAULT=N; missing se IN_DEFAULT=S
, PD_058 AS (
    SELECT 'PD_058',
           'PD_TOT_PRT: range [0,400] se IN_DEFAULT=N; deve essere NULL se IN_DEFAULT=S',
           COUNT_IF(
               (IN_DEFAULT = 'N' AND (PD_TOT_PRT IS NULL OR PD_TOT_PRT < 0 OR PD_TOT_PRT > 400))
            OR (IN_DEFAULT = 'S' AND PD_TOT_PRT IS NOT NULL)
           ),
           'CO;CA' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
)

-- PD_059 | PD_033 CALC | CO
-- PD_TOT: deve essere uguale al minimo di PD_TOT_PRT tra tutti i contratti del cliente
/*, PD_059 AS (
    SELECT 'PD_059',
           'PD_TOT: deve essere uguale a MIN(PD_TOT_PRT) calcolato sui contratti del cliente alla stessa data di osservazione',
           COUNT_IF(
               PD_TOT IS NULL
            OR PD_TOT_PRT IS NULL
            OR PD_TOT <> MIN(PD_TOT_PRT) OVER (PARTITION BY CLIENTE)
           ),
           'CO;CA' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
) */

, PD_059 AS (
    SELECT 'PD_059',
           'PD_TOT: deve essere uguale a MIN(PD_TOT_PRT) calcolato sui contratti del cliente alla stessa data di osservazione',
           COUNT_IF(
               PD_TOT IS NULL
               OR PD_TOT_PRT IS NULL
               OR PD_TOT <> MIN_PD_TOT_PRT
           ),
           'CO;CA' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM pd_score_min
)

-- PD_060 | PD_034 CALC | CO + CA
-- CLASSE_RISCHIO: range [1,17]; solo se IN_DEFAULT=S deve essere esattamente 1
, PD_060 AS (
    SELECT 'PD_060',
           'CLASSE_RISCHIO: range [1,17]; solo se IN_DEFAULT=S deve essere esattamente 1',
           COUNT_IF(
               CLASSE_RISCHIO IS NULL
            OR CLASSE_RISCHIO < 1
            OR CLASSE_RISCHIO > 17
            OR (IN_DEFAULT = 'S' AND CLASSE_RISCHIO <> 1)
           ),
           'CO;CA' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
)

-- PD_061 | PD_035 CALC | CO + CA
-- CLASSE_RISCHIO_PRT: range [1,17]; solo se IN_DEFAULT=S deve essere esattamente 1
, PD_061 AS (
    SELECT 'PD_061',
           'CLASSE_RISCHIO_PRT: range [1,17]; solo se IN_DEFAULT=S deve essere esattamente 1',
           COUNT_IF(
               CLASSE_RISCHIO_PRT IS NULL
            OR CLASSE_RISCHIO_PRT < 1
            OR CLASSE_RISCHIO_PRT > 17
            OR (IN_DEFAULT = 'S' AND CLASSE_RISCHIO_PRT <> 1)
           ),
           'CO;CA' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
)

-- PD_062 | PD_036 | CO + CA
-- Coerenza CLASSE_RISCHIO / PD_TOT: la classe deve corrispondere al range di PD_TOT
, PD_062 AS (
    SELECT 'PD_062',
           'Coerenza CLASSE_RISCHIO/PD_TOT: PD_TOT deve essere compreso tra PD_PUNTEGGIO_MIN e PD_PUNTEGGIO_MAX (estremi inclusi) della classe di rischio in PD_VALIDITA',
           COUNT_IF(
               b.PD_TOT IS NULL
            OR v.PD_CLASSE_RISCHIO IS NULL          -- classe non censita in PD_VALIDITA
            OR b.PD_TOT < v.PD_PUNTEGGIO_MIN
            OR b.PD_TOT > v.PD_PUNTEGGIO_MAX
           ),
           'CO;CA' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base b
	LEFT JOIN {{ env_var('DBT_DATABASE') }}.L1_O_BAS.IFBLFFPD v -- Tabella dei parametri
        ON b.CLASSE_RISCHIO = v.PD_CLASSE_RISCHIO
)
-- ── SEZIONE CCF / K ──────────────────────────────────────────

-- CCF_001 | CCF_001 INPUT | CA
-- IM_FIDO12: no NULL, no negativi
, CCF_001 AS (
    SELECT 'CCF_001',
           'CCF - IM_FIDO12: non sono ammessi valori NULL o negativi',
           {{ check_not_negative('IM_FIDO_12') }},
           'CA' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
    WHERE PROVENIENZA = 'CA'
)

-- CCF_002 | CCF_001 INPUT | CA
-- DISPONIBILE_NOUTI: no NULL, no negativi
, CCF_002 AS (
    SELECT 'CCF_002',
           'CCF - DISPONIBILE_NOUTI: non sono ammessi valori NULL o negativi',
           {{ check_not_negative('DISPONIBILE_NOUTI') }},
           'CA' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
    WHERE PROVENIENZA = 'CA'
)

-- CCF_003 | CCF_001 INPUT | CA
-- Delta CM_CRLMT - CMAVCRED: non può essere NULL o zero
, CCF_003 AS (
    SELECT 'CCF_003',
           'CCF - Delta (CM_CRLMT - CMAVCRED): non può essere NULL o zero',
           COUNT_IF(CM_CRLMT IS NULL OR CMAVCRED IS NULL OR (CM_CRLMT - CMAVCRED) = 0),
           'CA' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
    WHERE PROVENIENZA = 'CA'
)

-- CCF_004 | CCF_001 CALC | CA
-- CCF_MARGIN_TO_DRAWN: P_1..P_5 se PD_TYPE= CPA e TREATMENT =  CCF; null altrimenti

, CCF_004 AS (
    SELECT 'CCF_004',
           'CCF_MARGIN_TO_DRAWN: valori ammessi P_1..P_5 se PD_TYPE=CPA e TREATMENT=CCF; deve essere NULL altrimenti',
           
    COUNT_IF(
        (PD_TYPE = 'CPA'
            AND TREATMENT = 'CCF'
            AND (CCF_MARGIN_TO_DRAWN IS NULL
                 OR CCF_MARGIN_TO_DRAWN NOT IN (
                     'P_1', 'P_2', 'P_3', 'P_4', 'P_5'
                 )))
        OR (
            (PD_TYPE <> 'CPA' OR TREATMENT <> 'CCF')
            AND CCF_MARGIN_TO_DRAWN IS NOT NULL
        )
    )
,
           'CA' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
    WHERE PROVENIENZA = 'CA'
)


-- CCF_005 | CCF_002 CALC | CA
-- CCF_MAX_BTW_LIMIT_ONB: P_1..P_5 se CPA
, CCF_005 AS (
    SELECT 'CCF_005',
           'CCF_MAX_BTW_LIMIT_ONB: valori ammessi P_1..P_5 se PD_TYPE=CPA e TREATMENT = CCF; deve essere NULL altrimenti',
           
    COUNT_IF(
        (PD_TYPE = 'CPA'
        AND TREATMENT = 'CCF'
            AND (CCF_MAX_BTW_LIMIT_ONB IS NULL
                 OR CCF_MAX_BTW_LIMIT_ONB NOT IN (
                     'P_1', 'P_2', 'P_3', 'P_4', 'P_5'
                 )))
        OR (
            (PD_TYPE <> 'CPA' OR TREATMENT <> 'CCF')
            AND CCF_MAX_BTW_LIMIT_ONB IS NOT NULL
        )
    )

   
,
           'CA' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
    WHERE PROVENIENZA = 'CA'
)

-- CCF_006 | CCF_003 CALC | CA
-- CCF_MARGIN: P_1..P_8 se NPA
, CCF_006 AS (
    SELECT 'CCF_006',
           'CCF_MARGIN: valori ammessi P_1..P_8 se PD_TYPE=NPA e TREATMENT =CCF ; deve essere NULL altrimenti',
           
    COUNT_IF(
        (PD_TYPE = 'NPA'
        AND TREATMENT = 'CCF'
            AND (CCF_MARGIN IS NULL
                 OR CCF_MARGIN NOT IN (
                     'P_1', 'P_2', 'P_3', 'P_4', 'P_5', 'P_6', 'P_7', 'P_8'
                 )))
     
        OR (
            (PD_TYPE <> 'NPA' OR TREATMENT <> 'CCF')
            AND CCF_MARGIN IS NOT NULL
        )
    )
,
           'CA' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
    WHERE PROVENIENZA = 'CA'
)

-- CCF_007 | CCF_004 INPUT | CA
-- IM_FIDO_1..12: no NULL, no negativi su tutti i 12 mesi
, CCF_007 AS (
    SELECT 'CCF_007',
           'CCF - IM_FIDO_1..12: non sono ammessi valori NULL o negativi su nessuno dei 12 mesi',
           {{ check_not_negative_multi([
               'IM_FIDO_1','IM_FIDO_2','IM_FIDO_3','IM_FIDO_4',
               'IM_FIDO_5','IM_FIDO_6','IM_FIDO_7','IM_FIDO_8',
               'IM_FIDO_9','IM_FIDO_10','IM_FIDO_11','IM_FIDO_12'
             ]) }},
           'CA' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
    WHERE PROVENIENZA = 'CA'
)

-- CCF_008 | CCF_004 CALC | CA
-- CCF_DELTA_LIMIT_12M: P_1..P_4 se NPA/CPA e TREATMENT = CCF
, CCF_008 AS (
    SELECT 'CCF_008',
           'CCF_DELTA_LIMIT_12M: valori ammessi P_1..P_4 se PD_TYPE in (NPA,CPA) e TREATMENT = CCF; deve essere NULL altrimenti',
              COUNT_IF(
        (PD_TYPE IN (
                'NPA', 'CPA'
            ) 
            AND TREATMENT = 'CCF'
            AND (CCF_DELTA_LIMIT_12M IS NULL
                 OR CCF_DELTA_LIMIT_12M NOT IN (
                     'P_1', 'P_2', 'P_3', 'P_4'
                 )))
            OR (
            (PD_TYPE NOT IN (
                'NPA', 'CPA'
            ) OR TREATMENT <> 'CCF')
            AND CCF_DELTA_LIMIT_12M IS NOT NULL
        )
    )
,
           'CA' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
    WHERE PROVENIENZA = 'CA'
)

-- CCF_009 | CCF_004 CALC | CA
-- K_DELTA_LIMIT_12M: P_1..P_4 se NPA & TREATMENT = K factor;; P_1..P_5 se CPA
, CCF_009 AS (
    SELECT 'CCF_009',
           'K_DELTA_LIMIT_12M: P_1..P_4 se PD_TYPE = NPA  & TREATMENT = K factor; P_1..P_5 se PD_TYPE =  CPA; NULL altrimenti',
           COUNT_IF(
            (PD_TYPE = 'NPA' 
             AND TREATMENT = 'K factor'
                AND (K_DELTA_LIMIT_12M IS NULL
                    OR K_DELTA_LIMIT_12M NOT IN ('P_1','P_2','P_3','P_4')))
            OR (PD_TYPE = 'CPA'
                AND (K_DELTA_LIMIT_12M IS NULL
                    OR K_DELTA_LIMIT_12M NOT IN ('P_1','P_2','P_3','P_4','P_5')))
            OR ( (PD_TYPE NOT IN ('NPA','CPA') OR TREATMENT <> 'K factor' )
                AND K_DELTA_LIMIT_12M IS NOT NULL)
    ),
           'CA' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
    WHERE PROVENIENZA = 'CA'
)

-- CCF_010 | CCF_005 INPUT | CA
-- IM_IMPIEGHI1..12: no NULL, no negativi su tutti i 12 mesi
, CCF_010 AS (
    SELECT 'CCF_010',
           'CCF - IM_IMPIEGHI1..12: non sono ammessi valori NULL o negativi su nessuno dei 12 mesi',
           {{ check_not_negative_multi([
               'IM_IMPIEGHI0','IM_IMPIEGHI1','IM_IMPIEGHI2','IM_IMPIEGHI3','IM_IMPIEGHI4',
               'IM_IMPIEGHI5','IM_IMPIEGHI6','IM_IMPIEGHI7','IM_IMPIEGHI8',
               'IM_IMPIEGHI9','IM_IMPIEGHI10','IM_IMPIEGHI11'
             ]) }},
           'CA' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
    WHERE PROVENIENZA = 'CA'
)

-- CCF_011 | CCF_005 CALC | CA
-- K_MAX_UTIL_RATE_6M: P_1..P_4 se NPA & TREATMENT = K factor
, CCF_011 AS (
    SELECT 'CCF_011',
           'K_MAX_UTIL_RATE_6M: valori ammessi P_1..P_4 se PD_TYPE=NPA & TREATMENT = K factor; deve essere NULL altrimenti',
           
    COUNT_IF(
        (PD_TYPE = 'NPA'
        AND TREATMENT = 'K factor'
            AND (K_MAX_UTIL_RATE_6M IS NULL
                 OR K_MAX_UTIL_RATE_6M NOT IN (
                     'P_1', 'P_2', 'P_3', 'P_4'
                 )))
        OR (
            (PD_TYPE <> 'NPA' OR  TREATMENT <> 'K factor' )
            AND K_MAX_UTIL_RATE_6M IS NOT NULL)
    )
,
           'CA' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
    WHERE PROVENIENZA = 'CA'
)


-- CCF_012 | CCF_006 CALC | CA
-- CD_CLUSTER_CCF: valori per CPA/NPA & TREATMENT = CCF
, CCF_012 AS (
    SELECT 'CCF_012',
           'CD_CLUSTER_CCF: valori ammessi per CPA (LEAF 4-0..10-5) e NPA (LEAF 3-0..10-5) & TREATMENT = CCF; NULL altrimenti',
           COUNT_IF(
               (PD_TYPE = 'CPA' AND TREATMENT = 'CCF' AND (CD_CLUSTER_CCF IS NULL OR CD_CLUSTER_CCF NOT IN ('5','1','6','2','3','4')))
            OR (PD_TYPE = 'NPA' AND TREATMENT = 'CCF' AND (CD_CLUSTER_CCF IS NULL OR CD_CLUSTER_CCF NOT IN ('5','3','6','2','1','4')))
            OR ((PD_TYPE NOT IN ('CPA','NPA') OR  TREATMENT <> 'CCF') AND CD_CLUSTER_CCF IS NOT NULL)
           ),
           'CA' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
    WHERE PROVENIENZA = 'CA'
)



-- CCF_013 | CCF_007 CALC | CA
-- CD_CLUSTER_K: valori per CPA/NPA
, CCF_013 AS (
    SELECT 'CCF_013',
           'CD_CLUSTER_K: CPA ammesso LEAF 1-0/1-1 TREATMENT = K factor; NPA ammesso LEAF 3-0/4-1/5-2/6-3 TREATMENT = K factor; NULL altrimenti',
           COUNT_IF(
               (PD_TYPE = 'CPA' AND TREATMENT = 'K factor' AND (CD_CLUSTER_K IS NULL OR CD_CLUSTER_K NOT IN ('1','2')))
            OR (PD_TYPE = 'NPA' AND TREATMENT = 'K factor' AND (CD_CLUSTER_K IS NULL OR CD_CLUSTER_K NOT IN ('1','2','3','4')))
            OR ( (PD_TYPE NOT IN ('CPA','NPA') OR  TREATMENT <> 'K factor' ) AND CD_CLUSTER_K IS NOT NULL)
           ),
           'CA' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
    WHERE PROVENIENZA = 'CA'
)

-- CCF_014 | CCF_008 CALC | CA
-- se TREATMENT = CCF allora PC_CCF: non sono ammessi valori NULL o negativi
, CCF_014 AS (
    SELECT 'CCF_014',
           'se TREATMENT = CCF allora PC_CCF: non sono ammessi valori NULL o negativi', 
          COUNT_IF( TREATMENT = 'CCF' AND  PC_CCF IS NULL OR PC_CCF < 0)
,
           'CA' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
    WHERE PROVENIENZA = 'CA'
)

-- CCF_015 | CCF_009 CALC | CA
-- se TREATMENT = K factor allora PC_K: no NULL, no negativi
, CCF_015 AS (
    SELECT 'CCF_015',
           'se TREATMENT = K factor allora PC_K: non sono ammessi valori NULL o negativi',
          COUNT_IF(TREATMENT = 'K factor' AND PC_K IS NULL OR PC_K < 0),
           'CA' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
    WHERE PROVENIENZA = 'CA'
)

-- CCF_016 | CCF_010 | CA
-- PC_CCF: deve essere NULL se TREATMENT <> 'CCF'
, CCF_016 AS (
    SELECT 'CCF_016',
           'PC_CCF: deve essere NULL quando TREATMENT <> CCF',
           {{ check_missing_if_not('PC_CCF', 'TREATMENT', 'CCF') }},
           'CA' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
    WHERE PROVENIENZA = 'CA'
)

-- CCF_017 | CCF_011 | CA
-- PC_K: deve essere NULL se TREATMENT <> 'K Factor'
, CCF_017 AS (
    SELECT 'CCF_017',
           'PC_K: deve essere NULL quando TREATMENT <> K factor',
           {{ check_missing_if_not('PC_K', 'TREATMENT', 'K factor') }},   --To Do: controllare quando ci arrivano i dati la stringa esatta(case sensitivity)
           'CA' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
    WHERE PROVENIENZA = 'CA'
)

-- ── SEZIONE LGD / ELBE ───────────────────────────────────────

-- LGD_001 | LGD_001 INPUT | CO
-- IMFINANZ: no NULL, no negativi
, LGD_001 AS (
    SELECT 'LGD_001',
           'LGD - IMFINANZ: non sono ammessi valori NULL o negativi',
           {{ check_not_negative('IMFINANZ') }},
           'CO' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
    WHERE PROVENIENZA = 'CO'
)

-- LGD_002 | LGD_001 INPUT | CO
-- E_ONB: no NULL, no negativi
, LGD_002 AS (
    SELECT 'LGD_002',
           'LGD - E_ONB: non sono ammessi valori NULL o negativi',
           {{ check_not_negative('E_ONB') }},
           'CO;CA' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
    --WHERE PROVENIENZA = 'CO'
)

-- LGD_003 | LGD_002 INPUT | CO;CA
-- CONTRACT_NUM: no NULL, no negativi
, LGD_003 AS (
    SELECT 'LGD_003',
           'LGD - CONTRACT_NUM: non sono ammessi valori NULL o negativi',
           {{ check_not_negative('CONTRACT_NUM') }},
           'CO;CA' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
  --  WHERE PROVENIENZA = 'CO'
)

-- LGD_004 | LGD_003 INPUT | CO
-- REGIONE: no NULL, no stringa vuota
, LGD_004 AS (
    SELECT 'LGD_004',
           'LGD - REGIONE: non sono ammessi valori NULL o stringa vuota',
           COUNT_IF(REGIONE IS NULL OR TRIM(REGIONE) = ''),
           'CO;CA' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
    --WHERE PROVENIENZA = 'CO'
)

-- LGD_005 | LGD_004 INPUT | CO
-- DATA_CARICAMENTO: no NULL (DATA_CARICAMENTO_V2 non presente in OCS, mappato su DATA_CARICAMENTO)
, LGD_005 AS (
    SELECT 'LGD_005',
           'LGD - DATA_CARICAMENTO: non sono ammessi valori NULL (DATA_CARICAMENTO_V2 mappato su DATA_CARICAMENTO)',
           {{ check_not_null('DATA_CARICAMENTO') }},
           'CO' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
    WHERE PROVENIENZA = 'CO'
)

-- LGD_006 | LGD_004 CALC | CO
-- ANZ_ABITATIVA_MESI: no NULL, no negativi
, LGD_006 AS (
    SELECT 'LGD_006',
           'LGD - ANZ_ABITATIVA_MESI: non sono ammessi valori NULL o negativi',
           {{ check_not_negative('ANZ_ABITATIVA_MESI') }},
           'CO' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
    WHERE PROVENIENZA = 'CO'
)

-- LGD_007 | LGD_005 CALC | CO;CA
-- CD_CLUSTER_LGD: valori 1-3 per PPP/CPA/PPB; 1-2 per VEH/STF/NPA
, LGD_007 AS (
    SELECT 'LGD_007',
           'CD_CLUSTER_LGD: valori 1-3 per LGD_TYPE in (PPP,CPA,PPB); valori 1-2 per (VEH,STF,NPA); NULL altrimenti',
           COUNT_IF(
               (LGD_TYPE IN ('PPP','CPA','PPB')  AND (CD_CLUSTER_LGD IS NULL OR CD_CLUSTER_LGD NOT IN (1,2,3)))
            OR (LGD_TYPE IN ('VEH','STF','NPA') AND (CD_CLUSTER_LGD IS NULL OR CD_CLUSTER_LGD NOT IN (1,2)))
            OR (LGD_TYPE NOT IN ('PPP','CPA','PPB','VEH','STF','NPA') AND CD_CLUSTER_LGD IS NOT NULL)
           ),
           'CO;CA' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
    --WHERE PROVENIENZA = 'CO' 
)

-- LGD_008 | LGD_006 | CO
-- LGD_SCORE: deve essere NOT NULL se CD_CLUSTER_LGD è valorizzato
, LGD_008 AS (
    SELECT 'LGD_008',
           'LGD - Coerenza: LGD_SCORE deve essere valorizzato se CD_CLUSTER_LGD è presente',
           {{ check_present_if_not_null('LGD_SCORE', 'CD_CLUSTER_LGD') }},
           'CO;CA' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
    --WHERE PROVENIENZA = 'CO'
)



-- LGD_009 | LGD_009 CALC | CO + CA
-- CD_CLUSTER_ELBE: valori ammessi 1 o 2 se IN_DEFAULT = S
, LGD_009 AS (
    SELECT 'LGD_009',
           'CD_CLUSTER_ELBE: valori ammessi solo 1 o 2 (quando presente, ovvero quando IN_DEFAULT = S)',
           COUNT_IF( IN_DEFAULT = 'S' AND (CD_CLUSTER_ELBE IS NULL OR CD_CLUSTER_ELBE NOT IN (1,2))),
           'CO;CA' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
    --WHERE PROVENIENZA = 'CO'
)


-- LGD_010 | LGD_010 | CO
-- ELBE_SCORE: NOT NULL se CD_CLUSTER_ELBE presente e IN_DEFAULT=S
, LGD_010 AS (
    SELECT 'LGD_010',
           'ELBE - Coerenza LGDD: ELBE_SCORE deve essere valorizzato se CD_CLUSTER_ELBE presente e IN_DEFAULT=S',
           COUNT_IF(CD_CLUSTER_ELBE IS NOT NULL AND IN_DEFAULT = 'S' AND ELBE_SCORE IS NULL),
           'CO' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
    WHERE PROVENIENZA = 'CO'
)

-- LGD_011 | LGD_011 | CO
-- ELBE_CLASSE_RISC: NOT NULL se ELBE_SCORE è valorizzato
, LGD_011 AS (
    SELECT 'LGD_011',
           'ELBE - Coerenza: ELBE_CLASSE_RISC deve essere valorizzata se ELBE_SCORE è presente',
           {{ check_present_if_not_null('ELBE_CLASSE_RISC', 'ELBE_SCORE') }},
           'CO' AS TP_PROC_ESECUZIONE_CONTROLLO
    FROM base
    WHERE PROVENIENZA = 'CO'
)

-- ============================================================
-- STEP 4: UNION FINALE + ESITO
-- ============================================================
, all_checks AS (
    SELECT * FROM PD_001  UNION ALL SELECT * FROM PD_002  UNION ALL SELECT * FROM PD_003
    UNION ALL SELECT * FROM PD_004  UNION ALL SELECT * FROM PD_005  UNION ALL SELECT * FROM PD_006
    UNION ALL SELECT * FROM PD_007  UNION ALL SELECT * FROM PD_008  UNION ALL SELECT * FROM PD_009
    UNION ALL SELECT * FROM PD_010  UNION ALL SELECT * FROM PD_011  UNION ALL SELECT * FROM PD_012
    UNION ALL SELECT * FROM PD_013  UNION ALL SELECT * FROM PD_014  UNION ALL SELECT * FROM PD_015
    UNION ALL SELECT * FROM PD_016  UNION ALL SELECT * FROM PD_017  UNION ALL SELECT * FROM PD_018
    UNION ALL SELECT * FROM PD_019  UNION ALL SELECT * FROM PD_020  UNION ALL SELECT * FROM PD_021
    UNION ALL SELECT * FROM PD_022  UNION ALL SELECT * FROM PD_023  UNION ALL SELECT * FROM PD_024
    UNION ALL SELECT * FROM PD_025  UNION ALL SELECT * FROM PD_026  UNION ALL SELECT * FROM PD_027
    UNION ALL SELECT * FROM PD_028  UNION ALL SELECT * FROM PD_029  UNION ALL SELECT * FROM PD_030
    UNION ALL SELECT * FROM PD_031  UNION ALL SELECT * FROM PD_032  UNION ALL SELECT * FROM PD_033
    UNION ALL SELECT * FROM PD_034  UNION ALL SELECT * FROM PD_035  UNION ALL SELECT * FROM PD_036
    UNION ALL SELECT * FROM PD_037  UNION ALL SELECT * FROM PD_038  UNION ALL SELECT * FROM PD_039
    UNION ALL SELECT * FROM PD_040  UNION ALL SELECT * FROM PD_041  UNION ALL SELECT * FROM PD_042
    UNION ALL SELECT * FROM PD_043  UNION ALL SELECT * FROM PD_044  UNION ALL SELECT * FROM PD_045
    UNION ALL SELECT * FROM PD_046  UNION ALL SELECT * FROM PD_047  UNION ALL SELECT * FROM PD_048
    UNION ALL SELECT * FROM PD_049  UNION ALL SELECT * FROM PD_050  UNION ALL SELECT * FROM PD_051
    UNION ALL SELECT * FROM PD_052  UNION ALL SELECT * FROM PD_053  UNION ALL SELECT * FROM PD_054
    UNION ALL SELECT * FROM PD_055  UNION ALL SELECT * FROM PD_056  UNION ALL SELECT * FROM PD_057
    UNION ALL SELECT * FROM PD_058  UNION ALL SELECT * FROM PD_059  UNION ALL SELECT * FROM PD_060
    UNION ALL SELECT * FROM PD_061  UNION ALL SELECT * FROM PD_062
    UNION ALL SELECT * FROM CCF_001 UNION ALL SELECT * FROM CCF_002 UNION ALL SELECT * FROM CCF_003
    UNION ALL SELECT * FROM CCF_004 UNION ALL SELECT * FROM CCF_005 UNION ALL SELECT * FROM CCF_006
    UNION ALL SELECT * FROM CCF_007 UNION ALL SELECT * FROM CCF_008 UNION ALL SELECT * FROM CCF_009
    UNION ALL SELECT * FROM CCF_010 UNION ALL SELECT * FROM CCF_011 UNION ALL SELECT * FROM CCF_012
    UNION ALL SELECT * FROM CCF_013 UNION ALL SELECT * FROM CCF_014 UNION ALL SELECT * FROM CCF_015
    UNION ALL SELECT * FROM CCF_016 UNION ALL SELECT * FROM CCF_017
    UNION ALL SELECT * FROM LGD_001 UNION ALL SELECT * FROM LGD_002 UNION ALL SELECT * FROM LGD_003
    UNION ALL SELECT * FROM LGD_004 UNION ALL SELECT * FROM LGD_005 UNION ALL SELECT * FROM LGD_006
    UNION ALL SELECT * FROM LGD_007 UNION ALL SELECT * FROM LGD_008
    UNION ALL SELECT * FROM LGD_009
    UNION ALL SELECT * FROM LGD_010 UNION ALL SELECT * FROM LGD_011
)

SELECT
    $1                                                              AS CD_CONTROLLO,
    $2                                                              AS DS_CONTROLLO,
  TO_DATE( '{{ DATA_ESTRAZIONE }}' )                                           AS DT_CONTROLLO,
 $4                                                            AS TP_PROC_ESECUZIONE_CONTROLLO,
    CASE
--        WHEN col1 IN ('LGD_010','LGD_011') THEN 'N/A'
        WHEN $3 = 0                    THEN 'OK'
        ELSE                                  'KO'
    END                                                             AS CD_STATO,
    $3                                                               AS NM_RECORD_KO,
   TRY_CAST('{{ run_started_at }}' AS TIMESTAMP_NTZ)            AS TS_CARICAMENTO                                               
FROM all_checks
ORDER BY CD_CONTROLLO

