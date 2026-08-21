-- DM_47 | DM_CMP_ACC_CO_MATRIX_M | 13_Campioni.Accettazione Agos
-- 307 colonne: 21 anagrafiche/date + 44 eventi (calamita'/moratoria, offset 0-10)
--              + 121 NM_IMP_CURRENT_ACCO (= NM_IMPAGATE, inclusi accodamenti)
--              + 121 NM_IMP_CURRENT      (= NM_IMPAGATE - NM_RATE_ACCODATE, esclusi)
-- Sorgenti: DM_CMP_ACC_PERIMETRO_CO, OXDRFEVSOS, OXDRFTBTES, INDICE_RISCHIO_M
-- Ancora dei DATEDIFF: DT_PRIMA_SCADENZA (esplicita in tutte le RT del DM_47).
--
-- WARN: DT_STORNATA esposta senza alias (colonna finale si chiama DT_STORNATA, il
--       DM la chiama DT_STORNO): valutare se rinominare in output.
-- WARN: DT_APPOGGIO usa DT_CHIUSURA_EFFETTIVA al posto di DT_CHIUSURA_FINALE (non
--       esposta separatamente dal perimetro).
-- WARN: CD_MACRO_MERCATO_2/3/4 sono i nomi DM; il perimetro espone
--       CD_MACRO_PRODOTTO_2/3/4 - aliasati nel SELECT.
--
-- EVENTI CALAMITA/MORATORIA - catena OXDRFEVSOS -> OXDRFTBTES:
--   OXDRFEVSOS (PK CD_CLIENTE, SCD storicizzata su TS_INIZIO/FINE_VALIDITA) assegna
--   il tipo evento (OXEVSOS_TIPO_EVENTO, VARCHAR(2), es. codice) al cliente.
--   OXDRFTBTES (PK OXTBTES_TIPO_EVENTO) e' il lookup con le date ufficiali
--   dell'evento (uguali per tutti i clienti con lo stesso tipo evento).
-- WARN CRITICO: OXEVSOS_TIPO_EVENTO e OXTBTES_TIPO_EVENTO sono entrambi vuoti in
--       dev (0 righe), quindi il match fra i due domini (codice vs 'CALAMITA'/
--       'MORATORIA') NON E' VERIFICABILE in questo ambiente. Le 44 colonne evento
--       usciranno NULL finche' le tabelle non sono popolate. Se i domini non
--       corrispondono servira' una tabella di mapping codice<->descrizione: da
--       chiarire con Tommaso prima del rilascio.
-- WARN: FL_DELETED su OXDRFEVSOS - verificare il valore reale del flag di
--       soft-delete ('N'/'S' oppure 0/1) prima di eseguire in un ambiente con dati.

{% set mesi_eventi = range(0, 11) %}
{% set mesi_impagati = range(0, 121) %}

WITH perimetro AS (
    SELECT
        P.CD_PRATICA,
        P.TP_PROCEDURA,
        P.DT_OSSERVAZIONE,
        P.CD_CLIENTE,
        P.CD_MERCATO_1,
        P.CD_MERCATO_2,
        P.CD_MERCATO_3,
        P.CD_MERCATO_4,
        P.CD_MACRO_PRODOTTO_1,
        P.CD_MACRO_PRODOTTO_2,
        P.CD_MACRO_PRODOTTO_3,
        P.CD_MACRO_PRODOTTO_4,
        P.CD_STATO,
        P.DT_PASSAGGIO_PERDITA,
        P.DT_CESSIONE,
        P.DT_PRIMA_SCADENZA,
        P.DT_STORNATA,
        P.DT_CHIUSURA_EFFETTIVA,
        P.DT_DBT,
        P.DT_ESTINZIONE_ANTICIPATA
    FROM {{ ref('dm_cmp_acc_perimetro_co') }} P
    WHERE
       P.CD_STATO IN ('30', '50', '51', '55', '96', '97')
    {% if is_incremental() %}
      AND P.DT_OSSERVAZIONE = {{ last_day_past_month() }}
    {% endif %}
    QUALIFY ROW_NUMBER() OVER (PARTITION BY P.CD_PRATICA, P.TP_PROCEDURA, P.DT_OSSERVAZIONE ORDER BY 1) = 1
)

-- Eventi CALAMITA/MORATORIA: perimetro -> OXDRFEVSOS (as-of su CD_CLIENTE) ->
-- OXDRFTBTES (lookup su tipo evento). Join + pivot in un unico passaggio.
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

-- NM_IMP_CURRENT_ACCO* e NM_IMP_CURRENT*: da INDICE_RISCHIO_M, join + pivot in un
-- unico passaggio.
, impagati_pivot AS (
    SELECT
        P.CD_PRATICA,
        P.TP_PROCEDURA,
        P.DT_OSSERVAZIONE
        {%- for n in mesi_impagati %}
        , MAX(CASE WHEN DATEDIFF('month', P.DT_PRIMA_SCADENZA, IR.DT_OSSERVAZIONE) = {{ n }} THEN IR.NM_IMPAGATE END)                          AS NM_IMP_CURRENT_ACCO{{ n }}
        {%- endfor %}
        {%- for n in mesi_impagati %}
        , MAX(CASE WHEN DATEDIFF('month', P.DT_PRIMA_SCADENZA, IR.DT_OSSERVAZIONE) = {{ n }} THEN IR.NM_IMPAGATE - IR.NM_RATE_ACCODATE END)     AS NM_IMP_CURRENT{{ n }}
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
    P.DT_OSSERVAZIONE,
    P.CD_MERCATO_1,
    P.CD_MERCATO_2,
    P.CD_MERCATO_3,
    P.CD_MERCATO_4,
    P.CD_MACRO_PRODOTTO_1,
    P.CD_MACRO_PRODOTTO_2 AS CD_MACRO_MERCATO_2,
    P.CD_MACRO_PRODOTTO_3 AS CD_MACRO_MERCATO_3,
    P.CD_MACRO_PRODOTTO_4 AS CD_MACRO_MERCATO_4,
    P.CD_STATO,
    DATEDIFF('month', P.DT_PRIMA_SCADENZA, P.DT_OSSERVAZIONE) AS NM_MESI_VALUTAZIONE,
    P.DT_PASSAGGIO_PERDITA AS DT_PERDITA,
    P.DT_CESSIONE,
    P.DT_PRIMA_SCADENZA AS DT_PRIMA_SCAD,
    P.DT_STORNATA AS DT_STORNATA,
    COALESCE(P.DT_CHIUSURA_EFFETTIVA, P.DT_CESSIONE, P.DT_PASSAGGIO_PERDITA) AS DT_APPOGGIO,
    P.DT_CHIUSURA_EFFETTIVA AS DT_CHIUSURA_GEST,
    P.DT_DBT,
    P.DT_ESTINZIONE_ANTICIPATA AS DT_ESTINZIONE_ANTI
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
    {%- for n in mesi_impagati %}
    , IP.NM_IMP_CURRENT_ACCO{{ n }}
    {%- endfor %}
    {%- for n in mesi_impagati %}
    , IP.NM_IMP_CURRENT{{ n }}
    {%- endfor %}
FROM perimetro P
LEFT JOIN eventi_pivot EV
    ON EV.CD_PRATICA = P.CD_PRATICA
   AND EV.TP_PROCEDURA = P.TP_PROCEDURA
   AND EV.DT_OSSERVAZIONE = P.DT_OSSERVAZIONE
LEFT JOIN impagati_pivot IP
    ON IP.CD_PRATICA = P.CD_PRATICA
   AND IP.TP_PROCEDURA = P.TP_PROCEDURA
   AND IP.DT_OSSERVAZIONE = P.DT_OSSERVAZIONE