SELECT
    OX.DRPRA_PRATICA AS CD_PRATICA,
    OX.DRPRA_PROVENIENZA AS TP_PROCEDURA,
    {{ custom_to_date('OX.DRPRA_DATA_ESTRAZIONE') }} AS DT_OSSERVAZIONE, -- FIX: DRPRA_DATA_ESTRAZIONE è NUMERIC in L1, cast a DATE
    OX.DRPRA_CLIENTE AS CD_CLIENTE,
    CASE 
        WHEN OX.DRPRA_FORBORNE = 'FO' 
        THEN 'Y'
        ELSE 'N' 
    END AS FL_FORBEARANCE,
    NULL AS CD_CATEGORIA_FORBEARANCE,
    NULL AS TP_RISTRUTTURAZIONE,
    TRY_TO_DATE('1900-01-01') AS DT_RISTRUTTURAZIONE, -- FIX: da castare a to_date() e selezionare campo corretto OP aperto
    NULL AS NM_VAN_A,
    NULL AS NM_VAN_B,
    NULL AS PC_DO,
    OX.LASTMODIFIEDDATA AS LASTMODIFIEDDATA
FROM {{ ref('oxdrfpra') }} OX
WHERE OX.FL_DELETED='N'
{% if is_incremental() %} 
AND DT_OSSERVAZIONE = {{ get_dt_osservazione() }}
{% endif %} 
