SELECT
    Q.TARGET AS CD_SURVEY,
    {{ custom_to_date('Q.DATA_TRIGGER') }} AS DT_INVIO_TRIGGER,
    Q.COD_CLIENTE AS CD_CLIENTE,
    Q.COGNOME AS DS_COGNOME,
    Q.NOME AS DS_NOME,
    Q.SESSO AS CD_SESSO,
    Q.EMAIL AS DS_EMAIL,
    Q.COD_PRATICA AS CD_PRATICA,
    Q.STATO_PRATICA AS CD_STATO_PRATICA,
    Q.STATO_CLIENTE AS CD_STATO_CLIENTE,
    Q.CANALE_CONTATTO AS CD_CANALE_CONTATTO,
    Q.CALL_CENTER_ESTERNO AS CD_CALL_CENTER_ESTERNO,
    Q.COD_FILIALE AS CD_FILIALE,
    Q.AREA AS CD_AREA,
    Q.RETE AS CD_RETE,
    Q.BENE AS CD_BENE,
    Q.Q1 AS DS_Q1,
    Q.Q9 AS DS_Q9,
    Q.Q5 AS DS_Q5,
    Q.Q11 AS DS_Q11,
    Q.QID88 AS DS_QID88,
    Q.QID13 AS DS_QID13,
    Q.QID93 AS DS_QID93,
    Q.QID89 AS DS_QID89, -- WARN: campo duplicato nel data model (2 righe identiche), mantenuta la prima occorrenza
    Q.QID151 AS DS_QID151,
    Q.QID78 AS DS_QID78 -- WARN: campo duplicato nel data model (4 righe identiche), mantenuta la prima occorrenza
FROM {{ ref('3820_qualtrics_output') }} Q
-- WARN: nessun campo tecnico di storicizzazione (LASTMODIFIEDDATA/DT_OSSERVAZIONE) nel data model; trattata come S4 (insert_overwrite, nessun filtro incrementale), da confermare col team
