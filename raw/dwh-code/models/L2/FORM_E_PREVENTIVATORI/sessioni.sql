SELECT
    T.SESSIONUID AS CD_SESSIONE,
    'PP' AS TP_PROCEDURA, -- WARN: REGOLA TECNICA non compilata (NA); valore fisso 'PP' derivato dalla REGOLA FUNZIONALE ("Valore fisso 'PP'")
    {{ custom_to_timestamp_ntz('T.CREATIONDATE') }} AS TS_CREAZIONE,
    T.IPADDRESS AS CD_IP_ADDRESS,
    CASE WHEN T.MOBILE = 'True' THEN 'S' WHEN T.MOBILE = 'False' THEN 'N' ELSE NULL END AS FL_MOBILE, -- WARN: sorgente confermata booleano true/false; assunto formato stringa 'true'/'false' (da verificare se tipo BOOLEAN nativo, in tal caso confronto senza apici)
    T.BROKERCODE AS CD_INIZIATIVA_COMMERCIALE,
    {{ custom_to_decimal('T.AMOUNT', 15, 2) }} AS EU_IMPORTO_RICHIESTO, 
    TRY_CAST(T.RATE AS NUMBER(10)) AS NM_RATE,
    T.CAMPAIGNID AS CD_CAMPAGNA,
    T.LAYOUT AS TP_LAYOUT
FROM {{ ref('pp_session') }} T
 