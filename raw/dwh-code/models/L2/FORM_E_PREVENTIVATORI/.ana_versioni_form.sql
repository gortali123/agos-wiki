SELECT
    F.FORMID AS CD_FORM,
    F.VERSION AS NR_VERSIONE,
    F.STEPNUMBER AS NR_STEP,
    F.STEPDESCRIPTION AS DS_STEP,
    F.STEPORDER AS NR_ORDINE_STEP,
    F.STEPTYPE AS CD_TIPO_STEP,
    F.ACTIVE AS FL_ATTIVO,
    {{ custom_to_date('F.VALIDFROM') }} AS DT_INIZIO_VALIDITA,
    {{ custom_to_date('F.VALIDTO') }} AS DT_FINE_VALIDITA,
    NULL AS TP_FORM -- WARN: TAB presente ma COL vuota nel data model, nessuna sorgente indicata
FROM {{ ref('primeweb_form_version') }} F
-- WARN: nessun campo tecnico di storicizzazione (LASTMODIFIEDDATA/TS_INIZIO_VALIDITA/DT_OSSERVAZIONE) nel data model; trattata come S4 (insert_overwrite, nessun filtro incrementale), da confermare col team
