WITH SOURCE_FEA AS (
    SELECT
        'FEA'                                           AS TP_SORGENTE,
        T.idTransazione                                 AS CD_TRANSAZIONE,
        T.idTitolo                                      AS CD_PREMIO,
        NULL                                            AS TP_PROCEDURA,
        CAST(TI.idCertificato AS VARCHAR(250))          AS CD_PRATICA,
        CAST(TI.idProdottoVersione AS NUMBER(11,0))     AS CD_SERVIZIO,
        CAST(T.tipoOperazione AS VARCHAR(11))           AS TP_OPERAZIONE,
        T.tipoPagamento                                 AS TP_PAGAMENTO,
        T.data_presentazione                            AS DT_PRESENTAZIONE,
        T.dataEffetto                                   AS DT_EFFETTO,
        T.dataScadenza                                  AS DT_SCADENZA,
        T.dataValuta                                    AS DT_VALUTA,
        CAST(NULL AS DATE)                              AS DT_OPERAZIONE,
        T.idStatoTransazione                            AS CD_STATO_TRANSAZIONE,
        ST.dsStatoTransazione                           AS DS_STATO_TRANSAZIONE,
        CAST(T.premioNetto AS NUMBER(38,2))             AS EU_IMP_OPERAZIONE_PREM_NETTO,
        CAST(T.premioAddizionale AS NUMBER(38,2))       AS EU_PREMIO_ADDZL,
        CAST(T.premioImponibile AS NUMBER(38,2))        AS EU_PREMIO_IMPONIBILE,
        CAST(T.premioTasse AS NUMBER(38,2))             AS EU_PREMIO_TASSE,
        CAST(T.premioLordo AS NUMBER(38,2))             AS EU_IMP_OPERAZIONE_PREM_LORDO,
        CAST(T.premio_commissioni AS NUMBER(38,2))      AS EU_PREMIO_COMMISSIONI,
        CASE 
            WHEN NULLIF(T.idTransazioneProvvigioneAttiva, 0) IS NOT NULL THEN 'S' 
            ELSE 'N' 
        END                                             AS FL_PROVVIGIONE_ATTIVA,
        T.data_transazione_provvigione_passiva          AS DT_PROVVIGIONE_ATTIVA, -- Nota: L'analisi indica data_transazione_provvigione_attiva, ma nella tabella sorgente sembra esserci un ref specifico
        CAST(TA.importo_provvigione AS NUMBER(38,2))    AS EU_PROVVIGIONE_ATTIVA,
        TA.percentuale_provvigione                      AS PC_PROVVIGIONE_ATTIVA,
        CASE 
            WHEN NULLIF(T.idTransazioneProvvigionePassiva, 0) IS NOT NULL THEN 'S' 
            ELSE 'N' 
        END                                             AS FL_PROVVIGIONE_PASSIVA,
        T.data_transazione_provvigione_passiva          AS DT_PROVVIGIONE_PASSIVA,
        CAST(TP.importo_provvigione AS NUMBER(38,2))    AS EU_PROVVIGIONE_PASSIVA,
        TP.percentuale_provvigione                      AS PC_PROVVIGIONE_PASSIVA,
        NULL                                            AS LASTMODIFIEDDATA
    FROM {{ ref('tbltransazioni') }} T
    LEFT JOIN {{ ref('tblstatotransazione') }} ST 
        ON T.idStatoTransazione = ST.idStatoTransazione
        AND CURRENT_TIMESTAMP >= ST.TS_INIZIO_VALIDITA AND CURRENT_TIMESTAMP < ST.TS_FINE_VALIDITA
    LEFT JOIN {{ ref('tbltitoli') }} TI
        ON T.idTitolo = TI.idTitolo
        AND CURRENT_TIMESTAMP >= TI.TS_INIZIO_VALIDITA AND CURRENT_TIMESTAMP < TI.TS_FINE_VALIDITA
    LEFT JOIN {{ ref('tbltransazioniprovvigioniattive') }} TA
        ON T.idTransazioneProvvigioneAttiva = TA.idTransazioneProvvigioneAttiva
        AND CURRENT_TIMESTAMP >= TA.TS_INIZIO_VALIDITA AND CURRENT_TIMESTAMP < TA.TS_FINE_VALIDITA
    LEFT JOIN {{ ref('tbltransazioniprovvigionipassive') }} TP
        ON T.idTransazioneProvvigionePassiva = TP.idTransazioneProvvigionePassiva
        AND CURRENT_TIMESTAMP >= TP.TS_INIZIO_VALIDITA AND CURRENT_TIMESTAMP < TP.TS_FINE_VALIDITA
    WHERE CURRENT_TIMESTAMP >= T.TS_INIZIO_VALIDITA AND CURRENT_TIMESTAMP < T.TS_FINE_VALIDITA
),

