-- FREQUENZA : Mensile — incremental append + delete_last_month
WITH 
perimetro AS (
    SELECT 
        CD_PRATICA, TP_PROCEDURA, CD_CLIENTE, DT_OSSERVAZIONE, CD_TIPO_PRODOTTO, CD_EMETTITORE,
        CD_PRODOTTO, CD_STATO, DS_STATO, FL_DBT  
    FROM {{ ref('pratica_m') }}
    WHERE TP_PROCEDURA IN ('CO', 'CA', 'CQ')
    {% if is_incremental() %}
      AND DT_OSSERVAZIONE = {{ last_day_past_month() }}
    {% endif %}
),

segnalazioni_raw AS (
    SELECT
        CD_CONTROPARTE, TP_SEGNALAZIONE, PR_SEGNALAZIONE, DS_SEGNALAZIONE, CD_RISCHIO, CD_CLASSE, DT_INIZIO, DT_FINE
    FROM {{ ref('segnalazioni_anagrafiche') }}
),
cicli_step1 AS (
    SELECT
        CD_CONTROPARTE, TP_SEGNALAZIONE, PR_SEGNALAZIONE, DT_INIZIO, DT_FINE, CD_CLASSE,
        MAX(DT_FINE) OVER (PARTITION BY CD_CONTROPARTE ORDER BY DT_INIZIO, DT_FINE, PR_SEGNALAZIONE
            ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING
        ) AS MAX_DT_FINE_PRECEDENTE
    FROM segnalazioni_raw
),

cicli_step2 AS (
    SELECT
        CD_CONTROPARTE, TP_SEGNALAZIONE, PR_SEGNALAZIONE, DT_INIZIO, DT_FINE, CD_CLASSE,
        MAX_DT_FINE_PRECEDENTE,
        SUM(CASE
                WHEN MAX_DT_FINE_PRECEDENTE IS NULL OR DT_INIZIO > MAX_DT_FINE_PRECEDENTE THEN 1 ELSE 0
            END
        ) OVER (PARTITION BY CD_CONTROPARTE ORDER BY DT_INIZIO, DT_FINE, PR_SEGNALAZIONE
            ROWS UNBOUNDED PRECEDING
        ) AS CICLO_DEFAULT
    FROM cicli_step1
),

cicli_agg AS (
    SELECT
        CD_CONTROPARTE, CICLO_DEFAULT,
        MIN(DT_INIZIO) AS DT_INGRESSO_DEFAULT,
        MAX(DT_FINE)   AS DT_USCITA_DEFAULT
    FROM cicli_step2
    GROUP BY CD_CONTROPARTE, CICLO_DEFAULT
),

ciclo_attivo AS (
    SELECT
        CD_CONTROPARTE, DT_INGRESSO_DEFAULT, DT_USCITA_DEFAULT
    FROM cicli_agg
    WHERE {{ last_day_past_month() }} BETWEEN DT_INGRESSO_DEFAULT AND DT_USCITA_DEFAULT
),

cicli_completi AS (
    SELECT
        S.CD_CONTROPARTE,
        S.TP_SEGNALAZIONE,
        S.PR_SEGNALAZIONE,
        S.DT_INIZIO,
        S.DT_FINE,
        S.CD_CLASSE,
        C.CICLO_DEFAULT,
        C.DT_INGRESSO_DEFAULT,
        C.DT_USCITA_DEFAULT
    FROM cicli_step2 S
    JOIN cicli_agg C
        ON C.CD_CONTROPARTE = S.CD_CONTROPARTE
        AND C.CICLO_DEFAULT = S.CICLO_DEFAULT
),

