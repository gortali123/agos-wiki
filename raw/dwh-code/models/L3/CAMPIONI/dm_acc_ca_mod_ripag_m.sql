-- =============================================================================
-- MODELLO   : DM_CA_MOD_RIPAGAMENTO
-- PROCESSO  : Campioni Accettazione | LAYER: L3 - DataMart
-- PK        : CD_PRATICA, TP_PROCEDURA, DT_OSSERVAZIONE
-- =============================================================================


WITH

-- Perimetro filtrato tramite dm_acc_ca_perim (attiva=40/utilizzata=55).
perimetro AS (
    SELECT P.CD_PRATICA, P.TP_PROCEDURA, P.DT_OSSERVAZIONE, P.DT_PRIMA_SCADENZA, P.DT_DECORRENZA
 FROM {{ ref('dm_cmp_acc_perimetro_ca') }} P
    WHERE
       P.CD_STATO IN ('40', '55')
    {% if is_incremental() %}
      AND P.DT_OSSERVAZIONE = {{ last_day_past_month() }}
    {% endif %}
    QUALIFY ROW_NUMBER() OVER (PARTITION BY P.CD_PRATICA, P.TP_PROCEDURA, P.DT_OSSERVAZIONE ORDER BY 1) = 1
),



ripagamento_hist AS (
    SELECT
        P.CD_PRATICA, P.TP_PROCEDURA, P.DT_OSSERVAZIONE,
        {% for n in range(121) %}
        MAX(CASE WHEN DATEDIFF('month', P.DT_PRIMA_SCADENZA, CM.DT_OSSERVAZIONE) = {{ n }}
                 THEN CM.TP_RIMBORSO END) AS NM_RIPAGAMENTO_{{ n }}{% if not loop.last %},{% endif %}
        {% endfor %}
    FROM perimetro P
    LEFT JOIN {{ ref('carta_m') }} CM
        ON CM.CD_PRATICA = P.CD_PRATICA
        AND CM.TP_PROCEDURA = P.TP_PROCEDURA
    GROUP BY P.CD_PRATICA, P.TP_PROCEDURA, P.DT_OSSERVAZIONE
),

-- IN_MULTICHOICE: riporto diretto di TP_RIMBORSO (mese corrente).
multichoice AS (
    SELECT
        CD_PRATICA, TP_PROCEDURA, DT_OSSERVAZIONE, TP_RIMBORSO
    FROM {{ ref('carta_m') }}
    QUALIFY ROW_NUMBER() OVER (PARTITION BY CD_PRATICA, TP_PROCEDURA, DT_OSSERVAZIONE ORDER BY 1) = 1
)

SELECT
    P.CD_PRATICA,
    P.TP_PROCEDURA,
    P.DT_OSSERVAZIONE,
    P.DT_PRIMA_SCADENZA AS DT_PRIMA_SCAD,
    P.DT_PRIMA_SCADENZA AS DT_RIFERIMENTO,
    MC.TP_RIMBORSO AS IN_MULTICHOICE,
    {% for n in range(121) %}
    RH.NM_RIPAGAMENTO_{{ n }},
    {% endfor %}
    DATEDIFF('month', P.DT_DECORRENZA, P.DT_OSSERVAZIONE) AS NM_MESI

FROM perimetro P
LEFT JOIN ripagamento_hist RH
    ON RH.CD_PRATICA = P.CD_PRATICA
    AND RH.TP_PROCEDURA = P.TP_PROCEDURA
    AND RH.DT_OSSERVAZIONE = P.DT_OSSERVAZIONE
LEFT JOIN multichoice MC
    ON MC.CD_PRATICA = P.CD_PRATICA
    AND MC.TP_PROCEDURA = P.TP_PROCEDURA
    AND MC.DT_OSSERVAZIONE = P.DT_OSSERVAZIONE