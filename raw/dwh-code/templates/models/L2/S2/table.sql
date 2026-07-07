SELECT
    T.<pk_col> AS <CD_PK>,
    {{ custom_to_timestamp_ntz('T.<ts_inserimento_col>') }} AS TS_INSERIMENTO,
    T.<col1> AS <CAMPO1>,
    T.<col2> AS <CAMPO2>,
    T.LASTMODIFIEDDATA AS LASTMODIFIEDDATA
FROM {{ ref('<L1_table>') }} T

{% if is_incremental() %}
WHERE T.LASTMODIFIEDDATA > (SELECT COALESCE(MAX(LASTMODIFIEDDATA), '1900-01-01'::TIMESTAMP_NTZ) FROM {{ this }})
{% endif %}
