WITH base AS (

    SELECT
        T.CD_CONTROPARTE                                   AS CD_CONTROPARTE,
        T.CD_CANALE                                         AS CD_CANALE,
        T.TS_COMUNICAZIONE                                  AS TS_COMUNICAZIONE,
        {{ custom_to_timestamp_ntz('T.TS_CREAZIONE', '00000000') }} AS TS_INIZIO_VALIDITA,
        {{ ts_fine_validita('CD_CONTROPARTE, CD_CANALE, TS_COMUNICAZIONE', custom_to_timestamp_ntz('T.TS_CREAZIONE', '00000000')) }}      AS TS_FINE_VALIDITA,
        T.CD_SORGENTE                                       AS CD_SORGENTE,
        T.CD_THREAD                                         AS CD_THREAD,
        T.CD_MESSAGE                                        AS CD_MESSAGE,
        T.CD_BROADLOG                                        AS CD_BROADLOG,
        T.NM_VERSIONE                                       AS NM_VERSIONE,
        T.TP_COMUNICAZIONE                                  AS TP_COMUNICAZIONE,
        T.DS_COMUNICAZIONE                                  AS DS_COMUNICAZIONE,
        T.CD_UTENTE_CREAZIONE                               AS CD_UTENTE_CREAZIONE,
        T.CD_UTENTE_MODIFICA                                AS CD_UTENTE_MODIFICA,
        {{ custom_to_timestamp_ntz('T.TS_MODIFICA', '00000000') }}   AS LASTMODIFIEDDATA -- ho messo datamodifica ma bho
    --FROM { re('contact_history') }} T

),

dedup AS (

    SELECT
        CD_CONTROPARTE,
        CD_CANALE,
        TS_COMUNICAZIONE,
        TS_INIZIO_VALIDITA,
        TS_FINE_VALIDITA,
        CD_SORGENTE,
        CD_THREAD,
        CD_MESSAGE,
        CD_BROADLOG,
        NM_VERSIONE,
        TP_COMUNICAZIONE,
        DS_COMUNICAZIONE,
        CD_UTENTE_CREAZIONE,
        CD_UTENTE_MODIFICA,
        LASTMODIFIEDDATA,
        {{ hash_cols(['CD_CONTROPARTE', 'CD_CANALE', 'TS_COMUNICAZIONE', 'CD_SORGENTE', 'CD_THREAD', 'CD_MESSAGE', 'CD_BROADLOG', 'NM_VERSIONE', 'TP_COMUNICAZIONE', 'DS_COMUNICAZIONE', 'CD_UTENTE_CREAZIONE', 'CD_UTENTE_MODIFICA']) }} AS HASHED_COLS
    FROM base
    {{ is_incremental_S1('CD_CONTROPARTE, CD_CANALE, TS_COMUNICAZIONE') }}

)

SELECT
    H.CD_CONTROPARTE                                    AS CD_CONTROPARTE,
    H.CD_CANALE                                          AS CD_CANALE,
    H.TS_COMUNICAZIONE                                   AS TS_COMUNICAZIONE,
    H.TS_INIZIO_VALIDITA                                 AS TS_INIZIO_VALIDITA,
    {{ ts_fine_validita('H.CD_CONTROPARTE, H.CD_CANALE, H.TS_COMUNICAZIONE', 'H.TS_INIZIO_VALIDITA') }} AS TS_FINE_VALIDITA,
    H.CD_SORGENTE                                        AS CD_SORGENTE,
    H.CD_THREAD                                          AS CD_THREAD,
    H.CD_MESSAGE                                         AS CD_MESSAGE,
    H.CD_BROADLOG                                        AS CD_BROADLOG,
    H.NM_VERSIONE                                        AS NM_VERSIONE,
    H.TP_COMUNICAZIONE                                   AS TP_COMUNICAZIONE,
    H.DS_COMUNICAZIONE                                   AS DS_COMUNICAZIONE,
    H.CD_UTENTE_CREAZIONE                                AS CD_UTENTE_CREAZIONE,
    H.CD_UTENTE_MODIFICA                                 AS CD_UTENTE_MODIFICA,
    H.LASTMODIFIEDDATA                                   AS LASTMODIFIEDDATA
FROM dedup H