segnalazioni_pivot AS (
    SELECT
        CD_CONTROPARTE,
        CASE WHEN MAX(CASE
            WHEN TP_SEGNALAZIONE = 'IPE' AND (DT_FINE IS NULL OR DT_FINE >= CURRENT_DATE)
            THEN 1 ELSE 0
        END) = 1 THEN 'S' ELSE 'N' END  AS FL_IPE,
        CASE WHEN MAX(CASE
            WHEN TP_SEGNALAZIONE = 'UTP' AND (DT_FINE IS NULL OR DT_FINE >= CURRENT_DATE)
            THEN 1 ELSE 0
        END) = 1 THEN 'S' ELSE 'N' END AS FL_UTP,

        CASE WHEN MAX(CASE
            WHEN TP_SEGNALAZIONE = 'SOF' AND (DT_FINE IS NULL OR DT_FINE >= CURRENT_DATE)
            THEN 1 ELSE 0
        END) = 1 THEN 'S' ELSE 'N' END AS FL_SOF,

        CASE WHEN MAX(CASE
            WHEN TP_SEGNALAZIONE = 'BOM' AND (DT_FINE IS NULL OR DT_FINE >= CURRENT_DATE)
            THEN 1 ELSE 0
        END) = 1 THEN 'S' ELSE 'N' END AS FL_BONIS_FORZATO,

        CASE WHEN MAX(CASE
            WHEN TP_SEGNALAZIONE = 'SOV' AND (DT_FINE IS NULL OR DT_FINE >= CURRENT_DATE)
            THEN 1 ELSE 0
        END) = 1 THEN 'S' ELSE 'N' END AS FL_SOVRAINDEB
    FROM segnalazioni_raw
    GROUP BY CD_CONTROPARTE
),

ristrutturazione_cliente AS (
    SELECT
        CD_CLIENTE, DT_OSSERVAZIONE, DT_RISTRUTTURAZIONE, TP_RISTRUTTURAZIONE,
        ROW_NUMBER() OVER (PARTITION BY CD_CLIENTE, DT_OSSERVAZIONE ORDER BY DT_RISTRUTTURAZIONE DESC) AS RN
    FROM {{ ref('forbearance_m') }}
    WHERE DT_RISTRUTTURAZIONE IS NOT NULL
),

performing_raw AS (
    SELECT
        CD_CLIENTE, FL_FORBEARANCE, DT_INGRS_OBSERVATION, DT_USCITA_OBSERVATION, DT_INGRS_PROBATION,
        DT_USCITA_PROBATION_STIMATA, DT_USCITA_PROBATION
    FROM {{ ref('performing_m') }}
    WHERE DT_OSSERVAZIONE = {{ last_day_past_month() }}
),

perf_ciclo_attivo AS (
    SELECT
        PR.CD_CLIENTE,
        PR.DT_INGRS_PROBATION,
        PR.DT_USCITA_PROBATION_STIMATA,
        PR.DT_USCITA_PROBATION,
        PR.DT_INGRS_OBSERVATION
    FROM performing_raw PR
    JOIN cicli_completi CC
        ON CC.CD_CONTROPARTE = PR.CD_CLIENTE
        AND PR.DT_INGRS_PROBATION BETWEEN CC.DT_INGRESSO_DEFAULT AND CC.DT_USCITA_DEFAULT
),

segnalazioni_default AS (
    SELECT
        CD_CONTROPARTE,  DS_SEGNALAZIONE, CD_RISCHIO, DT_INIZIO, DT_FINE  
        --TP_SEGNALAZIONE,
        --PR_SEGNALAZIONE,
        --CD_CLASSE,
    FROM segnalazioni_raw
    WHERE CD_CLASSE IN ('SO', 'O2', 'IN')
),

segnalazioni_controparte AS (
    SELECT
        S.CD_CONTROPARTE,
        S.DS_SEGNALAZIONE,
        S.CD_RISCHIO,
        S.DT_INIZIO,
        S.DT_FINE,
        CASE
            WHEN S.DT_INIZIO <= {{ last_day_past_month() }}AND (S.DT_FINE IS NULL
            OR S.DT_FINE >= {{ last_day_past_month() }})
            THEN 1 ELSE 0
        END AS FL_ATTIVA
    FROM segnalazioni_default S
    WHERE S.DT_INIZIO <= {{ last_day_past_month() }}
),

