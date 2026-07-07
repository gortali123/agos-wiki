-- Procedura CONSUMO (PLPRAT + PLCHIEST, cluster B2)
SELECT
    'CO' AS TP_PROCEDURA,
    T.PLC_NUM_PRATICA AS CD_PRATICA,
    {{ custom_to_date('C.CHE_DATA_REGISTRAZIONE') }} AS DT_ESTINZIONE,
    {{ custom_to_decimal('C.CHE_IMPORTO_RECUPERAT', 13, 2) }} AS EU_ESTINTO
FROM {{ ref('plprat') }} T
INNER JOIN {{ ref('plchiest') }} C
    ON T.PLC_NUM_PRATICA = C.CHE_PRATICA
WHERE T.PLC_STATO = 55

UNION ALL

/* SELECT
     'CA' AS TP_PROCEDURA,
     T.CRCAR_KEY_N AS CD_PRATICA,                          
     {{ custom_to_date('C.CACHEST_DATA_REGISTRAZIONE') }} AS DT_ESTINZIONE,
     {{ custom_to_decimal('D.CRMCS_SALDO_FINALE_TOT', 13, 2) }} AS EU_ESTINTO
 FROM {{ ref('crcar') }} T                                  
 INNER JOIN {{ ref('cachfest') }} C                        
     ON T.CRCAR_KEY_N = C.CACHEST_CARTA
     AND C.FL_DELETED = 'N'
INNER JOIN {{ ref('crecca') }} D                      
     ON T.CRCAR_KEY_N = D.CRMCS_CARTA_N
     AND D.CRMCS_ARCHIVIATO = 'Z'
 WHERE T.CRCAR_BLOCCO = 'ES'

 UNION ALL*/

-- Procedura CQS (QSPRA + QSESTINZ, cluster B2)
SELECT
    'CQ' AS TP_PROCEDURA,
    T.QPR_NUM_PRATICA AS CD_PRATICA,
    {{ custom_to_date('C.QESTI_CED_DATA_ESTINZ') }} AS DT_ESTINZIONE,
    {{ custom_to_decimal(
        'C.QESTI_IMPORTO_RESIDUO
         - C.QESTI_SALDO_TFR
         - C.QESTI_INCASSO_EST
         - C.QESTI_ABB_PROMOZ
         + C.QESTI_ABB_COMM_BANCA
         + C.QESTI_ABB_COMM_FINANZ
         + C.QESTI_ABB_SPESE
         + C.QESTI_ABB_SPESE_F
         + C.QESTI_ABB_SPESE_R
         + C.QESTI_ABB_ONERI_CONV
         + C.QESTI_ABB_CORR_PROV
         + C.QESTI_ABB_PREMIO_ASS_V
         + C.QESTI_ABB_PREMIO_ASS_I', 13, 2) }} AS EU_ESTINTO
FROM {{ ref('qspra') }} T
INNER JOIN {{ ref('qsestinz') }} C
    ON T.QPR_NUM_PRATICA = C.QESTI_NUM_PRATICA
WHERE T.QPR_STATO = 80