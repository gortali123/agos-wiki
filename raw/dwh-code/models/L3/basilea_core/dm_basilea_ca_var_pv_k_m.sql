{% set nm_manual_adj_query %} 
    SELECT NM_MANUAL_ADJ
    FROM AGOS_DEV_16000.TECH.MANUAL_ADJUSTMENT_O  
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
    CC.PVKCA_DATA_ESTRAZIONE                                                          AS DATA_ESTRAZIONE,
    CAST(CC.PVKCA_PROVENIENZA AS VARCHAR(2))                                        AS CD_PROVENIENZA,
    CAST(CC.PVKCA_PRATICA AS NUMBER(12,0))                                          AS CD_PRATICA,
    CAST(CC.PVKCA_CD_PRODOTTO AS VARCHAR(2))                                        AS CD_PRODOTTO,
    CAST(CC.PVKCA_CD_EMETTITORE AS NUMBER(3,0))                                     AS CD_EMETTITORE,
    CAST(CC.PVKCA_TP_EMETTITORE AS VARCHAR(2))                                     AS TP_EMETTITORE,      
    CAST(CC.PVKCA_CD_CIRCUITO AS VARCHAR(1))                                           AS TP_CIRCUITO,          
    CAST(CC.PVKCA_SOCIETA AS NUMBER(5,0))                                           AS CD_SOCIETA,
    CAST(CC.PVKCA_CO_RE AS NUMBER(1,0))                                             AS TP_CO_RE,
    CAST(CC.PVKCA_CD_PRVN_INFO AS VARCHAR(2))                                       AS CD_PRVN_INFO,
    CAST(CC.PVKCA_FILIALE AS VARCHAR(3))                                            AS CD_FILIALE,
    CAST(CC.PVKCA_SUBPTF AS VARCHAR(30))                                             AS TP_SUBPTF,           
    CAST(CC.PVKCA_CD_BLOCCO AS VARCHAR(30))                                         AS CD_BLOCCO,
    CAST(CC.PVKCA_CD_NDG_CLIENTE AS NUMBER(9,0))                                    AS CD_NDG_CLIENTE,
    CAST(CC.PVKCA_CD_NDG_MST AS NUMBER(9,0))                                        AS CD_NDG_MST,
    CAST(CC.PVKCA_CLASSE_RISCHIO AS NUMBER(3,0))                                    AS TP_CLASSE_RISCHIO,
    CAST(CC.PVKCA_CLASSE_RISCHIO_PRT AS NUMBER(3,0))                                AS TP_CLASSE_RISCHIO_PRT,
    CAST(CC.PVKCA_IN_DEFAULT AS VARCHAR(1))                                         AS FL_DEFAULT,
    CC.PVKCA_DT_INGRS_DFLT_EBA                                        AS DATA_INGRS_DFLT_EBA,
    CAST(CC.PVKCA_FL_SME AS VARCHAR(1))                                             AS FL_SME,
    CAST(CC.PVKCA_CDGRIGLI AS VARCHAR(6))                                           AS CD_GRIGLIA,
    CAST(CC.PVKCA_DSGRIGLIA AS VARCHAR(30))                                         AS DS_GRIGLIA,
    CAST(CC.PVKCA_TREATMENT AS VARCHAR(30))                                         AS TP_TREATMENT,         
    CAST(CC.PVKCA_CD_RAGGR_IRB AS NUMBER(5,0))                                      AS CD_RAGGR_IRB,
    CAST( {{ custom_to_decimal('cc.PVKCA_DISPONIBILE_NOUTI',precision=13, decimal=2) }} AS NUMBER(13,2))    AS EU_DISPONIBILE_NOUTI,
    CAST( {{ custom_to_decimal('CC.PVKCA_EU_IMPIEGO_SALDO', precision=13, decimal=2) }} AS NUMBER(13,2))    AS EU_IMPIEGO_SALDO,
    CAST( {{ custom_to_decimal('CC.PVKCA_IM_IMPIEGHI', precision=13,      decimal=2) }} AS NUMBER(13,2))    AS EU_IMPIEGHI,
    CAST( {{ custom_to_decimal('CC.PVKCA_IM_RATEO',       precision=13,   decimal=2) }} AS NUMBER(13,2))    AS EU_RATEO,
    CAST( {{ custom_to_decimal('CC.PVKCA_IM_RISCONTO',   precision=13,    decimal=2) }} AS NUMBER(13,2))    AS EU_RISCONTO,
    CAST( {{ custom_to_decimal('CC.PVKCA_IM_FIDO', precision=13,      decimal=2) }} AS NUMBER(13,2))         AS EU_FIDO,
    CAST( {{ custom_to_decimal('CC.PVKCA_EU_LATE_FEES',  precision=13,    decimal=2) }} AS NUMBER(13,2))    AS EU_LATE_FEES,
    CAST( {{ custom_to_decimal('CC.PVKCA_EU_MORA',    precision=13,        decimal=2) }} AS NUMBER(13,2))    AS EU_MORA,
    CAST(CC.PVKCA_NM_MESI_IMPAGATO AS NUMBER(5,0))                                  AS NM_MESI_IMPAGATO,
    CAST(CC.PVKCA_GG_SCAD AS NUMBER(5,0))                                           AS NM_GG_SCAD,
    CAST(CC.PVKCA_STATUS AS VARCHAR(60))                                            AS DS_STATUS,            
    CAST( {{ custom_to_decimal('CC.PVKCA_PD',    precision=13,          decimal=10) }} AS NUMBER(13,10))       AS NM_PD,            
    CAST( {{ custom_to_decimal('CC.PVKCA_PD_FLOOR',    precision=13,    decimal=10) }} AS NUMBER(13,10))       AS NM_PD_FLOOR,      
    CAST(CC.PVKCA_PD_TYPE AS VARCHAR(3))                                            AS TP_PD_TYPE,
    CAST(CC.PVKCA_PD_TOT AS NUMBER(4,0))                                            AS NM_PD_TOT,
    CAST( {{ custom_to_decimal('CC.PVKCA_PD_SCORE',  precision=13,      decimal=10) }} AS NUMBER(13,10))       AS PC_PD_SCORE,      
    CAST( {{ custom_to_decimal('CC.PVKCA_PD_SCORE_FLOOR',  precision=13, decimal=10) }} AS NUMBER(13,10))       AS PC_PD_SCORE_FLOOR,  
    CAST(CC.PVKCA_PD_DSC_SCORE AS VARCHAR(60))                                      AS DS_PD_DSC_SCORE,
    CAST(CC.PVKCA_PD_TOT_PRT AS NUMBER(4,0))                                        AS NM_PD_TOT_PRT,
    CAST( {{ custom_to_decimal('CC.PVKCA_PD_SCORE_PRT', precision=13, decimal=10) }}  AS NUMBER(13,10))        AS PC_PD_SCORE_PRT,          
    CAST( {{ custom_to_decimal('CC.PVKCA_PD_SCORE_FLOOR_PRT', precision=13, decimal=10) }} AS NUMBER(13,10))   AS PC_PD_SCORE_FLOOR_PRT,    
    CAST(CC.PVKCA_LGD_CLASSE_RISC AS NUMBER(3,0))                                   AS TP_LGD_CLASSE_RISC,
    CAST(CC.PVKCA_CD_CLUSTER_LGD AS NUMBER(2,0))                                    AS TP_CLUSTER_LGD,
    CAST( {{ custom_to_decimal('CC.PVKCA_LGD',     precision=13,        decimal=10) }} AS NUMBER(13,10))       AS NM_LGD,           
    CAST( {{ custom_to_decimal('CC.PVKCA_LGD_FLOOR',   precision=13,    decimal=10) }} AS NUMBER(13,10))       AS NM_LGD_FLOOR,     
    CAST(CC.PVKCA_LGD_TYPE AS VARCHAR(3))                                           AS TP_LGD_TYPE,
    CAST( {{ custom_to_decimal('CC.PVKCA_LGD_SCORE',   precision=13,     decimal=10) }} AS NUMBER(13,10))      AS PC_LGD_SCORE,     
    CAST( {{ custom_to_decimal('CC.PVKCA_LGD_SCORE_FLOOR',  precision=13, decimal=10) }} AS NUMBER(13,10))      AS PC_LGD_SCORE_FLOOR,  
    CAST(CC.PVKCA_LGD_DSC_SCORE AS VARCHAR(60))                                     AS DS_LGD_DSC_SCORE,
    CAST(CC.PVKCA_MESI_ELBE AS NUMBER(5,0))                                         AS NM_MESI_ELBE,
    CAST(CC.PVKCA_NM_MM_ELBE AS NUMBER(5,0))                                        AS NM_MM_ELBE,
    CAST(CC.PVKCA_ELBE_CLASSE_RISC AS NUMBER(3,0))                                  AS NM_ELBE_CLASSE_RISC,
    CAST(CC.PVKCA_CD_CLUSTER_ELBE AS NUMBER(2,0))                                   AS TP_CLUSTER_ELBE,
    CAST(CC.PVKCA_ELBE_TYPE AS VARCHAR(3))                                          AS TP_ELBE_TYPE,
    CAST( {{ custom_to_decimal('CC.PVKCA_ELBE',    precision=13,         decimal=10) }} AS NUMBER(13,10))      AS NM_ELBE,          
    CAST( {{ custom_to_decimal('CC.PVKCA_ELBE_SCORE',  precision=13,     decimal=10) }} AS NUMBER(13,10))      AS PC_ELBE_SCORE,    
    CAST(CC.PVKCA_ELBE_DSC_SCORE AS VARCHAR(60))                                    AS DS_ELBE_DSC_SCORE,
    CAST(CC.PVKCA_CCF_CLASSE_RISC AS NUMBER(2,0))                                   AS TP_CCF_CLASSE_RISC,
    CAST(CC.PVKCA_CD_CLUSTER_CCF AS NUMBER(2,0))                                    AS TP_CLUSTER_CCF,
    CAST(CC.PVKCA_CCF_TYPE AS VARCHAR(3))                                           AS TP_CCF_TYPE,
    CAST( {{ custom_to_decimal('CC.PVKCA_CCF',  precision=13,     decimal=10) }} AS NUMBER(13,10))         AS NM_CCF,               
    CAST( {{ custom_to_decimal('CC.PVKCA_PC_CCF',    precision=13,   decimal=10) }}  AS NUMBER(13,10))     AS PC_CCF,               
    CAST(CC.PVKCA_DS_PARAM_CCF AS VARCHAR(60))                                      AS DS_PARAM_CCF,
    CAST(CC.PVKCA_K_CLASSE_RISC AS NUMBER(2,0))                                     AS TP_K_CLASSE_RISC,
    CAST(CC.PVKCA_CD_CLUSTER_K AS NUMBER(2,0))                                      AS TP_CLUSTER_K,
    CAST(CC.PVKCA_K_TYPE AS VARCHAR(3))                                             AS TP_K_TYPE,
    CAST({{ custom_to_decimal('CC.PVKCA_K',   precision=13,    decimal=10) }}  AS NUMBER(13,10))           AS NM_K,                 
    CAST( {{ custom_to_decimal('CC.PVKCA_PC_K',   precision=13,    decimal=10) }}  AS NUMBER(13,10))       AS PC_K,                 
    CAST(CC.PVKCA_DS_PARAM_K AS VARCHAR(60))                                        AS DS_PARAM_K,
    CAST( {{ custom_to_decimal('CC.PVKCA_SUPPORTING_FACTOR',  precision=13, decimal=10)}} AS NUMBER(13,10))       AS NM_SUPPORTING_FACTOR,    
    CAST( {{ custom_to_decimal('CC.PVKCA_PERDITA_ATTESA',    precision=13,    decimal=2) }} AS NUMBER(13,2))    AS EU_EL,            
    CAST( {{ custom_to_decimal('CC.PVKCA_PERDITA_ATTESA_FLOOR',  precision=13, decimal=2) }} AS NUMBER(13,2))    AS EU_EL_FLOOR,      
    CAST( {{ custom_to_decimal('CC.PVKCA_EAD_STIMATA',     precision=13,      decimal=2)  }} AS NUMBER(13,2))   AS EU_EAD_STIMATA,
    CAST( {{ custom_to_decimal('CC.PVKCA_EAD_STIMATA_FLOOR',  precision=13,   decimal=2)  }} AS NUMBER(13,2))   AS EU_EAD_STIMATA_FLOOR 
   FROM AGOS_DEV_16000.L1_O_BAS.IFBLFPVKCA_TEST AS CC    -- Da sostituire con la ref del modello dbt associato quando verrrano inviati i tracciati mensili da ocs. 
    where cc.PVKCA_DATA_ESTRAZIONE = LAST_DAY(DATEADD(MONTH, -4, CURRENT_DATE()))
),
 CTE_CORR AS (
    SELECT 
        cc.*,
        CA.SCRCA_CARTA_UTILIZZATA,
CASE 
 WHEN CC.NM_PD_FLOOR <> 1 THEN
        CASE
            WHEN CC.FL_SME = 'S' THEN
                0.03 * (1 - EXP(-35 * cc.NM_PD_FLOOR  )) / (1 - EXP(-35))
                + 0.16 * (1 - (1 - EXP(-35 * cc.NM_PD_FLOOR )) / (1 - EXP(-35)))
            ELSE 0.04
        END 
        ELSE null
        END  AS CORR_CALC, 
        DATEDIFF('MONTH', CM.DT_SCADENZA, CC.DATA_ESTRAZIONE) AS NM_ANZIANITA_CARTA 
    FROM  BASE AS cc 
    LEFT JOIN  AGOS_DEV_16000.L1_O_BAS.IFBLFSCRCA_TEST AS CA      -- Da sostituire con la ref del modello dbt associato quando verrrano inviati i tracciati mensili da ocs. 
        ON CC.CD_PRATICA = CA.SCRCA_PRATICA
        AND CC.CD_PROVENIENZA = CA.SCRCA_PROVENIENZA
        AND CC.DATA_ESTRAZIONE  =  CA.SCRCA_DATA_ESTRAZIONE
    LEFT JOIN {{ ref('carta_m') }} as CM           
        ON CC.CD_PRATICA = RIGHT(CM.CD_PRATICA, 12)
        AND CC.CD_PROVENIENZA = CM.TP_PROCEDURA
        AND CC.DATA_ESTRAZIONE = CM.DT_OSSERVAZIONE
),

