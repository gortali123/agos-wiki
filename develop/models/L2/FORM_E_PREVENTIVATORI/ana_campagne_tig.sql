SELECT
    C.CAMPAIGNID AS CD_CAMPAGNA,
    C.NAME AS DS_CAMPAGNA,
    C.CD_INIZIATIVA_COMMERCIALE AS CD_INIZIATIVA_COMMERCIALE,
    C.CATEGORY AS CD_CATEGORIA,
    C.TYPE AS TP_CAMPAGNA,
    C.ROLE AS CD_RUOLO,
    C.ACTIVE AS FL_ATTIVA,
    C.SETSUBSIDIARYFROMZIPCODE AS FL_SUBSIDIARY_FROM_ZIP
FROM {{ ref('1005_primeweb_pp_campaign') }} C
-- WARN: nessun campo tecnico di storicizzazione (LASTMODIFIEDDATA/TS_INIZIO_VALIDITA/DT_OSSERVAZIONE) nel data model; trattata come S4 (insert_overwrite, nessun filtro incrementale), da confermare col team
