-- =============================================================================
-- MODELLO   : DM_CAMPIONI_SOCIO
-- LAYER     : L3 - DataMart
-- STATO     : BOZZA - ottimizzata, ma ANCORA da verificare su:
--             - grana reale di SCORING_INPUT e ACCETTAZIONE_INPUT (assunto
--               storicizzate 1:N per CD_PRATICA+TP_PROCEDURA -> dedup con
--               QUALIFY come gia' fatto per ACCETTAZIONE_OUTPUT). Se invece
--               sono 1:1, il QUALIFY aggiunto e' un no-op innocuo.
--             - punto 6 (NM_RATE_IMPAGATE_MAX_PIT) ancora non verificato.
-- =============================================================================

WITH

sociodemo_pratiche_ranked AS (
    SELECT
        CD_PRATICA, TP_PROCEDURA, DT_OSSERVAZIONE, CD_CONTROPARTE,
        CD_ABITAZIONE, CD_STATO_CIVILE, CD_BENE, CD_CBSCORE_CRIF, NM_PRATICHE,
        NM_PROTESTI, DT_APERTURA_PRIMA_PRATICA
    FROM AGOS_DEV_16000.L2_SCORING.SOCIODEMO_SCORE_TEST
    QUALIFY ROW_NUMBER() OVER (PARTITION BY CD_PRATICA, TP_PROCEDURA, DT_OSSERVAZIONE ORDER BY 1) = 1
),

-- Key-set di push-down: limita gli scan successivi (carte_utilizzi, SI, AI)
-- al solo perimetro effettivo del datamart, invece di ripartire da zero
-- su tabelle intere.
chiavi_perimetro AS (
    SELECT DISTINCT CD_PRATICA, TP_PROCEDURA, DT_OSSERVAZIONE
    FROM sociodemo_pratiche_ranked
),

pratica_base AS (
    SELECT PM.CD_PRATICA, PM.TP_PROCEDURA, PM.DT_OSSERVAZIONE, PM.DT_PRIMA_SCADENZA
    FROM {{ ref('pratica_m') }} PM
    INNER JOIN chiavi_perimetro CP
        ON PM.CD_PRATICA = CP.CD_PRATICA
        AND PM.TP_PROCEDURA = CP.TP_PROCEDURA
        AND PM.DT_OSSERVAZIONE = CP.DT_OSSERVAZIONE
),

-- SCORING_INPUT dedup: assunzione storicizzata -> tenere l'ultima riga utile.
-- TODO: confermare la colonna di ordinamento corretta (qui si ipotizza
-- DT_CARIC_ULT_PRA_ACC come proxy di recency; da validare con il fornitore
-- del data model, potrebbe servire un vero TS_INSERIMENTO/DT_AGGIORNAMENTO).
scoring_input_dedup AS (
    SELECT 
	
	SI.*
	
		--SI.EU_REDDITO_MENSILE,
		--SI.CD_MODALITA_PAGAMENTO,
		--SI.EU_IMPORTO_FINANZIATO_ULTIMA_PRA_CLI,
		--SI.NM_RATE_TOT_ULT_CONS,
		--SI.DT_CARIC_ULT_REV_ACC,
		--SI.CD_ESITO_ULT_PP_REMOTO,
		--SI.CD_ESITO_ULTIMO_PP,
		--SI.NM_PRATICHE_CLI
		--SI.NM_PRATICHE_COOB,
		--SI.NM_PRAT_ACC_CONS,
		--SI.NM_PRAT_RES_CONS,
		--SI.NM_PRAT_RES_GEST,
		--SI.NM_PRA_RIT_CONS,
		--SI.DT_CARIC_PRI_PRA_ACC,
		--SI.DT_CARIC_ULT_PRA_ACC,
		--SI.DT_CARIC_ULT_PRA_RES,
		--SI.DT_DECOR_ULT_PRA_PP,
		--SI.DT_DECOR_ULT_PRA,
		--SI.DT_PRI_SCAD_ULT_CONS,
		--SI.NM_INSLV_TOT_120M,
		--SI.NM_INSOLV_12M,
		--SI.NM_PROTESTI_COO,
		--SI.EU_ANTICIPO,
		--SI.DT_DTINS
	
    FROM AGOS_DEV_16000.L2_SCORE_BANCHE_DATI.SCORING_INPUT SI
    INNER JOIN chiavi_perimetro CP
        ON SI.CD_PRATICA = CP.CD_PRATICA
        AND SI.TP_PROCEDURA = CP.TP_PROCEDURA
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY SI.CD_PRATICA, SI.TP_PROCEDURA
        ORDER BY SI.DT_CARIC_ULT_PRA_ACC DESC NULLS LAST
    ) = 1
),

