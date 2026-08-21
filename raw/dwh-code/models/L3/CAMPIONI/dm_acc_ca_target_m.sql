-- DM_45 | DM_CMP_ACC_CA_TARGET_M | 13_Campioni.Accettazione Agos
-- WARN: il DM usa P.DT_RIFERIMENTO come ancora dei DATEDIFF, campo non esposto dal
--       perimetro. Mappato su DT_DECORRENZA (coerente con la RT di NM_MESI, che usa


{% set mesi_offset = range(0, 121) %}

WITH perimetro AS (
    SELECT
        P.CD_PRATICA,
        P.TP_PROCEDURA,
        P.DT_OSSERVAZIONE,
        P.DT_CARICAMENTO,
        P.DT_DECORRENZA,
        -- colonne aggiuntive richieste dal DM_45: verificare che siano esposte da dm_cmp_acc_perimetro_ca
        P.CD_CLIENTE,
        P.CD_STATO,
        P.DT_CHIUSURA_EFFETTIVA,
        P.DT_DBT,
        P.DT_PASSAGGIO_PERDITA,
        P.DT_CESSIONE,
        P.DT_PRIMA_SCADENZA
    FROM {{ ref('dm_cmp_acc_perimetro_ca') }} P
    WHERE
       P.CD_STATO IN ('40', '55')
    {% if is_incremental() %}
      AND P.DT_OSSERVAZIONE = {{ last_day_past_month() }}
    {% endif %}
    QUALIFY ROW_NUMBER() OVER (PARTITION BY P.CD_PRATICA, P.TP_PROCEDURA, P.DT_OSSERVAZIONE ORDER BY 1) = 1
)

, carta AS (
    SELECT
        C.CD_PRATICA,
        C.DT_PRIMO_UTILIZZO
    FROM {{ ref('carta_m') }} C
    QUALIFY ROW_NUMBER() OVER (PARTITION BY C.CD_PRATICA ORDER BY 1) = 1
)

, estratto_conto AS (
    SELECT
        P.CD_PRATICA,
        P.TP_PROCEDURA,
        P.DT_OSSERVAZIONE,
        DATEDIFF('month', P.DT_DECORRENZA, EC.DT_OSSERVAZIONE) AS NM_OFFSET,
        EC.NM_INSOLUTI
    FROM perimetro P
    INNER JOIN {{ ref('carte_estratto_conto_m') }} EC
        ON EC.CD_PRATICA = P.CD_PRATICA
    WHERE DATEDIFF('month', P.DT_DECORRENZA, EC.DT_OSSERVAZIONE) >= 0
      AND DATEDIFF('month', P.DT_DECORRENZA, EC.DT_OSSERVAZIONE) < 121
)

, worst AS (
    SELECT
        E.CD_PRATICA,
        E.TP_PROCEDURA,
        E.DT_OSSERVAZIONE
        {%- for n in mesi_offset %}
        , MAX(CASE WHEN E.NM_OFFSET = {{ n }} THEN E.NM_INSOLUTI END) AS NM_WORST{{ n }}
        {%- endfor %}
    FROM estratto_conto E
    GROUP BY
        E.CD_PRATICA,
        E.TP_PROCEDURA,
        E.DT_OSSERVAZIONE
)

SELECT
    P.CD_PRATICA,
    P.TP_PROCEDURA,
    P.CD_CLIENTE AS CD_CLIENTE,   
    P.DT_OSSERVAZIONE,       
    P.CD_STATO,
    CASE WHEN P.DT_PASSAGGIO_PERDITA IS NOT NULL OR P.DT_CESSIONE IS NOT NULL THEN 'S' ELSE 'N' END AS FL_PERDITA_CESSIONE,
    P.DT_CARICAMENTO,
    P.DT_CHIUSURA_EFFETTIVA AS DT_CHIUSURA,  -- WARN: DM_45 dice DT_CHIUSURA_DEFINITIVA, il perimetro espone DT_CHIUSURA_EFFETTIVA (come DM_44)
    CA.DT_PRIMO_UTILIZZO AS DT_PRIMO_MOV_REGISTR,
    P.DT_DBT,
    P.DT_PASSAGGIO_PERDITA AS DT_PERDITA,
    P.DT_CESSIONE,
    P.DT_PRIMA_SCADENZA AS DT_PRIMA_SCAD
    {%- for n in mesi_offset %}
    , W.NM_WORST{{ n }}
    {%- endfor %}
    , DATEDIFF('month', P.DT_DECORRENZA, P.DT_OSSERVAZIONE) AS NM_MESI
FROM perimetro P
LEFT JOIN carta CA
    ON CA.CD_PRATICA = P.CD_PRATICA
LEFT JOIN worst W
    ON W.CD_PRATICA = P.CD_PRATICA
   AND W.TP_PROCEDURA = P.TP_PROCEDURA
   AND W.DT_OSSERVAZIONE = P.DT_OSSERVAZIONE