stato_cred_pratica AS (
    SELECT
        SC.DT_OSSERVAZIONE,
        P.CD_CLIENTE AS CD_CONTROPARTE,
        CASE 
            WHEN MAX(CASE WHEN SC.FL_DFLT_EBA = 'S' THEN 1 ELSE 0 END) = 1
            THEN 'S' 
            ELSE 'N' 
        END AS FL_DEFAULT_EBA
    FROM {{ ref('stato_creditizio_m') }} SC
    INNER JOIN perimetro P
        ON  P.CD_PRATICA      = SC.CD_PRATICA
        AND P.TP_PROCEDURA    = SC.TP_PROCEDURA
        AND P.DT_OSSERVAZIONE = SC.DT_OSSERVAZIONE
    WHERE SC.DT_OSSERVAZIONE  = {{ last_day_past_month() }}
    GROUP BY SC.DT_OSSERVAZIONE, P.CD_CLIENTE
),

primo_ingresso AS (
    SELECT
        P.CD_PRATICA,
        P.TP_PROCEDURA,
        P.CD_CLIENTE AS CD_CONTROPARTE,
        S.DT_INIZIO,
        S.DS_SEGNALAZIONE,
        ROW_NUMBER() OVER (PARTITION BY P.CD_PRATICA, P.TP_PROCEDURA ORDER BY S.DT_INIZIO ASC, S.CD_RISCHIO DESC) AS RN
    FROM perimetro P
    INNER JOIN segnalazioni_default S
        ON  S.CD_CONTROPARTE = P.CD_CLIENTE
),

ultimo_chiuso AS (
    SELECT
        CD_CONTROPARTE, DS_SEGNALAZIONE, DT_FINE,
        ROW_NUMBER() OVER (PARTITION BY CD_CONTROPARTE ORDER BY DT_FINE DESC, CD_RISCHIO DESC) AS RN
    FROM segnalazioni_default
    WHERE DT_FINE IS NOT NULL
),

ultimo_attivo AS (
    SELECT
        CD_CONTROPARTE, DS_SEGNALAZIONE,
        ROW_NUMBER() OVER (PARTITION BY CD_CONTROPARTE ORDER BY DT_INIZIO DESC, CD_RISCHIO DESC) AS RN
    FROM segnalazioni_controparte SC
    WHERE FL_ATTIVA = 1
),

flag_dbt_cli AS (
    SELECT
        CD_CLIENTE, DT_OSSERVAZIONE,
        CASE
            WHEN MAX(CASE WHEN FL_DBT = 'S' THEN 1 ELSE 0 END) = 1 THEN 'S' ELSE 'N'
        END AS FL_DBT_CLI
    FROM perimetro
    GROUP BY CD_CLIENTE, DT_OSSERVAZIONE
),

flag_forborne_cli AS (
    SELECT
        P.CD_CLIENTE,
        CASE
            WHEN MAX(CASE WHEN PE.FL_FORBEARANCE = 'F' THEN 1 ELSE 0 END) = 1 THEN 'S' ELSE 'N'
        END AS FL_FORBORNE_CLI
    FROM perimetro P
    LEFT JOIN performing_raw PE
        ON PE.CD_CLIENTE = P.CD_CLIENTE
    GROUP BY P.CD_CLIENTE
)

