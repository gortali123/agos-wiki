SELECT
    M.CD_PRATICA AS CD_PRATICA,
    M.TP_PROCEDURA AS TP_PROCEDURA,
    M.DT_OSSERVAZIONE AS DT_OSSERVAZIONE,
    T.DT_OSSERVAZIONE AS CA_MATRIX_T_NM_MESI, -- WARN: RT mappa DT_OSSERVAZIONE (DATE) su un campo tipizzato NUMBER(10,0), probabile errore nella regola tecnica; trascritto letteralmente
    T.DT_OSSERVAZIONE AS CA_MATRIX_T_NM_MESI_VALU, -- WARN: RT mappa DT_OSSERVAZIONE (DATE) su un campo tipizzato NUMBER(10,0), probabile errore nella regola tecnica; trascritto letteralmente
    T.DT_CHIUSURA AS CA_MATRIX_T_DT_APPOGGIO,
    NULL AS "CA_MATRIX_T_NM_IMPAGATO_CURRENT_##" -- WARN: RT = "calcolo da definire" e nome campo placeholder ('##') per una matrice mai risolta in colonne concrete
FROM {{ ref('svalutazione_m') }} AS M
LEFT JOIN {{ ref('pratica_m') }} AS T
    ON T.CD_PRATICA = M.CD_PRATICA
   AND T.TP_PROCEDURA = M.TP_PROCEDURA
   AND T.DT_OSSERVAZIONE = M.DT_OSSERVAZIONE
-- WARN: FREQ = Giornaliera; nessun filtro di riprocesso definito nel data model. SVALUTAZIONE_M non presente in raw/dwh-code, non verificabile la sua storicizzazione
