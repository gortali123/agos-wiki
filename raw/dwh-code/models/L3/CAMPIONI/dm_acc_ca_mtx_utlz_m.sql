-- =============================================================================
-- MODELLO   : DM_CA_MATRIX_UTLZ_M
-- PROCESSO  : Campioni Accettazione | LAYER: L3 - DataMart
-- PK        : CD_PRATICA, TP_PROCEDURA, DT_OSSERVAZIONE
-- =============================================================================


WITH

perimetro AS (
    SELECT P.CD_PRATICA, P.TP_PROCEDURA, P.DT_OSSERVAZIONE, P.DT_CARICAMENTO, P.DT_DECORRENZA
    FROM {{ ref('dm_cmp_acc_perimetro_ca') }} P
    WHERE
       P.CD_STATO IN ('40', '55')
    {% if is_incremental() %}
      AND P.DT_OSSERVAZIONE = {{ last_day_past_month() }}
    {% endif %}
    QUALIFY ROW_NUMBER() OVER (PARTITION BY P.CD_PRATICA, P.TP_PROCEDURA, P.DT_OSSERVAZIONE ORDER BY 1) = 1
),



utilizzi_hist AS (
    SELECT
        P.CD_PRATICA, P.TP_PROCEDURA, P.DT_OSSERVAZIONE,
        {% for n in range(121) %}
        COUNT(CASE WHEN DATEDIFF('month', P.DT_CARICAMENTO, CU.DT_UTILIZZO) = {{ n }}
                   THEN CU.CD_RIGA END) AS NM_UTILIZZI{{ n }}{% if not loop.last %},{% endif %}
        {% endfor %}
    FROM perimetro P
    LEFT JOIN AGOS_DEV_16000.L2_PRODOTTO.CARTE_UTILIZZI CU
        ON CU.CD_PRATICA = P.CD_PRATICA
        AND CU.TP_PROCEDURA = P.TP_PROCEDURA
    GROUP BY P.CD_PRATICA, P.TP_PROCEDURA, P.DT_OSSERVAZIONE
)

SELECT
    P.CD_PRATICA,
    P.TP_PROCEDURA,
    P.DT_OSSERVAZIONE,
    P.DT_CARICAMENTO,
    {% for n in range(121) %}
    UH.NM_UTILIZZI{{ n }},
    {% endfor %}
    DATEDIFF('month', P.DT_DECORRENZA, P.DT_OSSERVAZIONE) AS NM_MESI

FROM perimetro P
LEFT JOIN utilizzi_hist UH
    ON UH.CD_PRATICA = P.CD_PRATICA
    AND UH.TP_PROCEDURA = P.TP_PROCEDURA
    AND UH.DT_OSSERVAZIONE = P.DT_OSSERVAZIONE