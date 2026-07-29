{#
Dovrà essere verificato su YQNGRANT se aperta (condizione NGRANT_DATA_FINE = 0) una delle segnalazioni di Probation period da default
- Probation period (90 giorni)
- Probation period (estensione)
- Probation period (sospensione).
Se verificata tale condizione si dovrà ricercare se presente su YQNGRANT per il cliente una delle segnalazioni sopra indicate con NGRANT_DATA_FINE = NGRANT_DATA_INIZIO della segnalazione precedente e procedere così in modo ricorsivo fino a determinare la prima segnalazione di Probation period aperta.
Il campo verrà valorizzato con la data NGRANT_DATA_INIZIO di tale segnalazione

RIGA 162
#}
WITH
-- Lettura OXCTFFBT: record con progressivo massimo e data annullo non valorizzata
-- FIX: data model had 'OXCTFBT' (single F) → corretto in 'OXCTFFBT' (doppia F, coerente con catalogo e CFG_L1_SCHEMA)
OXCTFBT_ATTIVI AS (
    SELECT
        T.OXCTFBT_PROCEDURA,
        T.OXCTFBT_NUM_PRATICA,
        T.OXCTFBT_DATA_INGRESSO,
        T.OXCTFBT_DATA_USCITA
    FROM (
        SELECT
            T2.OXCTFBT_PROCEDURA,
            T2.OXCTFBT_NUM_PRATICA,
            T2.OXCTFBT_DATA_INGRESSO,
            T2.OXCTFBT_DATA_USCITA,
            MAX(T2.OXCTFBT_PROGRESSIVO) OVER (
                PARTITION BY T2.OXCTFBT_PROCEDURA,
                             T2.OXCTFBT_NUM_PRATICA
            ) AS OXCTFBT_PROGRESSIVO_MAX,
            T2.OXCTFBT_PROGRESSIVO
        FROM {{ ref('oxctffbt') }} T2
        WHERE T2.OXCTFBT_DATA_ANNULLO IS NOT NULL
    ) T
    WHERE T.OXCTFBT_PROGRESSIVO = T.OXCTFBT_PROGRESSIVO_MAX
),
-- Lettura OXCTFFBL: primo record con stato FP* o SN* per progressivo decrescente e data annullo non valorizzata
-- FIX: data model had 'OXCTFBL' (single F) → corretto in 'OXCTFFBL'; CTE rinominata OXCTFBL_FB (da OXCTFBL_ATTIVI) per disambiguare da OXCTFBL_FN
-- FIX: data model had 'OXCTFFBL' (single F) → corretto in 'OXCTFFBL'
OXCTFBL_FB AS (
    SELECT
        T.OXCTFBL_PROCEDURA,
        T.OXCTFBL_NUM_PRATICA,
        T.OXCTFBL_DATA
    FROM (
        SELECT
            T2.OXCTFBL_PROCEDURA,
            T2.OXCTFBL_NUM_PRATICA,
            T2.OXCTFBL_DATA,
            T2.OXCTFBL_STATO,
            T2.FL_DELETED,
            ROW_NUMBER() OVER (
                PARTITION BY T2.OXCTFBL_PROCEDURA,
                             T2.OXCTFBL_NUM_PRATICA
                ORDER BY     T2.OXCTFBL_PROGRESSIVO DESC
            ) AS RN
        FROM {{ ref('oxctffbl') }} T2
        WHERE T2.OXCTFBL_DATA_ANNULLO IS NOT NULL
        AND (   T2.OXCTFBL_STATO LIKE 'FP%'
               OR T2.OXCTFBL_STATO LIKE 'SN%')
        AND T2.FL_DELETED = 'N'
    ) T
    WHERE T.RN = 1
),
-- Lettura OXCTFFBL: primo record con stato FN* per progressivo decrescente e data annullo non valorizzata
OXCTFBL_FN AS (
    SELECT
        T.OXCTFBL_PROCEDURA,
        T.OXCTFBL_NUM_PRATICA,
        T.OXCTFBL_DATA
    FROM (
        SELECT
            T2.OXCTFBL_PROCEDURA,
            T2.OXCTFBL_NUM_PRATICA,
            T2.OXCTFBL_DATA,
            T2.OXCTFBL_STATO,
            T2.FL_DELETED,
            ROW_NUMBER() OVER (
                PARTITION BY T2.OXCTFBL_PROCEDURA,
                             T2.OXCTFBL_NUM_PRATICA
                ORDER BY     T2.OXCTFBL_PROGRESSIVO DESC
            ) AS RN
        FROM {{ ref('oxctffbl') }} T2
        WHERE T2.OXCTFBL_DATA_ANNULLO IS NOT NULL
        AND T2.OXCTFBL_STATO LIKE 'FN%'
        AND T2.FL_DELETED = 'N'
    ) T
    WHERE T.RN = 1
),
-- Lettura OXCTFFBP: primo record per progressivo decrescente e data annullo non valorizzata
-- FIX: data model had 'OXCTFBP' (single F) → corretto in 'OXCTFFBP'
OXCTFBP_ATTIVI AS (
    SELECT
        T.OXCTFBP_CLIENTE,
        T.OXCTFBP_DATA_INIZIO,
        T.OXCTFBP_DATA_USCITA,
        T.OXCTFBP_DATA_FINE
    FROM (
        SELECT
            T2.OXCTFBP_CLIENTE,
            T2.OXCTFBP_DATA_INIZIO,
            T2.OXCTFBP_DATA_USCITA,
            T2.OXCTFBP_DATA_FINE,
            ROW_NUMBER() OVER (
                PARTITION BY T2.OXCTFBP_CLIENTE
                ORDER BY     T2.OXCTFBP_PROGRESSIVO DESC
            ) AS RN
        FROM {{ ref('oxctffbp') }} T2
        WHERE T2.OXCTFBP_DATA_ANNULLO IS NOT NULL
    ) T
    WHERE T.RN = 1
),
-- Periodo di observation: ingresso (basato su STATO_CREDITIZIO_M)
OBS_INGRS AS (
    SELECT
        sa_aperta.CD_CONTROPARTE,
        COALESCE(sa_pdp.DT_INIZIO, sa_aperta.DT_INIZIO) AS DT_INIZIO_PROBATION_ORIGINE
    FROM {{ ref('segnalazioni_anagrafiche') }} sa_aperta
    INNER JOIN {{ ref('stato_creditizio_m') }} cde
        ON  cde.CD_CONTROPARTE = sa_aperta.CD_CONTROPARTE
        AND cde.FL_DFLT_EBA    = 'S'
    LEFT JOIN {{ ref('segnalazioni_anagrafiche') }} sa_pds
        ON  sa_pds.CD_CONTROPARTE  = sa_aperta.CD_CONTROPARTE
        AND sa_pds.TP_SEGNALAZIONE = 'PDS'
        AND sa_pds.DT_FINE         IS NULL
    LEFT JOIN {{ ref('segnalazioni_anagrafiche') }} sa_pde
        ON  sa_pde.CD_CONTROPARTE  = sa_aperta.CD_CONTROPARTE
        AND sa_pde.TP_SEGNALAZIONE = 'PDE'
        AND sa_pde.DT_FINE         = COALESCE(sa_pds.DT_INIZIO, sa_aperta.DT_INIZIO)
    LEFT JOIN {{ ref('segnalazioni_anagrafiche') }} sa_pdp
        ON  sa_pdp.CD_CONTROPARTE  = sa_aperta.CD_CONTROPARTE
        AND sa_pdp.TP_SEGNALAZIONE = 'PDP'
        AND sa_pdp.DT_FINE         = sa_pde.DT_INIZIO
    WHERE
        sa_aperta.DT_FINE IS NULL
        AND sa_aperta.TP_SEGNALAZIONE IN ('PDP', 'PDE', 'PDS')
),

CTE_RISCHIO AS (
    SELECT 
        FL_DFLT_EBA,
        CD_CONTROPARTE,
        CD_PRATICA
    FROM (
            SELECT 
                FL_DFLT_EBA,
                CD_CONTROPARTE,
                CD_PRATICA,
                DT_OSSERVAZIONE,
                ROW_NUMBER() OVER (
                    PARTITION BY CD_CONTROPARTE
                    ORDER BY DT_OSSERVAZIONE DESC
                ) AS rn
            FROM {{ ref('stato_creditizio_m') }}
           WHERE DT_OSSERVAZIONE = LAST_DAY(DATEADD(MONTH, -1, CURRENT_DATE())) AND  FL_DFLT_EBA = 'S' -- FIX LAST_DAY con riferimento a CURRENT_DATE
    )
    WHERE rn = 1
),

-- Periodo di observation: uscita (basato su STATO_CREDITIZIO_M)
OBS_USCITA AS (
    SELECT
        sa_aperta.CD_CONTROPARTE,
        COALESCE(sa_pds.DT_INIZIO, sa_pde.DT_INIZIO, sa_pdp.DT_INIZIO, sa_aperta.DT_INIZIO) AS DT_INIZIO_PROBATION_ORIGINE -- FIX
    FROM {{ ref('segnalazioni_anagrafiche') }} sa_aperta
    INNER JOIN CTE_RISCHIO cde
        ON  cde.CD_CONTROPARTE = sa_aperta.CD_CONTROPARTE
    LEFT JOIN {{ ref('segnalazioni_anagrafiche') }} sa_pds
        ON  sa_pds.CD_CONTROPARTE  = sa_aperta.CD_CONTROPARTE
        AND sa_pds.TP_SEGNALAZIONE = 'PDS'
        AND sa_pds.DT_FINE         IS NULL
    LEFT JOIN {{ ref('segnalazioni_anagrafiche') }} sa_pde
        ON  sa_pde.CD_CONTROPARTE  = sa_aperta.CD_CONTROPARTE
        AND sa_pde.TP_SEGNALAZIONE = 'PDE'
        AND sa_pde.DT_FINE         = COALESCE(sa_pds.DT_INIZIO, sa_aperta.DT_INIZIO)
    LEFT JOIN {{ ref('segnalazioni_anagrafiche') }} sa_pdp
        ON  sa_pdp.CD_CONTROPARTE  = sa_aperta.CD_CONTROPARTE
        AND sa_pdp.TP_SEGNALAZIONE = 'PDP'
        AND sa_pdp.DT_FINE         = sa_pde.DT_INIZIO
    WHERE
        sa_aperta.DT_FINE IS NULL
        AND sa_aperta.TP_SEGNALAZIONE IN ('PDP', 'PDE', 'PDS')
)

SELECT
    D.DRPRA_PRATICA AS CD_PRATICA,
    D.DRPRA_PROVENIENZA AS TP_PROCEDURA,
    -- FIX: DRPRA_DATA_ESTRAZIONE è NUMERIC in L1, cast a DATE
    {{ custom_to_date('D.DRPRA_DATA_ESTRAZIONE') }} AS DT_OSSERVAZIONE,
    D.DRPRA_CLIENTE AS CD_CLIENTE,
    -- FIX: OXCTFBT_DATA_INGRESSO è NUMERIC in L1, cast a DATE
    {{ custom_to_date('FBT.OXCTFBT_DATA_INGRESSO') }} AS DT_INGRS_FORBEARANCE,
    CASE
        -- FIX: data model had 'NA' (stringa incompatibile con tipo DATE) → sostituito con NULL
        WHEN D.DRPRA_FORBORNE = 'FO' THEN NULL
        -- FIX: OXCTFBT_DATA_USCITA è NUMERIC in L1, cast a DATE
        ELSE {{ custom_to_date('FBT.OXCTFBT_DATA_USCITA') }}
    END AS DT_USCITA_FORBEARANCE,
    -- FIX: OXCTFBL_DATA è NUMERIC in L1, cast a DATE
    COALESCE({{ custom_to_date('FBL.OXCTFBL_DATA') }}, TO_DATE('01/01/1900', 'DD/MM/YYYY')) AS DT_INGRS_PROBATION,
    COALESCE({{ custom_to_date('FBN.OXCTFBL_DATA') }}, TO_DATE('01/01/1900', 'DD/MM/YYYY')) AS DT_USCITA_PROBATION,
    CURRENT_DATE() AS DT_USCITA_PROBATION_STIMATA, -- WARN CURRENT_DATE() IN ATTESA DI DATA
    -- FIX: OXCTFBP_DATA_INIZIO/USCITA/FINE sono NUMERIC in L1, cast a DATE
    COALESCE({{ custom_to_date('FBP.OXCTFBP_DATA_INIZIO') }}, TO_DATE('01/01/1900', 'DD/MM/YYYY')) AS DT_INGRS_PURGATORY,
    -- FIX: data model had alias 'OXCTFBP_DATA_INIZIO' per DT_USCITA_PURGATORY → corretto riferimento a OXCTFBP_DATA_USCITA
    COALESCE({{ custom_to_date('FBP.OXCTFBP_DATA_USCITA') }}, TO_DATE('01/01/1900', 'DD/MM/YYYY')) AS DT_USCITA_PURGATORY,
    -- FIX: data model had alias 'OXCTFBP_DATA_INIZIO' per DT_USCITA_PURGATORY_STIMATA → corretto riferimento a OXCTFBP_DATA_FINE
    COALESCE({{ custom_to_date('FBP.OXCTFBP_DATA_FINE') }}, TO_DATE('01/01/1900', 'DD/MM/YYYY')) AS DT_USCITA_PURGATORY_STIMATA,
    OI.DT_INIZIO_PROBATION_ORIGINE AS DT_INGRS_OBSERVATION,
    OU.DT_INIZIO_PROBATION_ORIGINE AS DT_USCITA_OBSERVATION,
    D.DRPRA_FORBORNE AS FL_FORBEARANCE,
    D.DRPRA_STATUS_RISCHIO AS FL_PERFORMING,
    D.LASTMODIFIEDDATA AS LASTMODIFIEDDATA
FROM {{ ref('oxdrfpra') }} D
LEFT JOIN OXCTFBT_ATTIVI FBT
    ON  FBT.OXCTFBT_NUM_PRATICA = D.DRPRA_PRATICA
    AND FBT.OXCTFBT_PROCEDURA   = D.DRPRA_PROVENIENZA
LEFT JOIN OXCTFBL_FB FBL
    ON  FBL.OXCTFBL_NUM_PRATICA = D.DRPRA_PRATICA
    AND FBL.OXCTFBL_PROCEDURA   = D.DRPRA_PROVENIENZA
LEFT JOIN OXCTFBL_FN FBN
    ON  FBN.OXCTFBL_NUM_PRATICA = D.DRPRA_PRATICA
    AND FBN.OXCTFBL_PROCEDURA   = D.DRPRA_PROVENIENZA
LEFT JOIN OXCTFBP_ATTIVI FBP
    ON  FBP.OXCTFBP_CLIENTE = D.DRPRA_CLIENTE
LEFT JOIN OBS_INGRS OI
    ON  OI.CD_CONTROPARTE = D.DRPRA_CLIENTE
LEFT JOIN OBS_USCITA OU
    ON  OU.CD_CONTROPARTE = D.DRPRA_CLIENTE
WHERE D.FL_DELETED = 'N'
{% if is_incremental() %} 
AND DT_OSSERVAZIONE = {{ get_dt_osservazione() }} 
{% endif %} 