-- ACCETTAZIONE_INPUT dedup: stessa assunzione di cui sopra.
-- TODO: confermare colonna di ordinamento reale.
accettazione_input_dedup AS (
    SELECT
	AI.*,
		--AI.CD_PRATICA,
		--AI.TP_PROCEDURA,
		--AI.CD_OCCUPAZIONE,
		--AI.NM_INSOLV_MAX,
		--AI.NM_INSOLV_MAX,
		--AI.NM_INSOLV_ATTUALI,
		--AI.NM_INSOLV_24M,
		--AI.NM_INSOLUTO_MESE_CARICAMENTO
	
    FROM AGOS_DEV_16000.L2_SCORE_BANCHE_DATI.ACCETTAZIONE_INPUT AI
    INNER JOIN chiavi_perimetro CP
        ON AI.CD_PRATICA = CP.CD_PRATICA
        AND AI.TP_PROCEDURA = CP.TP_PROCEDURA
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY AI.CD_PRATICA, AI.TP_PROCEDURA
        ORDER BY AI.NM_INSOLUTO_MESE_CARICAMENTO DESC NULLS LAST
    ) = 1
),

-- ACCETTAZIONE_OUTPUT: cast normalizzato una sola volta qui dentro, invece
-- che nel JOIN esterno (evita cast per-riga e permette pruning su CD_PRATICA
-- lato AO se clusterizzata/partizionata su quella colonna).
accettazione_output_dedup AS (
    SELECT
        TRY_TO_NUMBER(AO.CD_PRATICA) AS CD_PRATICA,
        AO.NM_ETA,
        AO.NM_ANZIANITA_LAVORATIVA
    FROM AGOS_DEV_16000.L2_SCORE_BANCHE_DATI.ACCETTAZIONE_OUTPUT AO
    QUALIFY ROW_NUMBER() OVER (PARTITION BY AO.CD_PRATICA ORDER BY AO.TS_INSERIMENTO DESC) = 1
),

-- Ultimo pagamento retail (carte): limitato al perimetro tramite chiavi_perimetro
-- invece di ripartire da pratica_m intera.
carte_ultimo_pagamento AS (
    SELECT
        CP.CD_PRATICA, CP.TP_PROCEDURA, CP.DT_OSSERVAZIONE,
        MAX(CU.DT_UTILIZZO) AS DT_ULTIMA_RTL_PAGAMENTO
    FROM chiavi_perimetro CP
    LEFT JOIN {{ ref('carte_utilizzi') }} CU
        ON CP.CD_PRATICA = CU.CD_PRATICA
        AND CP.TP_PROCEDURA = CU.TP_PROCEDURA
        AND CU.DT_UTILIZZO <= CP.DT_OSSERVAZIONE
    WHERE CP.TP_PROCEDURA = 'CA'
    GROUP BY CP.CD_PRATICA, CP.TP_PROCEDURA, CP.DT_OSSERVAZIONE
)

