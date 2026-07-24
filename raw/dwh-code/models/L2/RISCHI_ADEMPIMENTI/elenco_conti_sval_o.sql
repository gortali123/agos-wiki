SELECT
    CONTO AS CD_CONTO,
    DT_INI_VAL AS DT_INI_VALI,
    DT_FINE_VAL AS DT_FINE_VALI
FROM {{ source('l1_e_bsn', 'lkp_elenco_conti') }}