CTE_CAP AS (
    SELECT
        CR.*,
        CR.CORR_CALC AS CORRELATION,
CASE 
 WHEN CR.NM_PD_FLOOR <> 1 THEN
         CR.NM_LGD_FLOOR  * AGOS_DEV_16000.TECH.PROBNORM(
            POWER(1 - CR.CORR_CALC, -0.5) * AGOS_DEV_16000.TECH.PROBIT( CR.NM_PD_FLOOR )
            + POWER(CR.CORR_CALC / (1 - CR.CORR_CALC), 0.5) * AGOS_DEV_16000.TECH.PROBIT(0.999)
        ) - CR.NM_PD_FLOOR  *  CR.NM_LGD_FLOOR 
        Else null
END AS CAPITAL_REQUIREMENT,

        CASE
            WHEN CR.SCRCA_CARTA_UTILIZZATA = 'N' THEN 'PDRF'
            WHEN CR.NM_ANZIANITA_CARTA < 4 THEN 'PDRG'
            WHEN CR.NM_ANZIANITA_CARTA >= 4 THEN 'PDRM'
        END AS DS_PD_CLASSIFICAZIONE_ANZIANITA
    FROM CTE_CORR CR
),

CTE_CALC AS (
    SELECT
        CC.*,
        CASE
              WHEN CC.NM_PD_FLOOR <> 1 THEN
              CASE
                  WHEN CC.FL_SME = 'S' THEN
                CC.CAPITAL_REQUIREMENT * 12.5 *  cc.EU_EAD_STIMATA_FLOOR * cc.NM_SUPPORTING_FACTOR   * {{ NM_MANUAL_ADJ }}
            ELSE CC.CAPITAL_REQUIREMENT * 12.5 *  cc.EU_EAD_STIMATA_FLOOR * cc.NM_SUPPORTING_FACTOR   * {{ NM_MANUAL_ADJ }}
            END
            ELSE GREATEST(0, 12.5 * (cc.PC_LGD_SCORE_FLOOR - cc.PC_ELBE_SCORE)) 
                       * {{ NM_MANUAL_ADJ }} / 100 * cc.EU_EAD_STIMATA_FLOOR
        END AS EU_RWA,

-- PV_IRB

       CASE
             WHEN CC.NM_PD_FLOOR <> 1 THEN
             CASE
                  WHEN CC.FL_SME = 'S' THEN
                CC.CAPITAL_REQUIREMENT * 12.5 * cc.EU_EAD_STIMATA_FLOOR * cc.NM_SUPPORTING_FACTOR   * {{ NM_MANUAL_ADJ }} * 0.08
            ELSE CC.CAPITAL_REQUIREMENT * 12.5 * cc.EU_EAD_STIMATA_FLOOR * cc.NM_SUPPORTING_FACTOR   * {{ NM_MANUAL_ADJ }} * 0.08
            END
         ELSE GREATEST(0, 12.5 * (cc.PC_LGD_SCORE_FLOOR - cc.PC_ELBE_SCORE)) 
                       * {{ NM_MANUAL_ADJ }} / 100 * cc.EU_EAD_STIMATA_FLOOR * 0.08
        END  AS EU_PV_IRB,
        CASE
            WHEN CC.FL_DEFAULT = 'S' THEN 'DEFAULT'
            WHEN CC.FL_DEFAULT = 'N' AND CC.DS_PD_CLASSIFICAZIONE_ANZIANITA = 'PDRF' THEN 'RECENTS'
            WHEN CC.FL_DEFAULT = 'N' AND CC.DS_PD_CLASSIFICAZIONE_ANZIANITA = 'PDRF' AND CC.NM_GG_SCAD > 0 THEN 'SENSITIVE'
            WHEN CC.FL_DEFAULT = 'N' AND CC.DS_PD_CLASSIFICAZIONE_ANZIANITA = 'PDRF' AND (CC.NM_GG_SCAD = 0 OR CC.NM_GG_SCAD IS NULL) THEN 'SOUNDS'
        END AS DS_STATUS_DEF_BASILEA
    FROM CTE_CAP CC
)


