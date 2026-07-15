SELECT
    M.CD_PRATICA AS CD_PRATICA,
    M.TP_PROCEDURA AS TP_PROCEDURA,
    M.DT_OSSERVAZIONE AS DT_OSSERVAZIONE,
    T.DT_PRIMA_SCADENZA AS CA_IMP_RATA_DT_RIFERIMENTO,
    T.EU_RATA AS "CA_IMP_RATA_IMPORTO_RATA##", -- WARN: nome campo nel data model e' un placeholder ('##', descrizione "da 0 a 120") che suggerisce una matrice di colonne RATA00..RATA120 mai risolta in campi concreti; trascritto letteralmente
    T.DT_OSSERVAZIONE AS CA_IMP_RATA_NM_MESI -- WARN: RT nel data model mappa DT_OSSERVAZIONE (DATE) su un campo tipizzato NUMBER(10,0), probabile errore nella regola tecnica; trascritto letteralmente
FROM {{ ref('carte_mov_estratto_conto_m') }} AS M
LEFT JOIN {{ ref('pratica_m') }} AS T
    ON T.CD_PRATICA = M.CD_PRATICA
   AND T.TP_PROCEDURA = M.TP_PROCEDURA
   AND T.DT_OSSERVAZIONE = M.DT_OSSERVAZIONE
-- WARN: FREQ = Giornaliera ma la main CARTE_MOV_ESTRATTO_CONTO_M non e' verificabile in raw/dwh-code; nessun filtro di riprocesso definito nel data model
