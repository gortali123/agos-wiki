-- SE FACCIO RUN SENZA ACCORDI VA

WITH
-- CTE per risalita gerarchica nodo aggiuntivo (CD_RETE_VENDITA_AGG, CD_AGENTE_AGG, CD_SUBAGENTE_AGG)
-- Fonte: CCINTICA, con lookup su CCANAISA / CCANAIAG / CCANAIRV
gerarchia_agg AS (
    SELECT
        m.INTICA_TIPO_INTERM,
        m.INTICA_INTERM,
        m.INTICA_TIPO_INTERM_A,
        m.INTICA_INTERM_A,
        sa.ISA_CODICE AS CD_SUBAGENTE_AGG,
        COALESCE(ag_dir.IAG_CODICE, ag_sa.IAG_CODICE) AS CD_AGENTE_AGG,
        COALESCE(rv.IRV_CODICE, ag_dir.IAG_RETE_VENDITA, ag_sa.IAG_RETE_VENDITA) AS CD_RETE_VENDITA_AGG
    FROM {{ ref('ccintica') }} m
    -- nodo aggiuntivo = SUBAGENTE
    LEFT JOIN {{ ref('ccanaisa') }} sa ON m.INTICA_TIPO_INTERM_A = 'SA'
        AND sa.ISA_CODICE = m.INTICA_INTERM_A
    -- nodo aggiuntivo = AGENTE (diretto)
    LEFT JOIN {{ ref('ccanaiag') }} ag_dir ON m.INTICA_TIPO_INTERM_A = 'AG'
        AND ag_dir.IAG_CODICE = m.INTICA_INTERM_A
    -- agente risalito dal subagente (solo quando il nodo e' un SA)
    LEFT JOIN {{ ref('ccanaiag') }} ag_sa ON m.INTICA_TIPO_INTERM_A = 'SA'
        AND ag_sa.IAG_CODICE = sa.ISA_AGENTE
    -- nodo aggiuntivo = RETE VENDITA
    LEFT JOIN {{ ref('ccanairv') }} rv ON m.INTICA_TIPO_INTERM_A = 'RV'
        AND rv.IRV_CODICE = m.INTICA_INTERM_A
),
 
-- CTE ausiliaria per accordi (CD_ACCORDO, DS_ACCORDO, TP_ACCORDO, DS_MARCA)
accordi AS (
    SELECT
        m.INTICA_TIPO_INTERM,
        m.INTICA_INTERM,
        m.INTICA_TIPO_INTERM_A,
        m.INTICA_INTERM_A,
        a.INTIAC_ACCORDO AS CD_ACCORDO,
        t.INTTAC_TIPO_ACCORDO AS TP_ACCORDO,
        t.INTTAC_DESCRIZIONE AS DS_ACCORDO,
        mk.INTAAM_MARCA AS DS_MARCA
    FROM {{ ref('ccintica') }} m
    LEFT JOIN {{ ref('ccintiac') }} a 
        ON a.INTIAC_TIPO_INTERM = m.INTICA_TIPO_INTERM_A
        AND a.INTIAC_INTERM = m.INTICA_INTERM_A
        --AND a.INTIAC_TIPO_INTERM_A = m.INTICA_TIPO_INTERM_A
        --AND a.INTIAC_INTERM_A = m.INTICA_INTERM_A
    LEFT JOIN {{ ref('ccinttac') }} t ON t.INTTAC_ACCORDO = a.INTIAC_ACCORDO
    --AND T.INTTAC_DATA_FINE = 99991231
    --LEFT JOIN AGOS_DEV_16000.L0.CCINTTTA d ON d.INTTTA_TIPO_ACCORDO = t.INTTAC_TIPO_ACCORDO
    --LEFT JOIN { re('ccinttta') }} d ON d.INTTTA_TIPO_ACCORDO = t.INTTAC_TIPO_ACCORDO
    LEFT JOIN {{ ref('ccintaam') }} mk 
    ON (
        mk.INTAAM_ACCORDO = a.INTIAC_ACCORDO
        AND mk.FL_DELETED='N'

    )
),

