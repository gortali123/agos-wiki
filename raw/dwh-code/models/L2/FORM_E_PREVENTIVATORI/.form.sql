WITH base AS (

    SELECT
        F.FormRequestId AS CD_FORM,
        NULL AS TP_FORM, -- WARN: nessuna sorgente nel data model
        F.Session_UID AS CD_SESSIONE,
        {{ custom_to_timestamp_ntz() }} AS TS_INIZIO_VALIDITA,
        {{ ts_fine_validita('F.FormRequestId', custom_to_timestamp_ntz()) }} AS TS_FINE_VALIDITA,
        F.CD_PRATICA AS CD_PRATICA,
        NULL AS CD_BROKER, -- WARN: nessuna sorgente nel data model
        NULL AS CD_FILIALE, -- WARN: nessuna sorgente nel data model
        NULL AS TP_PROCEDURA, -- WARN: nessuna sorgente nel data model (campo PK)
        F.FormRequestState AS TP_STATO_FORM,
        F.CD_ESITO AS DS_ESITO_FORM,
        {{ custom_to_timestamp_ntz('F.CreationDate') }} AS TS_CREAZIONE,
        F.IpAddress AS CD_IP_ADDRESS,
        F.Mobile AS FL_MOBILE,
        {{ custom_to_decimal('F.IM_IMFIN', 15, 2) }} AS EU_IMPORTO_FINANZIATO,
        F.NM_NMRATE AS NM_RATE,
        F.FL_DATI_MARK AS FL_CONSENSO_MARKETING,
        F.FL_DATI_PERS AS FL_CONSENSO_DATI_PERS,
        NULL AS FL_FIRMA_DIGITALE, -- WARN: nessuna sorgente nel data model
        NULL AS CD_CAMPAGNA, -- WARN: nessuna sorgente nel data model
        F.Merchant AS CD_MERCHANT,
        F.Prodotto AS DS_PRODOTTO_FINANZIATO,
        NULL AS CD_TIPO_PAGAMENTO, -- WARN: nessuna sorgente nel data model
        NULL AS CD_IBAN -- WARN: nessuna sorgente nel data model
    FROM {{ ref('primeweb_form_ecom') }} F

)

, dedup AS (

    SELECT
        CD_FORM, TP_FORM, CD_SESSIONE, TS_INIZIO_VALIDITA, TS_FINE_VALIDITA, CD_PRATICA,
        CD_BROKER, CD_FILIALE, TP_PROCEDURA, TP_STATO_FORM, DS_ESITO_FORM, TS_CREAZIONE,
        CD_IP_ADDRESS, FL_MOBILE, EU_IMPORTO_FINANZIATO, NM_RATE, FL_CONSENSO_MARKETING,
        FL_CONSENSO_DATI_PERS, FL_FIRMA_DIGITALE, CD_CAMPAGNA, CD_MERCHANT,
        DS_PRODOTTO_FINANZIATO, CD_TIPO_PAGAMENTO, CD_IBAN,
        {{ hash_cols([
            'CD_FORM', 'TP_FORM', 'CD_SESSIONE', 'CD_PRATICA', 'CD_BROKER', 'CD_FILIALE',
            'TP_PROCEDURA', 'TP_STATO_FORM', 'DS_ESITO_FORM', 'TS_CREAZIONE', 'CD_IP_ADDRESS',
            'FL_MOBILE', 'EU_IMPORTO_FINANZIATO', 'NM_RATE', 'FL_CONSENSO_MARKETING',
            'FL_CONSENSO_DATI_PERS', 'FL_FIRMA_DIGITALE', 'CD_CAMPAGNA', 'CD_MERCHANT',
            'DS_PRODOTTO_FINANZIATO', 'CD_TIPO_PAGAMENTO', 'CD_IBAN'
        ]) }} AS HASHED_COLS
    FROM base
    {{ is_incremental_S1('CD_FORM') }}

)

SELECT
    H.CD_FORM,
    H.TP_FORM,
    H.CD_SESSIONE,
    H.TS_INIZIO_VALIDITA,
    {{ ts_fine_validita('H.CD_FORM', 'H.TS_INIZIO_VALIDITA') }} AS TS_FINE_VALIDITA,
    H.CD_PRATICA,
    H.CD_BROKER,
    H.CD_FILIALE,
    H.TP_PROCEDURA,
    H.TP_STATO_FORM,
    H.DS_ESITO_FORM,
    H.TS_CREAZIONE,
    H.CD_IP_ADDRESS,
    H.FL_MOBILE,
    H.EU_IMPORTO_FINANZIATO,
    H.NM_RATE,
    H.FL_CONSENSO_MARKETING,
    H.FL_CONSENSO_DATI_PERS,
    H.FL_FIRMA_DIGITALE,
    H.CD_CAMPAGNA,
    H.CD_MERCHANT,
    H.DS_PRODOTTO_FINANZIATO,
    H.CD_TIPO_PAGAMENTO,
    H.CD_IBAN
FROM dedup H
-- WARN: nessun LASTMODIFIEDDATA nel data model per questa entita', da chiarire col team
