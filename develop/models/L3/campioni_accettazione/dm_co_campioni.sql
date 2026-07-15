SELECT
    M.CD_PRATICA AS CD_PRATICA,
    M.TP_PROCEDURA AS TP_PROCEDURA,
    M.DT_OSSERVAZIONE AS DT_OSSERVAZIONE,
    M.TS_ESTINZIONE_ANTICIPATA AS TS_ESTINZIONE_ANTICIPATA,
    NULL AS SCORE_DATA_DI_INSERIMENTO, -- WARN: RT = "calcolo da definire", nessuna logica nel data model; campo duplicato, mantenuta la prima occorrenza
    M.DT_PERDITA_CESSIONE AS DT_PERDITA_CESSIONE, -- WARN: campo duplicato nel data model, mantenuta la prima occorrenza
    M.DT_STORNO AS DT_STORNO, -- WARN: campo duplicato nel data model, mantenuta la prima occorrenza
    NULL AS SCORE_DATA_DI_VARIAZIONE, -- WARN: RT = "calcolo da definire", nessuna logica nel data model; campo duplicato, mantenuta la prima occorrenza
    NULL AS SETTORE, -- WARN: RT = "calcolo da definire", nessuna logica nel data model
    M.CD_STATO AS CD_STATO,
    M.DT_CHIUSURA AS DT_CHIUSURA,
    M.DT_DBT AS DT_DBT,
    M.DT_ESTINZIONE AS DT_ESTINZIONE,
    M.DT_PRIMA_SCADENZA AS DT_PRIMA_SCADENZA
FROM {{ ref('pratica_m') }} AS M
-- WARN: FREQ = Giornaliera ma la main PRATICA_M e' storicizzazione mensile (S_M); nessun filtro di riprocesso definito nel data model, verificare con l'owner