SELECT
    -- === CHIAVI ===
    SPR.CD_PRATICA,
    SPR.TP_PROCEDURA,
    SPR.CD_CONTROPARTE,
    SPR.DT_OSSERVAZIONE,

    -- === SOCIODEMO_SCORE diretti ===
    SPR.CD_ABITAZIONE AS CD_ABITAZIONE_UC,
    SPR.CD_STATO_CIVILE AS CD_STATO_CIVILE_UC,
    SPR.CD_BENE AS CD_BENE_UC,
    SPR.CD_CBSCORE_CRIF AS CD_SCORE_CRIF_UC,
    SPR.CD_CBSCORE_CRIF AS CD_SCORE_CRIF_COOBLIGATO_UC,  -- TODO punto 3: manca join coobbligato
    SPR.NM_PRATICHE,
    SPR.NM_PROTESTI,
    SPR.DT_APERTURA_PRIMA_PRATICA,

    -- === SCORING_INPUT (ora dedup, niente piu' rischio fan-out) ===
    SI.EU_REDDITO_MENSILE AS EU_REDDITO_MENSILE_UC,
    SI.CD_MODALITA_PAGAMENTO AS CD_PAGAMENTO_UC,
    SI.EU_IMPORTO_FINANZIATO_ULTIMA_PRA_CLI AS EU_FINANZIATO_UC,
    SI.NM_RATE_TOT_ULT_CONS,
    DATEDIFF('month', SI.DT_CARIC_ULT_REV_ACC, SPR.DT_OSSERVAZIONE) AS NM_MESI_APERTURA_CA_UC,  -- TODO punto 5
    SI.CD_ESITO_ULT_PP_REMOTO AS CD_ESITO_FIL_ULT_PP_UC,
    SI.CD_ESITO_ULTIMO_PP AS CD_ESITO_UTILIZZO_UC,
    SI.NM_PRATICHE_CLI AS NM_PRATICHE_CLIE,
    SI.NM_PRATICHE_COOB,
    SI.NM_PRAT_ACC_CONS,
    SI.NM_PRAT_RES_CONS,
    SI.NM_PRAT_RES_GEST,
    SI.NM_PRA_RIT_CONS AS NM_PRAT_RIT_CONS,
    SI.DT_CARIC_PRI_PRA_ACC,
    SI.DT_CARIC_ULT_PRA_ACC,
    SI.DT_CARIC_ULT_PRA_RES,
    SI.DT_DECOR_ULT_PRA_PP,
    SI.DT_DECOR_ULT_PRA AS DT_DECOR_ULT_PRATICA,
    SI.DT_PRI_SCAD_ULT_CONS,
    SI.NM_INSLV_TOT_120M AS NM_INSOLVENZE_TOT,
    SI.NM_INSOLV_12M AS NM_INSOL_12M_CLIE,
    SI.NM_PROTESTI_COO AS NM_PROTESTI_COOBLIGATO,
    -- Ora che SI e' dedup a 1 riga per chiave, la MAX(CASE...) e' una CASE
    -- scalare: niente piu' bisogno della window function OVER(), risparmia
    -- un partition/sort inutile.
    CASE WHEN SI.EU_ANTICIPO > 0 THEN SI.DT_DTINS END AS DT_ULTIMO_ANTICIPO,  -- TODO punto 7: da confermare

    -- === ACCETTAZIONE_INPUT (ora dedup) ===
    AI.CD_OCCUPAZIONE AS CD_IMPIEGO_UC,
    AI.CD_OCCUPAZIONE AS TP_ATTIVITA_PREC,  -- TODO punto 2: stessa sorgente di CD_IMPIEGO_UC, verificare
    AI.NM_INSOLV_MAX AS NM_INSOL_TOT_CONSUMO,
    AI.NM_INSOLV_MAX AS NM_INSOL_TOT_COOB,  -- TODO punto 4: manca filtro CD_RUOLO
    AI.NM_INSOLV_ATTUALI AS NM_INSOLUTO_CORRENTE,
    AI.NM_INSOLV_24M AS NM_INSOLVENZE_24M,
    AI.NM_INSOLUTO_MESE_CARICAMENTO AS NM_MAX_INSOLUTI_MESE,

    -- === ACCETTAZIONE_OUTPUT ===
    AO.NM_ETA AS NM_ETA_UC,
    AO.NM_ANZIANITA_LAVORATIVA AS NM_ANZIANITA_OCCUPAZIONE_UC,

    -- === PRATICA_M (anzianita' contratto, stesso pattern gia' usato in sviluppo_m) ===
    DATEDIFF('month', PB.DT_PRIMA_SCADENZA, SPR.DT_OSSERVAZIONE) AS NM_ANZIANITA_CONTRATTO_UC,

    -- === INDICE_RISCHIO_M ===
    IRM.NM_IMPAGATE AS NM_MAX_ARRETRATI,
    -- TODO punto 6: colonna NM_RATE_IMPAGATE_MAX_PIT mai verificata in
    -- INDICE_RISCHIO_M (rischio nome inventato) -> lasciato NULL finche' non
    -- si conferma il nome vero della colonna con un DESCRIBE TABLE.
    CAST(NULL AS DATE) AS DT_ULTIMA_DELINQUENCY,

    -- === CARTE_UTILIZZI (aggregato) ===
    CUP.DT_ULTIMA_RTL_PAGAMENTO

FROM sociodemo_pratiche_ranked SPR

LEFT JOIN scoring_input_dedup SI
    ON SPR.CD_PRATICA = SI.CD_PRATICA
    AND SPR.TP_PROCEDURA = SI.TP_PROCEDURA

LEFT JOIN accettazione_input_dedup AI
    ON SPR.CD_PRATICA = AI.CD_PRATICA
    AND SPR.TP_PROCEDURA = AI.TP_PROCEDURA

-- ACCETTAZIONE_OUTPUT: no TP_PROCEDURA (chiave e' CD_INQUIRYCODE+CD_RUOLO+
-- TS_INSERIMENTO). Dedup e cast gia' fatti in accettazione_output_dedup.
-- ASSUNZIONE invariata: non filtro per TS_INSERIMENTO <= DT_OSSERVAZIONE
-- perche' non specificato nella regola - se serve lo stato storico alla
-- data osservata invece dell'ultimo assoluto, va aggiunto quel filtro.
LEFT JOIN accettazione_output_dedup AO
    ON SPR.CD_PRATICA = AO.CD_PRATICA

LEFT JOIN pratica_base PB
    ON SPR.CD_PRATICA = PB.CD_PRATICA
    AND SPR.TP_PROCEDURA = PB.TP_PROCEDURA
    AND SPR.DT_OSSERVAZIONE = PB.DT_OSSERVAZIONE

LEFT JOIN {{ ref('indice_rischio_m') }} IRM
    ON SPR.CD_PRATICA = IRM.CD_PRATICA
    AND SPR.TP_PROCEDURA = IRM.TP_PROCEDURA
    AND SPR.DT_OSSERVAZIONE = IRM.DT_OSSERVAZIONE

-- TODO punto 6: join DQ per DT_ULTIMA_DELINQUENCY rimossa (colonna non
-- verificata), il campo resta NULL sopra finche' non si conferma la fonte.

LEFT JOIN carte_ultimo_pagamento CUP
    ON SPR.CD_PRATICA = CUP.CD_PRATICA
    AND SPR.TP_PROCEDURA = CUP.TP_PROCEDURA
    AND SPR.DT_OSSERVAZIONE = CUP.DT_OSSERVAZIONE