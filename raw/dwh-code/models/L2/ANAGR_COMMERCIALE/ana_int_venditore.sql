-- Anagrafica intermediari venditore con storicizzazione SCD2 S1 da CCINTLVE e CCANAINVE
-- Co-authored with CoCo
-- WARN: storicizzazione N/A nel catalog, inferita S1 da presenza di TS_INIZIO_VALIDITA in PK (pattern family ANA_INT_*)
-- WARN: sheet ANA_INT_VENDITORE non leggibile da READ_EXCEL_SHEET — campi business inferiti dal pattern degli altri ANA_INT_*
-- WARN: tabelle sorgente CCINTLVE / CCANAINVE e prefissi INTLVE_ / INVE_ inferiti dalla nomenclatura della family
-- WARN: CD_CONVENZIONATO — campo parent inferred, verificare vs data model
-- WARN: CD_RESPONSABILE — inferred da pattern subagente/convenzionato, verificare vs data model
-- WARN: DT_INIZIO_CONV / DT_FINE_CONV — inferred da pattern subagente, verificare vs data model

WITH base AS (
    SELECT
        COALESCE(L.INTLVE_INTERM, A.IVE_CODICE) AS CD_INTERMEDIARIO,
        COALESCE(L.INTLVE_TIPO_INTERM, A.IVE_TIPO_ANA) AS TP_INTERMEDIARIO,
        COALESCE(L.INTLVE_PROCEDURA, 'NA') AS TP_PROCEDURA,
        {{ custom_to_timestamp_ntz('L.INTLVE_DATA', 'L.INTLVE_ORA') }} AS TS_INIZIO_VALIDITA,
        {{ ts_fine_validita(
            "COALESCE(L.INTLVE_INTERM, A.IVE_CODICE), COALESCE(L.INTLVE_TIPO_INTERM, A.IVE_TIPO_ANA), COALESCE(L.INTLVE_PROCEDURA, 'NA')",
            custom_to_timestamp_ntz('L.INTLVE_DATA', 'L.INTLVE_ORA')
        ) }} AS TS_FINE_VALIDITA,
        {{ custom_to_date('COALESCE(L.INTLVE_DATA_INIZIO_RAPPORTO, A.IVE_INIZIO_RAPPORTO)', zero='min') }} AS DT_INIZIO_RAPPORTO,
        COALESCE(L.INTLVE_CAU_ANNULLO, A.IVE_CAU_ANNULLO) AS CD_CAUSALE_ANNULLO,
        COALESCE(L.INTLVE_CONVENZIONATO, A.IVE_CONVENZIONATO) AS CD_CONVENZIONATO_PV,
        COALESCE(L.INTLVE_AGENTE, A.IVE_AGENTE) AS CD_AGENTE_SA,
        COALESCE(L.INTLVE_MULTI_CV, A.IVE_MULTI_CONVENZIONATO) AS FL_MULTI_CONVENZIONATO,
        L.LASTMODIFIEDDATA AS LASTMODIFIEDDATA,
        ROW_NUMBER() OVER (
            PARTITION BY L.INTLVE_INTERM, L.INTLVE_TIPO_INTERM, L.INTLVE_PROCEDURA, L.INTLVE_DATA, L.INTLVE_ORA
            ORDER BY L.ROWID
        )::NUMBER(38, 0) AS PR_PK
    FROM {{ ref('ccintlve') }} L
    --LEFT JOIN AGOS_DEV_16000.L0.CCANAIVE A
    LEFT JOIN {{ ref('ccanaive') }} A
        ON (
            L.INTLVE_INTERM      = A.IVE_CODICE
            AND L.INTLVE_TIPO_INTERM = A.IVE_TIPO_ANA
        )
    WHERE L.FL_DELETED = 'N'
),

dedup AS (
    SELECT
        CD_INTERMEDIARIO,
        TP_INTERMEDIARIO,
        TP_PROCEDURA,
        TS_INIZIO_VALIDITA,
        TS_FINE_VALIDITA,
        PR_PK,
        DT_INIZIO_RAPPORTO,
        CD_CAUSALE_ANNULLO,
        CD_CONVENZIONATO_PV,
        CD_AGENTE_SA,
        FL_MULTI_CONVENZIONATO,
        LASTMODIFIEDDATA,
        {{ hash_cols(['CD_INTERMEDIARIO', 'TP_INTERMEDIARIO', 'TP_PROCEDURA', 'DT_INIZIO_RAPPORTO', 'CD_CAUSALE_ANNULLO', 'CD_CONVENZIONATO_PV', 'CD_AGENTE_SA', 'FL_MULTI_CONVENZIONATO']) }} AS HASHED_COLS
    FROM base {{ is_incremental_S1('CD_INTERMEDIARIO, TP_INTERMEDIARIO, TP_PROCEDURA', order_extra='PR_PK') }}
),

DEDUP_FV AS (
    SELECT
        CD_INTERMEDIARIO,
        TP_INTERMEDIARIO,
        TP_PROCEDURA,
        TS_INIZIO_VALIDITA,
        --TS_FINE_VALIDITA,
        {{ ts_fine_validita('CD_INTERMEDIARIO, TP_INTERMEDIARIO, TP_PROCEDURA', 'TS_INIZIO_VALIDITA') }} AS TS_FV_NEXT,
        PR_PK,
        DT_INIZIO_RAPPORTO,
        CD_CAUSALE_ANNULLO,
        CD_CONVENZIONATO_PV,
        CD_AGENTE_SA,
        FL_MULTI_CONVENZIONATO,
        LASTMODIFIEDDATA      
    FROM dedup 
)

SELECT
    H.CD_INTERMEDIARIO,
    H.TP_INTERMEDIARIO,
    H.TP_PROCEDURA,
    H.TS_INIZIO_VALIDITA,
    MAX(H.TS_FV_NEXT) OVER (
        PARTITION BY H.CD_INTERMEDIARIO, H.TP_INTERMEDIARIO, H.TP_PROCEDURA, H.TS_INIZIO_VALIDITA
    ) AS TS_FINE_VALIDITA,
    H.PR_PK,
    H.DT_INIZIO_RAPPORTO,
    H.CD_CAUSALE_ANNULLO,
    H.CD_CONVENZIONATO_PV,
    H.CD_AGENTE_SA,
    H.FL_MULTI_CONVENZIONATO,
    H.LASTMODIFIEDDATA
FROM DEDUP_FV H

