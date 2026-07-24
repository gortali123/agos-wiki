SELECT
    TP_RISTRUTTURAZIONE,
    DESCR AS DS_RISTRUTTURAZIONE,
    CASE
        WHEN TP_RISTRUTTURAZIONE IN ('1','2','7','8','B') THEN '13'
        WHEN TP_RISTRUTTURAZIONE IN ('3','4','A','C')     THEN '03'
        WHEN TP_RISTRUTTURAZIONE IN ('5','D')             THEN '06'
        WHEN TP_RISTRUTTURAZIONE = '9'                    THEN '11'
        WHEN TP_RISTRUTTURAZIONE = 'E'                    THEN '14'
    END AS CD_F_TYP
FROM {{ source('l1_e_bsn', 'lkp_ristrutturazioni') }}