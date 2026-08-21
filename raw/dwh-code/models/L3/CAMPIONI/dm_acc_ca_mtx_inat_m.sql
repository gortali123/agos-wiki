-- =============================================================================
-- MODELLO   : DM_CA_MATRIX_INAT
-- PROCESSO  : Campioni Accettazione | LAYER: L3 - DataMart
-- PK        : CD_PRATICA, TP_PROCEDURA, DT_OSSERVAZIONE
-- =============================================================================


WITH

-- Perimetro filtrato tramite dm_acc_ca_perim (attiva, non respinta, non
-- ritirata) - centralizzato li' invece di ripetere qui i filtri
-- CD_MACRO_PRODOTTO_4/DT_CARICAMENTO/CD_STATO/CREMEP.
perimetro AS (
    SELECT
        P.CD_PRATICA, P.TP_PROCEDURA, P.DT_OSSERVAZIONE, P.DT_CARICAMENTO,
        P.DT_CHIUSURA_EFFETTIVA, P.DT_PASSAGGIO_PERDITA, P.DT_CESSIONE,
        P.DT_PRIMA_SCADENZA, P.DT_DECORRENZA
    FROM {{ ref('dm_cmp_acc_perimetro_ca') }} P
    WHERE
       P.CD_STATO IN ('40', '55')
    {% if is_incremental() %}
      AND P.DT_OSSERVAZIONE = {{ last_day_past_month() }}
    {% endif %}
    QUALIFY ROW_NUMBER() OVER (PARTITION BY P.CD_PRATICA, P.TP_PROCEDURA, P.DT_OSSERVAZIONE ORDER BY 1) = 1
),

mov_agg AS (
    SELECT CD_PRATICA, DT_OSSERVAZIONE, COUNT(*) AS NM_MOVIMENTI
    FROM AGOS_DEV_16000.L2_PRODOTTO.CARTE_MOV_ESTRATTO_CONTO_M
    GROUP BY CD_PRATICA, DT_OSSERVAZIONE
),

-- Pivot su 121 mesi (0-120) rispetto a DT_PRIMA_SCADENZA, generato con ciclo
-- Jinja. Per ogni mese, calcola se la carta era Attiva ('A'), Inattiva ('I')
-- o chiusa/persa/ceduta in quel mese ('').
inattiva_hist AS (
    SELECT
        P.CD_PRATICA, P.TP_PROCEDURA, P.DT_OSSERVAZIONE,
        {% for n in range(121) %}
        MAX(CASE WHEN DATEDIFF('month', P.DT_PRIMA_SCADENZA, EC.DT_OSSERVAZIONE) = {{ n }} THEN
            CASE
                WHEN P.DT_CHIUSURA_EFFETTIVA IS NOT NULL
                     AND DATE_TRUNC('MONTH', P.DT_CHIUSURA_EFFETTIVA) = DATE_TRUNC('MONTH', EC.DT_OSSERVAZIONE)
                    THEN ''
                WHEN COALESCE(P.DT_PASSAGGIO_PERDITA, P.DT_CESSIONE) IS NOT NULL
                     AND DATE_TRUNC('MONTH', COALESCE(P.DT_PASSAGGIO_PERDITA, P.DT_CESSIONE)) = DATE_TRUNC('MONTH', EC.DT_OSSERVAZIONE)
                    THEN ''
                WHEN (EC.EU_SALDO_TOT <= 0 OR EC.EU_SALDO_TOT IS NULL) AND COALESCE(MOV.NM_MOVIMENTI, 0) <= 0
                    THEN 'I'
                ELSE 'A'
            END
        END) AS FL_INUTILIZZI{{ n }}{% if not loop.last %},{% endif %}
        {% endfor %}
    FROM perimetro P
    LEFT JOIN AGOS_DEV_16000.L2_PRODOTTO.CARTE_ESTRATTO_CONTO_M EC
        ON EC.CD_PRATICA = P.CD_PRATICA
    LEFT JOIN mov_agg MOV
        ON MOV.CD_PRATICA = EC.CD_PRATICA
        AND MOV.DT_OSSERVAZIONE = EC.DT_OSSERVAZIONE
    GROUP BY P.CD_PRATICA, P.TP_PROCEDURA, P.DT_OSSERVAZIONE
)

SELECT
    P.CD_PRATICA,
    P.TP_PROCEDURA,
    P.DT_OSSERVAZIONE,
    P.DT_CARICAMENTO AS DT_CARICAMENTO_SCORE,
    {% for n in range(121) %}
    IH.FL_INUTILIZZI{{ n }},
    {% endfor %}
    DATEDIFF('month', P.DT_DECORRENZA, P.DT_OSSERVAZIONE) AS NM_MESI

FROM perimetro P
LEFT JOIN inattiva_hist IH
    ON IH.CD_PRATICA = P.CD_PRATICA
    AND IH.TP_PROCEDURA = P.TP_PROCEDURA
    AND IH.DT_OSSERVAZIONE = P.DT_OSSERVAZIONE