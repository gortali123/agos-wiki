SELECT
    A.CD_USER_LOGIN AS CD_CLIENTE,
    {{ custom_to_timestamp_ntz('A.TS_LOGIN') }} AS TS_LOGIN,
    A.CD_ID_SESSION AS CD_ID_SESSION,
    A.CD_IP AS CD_IP,
    {{ custom_to_timestamp_ntz('A.TS_LOGOUT') }} AS TS_LOGOUT,
    A.TP_LOGOUT AS TP_LOGOUT,
    A.DN_USER_AGENT_BROWSER_L AS DN_USER_AGENT_BROWSER_L,
    A.DN_USER_AGENT_BROWSER_C AS DN_USER_AGENT_BROWSER_C,
    A.DN_CANALE_RISPO AS DN_CANALE_RISPO
FROM {{ ref('4077_pct_accesso_utente') }} A
-- WARN: nessun campo tecnico di storicizzazione (LASTMODIFIEDDATA/DT_OSSERVAZIONE) nel data model; trattata come S4 (insert_overwrite, nessun filtro incrementale), da confermare col team
-- WARN: LENGTH dichiarato 'TBD' per tutti i campi nel data model; data type nello yml da fallback naming convention
