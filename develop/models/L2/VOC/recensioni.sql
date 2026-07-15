SELECT
    R.REVIEW_ID AS CD_RECENSIONE,
    R.ID_REFERENCE AS CD_CONTROPARTE,
    R.LOCATION AS CD_FILIALE,
    NULL AS DS_INDIRIZZO_FILIALE, -- WARN: nessuna sorgente nel data model
    NULL AS CD_CITTA_FILIALE, -- WARN: nessuna sorgente nel data model
    R.STARS AS CD_STARS,
    {{ custom_to_timestamp_ntz('R.CREATEDAT') }} AS DT_CREATE_RECENSIONE,
    R.TEXT AS TX_COMMENT,
    R.DISPLAYNAME AS DS_REVIEWER,
    AI_SENTIMENT(R.TEXT) AS DS_SENTIMENT, -- WARN: RT nel data model referenzia se stessa ('FROM RECENSIONI', circolare); applicata la UDF direttamente sulla colonna sorgente TEXT
    NULL AS DT_RISPOSTA_AGOS, -- WARN: nessuna sorgente nel data model
    {{ custom_to_timestamp_ntz('R.UPDATEDAT') }} AS TX_REPLY_UPDATE_TIME,
    NULL AS FL_CONT_POST_RECENSIONE, -- WARN: nessuna sorgente nel data model
    CASE WHEN R.COMPANYREPLY IS NOT NULL THEN 'S' ELSE 'N' END AS FL_RISPOSTA_AGOS,
    NULL AS TX_RISPOSTA_CLIENTE, -- WARN: nessuna sorgente nel data model
    NULL AS DT_UPDATE -- WARN: nessuna sorgente nel data model
FROM {{ ref('1720_reviews') }} R
-- WARN: nessun campo tecnico di storicizzazione (LASTMODIFIEDDATA/DT_OSSERVAZIONE) nel data model; trattata come S4 (insert_overwrite, nessun filtro incrementale), da confermare col team