SELECT
    CC.DATA_ESTRAZIONE                    AS DT_ESTRAZIONE,
    CC.CD_PROVENIENZA                  AS CD_PROVENIENZA,
    CC.CD_PRATICA                      AS CD_PRATICA,
    CC.CD_PRODOTTO                     AS CD_PRODOTTO,
    CC.CD_EMETTITORE                   AS CD_EMETTITORE,
    CC.TP_EMETTITORE                   AS TP_EMETTITORE,
    CC.TP_CIRCUITO                     AS TP_CIRCUITO,
    CC.CD_SOCIETA                      AS CD_SOCIETA,
    CC.TP_CO_RE                        AS TP_CO_RE,
    CC.CD_PRVN_INFO                    AS CD_PRVN_INFO,
    CC.CD_FILIALE                      AS CD_FILIALE,
    CC.TP_SUBPTF                       AS TP_SUBPTF,
    CC.CD_BLOCCO                       AS CD_BLOCCO,
    CC.CD_NDG_CLIENTE                  AS CD_NDG_CLIENTE,
    CC.CD_NDG_MST                      AS CD_NDG_MST,
    CC.TP_CLASSE_RISCHIO               AS TP_CLASSE_RISCHIO,
    CC.TP_CLASSE_RISCHIO_PRT           AS TP_CLASSE_RISCHIO_PRT,
    CC.FL_DEFAULT                      AS FL_DEFAULT,
    CC.DATA_INGRS_DFLT_EBA               AS DT_INGRS_DFLT_EBA,
    CC.FL_SME                          AS FL_SME,
    CC.CD_GRIGLIA                     AS CD_GRIGLIA,
    CC.DS_GRIGLIA                    AS DS_GRIGLIA,
    CC.TP_TREATMENT                    AS TP_TREATMENT,
    CC.CD_RAGGR_IRB                    AS CD_RAGGR_IRB,
    CC.EU_DISPONIBILE_NOUTI            AS EU_DISPONIBILE_NOUTI,
    CC.EU_IMPIEGO_SALDO                AS EU_IMPIEGO_SALDO,
    CC.EU_IMPIEGHI                     AS EU_IMPIEGHI,
    CC.EU_RATEO                        AS EU_RATEO,
    CC.EU_RISCONTO                     AS EU_RISCONTO,
    CC.EU_FIDO                         AS EU_FIDO,
    CC.EU_LATE_FEES                    AS EU_LATE_FEES,
    CC.EU_MORA                         AS EU_MORA,
    CC.NM_MESI_IMPAGATO                AS NM_MESI_IMPAGATO,
    CC.NM_GG_SCAD                      AS NM_GG_SCAD,
    CC.DS_STATUS                       AS DS_STATUS,
    CC.NM_PD                           AS NM_PD,
    CC.NM_PD_FLOOR                     AS NM_PD_FLOOR,
    CC.TP_PD_TYPE                      AS TP_PD_TYPE,
    CC.NM_PD_TOT                       AS NM_PD_TOT,
    CC.PC_PD_SCORE                     AS PC_PD_SCORE,
    CC.PC_PD_SCORE_FLOOR               AS PC_PD_SCORE_FLOOR,
    CC.DS_PD_DSC_SCORE                 AS DS_PD_DSC_SCORE,
    CC.NM_PD_TOT_PRT                   AS NM_PD_TOT_PRT,
    CC.PC_PD_SCORE_PRT                 AS PC_PD_SCORE_PRT,
    CC.PC_PD_SCORE_FLOOR_PRT           AS PC_PD_SCORE_FLOOR_PRT,
    CC.TP_LGD_CLASSE_RISC              AS TP_LGD_CLASSE_RISC,
    CC.TP_CLUSTER_LGD                  AS TP_CLUSTER_LGD,
    CC.NM_LGD                          AS NM_LGD,
    CC.NM_LGD_FLOOR                    AS NM_LGD_FLOOR,
    CC.TP_LGD_TYPE                     AS TP_LGD_TYPE,
    CC.PC_LGD_SCORE                    AS PC_LGD_SCORE,
    CC.PC_LGD_SCORE_FLOOR              AS PC_LGD_SCORE_FLOOR,
    CC.DS_LGD_DSC_SCORE                AS DS_LGD_DSC_SCORE,
    CC.NM_MESI_ELBE                    AS NM_MESI_ELBE,
    CC.NM_MM_ELBE                      AS NM_MM_ELBE,
    CC.NM_ELBE_CLASSE_RISC             AS NM_ELBE_CLASSE_RISC,
    CC.TP_CLUSTER_ELBE                 AS TP_CLUSTER_ELBE,
    CC.TP_ELBE_TYPE                    AS TP_ELBE_TYPE,
    CC.NM_ELBE                         AS NM_ELBE,
    CC.PC_ELBE_SCORE                   AS PC_ELBE_SCORE,
    CC.DS_ELBE_DSC_SCORE               AS DS_ELBE_DSC_SCORE,
    CC.TP_CCF_CLASSE_RISC              AS TP_CCF_CLASSE_RISC,
    CC.TP_CLUSTER_CCF                  AS TP_CLUSTER_CCF,
    CC.TP_CCF_TYPE                     AS TP_CCF_TYPE,
    CC.NM_CCF                          AS NM_CCF,
    CC.PC_CCF                          AS PC_CCF,
    CC.DS_PARAM_CCF                    AS DS_PARAM_CCF,
    CC.TP_K_CLASSE_RISC                AS TP_K_CLASSE_RISC,
    CC.TP_CLUSTER_K                    AS TP_CLUSTER_K,
    CC.TP_K_TYPE                       AS TP_K_TYPE,
    CC.NM_K                            AS NM_K,
    CC.PC_K                            AS PC_K,
    CC.DS_PARAM_K                      AS DS_PARAM_K,
    CC.NM_SUPPORTING_FACTOR            AS NM_SUPPORTING_FACTOR,
    CC.EU_EAD_STIMATA                  AS EU_EAD_STIMATA,
    CC.EU_EAD_STIMATA_FLOOR            AS EU_EAD_STIMATA_FLOOR,
    CC.EU_EL                          , --AS EU_EL,
    CC.EU_EL_FLOOR                  ,--   AS EU_EL_FLOOR,
    CAST(CC.EU_RWA AS NUMBER(38,10))                                                 AS EU_RWA,
    CAST(CC.EU_PV_IRB AS NUMBER(38,10))                                              AS EU_PV_IRB,
    CAST(CC.CORRELATION AS NUMBER(38,10))                                           AS EU_CORRELATION,
    CAST(CC.CAPITAL_REQUIREMENT AS NUMBER(38,10))                                    AS EU_CAPITAL_REQUIREMENT,
    CAST(CC.NM_ANZIANITA_CARTA AS NUMBER(4,0))                                    AS NM_ANZIANITA_CARTA,
    CAST(CC.DS_PD_CLASSIFICAZIONE_ANZIANITA AS VARCHAR(4))                          AS DS_PD_CLASSIFICAZIONE_ANZIANITA,
    CAST(CC.DS_STATUS_DEF_BASILEA AS VARCHAR(10))                                   AS DS_STATUS_DEF_BASILEA
FROM CTE_CALC CC
