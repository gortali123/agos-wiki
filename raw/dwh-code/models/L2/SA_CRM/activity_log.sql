-- WARN: ACTIVITY_LOG compare nel Catalogo Entità sia sotto subject area CAMPAGNE
-- che Comunicazioni; scelto Comunicazioni sulla base del MODULO OCS "CMN - Comunicazioni"
-- presente su tutti i campi del foglio. Storicizzazione S1 e cluster C indicati
-- dall'utente (nel data model la storicizzazione risulta N/A).

WITH base AS (

    SELECT
        T.ID as ID,
        T.ID_APPLICAZIONE as ID_APPLICAZIONE,
        T.ID_FUNZIONE as ID_FUNZIONE,
        T.TS_CREAZIONE     AS TS_INIZIO_VALIDITA,
        {{ ts_fine_validita('T.ID','T.TS_CREAZIONE') }}      AS TS_FINE_VALIDITA,
        T.DS_DESCRIZIONE as DS_DESCRIZIONE,
        T.CD_USER_CREAZIONE as CD_USER_CREAZIONE,
        T.CD_USER_MODIFICA as CD_USER_MODIFICA,
        T.TS_MODIFICA as LASTMODIFIEDDATA

    --from { re('4414_activity_log') }} as T
    --WHERE T.FL_DELETED = 'N'

),

dedup AS (

    SELECT
        ID,
        ID_APPLICAZIONE,
        ID_FUNZIONE,
        TS_INIZIO_VALIDITA,
        TS_FINE_VALIDITA,
        DS_DESCRIZIONE,
        CD_USER_CREAZIONE,
        CD_USER_MODIFICA,
        LASTMODIFIEDDATA,
        {{ hash_cols(['ID', 'ID_APPLICAZIONE', 'ID_FUNZIONE', 'DS_DESCRIZIONE', 'CD_USER_CREAZIONE', 'CD_USER_MODIFICA']) }} as HASHED_COLS
    FROM base
    {{ is_incremental_S1('ID') }}

)

SELECT
    H.ID AS ID,
    H.ID_APPLICAZIONE AS ID_APPLICAZIONE,
    H.ID_FUNZIONE AS ID_FUNZIONE,
    H.TS_INIZIO_VALIDITA AS TS_INIZIO_VALIDITA,
    {{ ts_fine_validita('H.ID', 'H.TS_INIZIO_VALIDITA') }} AS TS_FINE_VALIDITA,
    H.DS_DESCRIZIONE AS DS_DESCRIZIONE,
    H.CD_USER_CREAZIONE AS CD_USER_CREAZIONE,
    H.CD_USER_MODIFICA AS CD_USER_MODIFICA,
    H.LASTMODIFIEDDATA AS LASTMODIFIEDDATA

FROM dedup AS H