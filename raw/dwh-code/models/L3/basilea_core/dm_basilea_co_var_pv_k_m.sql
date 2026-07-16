{% set nm_manual_adj_query %}
    SELECT NM_MANUAL_ADJ
    FROM {{ env_var('DBT_DATABASE') }}.TECH.MANUAL_ADJUSTMENT_O
    WHERE CD_MANUAL_ADJ = 'ADN'
      AND TS_FINE_VALIDITA = {{ custom_to_date("'99991231'") }}
    LIMIT 1
{% endset %}

{% if execute %}
    {% set nm_manual_adj_result = run_query(nm_manual_adj_query) %}
    {% set NM_MANUAL_ADJ = nm_manual_adj_result.columns[0].values()[0] %}
{% else %}
    {% set NM_MANUAL_ADJ = 1 %}
{% endif %}

WITH BASE AS (
    SELECT
        
        cc.PVKCO_DATA_ESTRAZIONE                                                            AS DT_ESTRAZIONE,

        
        CAST(cc.PVKCO_PROVENIENZA   AS VARCHAR(2))                                          AS CD_PROVENIENZA,
        CAST(cc.PVKCO_DSC_RAGSET    AS VARCHAR(5))                                          AS DS_RAGSET,
        CAST(cc.PVKCO_CD_PRVN_INFO  AS VARCHAR(2))                                          AS CD_PRVN_INFO,
        CAST(cc.PVKCO_FILIALE       AS VARCHAR(3))                                          AS CD_FILIALE,
        CAST(cc.PVKCO_SUBPTF        AS VARCHAR(30))                                         AS TP_SUBPTF,
        CAST(cc.PVKCO_IN_DEFAULT    AS VARCHAR(1))                                          AS FL_DEFAULT,
        CAST(cc.PVKCO_FL_SME        AS VARCHAR(1))                                          AS FL_SME,
        CAST(cc.PVKCO_DSGRIGLIA     AS VARCHAR(30))                                         AS DS_GRIGLIA,
        CAST(cc.PVKCO_PD_TYPE       AS VARCHAR(3))                                          AS TP_PD_TYPE,
        CAST(cc.PVKCO_PD_DSC_SCORE  AS VARCHAR(60))                                         AS DS_PD_DSC_SCORE,
        CAST(cc.PVKCO_LGD_TYPE      AS VARCHAR(3))                                          AS TP_LGD_TYPE,
        CAST(cc.PVKCO_LGD_DSC_SCORE AS VARCHAR(60))                                         AS DS_LGD_DSC_SCORE,
        CAST(cc.PVKCO_ELBE_TYPE     AS VARCHAR(3))                                          AS TP_ELBE_TYPE,
        CAST(cc.PVKCO_ELBE_DSC_SCORE AS VARCHAR(60))                                        AS DS_ELBE_DSC_SCORE,
        CAST(cc.PVKCO_CDSECUR       AS VARCHAR(2))                                          AS CD_SECUR,
        CASE WHEN l.FL_SRT = 'Y' THEN 'Y' ELSE 'N' END                                     AS FL_SRT,
        CAST(cc.PVKCO_PRATICA           AS NUMBER(12,0))                                    AS CD_PRATICA,
        CAST(cc.PVKCO_SOCIETA           AS NUMBER(5,0))                                     AS CD_SOCIETA,
        CAST(cc.PVKCO_CO_RE             AS NUMBER(1,0))                                     AS TP_CO_RE,
        CAST(cc.PVKCO_CD_NDG_CLIENTE    AS NUMBER(9,0))                                     AS CD_NDG_CLIENTE,
        CAST(cc.PVKCO_CD_NDG_MST        AS NUMBER(9,0))                                     AS CD_NDG_MST,
        CAST(cc.PVKCO_CLASSE_RISCHIO    AS NUMBER(3,0))                                     AS TP_CLASSE_RISCHIO,
        CAST(cc.PVKCO_CLASSE_RISCHIO_PRT AS NUMBER(3,0))                                    AS TP_CLASSE_RISCHIO_PRT,
        CAST(cc.PVKCO_GG_SCAD           AS NUMBER(5,0))                                     AS NM_GG_SCAD,
        CAST(cc.PVKCO_PD_TOT            AS NUMBER(4,0))                                     AS NM_PD_TOT,
        CAST(cc.PVKCO_PD_TOT_PRT        AS NUMBER(4,0))                                     AS NM_PD_TOT_PRT,
        CAST(cc.PVKCO_LGD_CLASSE_RISC   AS NUMBER(3,0))                                     AS TP_LGD_CLASSE_RISC,
        CAST(cc.PVKCO_CD_CLUSTER_LGD    AS NUMBER(2,0))                                     AS TP_CLUSTER_LGD,
        CAST(cc.PVKCO_MESI_ELBE         AS NUMBER(5,0))                                     AS NM_MESI_ELBE,
        CAST(cc.PVKCO_NM_MM_ELBE        AS NUMBER(5,0))                                     AS NM_MM_ELBE,
        CAST(cc.PVKCO_ELBE_CLASSE_RISC  AS NUMBER(3,0))                                     AS NM_ELBE_CLASSE_RISC,
        CAST(cc.PVKCO_CD_CLUSTER_ELBE   AS NUMBER(2,0))                                     AS TP_CLUSTER_ELBE,
        CAST(cc.PVKCO_SOC_SECUR         AS NUMBER(9,0))                                     AS CD_SOC_SECUR,
        cc.PVKCO_DT_INGRS_DFLT_EBA                                                         AS DATA_INGRS_DFLT_EBA,
        CAST( {{ custom_to_decimal('cc.PVKCO_DISPONIBILE_NOUTI', precision=13, decimal=2) }} AS NUMBER(13,2))  AS EU_DISPONIBILE_NOUTI,
        CAST( {{ custom_to_decimal('cc.PVKCO_EU_IMPIEGO_SALDO',  precision=13, decimal=2) }} AS NUMBER(13,2))  AS EU_IMPIEGO_SALDO,
        CAST( {{ custom_to_decimal('cc.PVKCO_IM_IMPIEGHI',       precision=13, decimal=2) }} AS NUMBER(13,2))  AS EU_IMPIEGHI,
        CAST( {{ custom_to_decimal('cc.PVKCO_IM_RATEO',          precision=13, decimal=2) }} AS NUMBER(13,2))  AS EU_RATEO,
        CAST( {{ custom_to_decimal('cc.PVKCO_IM_RISCONTO',       precision=13, decimal=2) }} AS NUMBER(13,2))  AS EU_RISCONTO,
        CAST( {{ custom_to_decimal('cc.PVKCO_EU_LATE_FEES',      precision=13, decimal=2) }} AS NUMBER(13,2))  AS EU_LATE_FEES,
        CAST( {{ custom_to_decimal('cc.PVKCO_EU_MORA',           precision=13, decimal=2) }} AS NUMBER(13,2))  AS EU_MORA,
        CAST( {{ custom_to_decimal('cc.PVKCO_PD',                 precision=13, decimal=10) }} AS NUMBER(13,10)) AS NM_PD,
        CAST( {{ custom_to_decimal('cc.PVKCO_PD_FLOOR',           precision=13, decimal=10) }} AS NUMBER(13,10)) AS NM_PD_FLOOR,
        CAST( {{ custom_to_decimal('cc.PVKCO_PD_SCORE',           precision=13, decimal=10) }} AS NUMBER(13,10)) AS PC_PD_SCORE,
        CAST( {{ custom_to_decimal('cc.PVKCO_PD_SCORE_FLOOR',     precision=13, decimal=10) }} AS NUMBER(13,10)) AS PC_PD_SCORE_FLOOR,
        CAST( {{ custom_to_decimal('cc.PVKCO_PD_SCORE_PRT',       precision=13, decimal=10) }} AS NUMBER(13,10)) AS PC_PD_SCORE_PRT,
        CAST( {{ custom_to_decimal('cc.PVKCO_PD_SCORE_FLOOR_PRT', precision=13, decimal=10) }} AS NUMBER(13,10)) AS PC_PD_SCORE_FLOOR_PRT,
        CAST( {{ custom_to_decimal('cc.PVKCO_LGD',                precision=13, decimal=10) }} AS NUMBER(13,10)) AS NM_LGD,
        CAST( {{ custom_to_decimal('cc.PVKCO_LGD_FLOOR',          precision=13, decimal=10) }} AS NUMBER(13,10)) AS NM_LGD_FLOOR,
        CAST( {{ custom_to_decimal('cc.PVKCO_LGD_SCORE',          precision=13, decimal=10) }} AS NUMBER(13,10)) AS PC_LGD_SCORE,
        CAST( {{ custom_to_decimal('cc.PVKCO_LGD_SCORE_FLOOR',    precision=13, decimal=10) }} AS NUMBER(13,10)) AS PC_LGD_SCORE_FLOOR,
        CAST( {{ custom_to_decimal('cc.PVKCO_ELBE',               precision=13, decimal=10) }} AS NUMBER(13,10)) AS NM_ELBE,
        CAST( {{ custom_to_decimal('cc.PVKCO_ELBE_SCORE',         precision=13, decimal=10) }} AS NUMBER(13,10)) AS PC_ELBE_SCORE,
        CAST( {{ custom_to_decimal('cc.PVKCO_SUPPORTING_FACTOR',  precision=13, decimal=10) }} AS NUMBER(13,10)) AS NM_SUPPORTING_FACTOR,
        CAST( {{ custom_to_decimal('cc.PVKCO_EAD_STIMATA',        precision=13, decimal=2) }}  AS NUMBER(13,2))  AS EAD_STIMATA,
        CAST( {{ custom_to_decimal('cc.PVKCO_EAD_STIMATA_FLOOR',  precision=13, decimal=2) }}  AS NUMBER(13,2))  AS EAD_STIMATA_FLOOR,
        CAST( {{ custom_to_decimal('cc.PVKCO_PERDITA_ATTESA',       precision=13, decimal=2) }} AS NUMBER(13,2))  AS EU_EL_GROSS_SRT,
        CAST( {{ custom_to_decimal('cc.PVKCO_PERDITA_ATTESA_FLOOR', precision=13, decimal=2) }} AS NUMBER(13,2))  AS EU_EL_FLOOR_GROSS_SRT

    FROM {{ env_var('DBT_DATABASE') }}.L1_O_BAS.IFBLFPVKCO_TEST AS cc
    LEFT JOIN {{ env_var('DBT_DATABASE') }}.TECH.LOOKUP_SRT_O AS l
        ON cc.PVKCO_CDSECUR = l.CD_SECUR
        -- da aggiungere condizione sulla data di osservazione nella lookup per ricavare le pratiche SRT più recenti, questo dipenderà dalla storicizzazione della tabella. 
    WHERE cc.PVKCO_DATA_ESTRAZIONE = LAST_DAY(DATEADD(MONTH, -4, CURRENT_DATE()))
),


