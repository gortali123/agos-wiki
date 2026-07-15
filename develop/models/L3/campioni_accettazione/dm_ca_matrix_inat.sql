SELECT
    M.CD_PRATICA AS CD_PRATICA,
    M.TP_PROCEDURA AS TP_PROCEDURA,
    M.DT_OSSERVAZIONE AS DT_OSSERVAZIONE,
    T.TS_CARICAMENTO AS CA_MATRIX_INAT_DT_CARICAMENTO_SCORE_V2,
    M.ID_UTILIZZO AS "CA_MATRIX_INAT_FL_INUTILIZZO##", -- WARN: nome campo placeholder ('##') per una matrice mai risolta in colonne concrete; mapping su ID_UTILIZZO ma tipizzato CHAR(1), possibile incoerenza; trascritto letteralmente
    T.CD_STATO AS CA_MATRIX_INAT_LOG_STATI,
    T.DT_OSSERVAZIONE AS CA_MATRIX_INAT_NM_MESI -- WARN: RT mappa DT_OSSERVAZIONE (DATE) su un campo tipizzato NUMBER(10,0), probabile errore nella regola tecnica; trascritto letteralmente
FROM {{ ref('carte_utilizzi') }} AS M
LEFT JOIN {{ ref('pratica_m') }} AS T
    ON T.CD_PRATICA = M.CD_PRATICA
   AND T.TP_PROCEDURA = M.TP_PROCEDURA
   AND T.DT_OSSERVAZIONE = M.DT_OSSERVAZIONE
-- WARN: FREQ = Giornaliera; nessun filtro di riprocesso definito nel data model
