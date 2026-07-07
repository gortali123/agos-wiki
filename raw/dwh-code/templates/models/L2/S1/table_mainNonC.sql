WITH base AS (
    SELECT
        T.<pk_col> AS <CD_PK>,
        {{ custom_to_timestamp_ntz('T.<data_col>', 'T.<ora_col>') }} AS TS_INIZIO_VALIDITA,
        {{ ts_fine_validita('T.<pk_col>', to_timestamp_ntz('T.<data_col>', 'T.<ora_col>')) }} AS TS_FINE_VALIDITA,
        T.<col1> AS <CAMPO1>,
        T.<col2> AS <CAMPO2>,
        T.LASTMODIFIEDDATA AS LASTMODIFIEDDATA
    FROM {{ ref('<L1_table>') }} T
),

dedup AS (
    SELECT
        <CD_PK>,
        TS_INIZIO_VALIDITA,
        TS_FINE_VALIDITA,
        <CAMPO1>,
        <CAMPO2>,
        LASTMODIFIEDDATA,
        {{ hash_cols([
            '<CD_PK>',
            '<CAMPO1>',
            '<CAMPO2>'
            -- tutti i campi di base esclusi TS_INIZIO_VALIDITA, TS_FINE_VALIDITA, LASTMODIFIEDDATA
        ]) }} AS HASHED_COLS
    FROM base
    {{ is_incremental_S1('<CD_PK>') }}
)

SELECT
    H.<CD_PK>,
    H.TS_INIZIO_VALIDITA,
    {{ ts_fine_validita('<CD_PK>', 'H.TS_INIZIO_VALIDITA') }} AS TS_FINE_VALIDITA,
    H.<CAMPO1>,
    H.<CAMPO2>,
    H.LASTMODIFIEDDATA
FROM dedup H
