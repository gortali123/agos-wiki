WITH base_raw AS (

    SELECT
        F.FormRequestId::VARCHAR AS CD_FORM,
        'PP' AS TP_FORM,
        F.Session_UID AS CD_SESSIONE,
        F.CreationDate AS TS_INIZIO_VALIDITA,
        F.CD_PRATICA::VARCHAR AS CD_PRATICA,
        F.BrokerCode AS CD_BROKER,
        F.SubsidiaryCode AS CD_FILIALE,
        'CO' AS TP_PROCEDURA,
        F.FormRequestState AS TP_STATO_FORM,
        NULL AS DS_ESITO_FORM,
        F.CreationDate AS TS_CREAZIONE,
        F.IpAddress AS CD_IP_ADDRESS,
        F.Mobile AS FL_MOBILE,
        F.IM_IMFIN AS EU_IMPORTO_FINANZIATO,
        F.NM_NMRATE AS NM_RATE,
        F.FL_DATI_MARK AS FL_CONSENSO_MARKETING,
        F.FL_DATI_PERS AS FL_CONSENSO_DATI_PERS,
        F.digitalsign AS FL_FIRMA_DIGITALE,
        F.campaignid AS CD_CAMPAGNA, 
        NULL AS CD_MERCHANT,
        NULL AS DS_PRODOTTO_FINANZIATO,
        F.cd_cdtppagcli AS CD_TIPO_PAGAMENTO, 
        F.iban AS CD_IBAN 
    FROM AGOS_DEV_16000.L1_E_PWB.PRIMEWEB_FORM_ECOM_TEST AS F

    union 
    
    SELECT
        F.FormRequestId::VARCHAR AS CD_FORM,
        'CA' AS TP_FORM,
        F.Session_UID AS CD_SESSIONE,
        TRY_TO_TIMESTAMP_NTZ(F.CreationDate, 'YYYYMMDD HH24MISS') AS TS_INIZIO_VALIDITA,
        F.CD_PRATICA::VARCHAR AS CD_PRATICA,
        NULL AS CD_BROKER,
        NULL AS CD_FILIALE,
        'CA' AS TP_PROCEDURA,
        F.FormRequestState AS TP_STATO_FORM,
        NULL AS DS_ESITO_FORM,
        TRY_TO_TIMESTAMP_NTZ(F.CreationDate, 'YYYYMMDD HH24MISS') AS TS_CREAZIONE,
        F.IpAddress AS CD_IP_ADDRESS,
        CASE WHEN F.mobile = 'True' THEN 'S' WHEN F.mobile = 'False' THEN 'N' ELSE NULL END AS FL_MOBILE,
        NULL AS EU_IMPORTO_FINANZIATO,
        NULL AS NM_RATE,
        CASE WHEN F.FL_DATI_MARK = 'True' THEN 'S' WHEN F.FL_DATI_MARK = 'False' THEN 'N' ELSE NULL END AS FL_CONSENSO_MARKETING,
        CASE WHEN F.FL_DATI_PERS = 'True' THEN 'S' WHEN F.FL_DATI_PERS = 'False' THEN 'N' ELSE NULL END AS FL_CONSENSO_DATI_PERS,
        CASE WHEN F.digitalsign = 'True' THEN 'S' WHEN F.digitalsign = 'False' THEN 'N' ELSE NULL END  AS FL_FIRMA_DIGITALE,
        NULL AS CD_CAMPAGNA, 
        NULL AS CD_MERCHANT,
        NULL AS DS_PRODOTTO_FINANZIATO,
        F.cd_cdtppagcli AS CD_TIPO_PAGAMENTO, 
        F.iban AS CD_IBAN 
    FROM {{ ref('carte') }} AS F

    union 

        SELECT
        F.FormRequestId::VARCHAR AS CD_FORM,
        'CQ' AS TP_FORM,
        F.Session_UID AS CD_SESSIONE,
        TRY_TO_TIMESTAMP_NTZ(F.CreationDate, 'YYYYMMDD HH24MISS') AS TS_INIZIO_VALIDITA,
        NULL AS CD_PRATICA,
        NULL AS CD_BROKER,
        NULL AS CD_FILIALE,
        'CQ' AS TP_PROCEDURA,
        F.FormRequestState AS TP_STATO_FORM,
        NULL AS DS_ESITO_FORM,
        TRY_TO_TIMESTAMP_NTZ(F.CreationDate, 'YYYYMMDD HH24MISS') AS TS_CREAZIONE,
        F.IpAddress AS CD_IP_ADDRESS,
        CASE WHEN F.mobile = 'True' THEN 'S' WHEN F.mobile = 'False' THEN 'N' ELSE NULL END AS FL_MOBILE,
        F.amountfinanced AS EU_IMPORTO_FINANZIATO,
        f.paymentsplit AS NM_RATE,
        CASE WHEN F.DATIMARK = 'True' THEN 'S' WHEN F.DATIMARK = 'False' THEN 'N' ELSE NULL END AS FL_CONSENSO_MARKETING,
        CASE WHEN F.DATIPERS = 'True' THEN 'S' WHEN F.DATIPERS = 'False' THEN 'N' ELSE NULL END AS FL_CONSENSO_DATI_PERS,
        NULL AS FL_FIRMA_DIGITALE,
        NULL AS CD_CAMPAGNA, 
        NULL AS CD_MERCHANT,
        NULL AS DS_PRODOTTO_FINANZIATO,
        NULL AS CD_TIPO_PAGAMENTO, 
        NULL AS CD_IBAN 
    FROM {{ ref('cq') }} AS F
),

