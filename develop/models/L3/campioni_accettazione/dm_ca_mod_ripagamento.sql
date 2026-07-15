SELECT
    M.CD_PRATICA AS CD_PRATICA,
    M.TP_PROCEDURA AS TP_PROCEDURA,
    M.DT_OSSERVAZIONE AS DT_OSSERVAZIONE,
    NULL AS CA_MOD_RIPAG_DT_PRIMA_SCAD, -- WARN: RT = "calcolo da definire", nessuna logica nel data model
    NULL AS CA_MOD_RIPAG_DT_RIFERIMENTO, -- WARN: RT = "calcolo da definire", nessuna logica nel data model
    NULL AS CA_MOD_RIPAG_IN_MULTICHOICE, -- WARN: RT = "calcolo da definire", nessuna logica nel data model (join a PRATICA_M dichiarato ma non utilizzato)
    NULL AS "CA_MOD_RIPAG_NM_RIPAGAMENTO_##", -- WARN: RT = "calcolo da definire" e nome campo placeholder ('##') per una matrice mai risolta in colonne concrete
    T.DT_OSSERVAZIONE AS CA_MOD_RIPAG_NM_MESI -- WARN: RT mappa DT_OSSERVAZIONE (DATE) su un campo tipizzato NUMBER(10,0), probabile errore nella regola tecnica; trascritto letteralmente
FROM {{ ref('estratto_conto_m') }} AS M
LEFT JOIN {{ ref('pratica_m') }} AS T
    ON T.CD_PRATICA = M.CD_PRATICA
   AND T.TP_PROCEDURA = M.TP_PROCEDURA
   AND T.DT_OSSERVAZIONE = M.DT_OSSERVAZIONE
-- WARN: FREQ = Giornaliera; nessun filtro di riprocesso definito nel data model. ESTRATTO_CONTO_M non presente in raw/dwh-code, non verificabile la sua storicizzazione