SELECT
    P.CD_PRATICA,
    P.TP_PROCEDURA,
    P.CD_CLIENTE AS CD_CONTROPARTE,
    {{ last_day_past_month() }} AS DT_OSSERVAZIONE,
    P.CD_TIPO_PRODOTTO,
    P.CD_EMETTITORE,
    P.CD_PRODOTTO,
    P.CD_STATO,
    P.DS_STATO,
    CA.DT_INGRESSO_DEFAULT AS DT_INGRS_DFLT_EBA,
    CA.DT_USCITA_DEFAULT AS DT_USCITA_DFLT_EBA,
    PCA.DT_INGRS_PROBATION,
    PCA.DT_USCITA_PROBATION_STIMATA,
    PCA.DT_USCITA_PROBATION,
    PCA.DT_INGRS_OBSERVATION,
    CASE
        WHEN PE.FL_FORBEARANCE = 'F'
         AND PE.DT_INGRS_OBSERVATION IS NOT NULL
         AND {{ last_day_past_month() }} >= PE.DT_INGRS_OBSERVATION
         AND (PE.DT_USCITA_OBSERVATION IS NULL
              OR {{ last_day_past_month() }} <= PE.DT_USCITA_OBSERVATION)
        THEN 'S' ELSE 'N'
    END AS FL_OBSERVATION_F,
    CASE
        WHEN PE.FL_FORBEARANCE = 'NF'
         AND PE.DT_INGRS_OBSERVATION IS NOT NULL
         AND {{ last_day_past_month() }} >= PE.DT_INGRS_OBSERVATION
         AND (PE.DT_USCITA_OBSERVATION IS NULL
              OR {{ last_day_past_month() }} <= PE.DT_USCITA_OBSERVATION)
        THEN 'S' ELSE 'N'
    END AS FL_OBSERVATION_NF,
    CASE
        WHEN PE.FL_FORBEARANCE = 'F'
         AND PE.DT_INGRS_OBSERVATION IS NOT NULL
         AND {{ last_day_past_month() }} >= PE.DT_INGRS_OBSERVATION
         AND (PE.DT_USCITA_OBSERVATION IS NULL
              OR {{ last_day_past_month() }} <= PE.DT_USCITA_OBSERVATION)
         AND {{ last_day_past_month() }} > DATEADD(DAY, 365, PE.DT_INGRS_OBSERVATION)
        THEN 'S' ELSE 'N'
    END AS FL_PROLUNGATION_F,
    CASE
        WHEN PE.FL_FORBEARANCE = 'NF'
         AND PE.DT_INGRS_OBSERVATION IS NOT NULL
         AND {{ last_day_past_month() }} >= PE.DT_INGRS_OBSERVATION
         AND (PE.DT_USCITA_OBSERVATION IS NULL
              OR {{ last_day_past_month() }} <= PE.DT_USCITA_OBSERVATION)
         AND {{ last_day_past_month() }} > DATEADD(DAY, 730, PE.DT_INGRS_OBSERVATION)
        THEN 'S' ELSE 'N'
    END AS FL_PROLUNGATION_NF,
    P.FL_DBT,
    FDBT.FL_DBT_CLI,
    SC.FL_DFLT_EBA,
    FFRB.FL_FORBORNE_CLI,
    CASE WHEN GT.FL_SUBITA = 'S' THEN 'S' ELSE 'N' END AS FL_TRUFFA,
    SP.FL_IPE,
    SP.FL_UTP,
    SP.FL_SOF,
    SP.FL_BONIS_FORZATO,
    SP.FL_SOVRAINDEB,
    GS.NM_GG_SCADUTO_EBA_CLI AS NM_GG_SCADT_CLI_EBA,
    CASE
        WHEN SCP.FL_DEFAULT_EBA = 'S'
        OR UC.DS_SEGNALAZIONE IS NOT NULL
        THEN PI.DS_SEGNALAZIONE
    END AS DS_MOTIVO_INGRS_DFLT_STO,
    CASE
        WHEN SCP.FL_DEFAULT_EBA = 'S' THEN UA.DS_SEGNALAZIONE
        WHEN UC.DS_SEGNALAZIONE IS NOT NULL THEN UC.DS_SEGNALAZIONE
    END AS DS_MOTIVO_EXIT_DFLT_STO,
    GS.NM_GG_SCADUTO_CLI AS NM_GG_SCADUTO_CLI,
    GS.NM_GG_SCADUTO_CONT AS NM_GG_SCADUTO_CONTR,
    GS.EU_SCADUTO_IMPAG_EBA AS EU_SCADUTO_IMPAG_EBA,
    GS.EU_IMPIEGO_TOT_EBA AS EU_IMPIEGO_TOT_EBA,
    {{ custom_to_date('FB.DT_RISTRUTTURAZIONE') }} AS DT_ULTIMA_RISTR

