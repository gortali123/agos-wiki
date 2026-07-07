SELECT
    T.PSVT_PROCEDURA AS TP_PROCEDURA,
    T.PSVT_PRATICA AS CD_PRATICA,
    T.PSVT_PROGRESSIVO AS PR_POSTVENDITA,
    {{ custom_to_date('T.PSVT_DATA_STATO') }} AS DT_PERDITA,
    CASE
        WHEN T.PSVT_AZIONE = 'EST' THEN {{ custom_to_decimal('B.CHE_ABBUONO', 13, 2) }}
        WHEN T.PSVT_AZIONE = 'STO' THEN {{ custom_to_decimal('C.CHS_IMP_ABBUONO', 13, 2) }}
        WHEN T.PSVT_AZIONE = 'ABB' THEN {{ custom_to_decimal(
            'NVL(D.PLPSDABB_SALDO_RATE, 0)
             + NVL(D.PLPSDABB_SALDO_ALTRI_ADDEB, 0)
             + NVL(D.PLPSDABB_SALDO_MORA_ES_ATT, 0)
             + NVL(D.PLPSDABB_SALDO_MORA_ES_PREC, 0)', 13, 2) }}
        WHEN T.PSVT_AZIONE = 'CHI' THEN {{ custom_to_decimal('E.CHU_SALDO', 13, 2) }}
    END AS EU_PERDITA,
    CASE
        WHEN (
            CASE
                WHEN T.PSVT_AZIONE = 'EST' THEN B.CHE_ABBUONO
                WHEN T.PSVT_AZIONE = 'STO' THEN C.CHS_IMP_ABBUONO
                WHEN T.PSVT_AZIONE = 'ABB' THEN NVL(D.PLPSDABB_SALDO_RATE, 0)
                                                 + NVL(D.PLPSDABB_SALDO_ALTRI_ADDEB, 0)
                                                 + NVL(D.PLPSDABB_SALDO_MORA_ES_ATT, 0)
                                                 + NVL(D.PLPSDABB_SALDO_MORA_ES_PREC, 0)
                WHEN T.PSVT_AZIONE = 'CHI' THEN E.CHU_SALDO
            END
        ) > 0 THEN 'S'
        ELSE NULL
    END AS FL_ABBUONO
FROM {{ ref('ccpsvt') }} T
LEFT JOIN {{ ref('plchiest') }} B
    ON T.PSVT_PROGRESSIVO = B.CHE_EV_PSV_ESI
LEFT JOIN {{ ref('plchistor') }} C
    ON T.PSVT_PROGRESSIVO = C.CHS_EV_PSV_STO
LEFT JOIN {{ ref('plpsfdabb') }} D
    ON T.PSVT_PROGRESSIVO = D.PLPSDABB_PROGRE
    AND D.FL_DELETED = 'N'
LEFT JOIN {{ ref('plchichi') }} E
    ON T.PSVT_PROGRESSIVO = E.CHU_PR_PSVT
WHERE T.FL_DELETED = 'N'
    AND T.PSVT_AZIONE IN ('ABB', 'CHI', 'EST', 'STO')
    AND T.PSVT_STATO = '30'
    AND T.PSVT_BLOCCO is NULL

UNION ALL

SELECT
    'CA' AS TP_PROCEDURA,
    T.CRMCS_CARTA_N AS CD_PRATICA,
    T.CRMCS_PROGRESSIVO AS PR_POSTVENDITA,
    {{ custom_to_date('C.CRMCC_DATA_REGISTRAZIONE') }} AS DT_PERDITA,
    {{ custom_to_decimal('C.CRMCC_IMPORTO', 13, 2) }} AS EU_PERDITA,
    CASE WHEN C.CRMCC_IMPORTO > 0 THEN 'S' ELSE NULL END AS FL_ABBUONO
FROM {{ ref('crecca') }} T
INNER JOIN {{ ref('creccc') }} C
    ON T.CRMCS_EMETTITORE = C.CRMCC_EMETTITORE
    AND T.CRMCS_CARTA_N = C.CRMCC_CARTA_N
    AND T.CRMCS_DATA_AA = C.CRMCC_DATA_AA
    AND T.CRMCS_DATA_MM = C.CRMCC_DATA_MM
    AND C.FL_DELETED = 'N'
LEFT JOIN {{ ref('cremep') }} P
    ON T.CRMCS_PRODOTTO = P.CEMPR_PRODOTTO
    AND P.FL_DELETED = 'N'
LEFT JOIN {{ ref('cremee') }} E 
    ON T.CRMCS_EMETTITORE = E.CEMEM_EMETTITORE
    AND E.FL_DELETED = 'N'
WHERE T.FL_DELETED = 'N'
    AND T.CRMCS_ARCHIVIATO in ('A','S')
    AND C.CRMCC_CAUSALE = COALESCE(P.CEMPR_CAUSALE_30, E.CEMEM_CAU_COMMISSIO30, -1)

UNION ALL

SELECT
    T.PSVT_PROCEDURA AS TP_PROCEDURA,
    T.PSVT_PRATICA AS CD_PRATICA,
    T.PSVT_PROGRESSIVO AS PR_POSTVENDITA,
    {{ custom_to_date('B.CQPSABB_DATA_VAL') }} AS DT_PERDITA,
    {{ custom_to_decimal(
        'COALESCE(B.CQPSABB_IMP_RP, 0)
         + COALESCE(B.CQPSABB_IMP_CD, 0)
         + COALESCE(B.CQPSABB_IMP_SC, 0)
         + COALESCE(B.CQPSABB_IMP_IM, 0)
         + COALESCE(B.CQPSABB_IMP_PE, 0)
         + COALESCE(B.CQPSABB_IMP_EA, 0)
         + COALESCE(B.CQPSABB_IMP_SB, 0)', 13, 2) }} AS EU_PERDITA,
    CASE
        WHEN (
            COALESCE(B.CQPSABB_IMP_RP, 0)
            + COALESCE(B.CQPSABB_IMP_CD, 0)
            + COALESCE(B.CQPSABB_IMP_SC, 0)
            + COALESCE(B.CQPSABB_IMP_IM, 0)
            + COALESCE(B.CQPSABB_IMP_PE, 0)
            + COALESCE(B.CQPSABB_IMP_EA, 0)
            + COALESCE(B.CQPSABB_IMP_SB, 0)
        ) > 0 THEN 'S'
        ELSE NULL
    END AS FL_ABBUONO
FROM {{ ref('ccpsvt') }} T
INNER JOIN {{ ref('cqpsfdabb') }} B
    ON T.PSVT_PROGRESSIVO = B.CQPSABB_PROGRESSIVO
    AND B.FL_DELETED = 'N'
WHERE T.FL_DELETED = 'N'
    AND T.PSVT_PROCEDURA = 'CQ'