cte_corr AS (
    SELECT
        cc.*,
        CASE
            WHEN CC.NM_PD_FLOOR <> 1
            THEN   0.03 * (1 - EXP(-35 * cc.NM_PD_FLOOR)) / (1 - EXP(-35))
                 + 0.16 * (1 - (1 - EXP(-35 * cc.NM_PD_FLOOR)) / (1 - EXP(-35)))
            ELSE NULL
        END AS CORR_CALC,
        DATEDIFF('MONTH', pm.DT_PRIMA_SCADENZA, cc.DT_ESTRAZIONE) AS NM_ANZIANITA_PRATICA
    FROM BASE AS cc
    LEFT JOIN {{ ref('pratica_m') }} AS pm 
        ON cc.CD_PRATICA = pm.CD_PRATICA
       AND cc.CD_PROVENIENZA = pm.TP_PROCEDURA
       AND cc.DT_ESTRAZIONE = pm.DT_OSSERVAZIONE
),


cte_cap AS (
    SELECT
        cc.*,
        CORR_CALC AS EU_CORRELATION,
        CASE
            WHEN CC.NM_PD_FLOOR <> 1
            THEN NM_LGD_FLOOR * {{ env_var('DBT_DATABASE') }}.TECH.PROBNORM(
                     POWER(1 - cc.CORR_CALC, -0.5) * {{ env_var('DBT_DATABASE') }}.TECH.PROBIT(cc.NM_PD_FLOOR)
                   + POWER(cc.CORR_CALC / (1 - cc.CORR_CALC), 0.5) * {{ env_var('DBT_DATABASE') }}.TECH.PROBIT(0.999)
                 ) - cc.NM_PD_FLOOR * cc.NM_LGD_FLOOR
            ELSE NULL
        END AS CAPITAL_REQUIREMENT,
        CASE
            WHEN NM_ANZIANITA_PRATICA < 0                                       THEN 'PDCF'
            WHEN NM_ANZIANITA_PRATICA >= 0 AND NM_ANZIANITA_PRATICA < 3         THEN 'PDCG'
            WHEN NM_ANZIANITA_PRATICA >= 3                                       THEN 'PDCM'
        END AS DS_PD_CLASSIFICAZIONE_ANZIANITA
    FROM cte_corr AS cc
), 