base as (
    select *, --TODO: rimuovere *
        {{ ts_fine_validita('CD_FORM, TP_FORM, TP_PROCEDURA','TS_INIZIO_VALIDITA') }} AS TS_FINE_VALIDITA
    from base_raw
),

dedup AS (

    SELECT
        CD_FORM,
        TP_FORM,
        CD_SESSIONE,
        TS_INIZIO_VALIDITA,
        TS_FINE_VALIDITA,
        CD_PRATICA,
        CD_BROKER,
        CD_FILIALE,
        TP_PROCEDURA,
        TP_STATO_FORM,
        DS_ESITO_FORM,
        TS_CREAZIONE,
        CD_IP_ADDRESS,
        FL_MOBILE,
        EU_IMPORTO_FINANZIATO,
        NM_RATE,
        FL_CONSENSO_MARKETING,
        FL_CONSENSO_DATI_PERS,
        FL_FIRMA_DIGITALE,
        CD_CAMPAGNA,
        CD_MERCHANT,
        DS_PRODOTTO_FINANZIATO,
        CD_TIPO_PAGAMENTO,
        CD_IBAN,

        {{ hash_cols([
            'CD_FORM',
            'TP_FORM',
            'CD_SESSIONE',
            'CD_PRATICA',
            'CD_BROKER',
            'CD_FILIALE',
            'TP_PROCEDURA',
            'TP_STATO_FORM',
            'DS_ESITO_FORM',
            'TS_CREAZIONE',
            'CD_IP_ADDRESS',
            'FL_MOBILE',
            'EU_IMPORTO_FINANZIATO',
            'NM_RATE',
            'FL_CONSENSO_MARKETING',
            'FL_CONSENSO_DATI_PERS',
            'FL_FIRMA_DIGITALE',
            'CD_CAMPAGNA',
            'CD_MERCHANT',
            'DS_PRODOTTO_FINANZIATO',
            'CD_TIPO_PAGAMENTO',
            'CD_IBAN'
        ]) }} AS HASHED_COLS

    FROM base

    {{ is_incremental_S1('CD_FORM,TP_FORM,TP_PROCEDURA', lastmodified='TS_INIZIO_VALIDITA') }}

)

SELECT
    H.CD_FORM,
    H.TP_FORM,
    H.CD_SESSIONE,
    H.TS_INIZIO_VALIDITA,
    {{ ts_fine_validita('CD_FORM, TP_FORM, TP_PROCEDURA','TS_INIZIO_VALIDITA') }} AS TS_FINE_VALIDITA,
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

FROM dedup AS H

-- WARN: nessun attributo sorgente disponibile per determinare
-- TS_FINE_VALIDITA; valorizzata convenzionalmente a 9999-12-31.