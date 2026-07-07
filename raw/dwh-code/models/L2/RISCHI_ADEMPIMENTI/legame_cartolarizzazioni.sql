WITH base AS (
    SELECT
        P.SCPRA_NUM_PRATICA AS CD_PRATICA,
        O.DRPRA_PROVENIENZA AS TP_PROCEDURA, -- FIX: data model had 'VARCAHR(2)' per TIPO TP_PROCEDURA (typo per VARCHAR)
        NULLIF(
            GREATEST(
                COALESCE({{ custom_to_date('P.SCPRA_DATA_CESSIONE') }},        TO_DATE('19000101','YYYYMMDD')),
                COALESCE({{ custom_to_date('P.SCPRA_DATA_CHIUSURA_TRANS') }},  TO_DATE('19000101','YYYYMMDD')),
                COALESCE({{ custom_to_date('P.SCPRA_DATA_RIACQUISTO') }},      TO_DATE('19000101','YYYYMMDD'))
            ),
            TO_DATE('19000101','YYYYMMDD')
        ) AS DT_OSSERVAZIONE,
        O.DRPRA_PRATICA AS CD_PRATICA_CARTOLARIZZATA, -- WARN: CD_PRATICA_CARTOLARIZZATA - RT mancante del campo SELECT ('SELECT FROM PLSECPRST INNER JOIN OXDRFPRA ON (...)'); usato COL=DRPRA_PRATICA
        O.LASTMODIFIEDDATA AS LASTMODIFIEDDATA
    FROM {{ ref('oxdrfpra') }} O
    INNER JOIN {{ ref('plsecprst') }} P ON P.SCPRA_NUM_PRATICA + 7000000000 = O.DRPRA_PRATICA
)
SELECT
    CD_PRATICA,
    TP_PROCEDURA,
    DT_OSSERVAZIONE,
    CD_PRATICA_CARTOLARIZZATA,
    LASTMODIFIEDDATA
FROM base
{% if is_incremental() %}
WHERE DT_OSSERVAZIONE = {{ last_day_past_month() }}
{% endif %}
