SELECT
    U.CD_USER_LOGIN AS CD_USER_LOGIN,
    U.CD_CPART AS CD_CPART,
    U.CD_ALIAS_LOGIN AS CD_ALIAS_LOGIN,
    {{ custom_to_timestamp_ntz('U.TS_LOGIN') }} AS TS_LOGIN,
    U.NM_ACCESSI AS NM_ACCESSI,
    U.NM_TENT AS NM_TENT,
    {{ custom_to_timestamp_ntz('U.TS_ULT_TENT') }} AS TS_ULT_TENT,
    U.IN_BLOCCO AS IN_BLOCCO,
    {{ custom_to_timestamp_ntz('U.TS_CAMBIO_PSW') }} AS TS_CAMBIO_PSW,
    {{ custom_to_timestamp_ntz('U.TS_FINE_VALI') }} AS TS_FINE_VALI,
    U.CD_USER_INSE AS CD_USER_INSE,
    U.CD_TRANS_INSE AS CD_TRANS_INSE,
    {{ custom_to_timestamp_ntz('U.TS_INSE') }} AS TS_INSE,
    U.CD_USER_VARZ AS CD_USER_VARZ,
    U.CD_TRANS_VARZ AS CD_TRANS_VARZ,
    {{ custom_to_timestamp_ntz('U.TS_VARZ') }} AS TS_VARZ
FROM {{ ref('4076_pct_user_psw') }} U
-- WARN: nessun LASTMODIFIEDDATA nel data model; trattata come S4 (insert_overwrite, nessun filtro incrementale), da confermare col team