-- Sorgente principale: CCINTLCA (L) + CCINTICA (A)
base AS (
    SELECT
        -- PK
        COALESCE(L.INTLCA_TIPO_INTERM, A.INTICA_TIPO_INTERM) AS TP_INTERM_PRINCIPALE,
        COALESCE(L.INTLCA_INTERM, A.INTICA_INTERM) AS CD_INTERM_PRINCIPALE,
        COALESCE(L.INTLCA_TIPO_INTERM_A, A.INTICA_TIPO_INTERM_A) AS TP_INTERM_AGGIUNTIVO,
        COALESCE(L.INTLCA_INTERM_A, A.INTICA_INTERM_A) AS CD_INTERM_AGGIUNTIVO,
        -- TS tecnici (cluster non-C: calcolati in L2)
        -- FIX: rimossa virgola spuria prima di ORDER BY rispetto alla RT originale
        {{ custom_to_timestamp_ntz('L.INTLCA_DATA', 'L.INTLCA_ORA') }} AS TS_INIZIO_VALIDITA,
        {{ ts_fine_validita(
            'COALESCE(L.INTLCA_TIPO_INTERM, A.INTICA_TIPO_INTERM), COALESCE(L.INTLCA_INTERM, A.INTICA_INTERM), COALESCE(L.INTLCA_TIPO_INTERM_A, A.INTICA_TIPO_INTERM_A), COALESCE(L.INTLCA_INTERM_A, A.INTICA_INTERM_A)',
            custom_to_timestamp_ntz('L.INTLCA_DATA', 'L.INTLCA_ORA')
        ) }} AS TS_FINE_VALIDITA,
        -- Campi business
        {{ custom_to_date('COALESCE(L.INTLCA_DATA_INIZIO, A.INTICA_DATA_INIZIO)', zero='min') }} AS DT_INIZIO_CATENA,
        {{ custom_to_date('COALESCE(L.INTLCA_DATA_FINE, A.INTICA_DATA_FINE)', zero='max') }} AS DT_FINE_CATENA,
        -- Accordi (da CTE accordi)
        acc.CD_ACCORDO AS CD_ACCORDO,
        acc.DS_ACCORDO AS DS_ACCORDO,
        acc.TP_ACCORDO AS TP_ACCORDO,
        acc.DS_MARCA AS DS_MARCA,
        -- Flags abilitazione (COALESCE L -> A)
        COALESCE(L.INTLCA_ABIL_CO, A.INTICA_ABIL_CO) AS FL_ABIL_CO,
        COALESCE(L.INTLCA_ABIL_CA, A.INTICA_ABIL_CA) AS FL_ABIL_CA,
        COALESCE(L.INTLCA_ABIL_CQ, A.INTICA_ABIL_CQ) AS FL_ABIL_CQ,
        COALESCE(L.INTLCA_OBBL_CO, A.INTICA_OBBL_CO) AS FL_OBBL_CO,
        COALESCE(L.INTLCA_OBBL_CA, A.INTICA_OBBL_CA) AS FL_OBBL_CA,
        COALESCE(L.INTLCA_OBBL_CQ, A.INTICA_OBBL_CQ) AS FL_OBBL_CQ,
        COALESCE(L.INTLCA_FORZ_AUT_CO, A.INTICA_FORZ_AUT_CO) AS FL_FORZ_AUT_CO,
        COALESCE(L.INTLCA_TIPO_FORZ_AUT_CO, A.INTICA_TIPO_FORZ_AUT_CO) AS TP_FORZ_AUT_CO,
        COALESCE(L.INTLCA_FORZ_AUT_CA, A.INTICA_FORZ_AUT_CA) AS FL_FORZ_AUT_CA,
        -- Campi gerarchia aggiuntiva (da CTE cd_rv_agg / cd_ag_agg / cd_sa_agg via INTLCA_INTERM)
        ger.CD_RETE_VENDITA_AGG AS CD_RETE_VENDITA_AGG,
        ger.CD_AGENTE_AGG AS CD_AGENTE_AGG,
        ger.CD_SUBAGENTE_AGG AS CD_SUBAGENTE_AGG,
        L.LASTMODIFIEDDATA AS LASTMODIFIEDDATA,
        ROW_NUMBER() OVER (
            PARTITION BY L.INTLCA_INTERM, L.INTLCA_TIPO_INTERM, L.INTLCA_TIPO_INTERM_A, L.INTLCA_INTERM_A, L.INTLCA_DATA, L.INTLCA_ORA
            ORDER BY L.ROWID
        )::NUMBER(38, 0) AS PR_PK
    FROM {{ ref('ccintlca') }} L
    LEFT JOIN {{ ref('ccintica') }} A 
        ON (
            L.INTLCA_INTERM = A.INTICA_INTERM
            AND L.INTLCA_TIPO_INTERM = A.INTICA_TIPO_INTERM
            AND L.INTLCA_TIPO_INTERM_A = A.INTICA_TIPO_INTERM_A
            AND L.INTlCA_INTERM_A = A.INTICA_INTERM_A
        )
    LEFT JOIN accordi acc 
        ON (
            acc.INTICA_TIPO_INTERM = L.INTLCA_TIPO_INTERM
            AND acc.INTICA_INTERM = L.INTLCA_INTERM
            AND acc.INTICA_TIPO_INTERM_A = L.INTLCA_TIPO_INTERM_A
            AND acc.INTICA_INTERM_A = L.INTLCA_INTERM_A
        )
    LEFT JOIN gerarchia_agg ger 
        ON(
            ger.INTICA_TIPO_INTERM = L.INTLCA_TIPO_INTERM
            AND ger.INTICA_INTERM = L.INTLCA_INTERM
            AND ger.INTICA_TIPO_INTERM_A = L.INTLCA_TIPO_INTERM_A
            AND ger.INTICA_INTERM_A = L.INTLCA_INTERM_A
        )
    WHERE L.FL_DELETED = 'N'
),
 
