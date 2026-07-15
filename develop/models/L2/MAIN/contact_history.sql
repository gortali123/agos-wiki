SELECT
    C.CD_CONTROPARTE AS CD_CONTROPARTE,
    C.CD_CANALE AS CD_CANALE,
    {{ custom_to_timestamp_ntz('C.TS_COMUNICAZIONE') }} AS TS_COMUNICAZIONE,
    C.CD_SORGENTE AS CD_SORGENTE,
    C.CD_THREAD AS CD_THREAD,
    C.CD_MESSAGE AS CD_MESSAGE,
    C.CD_BROADLOG AS CD_BROADLOG,
    C.NM_VERSIONE AS NM_VERSIONE,
    C.TP_COMUNICAZIONE AS TP_COMUNICAZIONE,
    C.DS_COMUNICAZIONE AS DS_COMUNICAZIONE,
    C.CD_UTENTE_CREAZIONE AS CD_UTENTE_CREAZIONE,
    {{ custom_to_timestamp_ntz('C.TS_CREAZIONE') }} AS TS_CREAZIONE,
    C.CD_UTENTE_MODIFICA AS CD_UTENTE_MODIFICA,
    {{ custom_to_timestamp_ntz('C.TS_MODIFICA') }} AS TS_MODIFICA
FROM {{ ref('crm_contact_history') }} C -- WARN: sorgente dichiarata 'CRM-ContactHistory (DynamoDB)', non un nome tabella Snowflake valido; nome modello dbt reale da confermare (probabile L1 ingestion di una sorgente DynamoDB, non presente in raw/dwh-code)
-- WARN: nessun campo tecnico di storicizzazione (LASTMODIFIEDDATA/DT_OSSERVAZIONE) nel data model; trattata come S4 (insert_overwrite, nessun filtro incrementale), da confermare col team
-- WARN: le colonne CHIAVI DI AGGANCIO dello sheet (es. 'FK: CD_CANALE -> LOOKUP_CANALE.CD_CANALE') descrivono relazioni concettuali a tabelle di lookup non presenti nel data model come sorgenti reali; non joinate, i codici restano non decodificati