cte_calc AS (
    SELECT
        cc.*,
        CASE WHEN cc.FL_SRT <> 'Y' THEN cc.EAD_STIMATA       ELSE 0 END  AS EU_EAD_STIMATA,
        cc.EAD_STIMATA                                                     AS EU_EAD_GROSS_SRT,
        CASE WHEN cc.FL_SRT <> 'Y' THEN cc.EAD_STIMATA_FLOOR  ELSE 0 END  AS EU_EAD_STIMATA_FLOOR,
        cc.EAD_STIMATA_FLOOR                                               AS EU_EAD_FLOOR_GROSS_SRT,
        CASE WHEN cc.FL_SRT <> 'Y' THEN cc.EU_EL_GROSS_SRT     ELSE 0 END  AS EU_EL,
        CASE WHEN cc.FL_SRT <> 'Y' THEN cc.EU_EL_FLOOR_GROSS_SRT ELSE 0 END AS EU_EL_FLOOR,

        -- EU_RWA
        CASE
            WHEN cc.NM_PD_FLOOR <> 1 THEN
                CASE
                    WHEN cc.FL_SRT <> 'Y'
                    THEN cc.CAPITAL_REQUIREMENT * 12.5 * cc.EAD_STIMATA_FLOOR * cc.NM_SUPPORTING_FACTOR * {{ NM_MANUAL_ADJ }}
                    ELSE 0
                END
            ELSE GREATEST(0, 12.5 * (cc.PC_LGD_SCORE_FLOOR - cc.PC_ELBE_SCORE))
                 * {{ NM_MANUAL_ADJ }} / 100 * cc.EAD_STIMATA_FLOOR
        END AS EU_RWA,

        -- EU_RWA_GROSS_SRT
        CASE
            WHEN cc.NM_PD_FLOOR <> 1
            THEN cc.CAPITAL_REQUIREMENT * 12.5 * cc.EAD_STIMATA_FLOOR * cc.NM_SUPPORTING_FACTOR * {{ NM_MANUAL_ADJ }}
            ELSE GREATEST(0, 12.5 * (cc.PC_LGD_SCORE_FLOOR - cc.PC_ELBE_SCORE))
                 * {{ NM_MANUAL_ADJ }} / 100 * cc.EAD_STIMATA_FLOOR
        END AS EU_RWA_GROSS_SRT,

        -- EU_PV_IRB
        CASE
            WHEN cc.NM_PD_FLOOR <> 1 THEN
                CASE
                    WHEN cc.FL_SRT <> 'Y'
                    THEN cc.CAPITAL_REQUIREMENT * 12.5 * cc.EAD_STIMATA_FLOOR * cc.NM_SUPPORTING_FACTOR * {{ NM_MANUAL_ADJ }} * 0.08
                    ELSE 0
                END
            ELSE GREATEST(0, 12.5 * (cc.PC_LGD_SCORE_FLOOR - cc.PC_ELBE_SCORE))
                 * {{ NM_MANUAL_ADJ }} / 100 * cc.EAD_STIMATA_FLOOR * 0.08
        END AS EU_PV_IRB,

        -- EU_PV_IRB_GROSS_SRT
        CASE
            WHEN cc.NM_PD_FLOOR <> 1
            THEN cc.CAPITAL_REQUIREMENT * 12.5 * cc.EAD_STIMATA_FLOOR * cc.NM_SUPPORTING_FACTOR * {{ NM_MANUAL_ADJ }} * 0.08
            ELSE GREATEST(0, 12.5 * (cc.PC_LGD_SCORE_FLOOR - cc.PC_ELBE_SCORE))
                 * {{ NM_MANUAL_ADJ }} / 100 * cc.EAD_STIMATA_FLOOR * 0.08
        END AS EU_PV_IRB_GROSS_SRT,

        -- DS_STATUS_DEF_BASILEA
        CASE
            WHEN cc.FL_DEFAULT = 'S' THEN 'DEFAULT'
            WHEN cc.FL_DEFAULT = 'N' AND cc.DS_PD_CLASSIFICAZIONE_ANZIANITA = 'PDCF' AND cc.NM_GG_SCAD > 0              THEN 'SENSITIVE'
            WHEN cc.FL_DEFAULT = 'N' AND cc.DS_PD_CLASSIFICAZIONE_ANZIANITA = 'PDCF' AND (cc.NM_GG_SCAD = 0 OR cc.NM_GG_SCAD IS NULL) THEN 'SOUNDS'
            WHEN cc.FL_DEFAULT = 'N' AND cc.DS_PD_CLASSIFICAZIONE_ANZIANITA = 'PDCF'                                    THEN 'RECENTS'
            ELSE NULL
        END AS DS_STATUS_DEF_BASILEA
    FROM cte_cap AS cc
)