SOURCE_OCS AS (
    SELECT
        'OCS'                                           AS TP_SORGENTE,
        NULL                                            AS CD_TRANSAZIONE,
        NULL                                            AS CD_PREMIO,
        NULL                                            AS TP_PROCEDURA,
        NULL                                            AS CD_PRATICA,
        NULL                                            AS CD_SERVIZIO,
        NULL                                            AS TP_OPERAZIONE,
        NULL                                            AS TP_PAGAMENTO,
        NULL                                            AS DT_PRESENTAZIONE,
        NULL                                            AS DT_EFFETTO,
        NULL                                            AS DT_SCADENZA,
        NULL                                            AS DT_VALUTA,
        NULL                                            AS DT_OPERAZIONE,
        NULL                                            AS CD_STATO_TRANSAZIONE,
        NULL                                            AS DS_STATO_TRANSAZIONE,
        0.0                                             AS EU_IMP_OPERAZIONE_PREM_NETTO,
        0.0                                             AS EU_PREMIO_ADDZL,
        0.0                                             AS EU_PREMIO_IMPONIBILE,
        0.0                                             AS EU_PREMIO_TASSE,
        0.0                                             AS EU_IMP_OPERAZIONE_PREM_LORDO,
        0.0                                             AS EU_PREMIO_COMMISSIONI,
        'N'                                             AS FL_PROVVIGIONE_ATTIVA,
        NULL                                            AS DT_PROVVIGIONE_ATTIVA,
        0.0                                             AS EU_PROVVIGIONE_ATTIVA,
        0.0                                             AS PC_PROVVIGIONE_ATTIVA,
        'N'                                             AS FL_PROVVIGIONE_PASSIVA,
        NULL                                            AS DT_PROVVIGIONE_PASSIVA,
        0.0                                             AS EU_PROVVIGIONE_PASSIVA,
        0.0                                             AS PC_PROVVIGIONE_PASSIVA,
        A.LASTMODIFIEDDATA                              AS LASTMODIFIEDDATA
    FROM {{ ref('cctabser') }} AS A
    WHERE 1=0 -- #TODO questo è un placeholder in attesa delle analisi
    AND A.FL_DELETED = 'N'
)


SELECT TP_SORGENTE,
    CD_TRANSAZIONE,
    CD_PREMIO,
    TP_PROCEDURA,
    CD_PRATICA,
    CD_SERVIZIO,
    TP_OPERAZIONE,
    TP_PAGAMENTO,
    DT_PRESENTAZIONE,
    DT_EFFETTO,
    DT_SCADENZA,
    DT_VALUTA,
    DT_OPERAZIONE,
    CD_STATO_TRANSAZIONE,
    DS_STATO_TRANSAZIONE,
    EU_IMP_OPERAZIONE_PREM_NETTO,
    EU_PREMIO_ADDZL,
    EU_PREMIO_IMPONIBILE,
    EU_PREMIO_TASSE,
    EU_IMP_OPERAZIONE_PREM_LORDO,
    EU_PREMIO_COMMISSIONI,
    FL_PROVVIGIONE_ATTIVA,
    DT_PROVVIGIONE_ATTIVA,
    EU_PROVVIGIONE_ATTIVA,
    PC_PROVVIGIONE_ATTIVA,
    FL_PROVVIGIONE_PASSIVA,
    DT_PROVVIGIONE_PASSIVA,
    EU_PROVVIGIONE_PASSIVA,
    PC_PROVVIGIONE_PASSIVA,
    LASTMODIFIEDDATA
FROM SOURCE_FEA

UNION ALL

SELECT TP_SORGENTE,
    CD_TRANSAZIONE,
    CD_PREMIO,
    TP_PROCEDURA,
    CD_PRATICA,
    CD_SERVIZIO,
    TP_OPERAZIONE,
    TP_PAGAMENTO,
    DT_PRESENTAZIONE,
    DT_EFFETTO,
    DT_SCADENZA,
    DT_VALUTA,
    DT_OPERAZIONE,
    CD_STATO_TRANSAZIONE,
    DS_STATO_TRANSAZIONE,
    EU_IMP_OPERAZIONE_PREM_NETTO,
    EU_PREMIO_ADDZL,
    EU_PREMIO_IMPONIBILE,
    EU_PREMIO_TASSE,
    EU_IMP_OPERAZIONE_PREM_LORDO,
    EU_PREMIO_COMMISSIONI,
    FL_PROVVIGIONE_ATTIVA,
    DT_PROVVIGIONE_ATTIVA,
    EU_PROVVIGIONE_ATTIVA,
    PC_PROVVIGIONE_ATTIVA,
    FL_PROVVIGIONE_PASSIVA,
    DT_PROVVIGIONE_PASSIVA,
    EU_PROVVIGIONE_PASSIVA,
    PC_PROVVIGIONE_PASSIVA,
    LASTMODIFIEDDATA
FROM SOURCE_OCS
