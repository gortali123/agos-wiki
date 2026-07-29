SELECT
    CT.BAPCT_NUM_PRATICA AS CD_PRATICA,
    CT.BAPCT_PROCEDURA AS TP_PROCEDURA,
    -- TODO: riceviamo 0, perchè?
    {{ custom_to_timestamp_ntz('CT.BAPCT_DATA_VAR', 'CT.BAPCT_ORA_VAR', 'current') }}
        AS TS_INSERIMENTO,
    CT.BAPCT_CONTROPARTE AS CD_CONTROPARTE,
    CT.BAPCT_RAPPORTO AS TP_RAPPORTO,
    CT.LASTMODIFIEDDATA
FROM {{ ref('bapratct') }} AS CT
{% if is_incremental() %}
    WHERE
        CT.LASTMODIFIEDDATA
        > (
            SELECT COALESCE(MAX(LASTMODIFIEDDATA), '1900-01-01'::TIMESTAMP_NTZ)
            FROM {{ this }}
        )
{% endif %}