SELECT
    cc.DT_ESTRAZIONE                                            AS DT_ESTRAZIONE,
    cc.CD_PROVENIENZA                                           AS CD_PROVENIENZA,
    cc.CD_PRATICA                                               AS CD_PRATICA,
    cc.DS_RAGSET                                                AS DS_RAGSET,
    cc.CD_SOCIETA                                               AS CD_SOCIETA,
    cc.TP_CO_RE                                                 AS TP_CO_RE,
    cc.CD_PRVN_INFO                                             AS CD_PRVN_INFO,
    cc.CD_FILIALE                                               AS CD_FILIALE,
    cc.TP_SUBPTF                                                AS TP_SUBPTF,
    cc.CD_NDG_CLIENTE                                           AS CD_NDG_CLIENTE,
    cc.CD_NDG_MST                                               AS CD_NDG_MST,
    cc.TP_CLASSE_RISCHIO                                        AS TP_CLASSE_RISCHIO,
    cc.TP_CLASSE_RISCHIO_PRT                                    AS TP_CLASSE_RISCHIO_PRT,
    cc.FL_DEFAULT                                               AS FL_DEFAULT,
    cc.DATA_INGRS_DFLT_EBA                                        AS DT_INGRS_DFLT_EBA,
    cc.FL_SME                                                   AS FL_SME,
    cc.DS_GRIGLIA                                             AS DS_GRIGLIA,
    cc.EU_DISPONIBILE_NOUTI                                     AS EU_DISPONIBILE_NOUTI,
    cc.EU_IMPIEGO_SALDO                                         AS EU_IMPIEGO_SALDO,
    cc.EU_IMPIEGHI                                              AS EU_IMPIEGHI,
    cc.EU_RATEO                                                 AS EU_RATEO,
    cc.EU_RISCONTO                                              AS EU_RISCONTO,
    cc.EU_LATE_FEES                                             AS EU_LATE_FEES,
    cc.EU_MORA                                                  AS EU_MORA,
    cc.NM_GG_SCAD                                               AS NM_GG_SCAD,
    cc.NM_PD                                                    AS NM_PD,
    cc.NM_PD_FLOOR                                              AS NM_PD_FLOOR,
    cc.TP_PD_TYPE                                               AS TP_PD_TYPE,
    cc.NM_PD_TOT                                                AS NM_PD_TOT,
    cc.PC_PD_SCORE                                              AS PC_PD_SCORE,
    cc.PC_PD_SCORE_FLOOR                                        AS PC_PD_SCORE_FLOOR,
    cc.DS_PD_DSC_SCORE                                          AS DS_PD_DSC_SCORE,
    cc.NM_PD_TOT_PRT                                            AS NM_PD_TOT_PRT,
    cc.PC_PD_SCORE_PRT                                          AS PC_PD_SCORE_PRT,
    cc.PC_PD_SCORE_FLOOR_PRT                                    AS PC_PD_SCORE_FLOOR_PRT,
    cc.TP_LGD_CLASSE_RISC                                       AS TP_LGD_CLASSE_RISC,
    cc.TP_CLUSTER_LGD                                           AS TP_CLUSTER_LGD,
    cc.NM_LGD                                                   AS NM_LGD,
    cc.NM_LGD_FLOOR                                             AS NM_LGD_FLOOR,
    cc.TP_LGD_TYPE                                              AS TP_LGD_TYPE,
    cc.PC_LGD_SCORE                                             AS PC_LGD_SCORE,
    cc.PC_LGD_SCORE_FLOOR                                       AS PC_LGD_SCORE_FLOOR,
    cc.DS_LGD_DSC_SCORE                                         AS DS_LGD_DSC_SCORE,
    cc.NM_MESI_ELBE                                             AS NM_MESI_ELBE,
    cc.NM_MM_ELBE                                               AS NM_MM_ELBE,
    cc.NM_ELBE_CLASSE_RISC                                      AS NM_ELBE_CLASSE_RISC,
    cc.TP_CLUSTER_ELBE                                          AS TP_CLUSTER_ELBE,
    cc.TP_ELBE_TYPE                                             AS TP_ELBE_TYPE,
    cc.NM_ELBE                                                  AS NM_ELBE,
    cc.PC_ELBE_SCORE                                            AS PC_ELBE_SCORE,
    cc.DS_ELBE_DSC_SCORE                                        AS DS_ELBE_DSC_SCORE,
    cc.NM_SUPPORTING_FACTOR                                     AS NM_SUPPORTING_FACTOR,
    cc.CD_SECUR                                                 AS CD_SECUR,
    cc.CD_SOC_SECUR                                             AS CD_SOC_SECUR,
    cc.FL_SRT                                                   AS FL_SRT,
    cc.EU_EAD_STIMATA                                           AS EU_EAD_STIMATA,
    cc.EU_EAD_GROSS_SRT                                         AS EU_EAD_GROSS_SRT,
    cc.EU_EAD_STIMATA_FLOOR                                     AS EU_EAD_STIMATA_FLOOR,
    cc.EU_EAD_FLOOR_GROSS_SRT                                   AS EU_EAD_FLOOR_GROSS_SRT,
    CAST(cc.EU_EL               AS NUMBER(13,2))                AS EU_EL,
    CAST(cc.EU_EL_GROSS_SRT     AS NUMBER(13,2))                AS EU_EL_GROSS_SRT,
    CAST(cc.EU_EL_FLOOR         AS NUMBER(13,2))                AS EU_EL_FLOOR,
    CAST(cc.EU_EL_FLOOR_GROSS_SRT AS NUMBER(13,2))              AS EU_EL_FLOOR_GROSS_SRT,
    CAST(cc.EU_RWA              AS NUMBER(38,10))                AS EU_RWA,
    CAST(cc.EU_RWA_GROSS_SRT    AS NUMBER(38,10))               AS EU_RWA_GROSS_SRT,
    CAST(cc.EU_PV_IRB           AS NUMBER(38,10))               AS EU_PV_IRB,
    CAST(cc.EU_PV_IRB_GROSS_SRT AS NUMBER(38,10))               AS EU_PV_IRB_GROSS_SRT,
    CAST(cc.EU_CORRELATION      AS NUMBER(38,10))               AS EU_CORRELATION,
    CAST(cc.CAPITAL_REQUIREMENT AS NUMBER(38,10))               AS EU_CAPITAL_REQUIREMENT,
    CAST(cc.NM_ANZIANITA_PRATICA AS NUMBER(4,0))                AS NM_ANZIANITA_PRATICA,
    CAST(cc.DS_PD_CLASSIFICAZIONE_ANZIANITA AS VARCHAR(4))      AS DS_PD_CLASSIFICAZIONE_ANZIANITA,
    CAST(cc.DS_STATUS_DEF_BASILEA AS VARCHAR(10))               AS DS_STATUS_DEF_BASILEA
FROM cte_calc AS cc