dedup AS (
    SELECT
        TP_INTERM_PRINCIPALE,
        CD_INTERM_PRINCIPALE,
        TP_INTERM_AGGIUNTIVO,
        CD_INTERM_AGGIUNTIVO,
        TS_INIZIO_VALIDITA,
        TS_FINE_VALIDITA,
        PR_PK,
        DT_INIZIO_CATENA,
        DT_FINE_CATENA,
        CD_ACCORDO,
        DS_ACCORDO,
        TP_ACCORDO,
        DS_MARCA,
        FL_ABIL_CO,
        FL_ABIL_CA,
        FL_ABIL_CQ,
        FL_OBBL_CO,
        FL_OBBL_CA,
        FL_OBBL_CQ,
        FL_FORZ_AUT_CO,
        TP_FORZ_AUT_CO,
        FL_FORZ_AUT_CA,
        CD_RETE_VENDITA_AGG,
        CD_AGENTE_AGG,
        CD_SUBAGENTE_AGG,
        LASTMODIFIEDDATA,
        {{ hash_cols([
            'TP_INTERM_PRINCIPALE', 'CD_INTERM_PRINCIPALE',
            'TP_INTERM_AGGIUNTIVO', 'CD_INTERM_AGGIUNTIVO',
            'DT_INIZIO_CATENA', 'DT_FINE_CATENA',
            'CD_ACCORDO', 'DS_ACCORDO', 'TP_ACCORDO', 'DS_MARCA',
            'FL_ABIL_CO', 'FL_ABIL_CA', 'FL_ABIL_CQ',
            'FL_OBBL_CO', 'FL_OBBL_CA', 'FL_OBBL_CQ',
            'FL_FORZ_AUT_CO', 'TP_FORZ_AUT_CO', 'FL_FORZ_AUT_CA',
            'CD_RETE_VENDITA_AGG', 'CD_AGENTE_AGG', 'CD_SUBAGENTE_AGG'
        ]) }} AS HASHED_COLS
    FROM base {{ is_incremental_S1('TP_INTERM_PRINCIPALE, CD_INTERM_PRINCIPALE, TP_INTERM_AGGIUNTIVO, CD_INTERM_AGGIUNTIVO', order_extra='PR_PK') }}
),

DEDUP_FV AS (
    SELECT
        TP_INTERM_PRINCIPALE,
        CD_INTERM_PRINCIPALE,
        TP_INTERM_AGGIUNTIVO,
        CD_INTERM_AGGIUNTIVO,
        TS_INIZIO_VALIDITA,
        --TS_FINE_VALIDITA,
        {{ ts_fine_validita('TP_INTERM_PRINCIPALE, CD_INTERM_PRINCIPALE, TP_INTERM_AGGIUNTIVO, CD_INTERM_AGGIUNTIVO', 'TS_INIZIO_VALIDITA') }} AS TS_FV_NEXT,
        PR_PK,
        DT_INIZIO_CATENA,
        DT_FINE_CATENA,
        CD_ACCORDO,
        DS_ACCORDO,
        TP_ACCORDO,
        DS_MARCA,
        FL_ABIL_CO,
        FL_ABIL_CA,
        FL_ABIL_CQ,
        FL_OBBL_CO,
        FL_OBBL_CA,
        FL_OBBL_CQ,
        FL_FORZ_AUT_CO,
        TP_FORZ_AUT_CO,
        FL_FORZ_AUT_CA,
        CD_RETE_VENDITA_AGG,
        CD_AGENTE_AGG,
        CD_SUBAGENTE_AGG,
        LASTMODIFIEDDATA     
    FROM dedup 
)

SELECT
    D.TP_INTERM_PRINCIPALE,
    D.CD_INTERM_PRINCIPALE,
    D.TP_INTERM_AGGIUNTIVO,
    D.CD_INTERM_AGGIUNTIVO,
    D.TS_INIZIO_VALIDITA,
    MAX(D.TS_FV_NEXT) OVER (
        PARTITION BY D.TP_INTERM_PRINCIPALE, D.CD_INTERM_PRINCIPALE, D.TP_INTERM_AGGIUNTIVO, D.CD_INTERM_AGGIUNTIVO, D.TS_INIZIO_VALIDITA
    ) AS TS_FINE_VALIDITA,
    D.PR_PK,
    D.DT_INIZIO_CATENA,
    D.DT_FINE_CATENA,
    D.CD_ACCORDO,
    D.DS_ACCORDO,
    D.TP_ACCORDO,
    D.DS_MARCA,
    D.FL_ABIL_CO,
    D.FL_ABIL_CA,
    D.FL_ABIL_CQ,
    D.FL_OBBL_CO,
    D.FL_OBBL_CA,
    D.FL_OBBL_CQ,
    D.FL_FORZ_AUT_CO,
    D.TP_FORZ_AUT_CO,
    D.FL_FORZ_AUT_CA,
    D.CD_RETE_VENDITA_AGG,
    D.CD_AGENTE_AGG,
    D.CD_SUBAGENTE_AGG,
    D.LASTMODIFIEDDATA
FROM DEDUP_FV D

