SELECT
    S.SESSIONUID AS CD_SESSIONE,
    'PP' AS TP_PROCEDURA, -- WARN: nessuna sorgente nel data model per questo campo; REGOLA FUNZIONALE dichiara "Valore fisso 'PP'"
    {{ custom_to_timestamp_ntz('S.CREATIONDATE') }} AS TS_CREAZIONE,
    S.IPADDRESS AS CD_IP_ADDRESS,
    S.MOBILE AS FL_MOBILE,
    S.BROKERCODE AS CD_INIZIATIVA_COMMERCIALE,
    {{ custom_to_decimal('S.AMOUNT', 15, 2) }} AS EU_IMPORTO_RICHIESTO,
    S.RATE AS NM_RATE,
    S.CAMPAIGNID AS CD_CAMPAGNA,
    S.LAYOUT AS TP_LAYOUT
FROM {{ ref('primeweb_pp_session') }} S
-- WARN: nessun campo tecnico di storicizzazione (LASTMODIFIEDDATA/DT_OSSERVAZIONE) nel data model; trattata come S4 (insert_overwrite, nessun filtro incrementale), da confermare col team
-- NOTA: riga 0 dello sheet dice "Tenere solo TIG, no distinzione per procedura" - il secondo blocco colonne per TIG-CA nel foglio e' vuoto, coerente con TP_PROCEDURA fisso 'PP'
