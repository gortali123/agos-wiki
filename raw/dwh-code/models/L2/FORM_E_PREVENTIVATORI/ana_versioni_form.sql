SELECT
    F.FORMID AS CD_FORM,
    F.VERSION AS NR_VERSIONE,
    F.STEPNUMBER AS NR_STEP,
    F.STEPDESCRIPTION AS DS_STEP,
    F.STEPORDER AS NR_ORDINE_STEP,
    F.STEPTYPE AS CD_TIPO_STEP,
    CASE WHEN F.active = 'True' THEN 'S' WHEN F.active = 'False' THEN 'N' ELSE NULL END AS FL_ATTIVO, -- WARN: sorgente confermata booleano true/false; assunto formato stringa 'true'/'false' (da verificare se tipo BOOLEAN nativo, in tal caso confronto senza apici)
    {{ custom_to_date('F.VALIDFROM') }} AS DT_INIZIO_VALIDITA,
    {{ custom_to_date('F.VALIDTO') }} AS DT_FINE_VALIDITA,
    NULL AS TP_FORM

FROM AGOS_DEV_16000.L1_E_PWB.PRIMEWEB_FORM_VERSION_TEST AS F
-- FROM { re('primeweb_form_ecom') }} F

-- WARN: TAB presente ma COL vuota nel data model,
-- nessuna sorgente indicata per TP_FORM

-- WARN: nessun campo tecnico di storicizzazione
-- (LASTMODIFIEDDATA/TS_INIZIO_VALIDITA/DT_OSSERVAZIONE)
-- nel data model; trattata come S4
-- (insert_overwrite, nessun filtro incrementale),
-- da confermare col team