FROM perimetro P

LEFT JOIN performing_raw PE ON PE.CD_CLIENTE = P.CD_CLIENTE
LEFT JOIN ciclo_attivo CA ON CA.CD_CONTROPARTE = P.CD_CLIENTE
LEFT JOIN perf_ciclo_attivo PCA ON PCA.CD_CLIENTE = P.CD_CLIENTE
LEFT JOIN (
    SELECT CD_PRATICA, TP_PROCEDURA, FL_SUBITA
    FROM {{ ref('gestione_truffe') }}
    WHERE FL_TRUFFA_ATTIVA = 'S'
    QUALIFY ROW_NUMBER() OVER (PARTITION BY CD_PRATICA, TP_PROCEDURA ORDER BY TS_INSERIMENTO DESC) = 1
) GT
    ON GT.CD_PRATICA = P.CD_PRATICA
    AND GT.TP_PROCEDURA = P.TP_PROCEDURA

LEFT JOIN segnalazioni_pivot SP ON SP.CD_CONTROPARTE = P.CD_CLIENTE
LEFT JOIN {{ ref('giorni_scaduto') }} GS 
    ON GS.CD_CONTROPARTE = P.CD_CLIENTE 
    AND GS.CD_PRATICA = P.CD_PRATICA
	AND GS.TP_PROCEDURA = P.TP_PROCEDURA
    AND GS.TS_INSERIMENTO = {{ last_day_past_month() }}
LEFT JOIN stato_cred_pratica SCP
    ON SCP.CD_CONTROPARTE = P.CD_CLIENTE
LEFT JOIN primo_ingresso PI
    ON  PI.CD_PRATICA = P.CD_PRATICA
    AND PI.TP_PROCEDURA = P.TP_PROCEDURA
    AND PI.RN = 1
LEFT JOIN ultimo_attivo UA
    ON  UA.CD_CONTROPARTE = P.CD_CLIENTE
    AND UA.RN = 1
LEFT JOIN ultimo_chiuso UC
    ON  UC.CD_CONTROPARTE = P.CD_CLIENTE
    AND UC.RN = 1
    AND COALESCE(SCP.FL_DEFAULT_EBA, 'N') = 'N'
    AND {{ last_day_past_month() }} <= LAST_DAY(DATEADD(MONTH, 1, UC.DT_FINE))
LEFT JOIN ristrutturazione_cliente FB
    ON  FB.CD_CLIENTE = P.CD_CLIENTE
    AND FB.DT_OSSERVAZIONE = {{ last_day_past_month() }}
    AND FB.RN = 1
LEFT JOIN {{ ref('stato_creditizio_m') }} SC
    ON SC.CD_PRATICA = P.CD_PRATICA
    AND SC.TP_PROCEDURA = P.TP_PROCEDURA
    AND SC.DT_OSSERVAZIONE = P.DT_OSSERVAZIONE
LEFT JOIN flag_dbt_cli FDBT
    ON FDBT.CD_CLIENTE = P.CD_CLIENTE
    AND FDBT.DT_OSSERVAZIONE = {{ last_day_past_month() }}
LEFT JOIN flag_forborne_cli FFRB
    ON FFRB.CD_CLIENTE = P.CD_CLIENTE

{% if is_incremental() %}
    WHERE P.DT_OSSERVAZIONE = {{ last_day_past_month() }}
{% endif %}
