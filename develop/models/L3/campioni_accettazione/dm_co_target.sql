SELECT
    M.CD_PRATICA AS CD_PRATICA,
    M.TP_PROCEDURA AS TP_PROCEDURA,
    M.DT_OSSERVAZIONE AS DT_OSSERVAZIONE,
    SS.CD_BLOCCO AS "CO_TARGET_DT_CALA_FINE_##", -- WARN: RT mappa SOCIODEMO_SCORE.CD_BLOCCO su un campo DT_ (DATE) e nome placeholder ('##'); trascritto letteralmente
    SS.CD_BLOCCO AS "CO_TARGET_DT_MORA_FINE_##", -- WARN: RT mappa SOCIODEMO_SCORE.CD_BLOCCO su un campo DT_ (DATE) e nome placeholder ('##'); trascritto letteralmente
    SS.CD_BLOCCO AS "CO_TARGET_DT_CALA_INIZ_##", -- WARN: RT mappa SOCIODEMO_SCORE.CD_BLOCCO su un campo DT_ (DATE) e nome placeholder ('##'); trascritto letteralmente
    SS.CD_BLOCCO AS "CO_TARGET_DT_MORA_INIZ_##", -- WARN: RT mappa SOCIODEMO_SCORE.CD_BLOCCO su un campo DT_ (DATE) e nome placeholder ('##'); trascritto letteralmente
    PM.DT_PRIMA_SCADENZA AS CO_TARGET_NM_MESI_VALUTAZIONE, -- WARN: RT mappa DT_PRIMA_SCADENZA (DATE) su un campo tipizzato NUMBER(10,0), probabile errore nella regola tecnica; trascritto letteralmente
    NULL AS "CO_TARGET_NM_WORST_ACCO##", -- WARN: RT = "calcolo da definire" e nome campo placeholder ('##') per una matrice mai risolta in colonne concrete
    NULL AS "CO_TARGET_NM_WORST##" -- WARN: RT = "calcolo da definire" e nome campo placeholder ('##') per una matrice mai risolta in colonne concrete
FROM {{ ref('oxdrftbtes') }} AS M
LEFT JOIN {{ ref('sociodemo_score') }} AS SS
    ON SS.CD_PRATICA = M.CD_PRATICA
   AND SS.TP_PROCEDURA = M.TP_PROCEDURA
   AND SS.DT_OSSERVAZIONE = M.DT_OSSERVAZIONE
LEFT JOIN {{ ref('pratica_m') }} AS PM
    ON PM.CD_PRATICA = M.CD_PRATICA
   AND PM.TP_PROCEDURA = M.TP_PROCEDURA
   AND PM.DT_OSSERVAZIONE = M.DT_OSSERVAZIONE
-- WARN: FREQ = Giornaliera; nessun filtro di riprocesso definito nel data model. OXDRFTBTES non presente in raw/dwh-code, non verificabile la sua storicizzazione
