SELECT
    M.CD_PRATICA AS CD_PRATICA,
    M.TP_PROCEDURA AS TP_PROCEDURA,
    M.DT_OSSERVAZIONE AS DT_OSSERVAZIONE,
    NULL AS CA_MATRIX_UTLZ_DT_CARICAMENTO_V2, -- WARN: RT = "calcolo da definire", nessuna logica nel data model
    M.ID_UTILIZZO AS "CA_MATRIX_UTLZ_NUM_UTILIZZI##", -- WARN: nome campo placeholder ('##') per una matrice mai risolta in colonne concrete; trascritto letteralmente
    T.DT_OSSERVAZIONE AS CA_MATRIX_UTLZ_NM_MESI -- WARN: RT mappa DT_OSSERVAZIONE (DATE) su un campo tipizzato NUMBER(10,0), probabile errore nella regola tecnica; trascritto letteralmente
FROM {{ ref('carte_utilizzi') }} AS M
LEFT JOIN {{ ref('pratica_m') }} AS T
    ON T.CD_PRATICA = M.CD_PRATICA
   AND T.TP_PROCEDURA = M.TP_PROCEDURA
   AND T.DT_OSSERVAZIONE = M.DT_OSSERVAZIONE
-- WARN: FREQ = Giornaliera; nessun filtro di riprocesso definito nel data model
