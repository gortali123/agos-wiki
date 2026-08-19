SELECT
    TP_RISTRUTTURAZIONE,
    DESCR AS DS_RISTRUTTURAZIONE,
    CASE
        WHEN TP_RISTRUTTURAZIONE IN ('1','2','7','8','B') THEN '13'
        WHEN TP_RISTRUTTURAZIONE IN ('3','4','A','C')     THEN '03'
        WHEN TP_RISTRUTTURAZIONE IN ('5','D')             THEN '06'
        WHEN TP_RISTRUTTURAZIONE = '9'                    THEN '11'
        WHEN TP_RISTRUTTURAZIONE = 'E'                    THEN '14'
    END AS CD_F_TYP,
    CASE WHEN TP_RISTRUTTURAZIONE = '3' THEN '10'
             WHEN TP_RISTRUTTURAZIONE in ('4','A','C') THEN '20'
             WHEN TP_RISTRUTTURAZIONE in ('5','D') THEN '30'
             WHEN TP_RISTRUTTURAZIONE in ('1','2', '7', '8', 'B') THEN '40'
             WHEN TP_RISTRUTTURAZIONE = 'E' THEN '50'
             WHEN TP_RISTRUTTURAZIONE = '9' THEN '70'
             WHEN TP_RISTRUTTURAZIONE = '6' THEN NULL
     END AS CD_SFTYP
FROM {{ source('l1_e_bsn', 'lkp_ristrutturazioni') }}