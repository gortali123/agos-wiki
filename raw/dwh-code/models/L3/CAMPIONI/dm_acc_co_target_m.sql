-- DM_46 | dm_acc_co_target_m | 13_Campioni.Accettazione Agos
-- 307 colonne: 20 anagrafiche/date + 44 eventi (calamita'/moratoria, offset 0-10)
--              + 1 NM_MESI_VALUTAZIONE
--              + 121 NM_WORST_ACCO (= NM_MAX_RATE_IMPAGATE, inclusi accodamenti)
--              + 121 NM_WORST      (= NM_MAX_RATE_IMPAGATE - NM_RATE_ACCODATE, esclusi)
-- Sorgenti: DM_CMP_ACC_PERIMETRO_CO, SOCIODEMO_SCORE_TEST, OXDRFEVSOS, OXDRFTBTES,
--           INDICE_RISCHIO_M
-- Ancora dei DATEDIFF: DT_PRIMA_SCADENZA
--
-- WARN: DT_INSERIMENTO da SOCIODEMO_SCORE_TEST: il DM non specifica le chiavi di
--       aggancio (KEYS=NA). La tabella ha piu' righe per (CD_PRATICA, TP_PROCEDURA):
--       almeno una per CD_CONTROPARTE (cliente/coobligato) e una per ogni
--       DT_OSSERVAZIONE storica (vedi dm_campioni_sviluppo_m). Qui si assume che
--       DT_INSERIMENTO sia riferito al CLIENTE nel mese corrente: dedup su
--       (CD_PRATICA, TP_PROCEDURA, DT_OSSERVAZIONE, CD_CONTROPARTE) e filtro
--       CD_CONTROPARTE = CD_CLIENTE, altrimenti il join genera fan-out (duplica
--       le righe del perimetro).
-- WARN CRITICO: catena eventi OXDRFEVSOS -> OXDRFTBTES non verificabile in dev,
--       entrambe le tabelle sono vuote (0 righe). Il join fra OXEVSOS_TIPO_EVENTO
--       (VARCHAR(2), presumibilmente un codice) e OXTBTES_TIPO_EVENTO (filtrato
--       su 'CALAMITA'/'MORATORIA') non e' testabile: se i domini non
--       corrispondono servira' una tabella di mapping. Da chiarire con Tommaso.
-- WARN: DT_STORNO sourced da DT_STORNATA sul perimetro.

{% set mesi_eventi = range(0, 11) %}
{% set mesi_impagati = range(0, 121) %}

WITH perimetro AS (
    SELECT
        P.CD_PRATICA,
        P.TP_PROCEDURA,
        P.DT_OSSERVAZIONE,
        P.CD_CLIENTE,
        P.CD_STATO,
        P.CD_MACRO_PRODOTTO_1,
        P.CD_MACRO_PRODOTTO_2,
        P.CD_MACRO_PRODOTTO_3,
        P.CD_MACRO_PRODOTTO_4,
        P.CD_MERCATO_1,
        P.CD_MERCATO_2,
        P.CD_MERCATO_3,
        P.CD_MERCATO_4,
        P.DT_CHIUSURA_EFFETTIVA,
        P.DT_DBT,
        P.DT_ESTINZIONE_ANTICIPATA,
        P.DT_PASSAGGIO_PERDITA,
        P.DT_PRIMA_SCADENZA,
        P.DT_STORNATA
    FROM {{ ref('dm_cmp_acc_perimetro_co') }} P
    WHERE
       P.CD_STATO IN ('30', '50', '51', '55', '96', '97')
    {% if is_incremental() %}
      AND P.DT_OSSERVAZIONE = {{ last_day_past_month() }}
    {% endif %}
    QUALIFY ROW_NUMBER() OVER (PARTITION BY P.CD_PRATICA, P.TP_PROCEDURA, P.DT_OSSERVAZIONE ORDER BY 1) = 1
)

-- DT_INSERIMENTO da SOCIODEMO_SCORE_TEST: dedup su CD_CONTROPARTE + DT_OSSERVAZIONE
-- per evitare il fan-out (vedi WARN in testa al file).
, sociodemo AS (
    SELECT
        S.CD_PRATICA,
        S.TP_PROCEDURA,
        S.DT_OSSERVAZIONE,
        S.CD_CONTROPARTE
    FROM AGOS_DEV_16000.L2_SCORING.SOCIODEMO_SCORE_TEST S
    QUALIFY ROW_NUMBER() OVER (PARTITION BY S.CD_PRATICA, S.TP_PROCEDURA, S.DT_OSSERVAZIONE, S.CD_CONTROPARTE ORDER BY 1) = 1
)

-- Eventi CALAMITA/MORATORIA: perimetro -> OXDRFEVSOS (as-of su CD_CLIENTE) ->
-- OXDRFTBTES (lookup su tipo evento). Vedi WARN CRITICO in testa al file.
, eventi_pivot AS (
    SELECT
        P.CD_PRATICA,
        P.TP_PROCEDURA,
        P.DT_OSSERVAZIONE
        {%- for n in mesi_eventi %}
        , MAX(CASE WHEN OX.OXTBTES_TIPO_EVENTO = 'CALAMITA'  AND DATEDIFF('month', P.DT_PRIMA_SCADENZA, OX.OXTBTES_DATA_INIZIO) = {{ n }} THEN OX.OXTBTES_DATA_FINE END)    AS DT_CALA_FINE_{{ n }}
        {%- endfor %}
        {%- for n in mesi_eventi %}
        , MAX(CASE WHEN OX.OXTBTES_TIPO_EVENTO = 'CALAMITA'  AND DATEDIFF('month', P.DT_PRIMA_SCADENZA, OX.OXTBTES_DATA_INIZIO) = {{ n }} THEN OX.OXTBTES_DATA_INIZIO END)  AS DT_CALA_INIZ_{{ n }}
        {%- endfor %}
        {%- for n in mesi_eventi %}
        , MAX(CASE WHEN OX.OXTBTES_TIPO_EVENTO = 'MORATORIA' AND DATEDIFF('month', P.DT_PRIMA_SCADENZA, OX.OXTBTES_DATA_INIZIO) = {{ n }} THEN OX.OXTBTES_DATA_FINE END)    AS DT_MORA_FINE_{{ n }}
        {%- endfor %}
        {%- for n in mesi_eventi %}
        , MAX(CASE WHEN OX.OXTBTES_TIPO_EVENTO = 'MORATORIA' AND DATEDIFF('month', P.DT_PRIMA_SCADENZA, OX.OXTBTES_DATA_INIZIO) = {{ n }} THEN OX.OXTBTES_DATA_INIZIO END)  AS DT_MORA_INIZ_{{ n }}
        {%- endfor %}
    FROM perimetro P
    LEFT JOIN AGOS_DEV_16000.L1_O_SDS.OXDRFEVSOS EV
        ON EV.OXEVSOS_CLIENTE = P.CD_CLIENTE
       AND EV.FL_DELETED = 'N'  -- WARN: verificare valore reale del flag
       AND P.DT_OSSERVAZIONE >= EV.TS_INIZIO_VALIDITA
       AND (EV.TS_FINE_VALIDITA IS NULL OR P.DT_OSSERVAZIONE < EV.TS_FINE_VALIDITA)
    LEFT JOIN {{ ref('oxdrftbtes') }} OX
        ON OX.OXTBTES_TIPO_EVENTO = EV.OXEVSOS_TIPO_EVENTO  -- WARN CRITICO: domini non verificabili, vedi header
       AND OX.OXTBTES_TIPO_EVENTO IN ('CALAMITA', 'MORATORIA')
       AND DATEDIFF('month', P.DT_PRIMA_SCADENZA, OX.OXTBTES_DATA_INIZIO) BETWEEN 0 AND 10
    GROUP BY P.CD_PRATICA, P.TP_PROCEDURA, P.DT_OSSERVAZIONE
)

-- NM_WORST_ACCO* e NM_WORST*: da INDICE_RISCHIO_M, join + pivot in un unico passaggio
, worst_pivot AS (
    SELECT
        P.CD_PRATICA,
        P.TP_PROCEDURA,
        P.DT_OSSERVAZIONE
        {%- for n in mesi_impagati %}
        , MAX(CASE WHEN DATEDIFF('month', P.DT_PRIMA_SCADENZA, IR.DT_OSSERVAZIONE) = {{ n }} THEN IR.NM_MAX_RATE_IMPAGATE END)                              AS NM_WORST_ACCO{{ n }}
        {%- endfor %}
        {%- for n in mesi_impagati %}
        , MAX(CASE WHEN DATEDIFF('month', P.DT_PRIMA_SCADENZA, IR.DT_OSSERVAZIONE) = {{ n }} THEN IR.NM_MAX_RATE_IMPAGATE - IR.NM_RATE_ACCODATE END)         AS NM_WORST{{ n }}
        {%- endfor %}
    FROM perimetro P
    INNER JOIN {{ ref('indice_rischio_m') }} IR
        ON IR.CD_PRATICA = P.CD_PRATICA
       AND IR.TP_PROCEDURA = P.TP_PROCEDURA
       AND DATEDIFF('month', P.DT_PRIMA_SCADENZA, IR.DT_OSSERVAZIONE) BETWEEN 0 AND 120
    GROUP BY P.CD_PRATICA, P.TP_PROCEDURA, P.DT_OSSERVAZIONE
)

SELECT
    P.CD_PRATICA,
    P.TP_PROCEDURA,
    P.CD_CLIENTE AS CD_CLEINTE,      -- FIX: typo nel DM, mantenuto per aderenza
    P.DT_OSSERVAZIONE,
    P.CD_STATO AS CD_STATO_PRAT,
    P.CD_MACRO_PRODOTTO_1,
    P.CD_MACRO_PRODOTTO_2,
    P.CD_MACRO_PRODOTTO_3,
    P.CD_MACRO_PRODOTTO_4,
    P.CD_MERCATO_1,
    P.CD_MERCATO_2,
    P.CD_MERCATO_3,
    P.CD_MERCATO_4,
    SD.DT_OSSERVAZIONE AS DT_INSERIMENTO,
    P.DT_CHIUSURA_EFFETTIVA AS DT_CHIUSURA_GEST,
    P.DT_DBT,
    P.DT_ESTINZIONE_ANTICIPATA AS DT_ESTINZIONE_ANTI,
    P.DT_PASSAGGIO_PERDITA AS DT_PERDITA,
    P.DT_PRIMA_SCADENZA AS DT_PRIMA_SCAD,
    P.DT_STORNATA AS DT_STORNATA
    {%- for n in mesi_eventi %}
    , EV.DT_CALA_FINE_{{ n }}
    {%- endfor %}
    {%- for n in mesi_eventi %}
    , EV.DT_CALA_INIZ_{{ n }}
    {%- endfor %}
    {%- for n in mesi_eventi %}
    , EV.DT_MORA_FINE_{{ n }}
    {%- endfor %}
    {%- for n in mesi_eventi %}
    , EV.DT_MORA_INIZ_{{ n }}
    {%- endfor %}
    , DATEDIFF('month', P.DT_PRIMA_SCADENZA, P.DT_OSSERVAZIONE) AS NM_MESI_VALUTAZIONE
    {%- for n in mesi_impagati %}
    , WP.NM_WORST_ACCO{{ n }}
    {%- endfor %}
    {%- for n in mesi_impagati %}
    , WP.NM_WORST{{ n }}
    {%- endfor %}
FROM perimetro P
LEFT JOIN sociodemo SD
    ON SD.CD_PRATICA = P.CD_PRATICA
   AND SD.TP_PROCEDURA = P.TP_PROCEDURA
   AND SD.DT_OSSERVAZIONE = P.DT_OSSERVAZIONE
   AND SD.CD_CONTROPARTE = P.CD_CLIENTE
LEFT JOIN eventi_pivot EV
    ON EV.CD_PRATICA = P.CD_PRATICA
   AND EV.TP_PROCEDURA = P.TP_PROCEDURA
   AND EV.DT_OSSERVAZIONE = P.DT_OSSERVAZIONE
LEFT JOIN worst_pivot WP
    ON WP.CD_PRATICA = P.CD_PRATICA
   AND WP.TP_PROCEDURA = P.TP_PROCEDURA
   AND WP.DT_OSSERVAZIONE = P.DT_OSSERVAZIONE