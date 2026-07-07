with SOURCE_OCS as (
    select
        'OCS'                                                   AS TP_SORGENTE,
        0                                                       AS CD_PROVVIGIONE,
        A.BAPV_PROCEDURA                                        AS TP_PROCEDURA,
        CAST(A.BAPV_NUM_PRATICA AS VARCHAR(250))                AS CD_PRATICA,
        CASE  WHEN TRIM(A.BAPV_SERVIZIO) = '' OR A.BAPV_SERVIZIO IS NULL THEN '0'
        ELSE A.BAPV_SERVIZIO
        END                                                     AS CD_SERVIZIO,
        A.BAPV_ANNOMESE                                         AS NM_ANNOMESE_MATURAZIONE,
        A.BAPV_TIPO_PROVVIGIONE                                 AS TP_PROVVIGIONE,
        NULL                                                    AS CD_TRANSAZIONE,
        A.BAPV_FLAG_STORNO                                      AS FL_STORNO,
        {{ custom_to_date('A.BAPV_DATA_LIQUIDAZIONE')}}                 AS DT_LIQUIDAZIONE,
        NULL                                                    AS DT_VALUTA,
        {{ custom_to_decimal("CASE WHEN A.BAPV_FLAG_STORNO = 'S' THEN -A.BAPV_IMPORTO_1 ELSE A.BAPV_IMPORTO_1 END") }} AS EU_IMPORTO_1,
        {{ custom_to_decimal("CASE WHEN A.BAPV_FLAG_STORNO = 'S' THEN -A.BAPV_IMPORTO_2 ELSE A.BAPV_IMPORTO_2 END") }} AS EU_IMPORTO_2,
        {{ custom_to_decimal("CASE WHEN A.BAPV_FLAG_STORNO = 'S' THEN -A.BAPV_IMPORTO_FISSO ELSE A.BAPV_IMPORTO_FISSO END") }} AS EU_IMPORTO_FISSO,
        {{ custom_to_decimal(
            "CASE WHEN A.BAPV_FLAG_STORNO = 'S' THEN -A.BAPV_TOTALE ELSE A.BAPV_TOTALE END", 
            38, 2
        ) }} AS EU_TOTALE,
        A.BAPV_INTERMEDIARIO                                    AS CD_INTERMEDIARIO,
        A.BAPV_TIPO_INTERMEDIARIO                               AS TP_INTERMEDIARIO,
        A.BAPV_DESTINATARIO                                     AS CD_DESTINATARIO,
        A.BAPV_TIPO_DESTINATARIO                                AS TP_DESTINATARIO,
        A.LASTMODIFIEDDATA                                      AS LASTMODIFIEDDATA
    FROM {{ ref('bapratpv') }} AS A
    WHERE BAPV_PROCEDURA IN ('CO', 'CA')
)

, SOURCE_FEA_ATTIVE as (
    select
        'FEA'                                                   AS TP_SORGENTE,
        a.idTransazioneProvvigioneAttiva                        AS CD_PROVVIGIONE,
        'NA'                                                    AS TP_PROCEDURA,
        CAST(COALESCE(p.numeroCertificato, 0) AS VARCHAR(250))   AS CD_PRATICA,
        CAST(CAST(a.idProdottoVersione AS INTEGER) AS VARCHAR)  AS CD_SERVIZIO,
        0                                                       AS NM_ANNOMESE_MATURAZIONE,
        'ATT'                                                   AS TP_PROVVIGIONE,
        a.idTransazione                                         AS CD_TRANSAZIONE,
        CASE
            WHEN p.premiolordo > 0 THEN 'S'
            WHEN p.premiolordo < 0 THEN 'N'
            ELSE NULL
        END                                                     AS FL_STORNO,
        NULL                                                    AS DT_LIQUIDAZIONE,
        {{ custom_to_date('a.data_valuta')}}                            AS DT_VALUTA,
        NULL                                                    AS EU_IMPORTO_1,
        NULL                                                    AS EU_IMPORTO_2,
        NULL                                                    AS EU_IMPORTO_FISSO,
        CAST(a.importo_provvigione AS NUMBER (38,2))            AS EU_TOTALE,
        NULL                                                    AS CD_INTERMEDIARIO,
        NULL                                                    AS TP_INTERMEDIARIO,
        NULL                                                    AS CD_DESTINATARIO,
        NULL                                                    AS TP_DESTINATARIO,
        NULL                                                    AS LASTMODIFIEDDATA
    FROM {{ ref('tbltransazioniprovvigioniattive') }} as a 
    left join {{ ref('tbltransazioni') }} as p
    on a.idTransazioneProvvigioneAttiva = p.IDTRANSAZIONE
    and CURRENT_TIMESTAMP >= p.TS_INIZIO_VALIDITA AND CURRENT_TIMESTAMP < p.TS_FINE_VALIDITA
    where CURRENT_TIMESTAMP >= a.TS_INIZIO_VALIDITA AND CURRENT_TIMESTAMP < a.TS_FINE_VALIDITA
)

, SOURCE_FEA_PASSIVE as (
    select
        'FEA'                                                   AS TP_SORGENTE,
        b.idTransazioneProvvigionePassiva                       AS CD_PROVVIGIONE,
        'NA'                                                    AS TP_PROCEDURA,
        CAST(COALESCE(p.numeroCertificato, 0) AS VARCHAR(250))   AS CD_PRATICA,
        CAST(CAST(b.idProdottoVersione AS INTEGER) AS VARCHAR)  AS CD_SERVIZIO,
        0                                                       AS NM_ANNOMESE_MATURAZIONE,
        'PAS'                                                   AS TP_PROVVIGIONE,
        b.idTransazione                                         AS CD_TRANSAZIONE,
        CASE
            WHEN p.premiolordo > 0 THEN 'S'
            WHEN p.premiolordo < 0 THEN 'N'
            ELSE NULL
        END                                                     AS FL_STORNO,
        NULL                                                    AS DT_LIQUIDAZIONE,
        {{ custom_to_date('b.data_valuta')}}                            AS DT_VALUTA,
        NULL                                                    AS EU_IMPORTO_1,
        NULL                                                    AS EU_IMPORTO_2,
        NULL                                                    AS EU_IMPORTO_FISSO,
        CAST(b.importo_provvigione AS NUMBER(38,2))             AS EU_TOTALE,
        NULL                                                    AS CD_INTERMEDIARIO,
        NULL                                                    AS TP_INTERMEDIARIO,
        NULL                                                    AS CD_DESTINATARIO,
        NULL                                                    AS TP_DESTINATARIO,
        NULL                                                    AS LASTMODIFIEDDATA
    FROM {{ ref('tbltransazioniprovvigionipassive') }} as b 
    left join {{ ref('tbltransazioni') }} as p
    on b.idTransazioneProvvigionePassiva = p.IDTRANSAZIONE
    and CURRENT_TIMESTAMP >= p.TS_INIZIO_VALIDITA AND CURRENT_TIMESTAMP < p.TS_FINE_VALIDITA
    where CURRENT_TIMESTAMP >= b.TS_INIZIO_VALIDITA AND CURRENT_TIMESTAMP < b.TS_FINE_VALIDITA
)
-- ==============================================================
-- FINAL UNION ALL
-- ==============================================================
SELECT
    TP_SORGENTE,
    CD_PROVVIGIONE,
    TP_PROCEDURA,
    CD_PRATICA,
    CD_SERVIZIO,
    NM_ANNOMESE_MATURAZIONE,
    TP_PROVVIGIONE,
    CD_TRANSAZIONE,
    FL_STORNO,
    DT_LIQUIDAZIONE,
    DT_VALUTA,
    EU_IMPORTO_1,
    EU_IMPORTO_2,
    EU_IMPORTO_FISSO,
    EU_TOTALE,
    CD_INTERMEDIARIO,
    TP_INTERMEDIARIO,
    CD_DESTINATARIO,
    TP_DESTINATARIO,
    LASTMODIFIEDDATA
FROM SOURCE_OCS

UNION ALL

SELECT
    TP_SORGENTE,
    CD_PROVVIGIONE,
    TP_PROCEDURA,
    CD_PRATICA,
    CD_SERVIZIO,
    NM_ANNOMESE_MATURAZIONE,
    TP_PROVVIGIONE,
    CD_TRANSAZIONE,
    FL_STORNO,
    DT_LIQUIDAZIONE,
    DT_VALUTA,
    EU_IMPORTO_1,
    EU_IMPORTO_2,
    EU_IMPORTO_FISSO,
    EU_TOTALE,
    CD_INTERMEDIARIO,
    TP_INTERMEDIARIO,
    CD_DESTINATARIO,
    TP_DESTINATARIO,
    LASTMODIFIEDDATA
FROM SOURCE_FEA_ATTIVE
    
UNION ALL

SELECT     
    TP_SORGENTE,
    CD_PROVVIGIONE,
    TP_PROCEDURA,
    CD_PRATICA,
    CD_SERVIZIO,
    NM_ANNOMESE_MATURAZIONE,
    TP_PROVVIGIONE,
    CD_TRANSAZIONE,
    FL_STORNO,
    DT_LIQUIDAZIONE,
    DT_VALUTA,
    EU_IMPORTO_1,
    EU_IMPORTO_2,
    EU_IMPORTO_FISSO,
    EU_TOTALE,
    CD_INTERMEDIARIO,
    TP_INTERMEDIARIO,
    CD_DESTINATARIO,
    TP_DESTINATARIO,
    LASTMODIFIEDDATA
FROM SOURCE_FEA_PASSIVE